from __future__ import annotations

import json
import logging
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any

import httpx

from .settings import BackendSettings


LOGGER = logging.getLogger("novelgame.ollama")
OLLAMA_CLIENT_LIMITS = httpx.Limits(max_keepalive_connections=4, max_connections=8)


def parse_int_value(raw_value: Any, default: int = 0) -> int:
	try:
		return int(raw_value)
	except (TypeError, ValueError):
		return default


def parse_iso_datetime(raw_value: Any) -> datetime | None:
	value = str(raw_value or "").strip()
	if not value:
		return None
	if value.endswith("Z"):
		value = f"{value[:-1]}+00:00"
	try:
		parsed = datetime.fromisoformat(value)
	except ValueError:
		return None
	if parsed.tzinfo is None:
		return parsed.replace(tzinfo=timezone.utc)
	return parsed.astimezone(timezone.utc)


def get_remaining_seconds(raw_value: Any) -> int | None:
	parsed = parse_iso_datetime(raw_value)
	if parsed is None:
		return None
	return int((parsed - datetime.now(timezone.utc)).total_seconds())


def extract_usage_metrics(response_payload: Any) -> dict[str, Any]:
	if not isinstance(response_payload, dict):
		return {}
	return {
		"load_duration": parse_int_value(response_payload.get("load_duration", 0), 0),
		"prompt_eval_count": parse_int_value(response_payload.get("prompt_eval_count", 0), 0),
		"prompt_eval_duration": parse_int_value(response_payload.get("prompt_eval_duration", 0), 0),
		"eval_count": parse_int_value(response_payload.get("eval_count", 0), 0),
		"eval_duration": parse_int_value(response_payload.get("eval_duration", 0), 0),
		"total_duration": parse_int_value(response_payload.get("total_duration", 0), 0),
	}


def get_model_profile_overrides(model_name: str) -> dict[str, Any]:
	clean_name = model_name.strip().lower()
	if clean_name.startswith("gemma4"):
		return {"temperature": 1.0, "top_p": 0.95, "top_k": 64}
	return {}


