import json
import os
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException


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


OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://127.0.0.1:11434").rstrip("/")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5:7b")
OLLAMA_KEEP_ALIVE = os.getenv("OLLAMA_KEEP_ALIVE", "20m").strip() or "20m"
OLLAMA_REQUEST_TIMEOUT_SECONDS = get_env_float("OLLAMA_REQUEST_TIMEOUT_SECONDS", 25.0, 5.0)
OLLAMA_HEALTH_TIMEOUT_SECONDS = get_env_float("OLLAMA_HEALTH_TIMEOUT_SECONDS", 5.0, 1.0)
OLLAMA_NUM_PREDICT = get_env_int("OLLAMA_NUM_PREDICT", 140, 32)
OLLAMA_NUM_CTX = get_env_int("OLLAMA_NUM_CTX", 2048, 512)
OLLAMA_TEMPERATURE = get_env_float("OLLAMA_TEMPERATURE", 0.25, 0.0)
OLLAMA_TOP_P = get_env_float("OLLAMA_TOP_P", 0.8, 0.1)
MAX_CANDIDATE_ITEMS = 3
MAX_RECENT_ITEMS = 3
MAX_TEXT_LENGTH = 140
OLLAMA_CLIENT_LIMITS = httpx.Limits(max_keepalive_connections=4, max_connections=8)

app = FastAPI(title="NovelGame Ollama Backend")
ollama_client: httpx.AsyncClient | None = None


def get_ollama_client() -> httpx.AsyncClient:
	global ollama_client
	if ollama_client is None:
		ollama_client = httpx.AsyncClient(timeout=OLLAMA_REQUEST_TIMEOUT_SECONDS, limits=OLLAMA_CLIENT_LIMITS)
	return ollama_client


@app.on_event("shutdown")
async def shutdown_ollama_client() -> None:
	global ollama_client
	if ollama_client is None:
		return
	await ollama_client.aclose()
	ollama_client = None


@app.get("/health")
async def health() -> dict[str, Any]:
	status = "healthy"
	message = "Ollama backend is ready."

	try:
		client = get_ollama_client()
		response = await client.get(f"{OLLAMA_HOST}/api/tags", timeout=OLLAMA_HEALTH_TIMEOUT_SECONDS)
		response.raise_for_status()
		payload = response.json()
		model_names = [str(model.get("name", "")) for model in payload.get("models", [])]
		if not any(name.startswith(OLLAMA_MODEL) for name in model_names):
			status = "degraded"
			message = "Ollama is reachable but the configured model is not pulled yet."
		return {
			"status": status,
			"message": message,
			"ready": status == "healthy",
			"provider": "ollama",
			"model": OLLAMA_MODEL,
			"latency_profile": {
				"timeout_seconds": OLLAMA_REQUEST_TIMEOUT_SECONDS,
				"num_predict": OLLAMA_NUM_PREDICT,
				"keep_alive": OLLAMA_KEEP_ALIVE,
			},
		}
	except Exception as exc:
		return {
			"status": "unhealthy",
			"message": f"Failed to reach Ollama: {exc}",
			"ready": False,
			"provider": "ollama",
			"model": OLLAMA_MODEL,
		}


@app.post("/v1/story/turn")
async def story_turn(payload: dict[str, Any]) -> dict[str, Any]:
	try:
		prompt = build_ollama_prompt(payload)
		response_text = await generate_with_ollama(prompt)
		parsed = try_parse_json_block(response_text)
		if parsed is None:
			return build_fallback_response(payload, response_text)
		return normalize_turn_response(payload, parsed)
	except httpx.TimeoutException:
		return build_fallback_response(payload, "", "ollama_timeout")
	except httpx.HTTPError as exc:
		raise HTTPException(status_code=502, detail=f"Ollama request failed: {exc}")
	except HTTPException:
		raise
	except Exception as exc:
		raise HTTPException(status_code=500, detail=f"Failed to generate turn: {exc}")


async def generate_with_ollama(prompt: str) -> str:
	request_payload = {
		"model": OLLAMA_MODEL,
		"prompt": prompt,
		"stream": False,
		"format": "json",
		"keep_alive": OLLAMA_KEEP_ALIVE,
		"options": {
			"temperature": OLLAMA_TEMPERATURE,
			"top_p": OLLAMA_TOP_P,
			"num_predict": OLLAMA_NUM_PREDICT,
			"num_ctx": OLLAMA_NUM_CTX,
		},
	}

	client = get_ollama_client()
	response = await client.post(f"{OLLAMA_HOST}/api/generate", json=request_payload)
	response.raise_for_status()
	payload = response.json()
	return str(payload.get("response", "")).strip()


