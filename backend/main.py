import logging
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException

from app.model_adapter import OllamaModelAdapter
from app.prompt_memory import build_conservative_prompt_summary, build_turn_prompt
from app.response_normalization import build_fallback_response, parse_model_response
from app.session_store import SessionStore
from app.settings import settings


if not logging.getLogger().handlers:
	logging.basicConfig(level=logging.INFO)


app = FastAPI(title="NovelGame Ollama Backend")
model_adapter = OllamaModelAdapter(settings)
session_store = SessionStore(settings.backend_sqlite_path)


def resolve_session_state(payload: dict[str, Any]) -> tuple[str, bool]:
	session_payload = payload.get("session", {})
	if not isinstance(session_payload, dict):
		return "", False
	session_id = str(session_payload.get("id", "")).strip()
	if not session_id:
		return "", False
	reset_prompt_cache = bool(session_payload.get("reset_prompt_cache", False))
	return session_id, reset_prompt_cache


def persist_session_turn(session_id: str, source_payload: dict[str, Any], normalized_payload: dict[str, Any]) -> None:
	turn_index = session_store.append_dialogue_turn(session_id, source_payload, normalized_payload)
	recent_turns = session_store.get_recent_turns(session_id, limit=6)
	prompt_summary_cache = build_conservative_prompt_summary(recent_turns)
	session_store.upsert_prompt_summary_cache(session_id, prompt_summary_cache, turn_index)


@app.on_event("shutdown")
async def shutdown_resources() -> None:
	await model_adapter.shutdown()
	session_store.close()


@app.get("/health")
async def health() -> dict[str, Any]:
	try:
		return await model_adapter.collect_backend_health_state()
	except Exception as exc:
		return {
			"status": "unhealthy",
			"message": f"Failed to reach Ollama: {exc}",
			"ready": False,
			"warm": False,
			"warm_fail_reasons": ["ollama_unreachable"],
			"provider": "ollama",
			"model": settings.ollama_model,
			"effective_num_ctx": settings.effective_num_ctx,
			"context_length": 0,
			"size_vram": 0,
			"expires_at": "",
		}


@app.post("/v1/backend/prewarm")
async def prewarm_backend(payload: dict[str, Any] | None = None) -> dict[str, Any]:
	reason = "manual"
	if isinstance(payload, dict):
		reason = str(payload.get("reason", reason)).strip() or reason
	try:
		return await model_adapter.ensure_warm_backend(reason)
	except httpx.TimeoutException as exc:
		raise HTTPException(status_code=504, detail=f"Prewarm timed out: {exc}")
	except httpx.HTTPError as exc:
		raise HTTPException(status_code=502, detail=f"Prewarm failed: {exc}")
	except Exception as exc:
		raise HTTPException(status_code=500, detail=f"Failed to prewarm backend: {exc}")


@app.post("/v1/story/turn")
async def story_turn(payload: dict[str, Any]) -> dict[str, Any]:
	session_id, reset_prompt_cache = resolve_session_state(payload)
	if session_id and reset_prompt_cache:
		session_store.reset_session(session_id)

	try:
		prompt_summary_cache = session_store.get_prompt_summary_cache(session_id) if session_id else ""
		prompt = build_turn_prompt(payload, prompt_summary_cache=prompt_summary_cache)
		response_text, usage_metrics = await model_adapter.generate(prompt)
		model_adapter.log_turn_metrics(prompt, usage_metrics)
		normalized_payload, _used_fallback = parse_model_response(payload, response_text)
		if session_id:
			persist_session_turn(session_id, payload, normalized_payload)
		return normalized_payload
	except httpx.TimeoutException:
		fallback_payload = build_fallback_response(payload, "", "ollama_timeout")
		if session_id:
			persist_session_turn(session_id, payload, fallback_payload)
		return fallback_payload
	except httpx.HTTPError as exc:
		raise HTTPException(status_code=502, detail=f"Ollama request failed: {exc}")
	except HTTPException:
		raise
	except Exception as exc:
		raise HTTPException(status_code=500, detail=f"Failed to generate turn: {exc}")