@dataclass(slots=True)
class OllamaModelAdapter:
	settings: BackendSettings
	logger: logging.Logger = LOGGER
	_client: httpx.AsyncClient | None = None

	def get_ollama_client(self) -> httpx.AsyncClient:
		if self._client is None:
			self._client = httpx.AsyncClient(
				timeout=self.settings.ollama_request_timeout_seconds,
				limits=OLLAMA_CLIENT_LIMITS,
			)
		return self._client

	async def shutdown(self) -> None:
		if self._client is None:
			return
		await self._client.aclose()
		self._client = None

	async def request(self, method: str, url: str, **kwargs: Any) -> httpx.Response:
		client = self.get_ollama_client()
		try:
			return await client.request(method, url, **kwargs)
		except RuntimeError as exc:
			if "Event loop is closed" not in str(exc):
				raise
			try:
				if self._client is not None:
					await self._client.aclose()
			except Exception:
				pass
			self._client = httpx.AsyncClient(
				timeout=self.settings.ollama_request_timeout_seconds,
				limits=OLLAMA_CLIENT_LIMITS,
			)
			return await self._client.request(method, url, **kwargs)

	def get_effective_num_ctx(self) -> int:
		return self.settings.effective_num_ctx

	def extract_model_context_length(self, model_entry: Any) -> int:
		if not isinstance(model_entry, dict):
			return 0
		details = model_entry.get("details", {}) if isinstance(model_entry.get("details", {}), dict) else {}
		return parse_int_value(model_entry.get("context_length", details.get("context_length", 0)), 0)

	def find_running_model(self, ps_payload: Any) -> dict[str, Any] | None:
		if not isinstance(ps_payload, dict):
			return None
		for raw_model in ps_payload.get("models", []):
			if not isinstance(raw_model, dict):
				continue
			name = str(raw_model.get("name", "")).strip()
			model_name = str(raw_model.get("model", "")).strip()
			if name == self.settings.ollama_model or model_name == self.settings.ollama_model:
				return raw_model
		return None

	def is_model_pulled(self, tags_payload: Any) -> bool:
		if not isinstance(tags_payload, dict):
			return False
		for raw_model in tags_payload.get("models", []):
			if not isinstance(raw_model, dict):
				continue
			name = str(raw_model.get("name", "")).strip()
			model_name = str(raw_model.get("model", "")).strip()
			if (
				name == self.settings.ollama_model
				or model_name == self.settings.ollama_model
				or name.startswith(f"{self.settings.ollama_model}:")
			):
				return True
		return False

	def evaluate_warm_state(self, model_entry: Any) -> dict[str, Any]:
		warm_fail_reasons: list[str] = []
		context_length = 0
		size_vram = 0
		expires_at = ""

		if not isinstance(model_entry, dict):
			return {
				"warm": False,
				"warm_fail_reasons": ["model_not_loaded"],
				"context_length": 0,
				"size_vram": 0,
				"expires_at": "",
			}

		model_name = str(model_entry.get("name", model_entry.get("model", ""))).strip()
		if model_name != self.settings.ollama_model:
			warm_fail_reasons.append("model_name_mismatch")

		size = parse_int_value(model_entry.get("size", 0), 0)
		size_vram = parse_int_value(model_entry.get("size_vram", 0), 0)
		if size > 0:
			vram_ratio = float(size_vram) / float(size)
			if vram_ratio < self.settings.backend_warm_min_vram_ratio:
				warm_fail_reasons.append("insufficient_vram_residency")

		context_length = self.extract_model_context_length(model_entry)
		if context_length < self.get_effective_num_ctx():
			warm_fail_reasons.append("insufficient_context_length")

		expires_at = str(model_entry.get("expires_at", "")).strip()
		if expires_at:
			remaining_seconds = get_remaining_seconds(expires_at)
			if remaining_seconds is not None and remaining_seconds < self.settings.backend_warm_min_expires_seconds:
				warm_fail_reasons.append("expires_too_soon")

		return {
			"warm": len(warm_fail_reasons) == 0,
			"warm_fail_reasons": warm_fail_reasons,
			"context_length": context_length,
			"size_vram": size_vram,
			"expires_at": expires_at,
		}

	async def fetch_ollama_tags(self) -> dict[str, Any]:
		response = await self.request(
			"GET",
			f"{self.settings.ollama_host}/api/tags",
			timeout=self.settings.ollama_health_timeout_seconds,
		)
		response.raise_for_status()
		payload = response.json()
		return payload if isinstance(payload, dict) else {}

	async def fetch_ollama_ps(self) -> dict[str, Any]:
		response = await self.request(
			"GET",
			f"{self.settings.ollama_host}/api/ps",
			timeout=self.settings.ollama_health_timeout_seconds,
		)
		response.raise_for_status()
		payload = response.json()
		return payload if isinstance(payload, dict) else {}

	async def collect_backend_health_state(self) -> dict[str, Any]:
		tags_payload = await self.fetch_ollama_tags()
		ps_payload = await self.fetch_ollama_ps()
		model_pulled = self.is_model_pulled(tags_payload)
		running_model = self.find_running_model(ps_payload)
		warm_state = self.evaluate_warm_state(running_model)

		status = "healthy" if model_pulled else "degraded"
		message = "Ollama backend is ready." if model_pulled else "Ollama is reachable but the configured model is not pulled yet."
		if model_pulled and not warm_state["warm"]:
			message = "Ollama is reachable, but the configured model is not warm yet."

		return {
			"status": status,
			"message": message,
			"ready": model_pulled,
			"warm": bool(warm_state["warm"]),
			"warm_fail_reasons": warm_state["warm_fail_reasons"],
			"provider": "ollama",
			"model": self.settings.ollama_model,
			"effective_num_ctx": self.get_effective_num_ctx(),
			"context_length": warm_state["context_length"],
			"size_vram": warm_state["size_vram"],
			"expires_at": warm_state["expires_at"],
			"latency_profile": {
				"timeout_seconds": self.settings.ollama_request_timeout_seconds,
				"num_predict": self.settings.ollama_num_predict,
				"num_ctx": self.get_effective_num_ctx(),
				"keep_alive": self.settings.ollama_keep_alive,
			},
		}

	def build_prewarm_request_payload(self, strategy: str) -> dict[str, Any]:
		if strategy == "single_token_probe":
			return {
				"model": self.settings.ollama_model,
				"prompt": ".",
				"stream": False,
				"keep_alive": -1,
				"options": {
					"num_predict": 1,
					"num_ctx": self.get_effective_num_ctx(),
				},
			}
		return {
			"model": self.settings.ollama_model,
			"keep_alive": -1,
			"options": {"num_ctx": self.get_effective_num_ctx()},
		}

	async def run_prewarm_request(self, strategy: str) -> dict[str, Any]:
		request_payload = self.build_prewarm_request_payload(strategy)
		try:
			response = await self.request(
				"POST",
				f"{self.settings.ollama_host}/api/generate",
				json=request_payload,
				timeout=self.settings.ollama_request_timeout_seconds,
			)
			response.raise_for_status()
			if response.content:
				response.json()
			return {"ok": True, "strategy": strategy}
		except httpx.TimeoutException:
			return {"ok": False, "strategy": strategy, "reason": "timeout"}
		except (httpx.HTTPError, ValueError) as exc:
			return {
				"ok": False,
				"strategy": strategy,
				"reason": exc.__class__.__name__.lower(),
				"message": str(exc),
			}

	async def ensure_warm_backend(self, reason: str = "manual") -> dict[str, Any]:
		before_state = await self.collect_backend_health_state()
		if before_state["warm"]:
			before_state["prewarm"] = {
				"reason": reason,
				"strategy": self.settings.prewarm_strategy,
				"fallback_used": False,
				"fallback_reason": "",
				"warm_before": True,
				"warm_after": True,
			}
			return before_state

		fallback_used = False
		fallback_reason = ""
		request_result = await self.run_prewarm_request(self.settings.prewarm_strategy)

		if not request_result["ok"] and self.settings.prewarm_strategy == "empty_request":
			fallback_used = True
			fallback_reason = str(request_result.get("reason", "empty_request_failed"))
			request_result = await self.run_prewarm_request("single_token_probe")

		after_state = await self.collect_backend_health_state()
		if request_result["ok"] and not after_state["warm"] and self.settings.prewarm_strategy == "empty_request" and not fallback_used:
			fallback_used = True
			fallback_reason = "warm_validation_failed"
			request_result = await self.run_prewarm_request("single_token_probe")
			after_state = await self.collect_backend_health_state()

		after_state["prewarm"] = {
			"reason": reason,
			"strategy": str(request_result.get("strategy", self.settings.prewarm_strategy)),
			"fallback_used": fallback_used,
			"fallback_reason": fallback_reason,
			"warm_before": bool(before_state.get("warm", False)),
			"warm_after": bool(after_state.get("warm", False)),
		}
		self.logger.info(
			"ollama_prewarm %s",
			json.dumps(
				{
					"reason": reason,
					"strategy": after_state["prewarm"]["strategy"],
					"fallback_used": fallback_used,
					"fallback_reason": fallback_reason,
					"warm_before": before_state.get("warm", False),
					"warm_after": after_state.get("warm", False),
					"warm_fail_reasons": after_state.get("warm_fail_reasons", []),
				},
				ensure_ascii=False,
				sort_keys=True,
			),
		)
		return after_state

	def build_generate_payload(
		self,
		prompt: str,
		model_name: str | None = None,
		option_overrides: dict[str, Any] | None = None,
		use_model_profile: bool = False,
	) -> dict[str, Any]:
		resolved_model = (model_name or self.settings.ollama_model).strip() or self.settings.ollama_model
		options: dict[str, Any] = {
			"temperature": self.settings.ollama_temperature,
			"top_p": self.settings.ollama_top_p,
			"num_predict": self.settings.ollama_num_predict,
			"num_ctx": self.get_effective_num_ctx(),
			"repeat_penalty": self.settings.ollama_repeat_penalty,
		}
		if use_model_profile:
			options.update(get_model_profile_overrides(resolved_model))
		if option_overrides:
			options.update(option_overrides)
		return {
			"model": resolved_model,
			"prompt": prompt,
			"stream": False,
			"format": self.settings.ollama_response_schema,
			"keep_alive": self.settings.ollama_keep_alive,
			"options": options,
		}

	async def generate(
		self,
		prompt: str,
		model_name: str | None = None,
		option_overrides: dict[str, Any] | None = None,
		use_model_profile: bool = False,
	) -> tuple[str, dict[str, Any]]:
		request_payload = self.build_generate_payload(
			prompt,
			model_name=model_name,
			option_overrides=option_overrides,
			use_model_profile=use_model_profile,
		)
		response = await self.request(
			"POST",
			f"{self.settings.ollama_host}/api/generate",
			json=request_payload,
		)
		response.raise_for_status()
		payload = response.json()
		return str(payload.get("response", "")).strip(), extract_usage_metrics(payload)

	def log_turn_metrics(self, prompt: str, usage_metrics: dict[str, Any], model_name: str | None = None) -> None:
		self.logger.info(
			"ollama_turn_metrics %s",
			json.dumps(
				{
					"model": model_name or self.settings.ollama_model,
					"prompt_chars": len(prompt),
					"effective_num_ctx": self.get_effective_num_ctx(),
					**usage_metrics,
				},
				ensure_ascii=False,
				sort_keys=True,
			),
		)
