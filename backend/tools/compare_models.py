from __future__ import annotations

import argparse
import asyncio
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

ROOT_DIR = Path(__file__).resolve().parent.parent
if str(ROOT_DIR) not in sys.path:
	sys.path.insert(0, str(ROOT_DIR))

from app.model_adapter import OllamaModelAdapter
from app.prompt_memory import build_turn_prompt, is_low_signal_content, normalize_story_text
from app.response_normalization import build_fallback_response, parse_model_response, try_parse_json_block
from app.settings import settings


DEFAULT_MODELS = ["qwen2.5:14b", "gemma4:e4b"]
FORBIDDEN_RAW_MARKERS = ["<|channel>", "<|think|>", "<channel|>", "assistant:", "system:"]
FORBIDDEN_DIALOGUE_PREFIXES = ["화자:", "speaker:", "character_id:", "sprite_id:"]


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser(description="Compare local Ollama models with fixed VN fixtures.")
	parser.add_argument(
		"--fixtures-dir",
		default=str((Path(__file__).resolve().parent.parent / "fixtures" / "story_turn").resolve()),
		help="Directory containing story turn fixture JSON files.",
	)
	parser.add_argument(
		"--models",
		nargs="+",
		default=DEFAULT_MODELS,
		help="Models to compare. Defaults to qwen2.5:14b and gemma4:e4b.",
	)
	parser.add_argument(
		"--output",
		default="",
		help="Optional output JSON path. Defaults to backend/compare_results/<timestamp>.json.",
	)
	return parser.parse_args()


def load_fixture(path: Path) -> dict[str, Any]:
	return json.loads(path.read_text(encoding="utf-8"))


def evaluate_structure(fixture: dict[str, Any], normalized_payload: dict[str, Any], raw_response: str, json_parse_success: bool) -> dict[str, Any]:
	content = normalized_payload.get("content", {}) if isinstance(normalized_payload.get("content", {}), dict) else {}
	direction = normalized_payload.get("direction", {}) if isinstance(normalized_payload.get("direction", {}), dict) else {}
	asset_candidates = fixture.get("asset_candidates", {}) if isinstance(fixture.get("asset_candidates", {}), dict) else {}
	recent_conversation = fixture.get("recent_conversation", [])

	background_ids = {
		str(item.get("id", "")).strip()
		for item in asset_candidates.get("backgrounds", [])
		if isinstance(item, dict) and str(item.get("id", "")).strip()
	}
	cg_ids = {
		str(item.get("id", "")).strip()
		for item in asset_candidates.get("cgs", [])
		if isinstance(item, dict) and str(item.get("id", "")).strip()
	}
	sprite_ids = {
		str(item.get("id", "")).strip()
		for item in asset_candidates.get("sprites", [])
		if isinstance(item, dict) and str(item.get("id", "")).strip()
	}

	dialogue_text = normalize_story_text(content.get("dialogue", ""))
	raw_has_forbidden_markers = any(marker in raw_response for marker in FORBIDDEN_RAW_MARKERS)
	dialogue_has_forbidden_prefix = any(dialogue_text.lower().startswith(prefix) for prefix in FORBIDDEN_DIALOGUE_PREFIXES)
	invalid_background = str(direction.get("background_id", "")).strip() not in background_ids if background_ids else False
	invalid_cg = str(direction.get("cg_id", "")).strip() not in {"", *cg_ids}
	invalid_sprite = False
	for state in direction.get("character_states", []):
		if not isinstance(state, dict):
			invalid_sprite = True
			break
		sprite_id = str(state.get("sprite_id", "")).strip()
		if sprite_id and sprite_id not in sprite_ids:
			invalid_sprite = True
			break

	structure_ok = json_parse_success and not raw_has_forbidden_markers and not dialogue_has_forbidden_prefix and not invalid_background and not invalid_cg and not invalid_sprite
	low_signal = is_low_signal_content(content if isinstance(content, dict) else {}, recent_conversation)
	return {
		"json_parse_success": json_parse_success,
		"raw_has_forbidden_markers": raw_has_forbidden_markers,
		"dialogue_has_forbidden_prefix": dialogue_has_forbidden_prefix,
		"invalid_background_id": invalid_background,
		"invalid_cg_id": invalid_cg,
		"invalid_sprite_id": invalid_sprite,
		"low_signal_repeat": low_signal,
		"structure_ok": structure_ok and not low_signal,
	}


async def run_fixture(adapter: OllamaModelAdapter, model_name: str, fixture: dict[str, Any]) -> dict[str, Any]:
	prompt = build_turn_prompt(fixture, prompt_summary_cache="")
	raw_response, usage_metrics = await adapter.generate(
		prompt,
		model_name=model_name,
		use_model_profile=True,
	)
	json_parse_success = try_parse_json_block(raw_response) is not None
	normalized_payload, used_fallback = parse_model_response(fixture, raw_response)
	if used_fallback and not json_parse_success:
		normalized_payload = build_fallback_response(fixture, raw_response)
	evaluation = evaluate_structure(fixture, normalized_payload, raw_response, json_parse_success)
	return {
		"model": model_name,
		"prompt_chars": len(prompt),
		"usage_metrics": usage_metrics,
		"used_fallback": used_fallback,
		"evaluation": evaluation,
		"raw_response": raw_response,
		"normalized_payload": normalized_payload,
	}


async def main() -> None:
	args = parse_args()
	fixtures_dir = Path(args.fixtures_dir).resolve()
	fixture_paths = sorted(fixtures_dir.glob("*.json"))
	if not fixture_paths:
		raise SystemExit(f"No fixture JSON files found in {fixtures_dir}")

	adapter = OllamaModelAdapter(settings)
	report: dict[str, Any] = {
		"generated_at": datetime.utcnow().isoformat() + "Z",
		"fixtures_dir": str(fixtures_dir),
		"models": args.models,
		"results": [],
	}

	try:
		for fixture_path in fixture_paths:
			fixture = load_fixture(fixture_path)
			fixture_result = {
				"fixture": fixture_path.name,
				"runs": [],
			}
			for model_name in args.models:
				fixture_result["runs"].append(await run_fixture(adapter, model_name, fixture))
			report["results"].append(fixture_result)
	finally:
		await adapter.shutdown()

	output_path = Path(args.output).resolve() if args.output else (fixtures_dir.parent.parent / "compare_results" / f"model_compare_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json").resolve()
	output_path.parent.mkdir(parents=True, exist_ok=True)
	output_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
	print(output_path)


if __name__ == "__main__":
	asyncio.run(main())
