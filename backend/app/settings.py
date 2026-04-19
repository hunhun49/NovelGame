from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any


def get_env_int(name: str, default: int, minimum: int) -> int:
	raw_value = os.getenv(name, str(default)).strip()
	try:
		return max(int(raw_value), minimum)
	except ValueError:
		return default


def get_env_float(name: str, default: float, minimum: float) -> float:
	raw_value = os.getenv(name, str(default)).strip()
	try:
		return max(float(raw_value), minimum)
	except ValueError:
		return default


def get_env_choice(name: str, default: str, allowed_values: set[str]) -> str:
	raw_value = os.getenv(name, default).strip().lower()
	return raw_value if raw_value in allowed_values else default


@dataclass(slots=True)
class BackendSettings:
	ollama_host: str
	ollama_model: str
	ollama_dialogue_base_language: str
	ollama_keep_alive: str
	ollama_request_timeout_seconds: float
	ollama_health_timeout_seconds: float
	ollama_num_predict: int
	ollama_num_ctx: int
	ollama_context_length: int
	ollama_temperature: float
	ollama_top_p: float
	ollama_repeat_penalty: float
	prewarm_strategy: str
	backend_warm_min_vram_ratio: float
	backend_warm_min_expires_seconds: int
	backend_sqlite_path: str
	max_candidate_items: int = 3
	max_recent_items: int = 4
	max_text_length: int = 140
	target_script_min_length: int = 220
	target_script_max_length: int = 340
	min_acceptable_script_length: int = 180
	min_narration_length: int = 48
	min_dialogue_length: int = 16
	min_action_length: int = 12
	max_profile_text_length: int = 96
	max_style_examples: int = 1
	max_style_traits: int = 3
	max_world_rules: int = 2
	max_story_examples: int = 1
	max_prompt_summary_length: int = 320

	@property
	def effective_num_ctx(self) -> int:
		return max(self.ollama_num_ctx, self.ollama_context_length if self.ollama_context_length > 0 else 0)

	@property
	def ollama_response_schema(self) -> dict[str, Any]:
		return {
			"type": "object",
			"required": ["content", "direction"],
			"properties": {
				"content": {
					"type": "object",
					"required": ["narration", "dialogue", "action"],
					"properties": {
						"narration": {"type": "string", "minLength": 1},
						"dialogue": {"type": "string", "minLength": 1},
						"action": {"type": "string", "minLength": 1},
					},
				},
				"direction": {
					"type": "object",
					"required": ["scene_mode", "background_id", "character_states", "cg_id", "transition", "camera_fx"],
					"properties": {
						"scene_mode": {"type": "string", "enum": ["layered", "cg"]},
						"background_id": {"type": "string"},
						"character_states": {
							"type": "array",
							"items": {
								"type": "object",
								"required": ["character_id", "sprite_id", "position"],
								"properties": {
									"character_id": {"type": "string"},
									"sprite_id": {"type": "string"},
									"position": {"type": "string", "enum": ["left", "center", "right"]},
									"emotion": {"type": "string", "enum": ["neutral", "joy", "sad", "angry"]},
								},
							},
						},
						"cg_id": {"type": "string"},
						"transition": {"type": "string", "enum": ["cut", "fade", "crossfade"]},
						"camera_fx": {"type": "string", "enum": ["none", "dim"]},
					},
				},
			},
		}

	@classmethod
	def from_env(cls) -> "BackendSettings":
		backend_dir = Path(__file__).resolve().parent.parent
		default_sqlite_path = str((backend_dir / "backend_state.sqlite3").resolve())
		return cls(
			ollama_host=os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/"),
			ollama_model=os.getenv("OLLAMA_MODEL", "gemma4:e4b"),
			ollama_dialogue_base_language=get_env_choice("OLLAMA_DIALOGUE_BASE_LANGUAGE", "kr", {"auto", "jp", "en", "kr"}),
			ollama_keep_alive=os.getenv("OLLAMA_KEEP_ALIVE", "20m").strip() or "20m",
			ollama_request_timeout_seconds=get_env_float("OLLAMA_REQUEST_TIMEOUT_SECONDS", 40.0, 5.0),
			ollama_health_timeout_seconds=get_env_float("OLLAMA_HEALTH_TIMEOUT_SECONDS", 5.0, 1.0),
			ollama_num_predict=get_env_int("OLLAMA_NUM_PREDICT", 320, 32),
			ollama_num_ctx=get_env_int("OLLAMA_NUM_CTX", 4096, 512),
			ollama_context_length=get_env_int("OLLAMA_CONTEXT_LENGTH", 0, 0),
			ollama_temperature=get_env_float("OLLAMA_TEMPERATURE", 0.4, 0.0),
			ollama_top_p=get_env_float("OLLAMA_TOP_P", 0.9, 0.1),
			ollama_repeat_penalty=get_env_float("OLLAMA_REPEAT_PENALTY", 1.10, 1.0),
			prewarm_strategy=get_env_choice("PREWARM_STRATEGY", "empty_request", {"empty_request", "single_token_probe"}),
			backend_warm_min_vram_ratio=get_env_float("BACKEND_WARM_MIN_VRAM_RATIO", 0.85, 0.0),
			backend_warm_min_expires_seconds=get_env_int("BACKEND_WARM_MIN_EXPIRES_SECONDS", 120, 0),
			backend_sqlite_path=os.getenv("BACKEND_SQLITE_PATH", default_sqlite_path).strip() or default_sqlite_path,
		)


settings = BackendSettings.from_env()
