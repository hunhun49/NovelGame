from __future__ import annotations

from typing import Any

from .prompt_memory import (
	build_fallback_response,
	normalize_turn_response,
	try_parse_json_block,
)


def parse_model_response(source_payload: dict[str, Any], response_text: str) -> tuple[dict[str, Any], bool]:
	parsed = try_parse_json_block(response_text)
	if parsed is None:
		return build_fallback_response(source_payload, response_text), True
	return normalize_turn_response(source_payload, parsed), False


__all__ = [
	"build_fallback_response",
	"normalize_turn_response",
	"parse_model_response",
	"try_parse_json_block",
]
