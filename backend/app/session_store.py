from __future__ import annotations

import json
import sqlite3
import threading
from datetime import datetime, timezone
from typing import Any


def utc_now_iso() -> str:
	return datetime.now(timezone.utc).isoformat()


class SessionStore:
	def __init__(self, sqlite_path: str) -> None:
		self._lock = threading.Lock()
		self._connection = sqlite3.connect(sqlite_path, check_same_thread=False)
		self._connection.row_factory = sqlite3.Row
		with self._lock:
			self._connection.execute("PRAGMA journal_mode=WAL")
			self._connection.execute("PRAGMA synchronous=NORMAL")
			self._ensure_schema()

	def close(self) -> None:
		with self._lock:
			self._connection.close()

	def _ensure_schema(self) -> None:
		self._connection.executescript(
			"""
			CREATE TABLE IF NOT EXISTS dialogue_turns (
				id INTEGER PRIMARY KEY AUTOINCREMENT,
				session_id TEXT NOT NULL,
				turn_index INTEGER NOT NULL,
				world_id TEXT NOT NULL,
				main_character_ids_json TEXT NOT NULL,
				narration TEXT NOT NULL,
				dialogue TEXT NOT NULL,
				action TEXT NOT NULL,
				scene_mode TEXT NOT NULL,
				background_id TEXT NOT NULL,
				cg_id TEXT NOT NULL,
				transition TEXT NOT NULL,
				camera_fx TEXT NOT NULL,
				relationship_delta_json TEXT NOT NULL,
				set_flags_json TEXT NOT NULL,
				content_rating TEXT NOT NULL,
				bgm_id TEXT NOT NULL,
				sfx_id TEXT NOT NULL,
				volume_profile TEXT NOT NULL,
				summary_candidate TEXT NOT NULL,
				created_at TEXT NOT NULL,
				UNIQUE(session_id, turn_index)
			);
			CREATE INDEX IF NOT EXISTS dialogue_turns_session_turn_idx
			ON dialogue_turns(session_id, turn_index);

			CREATE TABLE IF NOT EXISTS session_memory (
				session_id TEXT PRIMARY KEY,
				prompt_summary_cache TEXT NOT NULL,
				source_turn_index INTEGER NOT NULL DEFAULT 0,
				updated_at TEXT NOT NULL
			);
			"""
		)
		self._connection.commit()

	def reset_session(self, session_id: str) -> None:
		with self._lock:
			self._connection.execute("DELETE FROM dialogue_turns WHERE session_id = ?", (session_id,))
			self._connection.execute("DELETE FROM session_memory WHERE session_id = ?", (session_id,))
			self._connection.commit()

	def get_next_turn_index(self, session_id: str) -> int:
		with self._lock:
			row = self._connection.execute(
				"SELECT COALESCE(MAX(turn_index), 0) AS max_turn_index FROM dialogue_turns WHERE session_id = ?",
				(session_id,),
			).fetchone()
		return int(row["max_turn_index"]) + 1 if row is not None else 1

	def get_prompt_summary_cache(self, session_id: str) -> str:
		with self._lock:
			row = self._connection.execute(
				"SELECT prompt_summary_cache FROM session_memory WHERE session_id = ?",
				(session_id,),
			).fetchone()
		if row is None:
			return ""
		return str(row["prompt_summary_cache"] or "").strip()

	def upsert_prompt_summary_cache(self, session_id: str, prompt_summary_cache: str, source_turn_index: int) -> None:
		with self._lock:
			self._connection.execute(
				"""
				INSERT INTO session_memory(session_id, prompt_summary_cache, source_turn_index, updated_at)
				VALUES(?, ?, ?, ?)
				ON CONFLICT(session_id) DO UPDATE SET
					prompt_summary_cache = excluded.prompt_summary_cache,
					source_turn_index = excluded.source_turn_index,
					updated_at = excluded.updated_at
				""",
				(session_id, prompt_summary_cache, source_turn_index, utc_now_iso()),
			)
			self._connection.commit()

	def append_dialogue_turn(self, session_id: str, source_payload: dict[str, Any], normalized_payload: dict[str, Any]) -> int:
		turn_index = self.get_next_turn_index(session_id)
		world = source_payload.get("world", {}) if isinstance(source_payload.get("world", {}), dict) else {}
		persona = source_payload.get("persona", {}) if isinstance(source_payload.get("persona", {}), dict) else {}
		main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
		main_character_ids = [
			str(character.get("id", "")).strip()
			for character in main_characters
			if isinstance(character, dict) and str(character.get("id", "")).strip()
		]

		content = normalized_payload.get("content", {}) if isinstance(normalized_payload.get("content", {}), dict) else {}
		direction = normalized_payload.get("direction", {}) if isinstance(normalized_payload.get("direction", {}), dict) else {}
		state_update = normalized_payload.get("state_update", {}) if isinstance(normalized_payload.get("state_update", {}), dict) else {}
		memory_hint = normalized_payload.get("memory_hint", {}) if isinstance(normalized_payload.get("memory_hint", {}), dict) else {}
		audio = normalized_payload.get("audio", {}) if isinstance(normalized_payload.get("audio", {}), dict) else {}

		with self._lock:
			self._connection.execute(
				"""
				INSERT INTO dialogue_turns(
					session_id,
					turn_index,
					world_id,
					main_character_ids_json,
					narration,
					dialogue,
					action,
					scene_mode,
					background_id,
					cg_id,
					transition,
					camera_fx,
					relationship_delta_json,
					set_flags_json,
					content_rating,
					bgm_id,
					sfx_id,
					volume_profile,
					summary_candidate,
					created_at
				)
				VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
				""",
				(
					session_id,
					turn_index,
					str(world.get("selected_world_id", "")).strip(),
					json.dumps(main_character_ids, ensure_ascii=False),
					str(content.get("narration", "")),
					str(content.get("dialogue", "")),
					str(content.get("action", "")),
					str(direction.get("scene_mode", "")),
					str(direction.get("background_id", "")),
					str(direction.get("cg_id", "")),
					str(direction.get("transition", "")),
					str(direction.get("camera_fx", "")),
					json.dumps(state_update.get("relationship_delta", {}), ensure_ascii=False, sort_keys=True),
					json.dumps(state_update.get("set_flags", []), ensure_ascii=False),
					str(state_update.get("content_rating", "")),
					str(audio.get("bgm_id", "")),
					str(audio.get("sfx_id", "")),
					str(audio.get("volume_profile", "")),
					str(memory_hint.get("summary_candidate", "")),
					utc_now_iso(),
				),
			)
			self._connection.execute(
				"DELETE FROM dialogue_turns WHERE session_id = ? AND turn_index <= ?",
				(session_id, max(turn_index - 24, 0)),
			)
			self._connection.commit()
		return turn_index

	def get_recent_turns(self, session_id: str, limit: int = 6) -> list[dict[str, Any]]:
		with self._lock:
			rows = self._connection.execute(
				"""
				SELECT
					session_id,
					turn_index,
					world_id,
					main_character_ids_json,
					narration,
					dialogue,
					action,
					scene_mode,
					background_id,
					cg_id,
					transition,
					camera_fx,
					relationship_delta_json,
					set_flags_json,
					content_rating,
					bgm_id,
					sfx_id,
					volume_profile,
					summary_candidate,
					created_at
				FROM dialogue_turns
				WHERE session_id = ?
				ORDER BY turn_index DESC
				LIMIT ?
				""",
				(session_id, limit),
			).fetchall()

		result: list[dict[str, Any]] = []
		for row in reversed(rows):
			result.append(
				{
					"session_id": str(row["session_id"]),
					"turn_index": int(row["turn_index"]),
					"world_id": str(row["world_id"]),
					"main_character_ids": json.loads(str(row["main_character_ids_json"] or "[]")),
					"narration": str(row["narration"]),
					"dialogue": str(row["dialogue"]),
					"action": str(row["action"]),
					"scene_mode": str(row["scene_mode"]),
					"background_id": str(row["background_id"]),
					"cg_id": str(row["cg_id"]),
					"transition": str(row["transition"]),
					"camera_fx": str(row["camera_fx"]),
					"relationship_delta": json.loads(str(row["relationship_delta_json"] or "{}")),
					"set_flags": json.loads(str(row["set_flags_json"] or "[]")),
					"content_rating": str(row["content_rating"]),
					"bgm_id": str(row["bgm_id"]),
					"sfx_id": str(row["sfx_id"]),
					"volume_profile": str(row["volume_profile"]),
					"summary_candidate": str(row["summary_candidate"]),
					"created_at": str(row["created_at"]),
				}
			)
		return result