def build_ollama_prompt(payload: dict[str, Any]) -> str:
	persona = payload.get("persona", {})
	world = payload.get("world", {})
	runtime_state = payload.get("runtime_state", {})
	asset_candidates = payload.get("asset_candidates", {})
	recent_conversation = payload.get("recent_conversation", [])
	world_profile = world.get("profile", {}) if isinstance(world.get("profile", {}), dict) else {}
	main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
	player_character = persona.get("player_character", {}) if isinstance(persona.get("player_character", {}), dict) else {}
	player_input = trim_text(runtime_state.get("pending_player_input", ""), MAX_TEXT_LENGTH) or "다음 장면을 진행해 줘"
	world_name = trim_text(world_profile.get("story_title", "") or world_profile.get("name_ko", "선택된 세계관"), 80)
	main_character_names = [trim_text((character or {}).get("name_ko", ""), 32) for character in main_characters if isinstance(character, dict)]
	main_character_names = [name for name in main_character_names if name]
	player_name = trim_text(player_character.get("name_ko", "") or persona.get("player_name", "플레이어"), 32)
	compact_payload = {
		"world": {
			"name": world_name,
			"location": trim_text(world.get("location_id", ""), 40),
			"rating": trim_text(world.get("rating_lane", "general"), 16),
		},
		"cast": {
			"player": player_name,
			"main": main_character_names[:2],
		},
		"runtime": {
			"input": player_input,
			"scene_mode": trim_text(runtime_state.get("scene_mode", "layered"), 16),
		},
		"recent": summarize_recent_conversation(recent_conversation),
		"assets": summarize_asset_candidates(asset_candidates),
	}

	prompt_lines = [
		"너는 한국어 비주얼 노벨 턴 생성기다.",
		"JSON 객체 하나만 출력한다.",
		"문장은 짧고 자연스럽게 쓴다.",
		"assets 후보 ID만 사용한다.",
		"scene_mode=layered|cg, position=left|center|right.",
		"content_rating=general|mature|adult|extreme.",
		"대화는 1~2문장, narration/action도 짧게 유지한다.",
		"키: content,direction,state_update,memory_hint,audio.",
		json.dumps(compact_payload, ensure_ascii=False, separators=(",", ":")),
	]
	return "\n".join(prompt_lines)


def summarize_recent_conversation(recent_conversation: Any) -> list[str]:
	if not isinstance(recent_conversation, list):
		return []

	result: list[str] = []
	for item in recent_conversation[-MAX_RECENT_ITEMS:]:
		if not isinstance(item, dict):
			continue
		role = trim_text(item.get("role", "?"), 12)
		text = trim_text(item.get("text", ""), MAX_TEXT_LENGTH)
		if text:
			result.append(f"{role}:{text}")
	return result


def summarize_asset_candidates(asset_candidates: dict[str, Any]) -> dict[str, Any]:
	return {
		"backgrounds": summarize_ids(asset_candidates.get("backgrounds", [])),
		"sprites": summarize_sprites(asset_candidates.get("sprites", [])),
		"cgs": summarize_ids(asset_candidates.get("cgs", [])),
		"bgms": summarize_ids(asset_candidates.get("bgms", [])),
		"sfxs": summarize_ids(asset_candidates.get("sfxs", [])),
	}


def summarize_ids(items: Any) -> list[str]:
	if not isinstance(items, list):
		return []
	result: list[str] = []
	for item in items[:MAX_CANDIDATE_ITEMS]:
		if not isinstance(item, dict):
			continue
		item_id = trim_text(item.get("id", ""), 40)
		if item_id:
			result.append(item_id)
	return result


def summarize_sprites(items: Any) -> list[str]:
	if not isinstance(items, list):
		return []
	result: list[str] = []
	for item in items[:MAX_CANDIDATE_ITEMS]:
		if not isinstance(item, dict):
			continue
		item_id = trim_text(item.get("id", ""), 40)
		character_id = trim_text(item.get("character_id", ""), 32)
		if item_id:
			result.append(f"{item_id}:{character_id}")
	return result


def trim_text(raw_value: Any, max_length: int) -> str:
	value = str(raw_value or "").strip().replace("\n", " ")
	if len(value) <= max_length:
		return value
	if max_length <= 1:
		return value[:max_length]
	return f"{value[: max_length - 1]}…"


def try_parse_json_block(raw_text: str) -> dict[str, Any] | None:
	if not raw_text:
		return None

	try:
		parsed = json.loads(raw_text)
		return parsed if isinstance(parsed, dict) else None
	except json.JSONDecodeError:
		pass

	start = raw_text.find("{")
	end = raw_text.rfind("}")
	if start == -1 or end == -1 or end <= start:
		return None

	try:
		parsed = json.loads(raw_text[start : end + 1])
		return parsed if isinstance(parsed, dict) else None
	except json.JSONDecodeError:
		return None


def normalize_turn_response(source_payload: dict[str, Any], model_payload: dict[str, Any]) -> dict[str, Any]:
	world = source_payload.get("world", {})
	runtime_state = source_payload.get("runtime_state", {})
	asset_candidates = source_payload.get("asset_candidates", {})
	player_input = str(runtime_state.get("pending_player_input", "")).strip() or "다음 장면을 진행해 줘"
	default_rating = str(world.get("rating_lane", "general") or world.get("profile", {}).get("default_rating_lane", "general"))

	content = model_payload.get("content", {}) if isinstance(model_payload.get("content", {}), dict) else {}
	direction = model_payload.get("direction", {}) if isinstance(model_payload.get("direction", {}), dict) else {}
	state_update = model_payload.get("state_update", {}) if isinstance(model_payload.get("state_update", {}), dict) else {}
	memory_hint = model_payload.get("memory_hint", {}) if isinstance(model_payload.get("memory_hint", {}), dict) else {}
	audio = model_payload.get("audio", {}) if isinstance(model_payload.get("audio", {}), dict) else {}

	background_id = coerce_asset_id(direction.get("background_id", ""), asset_candidates.get("backgrounds", []))
	character_states = normalize_character_states(direction.get("character_states", []), asset_candidates.get("sprites", []))
	cg_id = coerce_asset_id(direction.get("cg_id", ""), asset_candidates.get("cgs", []))
	bgm_id = coerce_asset_id(audio.get("bgm_id", ""), asset_candidates.get("bgms", []))
	sfx_id = coerce_asset_id(audio.get("sfx_id", ""), asset_candidates.get("sfxs", []))

	return {
		"content": {
			"narration": coerce_string(content.get("narration"), f"입력 \"{player_input}\"에 반응해 다음 장면이 이어집니다."),
			"dialogue": coerce_string(content.get("dialogue"), "좋아. 이 흐름으로 장면을 이어 가 보자."),
			"action": coerce_string(content.get("action"), "장면의 분위기와 인물 배치를 다음 턴에 맞게 조정합니다."),
		},
		"direction": {
			"scene_mode": coerce_scene_mode(direction.get("scene_mode", "layered"), cg_id),
			"background_id": background_id,
			"character_states": character_states,
			"cg_id": cg_id,
			"transition": coerce_transition(direction.get("transition", "fade")),
			"camera_fx": coerce_camera_fx(direction.get("camera_fx", "none")),
		},
		"state_update": {
			"relationship_delta": state_update.get("relationship_delta", {}) if isinstance(state_update.get("relationship_delta", {}), dict) else {},
			"set_flags": state_update.get("set_flags", []) if isinstance(state_update.get("set_flags", []), list) else [],
			"content_rating": coerce_rating(state_update.get("content_rating", default_rating), default_rating),
		},
		"memory_hint": {
			"summary_candidate": coerce_string(memory_hint.get("summary_candidate"), f"입력 \"{player_input}\" 기준으로 한 턴이 진행되었습니다."),
		},
		"audio": {
			"bgm_id": bgm_id,
			"sfx_id": sfx_id,
			"volume_profile": coerce_volume_profile(audio.get("volume_profile", "default")),
		},
	}


def normalize_character_states(raw_states: Any, sprite_candidates: list[dict[str, Any]]) -> list[dict[str, str]]:
	if not isinstance(raw_states, list):
		return []

	valid_positions = {"left", "center", "right"}
	available_sprite_ids = {str(candidate.get("id", "")) for candidate in sprite_candidates}
	available_by_character: dict[str, str] = {}
	for candidate in sprite_candidates:
		character_id = str(candidate.get("character_id", ""))
		candidate_id = str(candidate.get("id", ""))
		if character_id and candidate_id and character_id not in available_by_character:
			available_by_character[character_id] = candidate_id

	resolved: list[dict[str, str]] = []
	seen_positions: set[str] = set()
	for raw_state in raw_states:
		if not isinstance(raw_state, dict):
			continue
		position = str(raw_state.get("position", "")).lower()
		character_id = str(raw_state.get("character_id", "")).strip()
		sprite_id = str(raw_state.get("sprite_id", "")).strip()
		if position not in valid_positions or position in seen_positions or not character_id:
			continue
		if sprite_id not in available_sprite_ids:
			sprite_id = available_by_character.get(character_id, "")
		if not sprite_id:
			continue
		resolved.append({
			"character_id": character_id,
			"sprite_id": sprite_id,
			"position": position,
		})
		seen_positions.add(position)

	return resolved


def coerce_asset_id(raw_id: Any, candidates: Any) -> str:
	candidate_ids = [str(candidate.get("id", "")) for candidate in candidates if isinstance(candidate, dict)]
	requested_id = str(raw_id or "").strip()
	if requested_id and requested_id in candidate_ids:
		return requested_id
	return candidate_ids[0] if candidate_ids else ""


def coerce_scene_mode(raw_mode: Any, cg_id: str) -> str:
	mode = str(raw_mode or "").strip().lower()
	if mode == "cg" and cg_id:
		return "cg"
	return "layered"


def coerce_transition(raw_value: Any) -> str:
	value = str(raw_value or "").strip().lower()
	return value if value in {"cut", "fade", "crossfade"} else "fade"


def coerce_camera_fx(raw_value: Any) -> str:
	value = str(raw_value or "").strip().lower()
	return value if value in {"none", "dim"} else "none"


def coerce_rating(raw_value: Any, fallback: str) -> str:
	value = str(raw_value or "").strip().lower()
	return value if value in {"general", "mature", "adult", "extreme"} else fallback


def coerce_volume_profile(raw_value: Any) -> str:
	value = str(raw_value or "").strip().lower()
	return value if value in {"default", "quiet", "dramatic"} else "default"


def coerce_string(raw_value: Any, fallback: str) -> str:
	value = str(raw_value or "").strip()
	return value if value else fallback


def build_fallback_response(source_payload: dict[str, Any], model_text: str, debug_reason: str = "") -> dict[str, Any]:
	world = source_payload.get("world", {})
	runtime_state = source_payload.get("runtime_state", {})
	asset_candidates = source_payload.get("asset_candidates", {})
	world_profile = world.get("profile", {}) if isinstance(world.get("profile", {}), dict) else {}
	world_name = str(world_profile.get("story_title", "") or world_profile.get("name_ko", "선택된 세계관"))
	player_input = str(runtime_state.get("pending_player_input", "")).strip() or "다음 장면을 진행해 줘"
	sprite_candidates = asset_candidates.get("sprites", [])
	background_id = coerce_asset_id("", asset_candidates.get("backgrounds", []))
	bgm_id = coerce_asset_id("", asset_candidates.get("bgms", []))
	lead_character_id = ""
	lead_sprite_id = ""
	if sprite_candidates:
		lead_character_id = str(sprite_candidates[0].get("character_id", ""))
		lead_sprite_id = str(sprite_candidates[0].get("id", ""))

	character_states = []
	if lead_character_id and lead_sprite_id:
		character_states.append({
			"character_id": lead_character_id,
			"sprite_id": lead_sprite_id,
			"position": "center",
		})

	set_flags = ["backend_fallback_response"]
	if debug_reason:
		set_flags.append(debug_reason)

	debug_payload: dict[str, Any] = {}
	if model_text:
		debug_payload["raw_model_text"] = model_text
	if debug_reason:
		debug_payload["reason"] = debug_reason

	response_payload = {
		"content": {
			"narration": f"{world_name}에서 입력 \"{player_input}\"을 반영해 다음 장면을 이어갑니다.",
			"dialogue": "지금은 백엔드 보정 응답이 적용되었습니다. 다음 턴으로 자연스럽게 이어 가겠습니다.",
			"action": "모델이 JSON 형식을 벗어나 fallback 응답으로 장면을 복구했습니다.",
		},
		"direction": {
			"scene_mode": "layered",
			"background_id": background_id,
			"character_states": character_states,
			"cg_id": "",
			"transition": "fade",
			"camera_fx": "none",
		},
		"state_update": {
			"relationship_delta": {},
			"set_flags": set_flags,
			"content_rating": coerce_rating(world.get("rating_lane", "general"), "general"),
		},
		"memory_hint": {
			"summary_candidate": f"입력 \"{player_input}\"에 대해 fallback 응답이 한 번 생성되었습니다.",
		},
		"audio": {
			"bgm_id": bgm_id,
			"sfx_id": "",
			"volume_profile": "quiet",
		},
	}
	if debug_payload:
		response_payload["debug"] = debug_payload
	return response_payload
