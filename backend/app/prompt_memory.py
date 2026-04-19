import json
from typing import Any

from .settings import settings

OLLAMA_DIALOGUE_BASE_LANGUAGE = settings.ollama_dialogue_base_language
MAX_CANDIDATE_ITEMS = settings.max_candidate_items
MAX_RECENT_ITEMS = settings.max_recent_items
MAX_TEXT_LENGTH = settings.max_text_length
TARGET_SCRIPT_MIN_LENGTH = settings.target_script_min_length
TARGET_SCRIPT_MAX_LENGTH = settings.target_script_max_length
MIN_ACCEPTABLE_SCRIPT_LENGTH = settings.min_acceptable_script_length
MIN_NARRATION_LENGTH = settings.min_narration_length
MIN_DIALOGUE_LENGTH = settings.min_dialogue_length
MIN_ACTION_LENGTH = settings.min_action_length
MAX_PROFILE_TEXT_LENGTH = settings.max_profile_text_length
MAX_STYLE_EXAMPLES = settings.max_style_examples
MAX_STYLE_TRAITS = settings.max_style_traits
MAX_WORLD_RULES = settings.max_world_rules
MAX_STORY_EXAMPLES = settings.max_story_examples
MAX_PROMPT_SUMMARY_LENGTH = settings.max_prompt_summary_length

def describe_dialogue_base_language() -> str:
    if OLLAMA_DIALOGUE_BASE_LANGUAGE == "kr":
        return "Korean"
    if OLLAMA_DIALOGUE_BASE_LANGUAGE == "en":
        return "English"
    if OLLAMA_DIALOGUE_BASE_LANGUAGE == "auto":
        return "English or Japanese"
    return "Japanese"

def build_direct_kr_prompt(payload: dict[str, Any], prompt_summary_cache: str = "") -> str:
	persona = payload.get("persona", {})
	world = payload.get("world", {})
	runtime_state = payload.get("runtime_state", {})
	asset_candidates = payload.get("asset_candidates", {})
	recent_conversation = payload.get("recent_conversation", [])
	world_profile = world.get("profile", {}) if isinstance(world.get("profile", {}), dict) else {}
	main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
	relationship_scores = persona.get("relationship_scores", {}) if isinstance(persona.get("relationship_scores", {}), dict) else {}
	player_character = persona.get("player_character", {}) if isinstance(persona.get("player_character", {}), dict) else {}
	player_input = trim_text(runtime_state.get("pending_player_input", ""), MAX_TEXT_LENGTH) or "다음 장면을 이어 가 주세요."
	world_name = trim_text(world_profile.get("story_title", "") or world_profile.get("name_ko", "이야기"), 80)
	player_name = trim_text(player_character.get("name_ko", "") or persona.get("player_name", "플레이어"), 32)
	lead_character_profile = build_character_prompt_profile(main_characters[0] if main_characters else {}, relationship_scores)
	support_character_profiles = [
		character_profile
		for character_profile in [build_character_prompt_profile(character, relationship_scores) for character in main_characters[1:2]]
		if character_profile
	]
	template_hint = build_story_template_hint(str(world_profile.get("story_prompt_template", "basic")))
	clean_prompt_summary_cache = trim_text(prompt_summary_cache, MAX_PROMPT_SUMMARY_LENGTH)
	compact_payload = {
		"world": {
			"name": world_name,
			"location": trim_text(world.get("location_id", ""), 40),
			"rating": trim_text(world.get("rating_lane", "general"), 16),
			"genre": trim_text(world_profile.get("genre", ""), 32),
			"tone": trim_text(world_profile.get("tone", ""), 32),
			"template": trim_text(world_profile.get("story_prompt_template", "basic"), 16),
			"premise": trim_text(world_profile.get("premise", ""), MAX_PROFILE_TEXT_LENGTH),
			"initial_situation": trim_text(world_profile.get("initial_situation", ""), MAX_PROFILE_TEXT_LENGTH),
			"core_rules": summarize_strings(world_profile.get("core_rules", []), MAX_WORLD_RULES, 40),
			"story_examples": summarize_strings(world_profile.get("story_examples", []), MAX_STORY_EXAMPLES, 60),
		},
		"cast": {
			"player": build_player_prompt_profile(player_character, player_name),
			"lead": lead_character_profile,
			"support": support_character_profiles,
		},
		"runtime": {
			"input": player_input,
			"scene_mode": trim_text(runtime_state.get("scene_mode", "layered"), 16),
		},
		"recent": summarize_recent_conversation(recent_conversation),
		"assets": summarize_asset_candidates(asset_candidates),
	}
	if clean_prompt_summary_cache:
		compact_payload["memory"] = {
			"prompt_summary_cache": clean_prompt_summary_cache,
		}

	base_language_hint = "중간 언어 초안 없이 바로 자연스러운 한국어로 작성한다."
	if OLLAMA_DIALOGUE_BASE_LANGUAGE != "kr":
		base_language_hint = f"내부 초안은 {describe_dialogue_base_language()}를 참고할 수 있지만 최종 출력은 반드시 자연스러운 한국어만 사용한다."

	prompt_lines = [
		"당신은 비주얼 노벨 한 턴을 생성하는 작가다.",
		"출력은 JSON 객체 하나만 반환한다.",
		"최종 문장은 반드시 자연스러운 한국어로만 작성한다.",
		base_language_hint,
		"플레이어 입력을 반복하지 말고 장면을 한 단계 앞으로 진행시킨다.",
		"content와 direction만 생성한다. state_update, memory_hint, audio는 생성하지 않는다.",
		"dialogue는 cast.lead의 성격, 말투, speech_examples를 가장 강한 기준으로 따른다.",
		"recent와 같은 문장을 그대로 반복하지 않는다.",
		"memory.prompt_summary_cache는 recent보다 우선하지 않는 보조 요약이다. recent와 충돌하면 recent를 따른다.",
		"배경, 스프라이트, CG, BGM, SFX는 반드시 assets에 있는 ID만 사용한다.",
		"scene_mode는 layered 또는 cg만 사용한다.",
		"position은 left, center, right만 사용한다.",
		"emotion은 neutral, joy, sad, angry 중 하나만 사용한다.",
		f"content 전체 분량은 공백 포함 약 {TARGET_SCRIPT_MIN_LENGTH}~{TARGET_SCRIPT_MAX_LENGTH}자다.",
		"출력 규칙: narration=장면 설명만, dialogue=캐릭터의 실제 발화만, action=행동이나 감정의 여운만 쓴다.",
		"narration에는 직접 대사, 따옴표, 화자 이름, 별칭, 콜론 대사 라벨을 넣지 않는다.",
		"narration은 2~3문장으로 분위기와 감정 변화를 짧고 선명하게 묘사한다.",
		"dialogue는 1~2문장으로 압축하고, 군더더기 설명 없이 실제 대사만 적는다.",
		"dialogue 앞에는 화자 이름, 화자 별칭, character_id, sprite_id, 스프라이트 이름, 파일명, 대사 라벨, 콜론(:), 따옴표를 절대 붙이지 않는다.",
		"action에는 직접 대사, 화자 이름, 콜론 대사 라벨을 넣지 않는다.",
		"action은 1문장으로 행동이나 연출 힌트만 짧게 적는다.",
		"세 필드는 서로 이어지는 같은 장면이어야 한다.",
		"예시: narration='빗소리가 얇게 창문을 두드렸다.' dialogue='주인님, 저도 반갑습니다.' action='수진은 살짝 눈을 내리깔며 숨을 고른다.'",
		template_hint,
		f"character_states의 주인공은 cast.lead.id({lead_character_profile.get('id', '')})를 우선 사용한다.",
		"빈 문자열, null, 설명문, 주석을 넣지 않는다.",
		"반드시 JSON 스키마에 맞게만 출력한다.",
		json.dumps(compact_payload, ensure_ascii=False, separators=(",", ":")),
	]
	if clean_prompt_summary_cache:
		prompt_lines.insert(8, "memory.prompt_summary_cache를 참고해 최근 장면 흐름을 짧게 이어가되, memory 문장을 그대로 복사하지 않는다.")
	return "\n".join(prompt_lines)


def build_ollama_prompt(payload: dict[str, Any]) -> str:
	persona = payload.get("persona", {})
	world = payload.get("world", {})
	runtime_state = payload.get("runtime_state", {})
	asset_candidates = payload.get("asset_candidates", {})
	recent_conversation = payload.get("recent_conversation", [])
	world_profile = world.get("profile", {}) if isinstance(world.get("profile", {}), dict) else {}
	main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
	relationship_scores = persona.get("relationship_scores", {}) if isinstance(persona.get("relationship_scores", {}), dict) else {}
	player_character = persona.get("player_character", {}) if isinstance(persona.get("player_character", {}), dict) else {}
	player_input = trim_text(runtime_state.get("pending_player_input", ""), MAX_TEXT_LENGTH) or "다음 장면을 진행해 줘"
	world_name = trim_text(world_profile.get("story_title", "") or world_profile.get("name_ko", "선택된 세계관"), 80)
	player_name = trim_text(player_character.get("name_ko", "") or persona.get("player_name", "플레이어"), 32)
	lead_character_profile = build_character_prompt_profile(main_characters[0] if main_characters else {}, relationship_scores)
	support_character_profiles = [
		character_profile
		for character_profile in [build_character_prompt_profile(character, relationship_scores) for character in main_characters[1:2]]
		if character_profile
	]
	template_hint = build_story_template_hint(str(world_profile.get("story_prompt_template", "basic")))
	compact_payload = {
		"world": {
			"name": world_name,
			"location": trim_text(world.get("location_id", ""), 40),
			"rating": trim_text(world.get("rating_lane", "general"), 16),
			"genre": trim_text(world_profile.get("genre", ""), 32),
			"tone": trim_text(world_profile.get("tone", ""), 32),
			"template": trim_text(world_profile.get("story_prompt_template", "basic"), 16),
			"premise": trim_text(world_profile.get("premise", ""), MAX_PROFILE_TEXT_LENGTH),
			"initial_situation": trim_text(world_profile.get("initial_situation", ""), MAX_PROFILE_TEXT_LENGTH),
			"core_rules": summarize_strings(world_profile.get("core_rules", []), MAX_WORLD_RULES, 40),
			"story_examples": summarize_strings(world_profile.get("story_examples", []), 2, 60),
		},
		"cast": {
			"player": build_player_prompt_profile(player_character, player_name),
			"lead": lead_character_profile,
			"support": support_character_profiles,
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
		"문장은 소설처럼 유려하고 자연스럽게 쓴다.",
		"출력 문장은 한국어만 사용한다.",
		"대사 생성은 하이브리드 전략을 따른다.",
		"순서는 Base Dialogue -> Emotion Layer -> Personality Layer -> KR Rewrite 이다.",
		build_hybrid_dialogue_strategy_hint(lead_character_profile),
		"최종 출력에는 리라이팅이 끝난 한국어 결과만 넣고, 중간 언어 초안, 번역 과정, 설명 문장은 절대 노출하지 않는다.",
		"dialogue는 cast.lead의 main_personality, sub_personalities, speech_style, speech_examples를 가장 강한 앵커로 사용한다.",
		"Emotion Layer에는 최근 대화의 감정선, relationship_state, 현재 입력의 긴장/호감/불안 신호를 반영한다.",
		"프로필이나 예시가 젊은 여성 캐릭터 톤을 가리키면 10~20대 한국어 구어체 감각을 살리고, 그렇지 않으면 프로필에 맞는 화법을 우선한다.",
		"직역투, 번역체, 과한 존댓말, 딱딱한 설명체, 같은 어미/감탄사 반복을 피한다.",
		"빈 문자열, 생략, null, 설명문을 쓰지 않는다.",
		"직전 recent와 같은 문장을 그대로 반복하지 않는다.",
		"플레이어 입력을 그대로 되풀이하지 말고 한 단계 진전시킨다.",
		"매 턴마다 감정, 정보, 행동 중 최소 하나는 새롭게 바뀌어야 한다.",
		"이번 호출에서는 content와 direction만 생성한다.",
		"state_update, memory_hint, audio는 서버가 채우므로 생성하지 않는다.",
		template_hint,
		"assets 후보 ID만 사용한다.",
		"scene_mode=layered|cg, position=left|center|right.",
		f"character_states에 반드시 cast.lead.id({lead_character_profile.get('id', '?')})를 character_id로 사용하라. 다른 id를 사용하지 마라.",
		"character_states의 각 항목에 emotion 필드를 반드시 포함하라: neutral(평온), joy(기쁨/설렘), sad(슬픔/그리움), angry(화남/짜증) 중 대사 감정에 맞게 선택한다.",
		f"content 전체 분량은 공백 포함 약 {TARGET_SCRIPT_MIN_LENGTH}~{TARGET_SCRIPT_MAX_LENGTH}자다.",
		"출력 규칙: narration=장면 설명만, dialogue=캐릭터의 실제 발화만, action=행동/생각/여운만 작성한다.",
		"narration에는 직접 대사, 따옴표, 화자 이름, 화자 별칭, 콜론 대사 라벨을 넣지 않는다.",
		"narration은 장면, 분위기, 감정 변화를 살린 2~4문장으로 작성한다.",
		"dialogue는 화자 이름, 화자 별칭, 따옴표, 대사 라벨 없이 실제 대사 내용만 1~3문장으로 작성한다.",
		"dialogue 앞에는 character_id, sprite_id, 스프라이트 이름, 파일명 같은 기술 식별자와 콜론(:)을 절대 붙이지 않는다.",
		"action에는 직접 대사, 따옴표, 화자 이름, 대사 라벨을 넣지 않는다.",
		"action은 행동, 생각, 여운을 짧지만 선명한 1~2문장으로 작성한다.",
		"content 세 필드는 함께 읽었을 때 한 장면의 짧은 소설처럼 이어져야 한다.",
		"예시: narration='창가 쪽 공기가 늦은 저녁처럼 가라앉았다.' dialogue='주인님, 저도 반갑습니다.' action='수진은 손끝을 모은 채 조심스럽게 시선을 맞춘다.'",
		"키: content,direction.",
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


def summarize_strings(items: Any, max_items: int, max_length: int) -> list[str]:
	if not isinstance(items, list):
		return []
	result: list[str] = []
	for item in items[:max_items]:
		text = trim_text(item, max_length)
		if text:
			result.append(text)
	return result


def parse_int_value(raw_value: Any, default: int = 0) -> int:
	try:
		return int(raw_value)
	except (TypeError, ValueError):
		return default


def describe_relationship_state(score: int) -> str:
	if score >= 40:
		return "가깝고 편한 사이"
	if score >= 15:
		return "호감과 신뢰가 쌓이는 중"
	if score <= -15:
		return "긴장과 경계가 남아 있음"
	return "아직 조심스럽게 거리를 재는 중"


def build_player_prompt_profile(player_character: dict[str, Any], fallback_name: str) -> dict[str, Any]:
	if not isinstance(player_character, dict):
		return {"name": fallback_name}
	return {
		"name": trim_text(player_character.get("name_ko", "") or fallback_name, 32),
		"summary": trim_text(player_character.get("summary", ""), 60),
		"main_personality": trim_text(player_character.get("main_personality", ""), 24),
	}


def build_character_prompt_profile(raw_character: Any, relationship_scores: dict[str, Any]) -> dict[str, Any]:
	if not isinstance(raw_character, dict):
		return {}

	character_id = trim_text(raw_character.get("id", ""), 40)
	relationship_score = parse_int_value(relationship_scores.get(character_id, 0), 0)
	return {
		"id": character_id,
		"name": trim_text(raw_character.get("name_ko", ""), 32),
		"role": trim_text(raw_character.get("role", ""), 24),
		"summary": trim_text(raw_character.get("summary", ""), MAX_PROFILE_TEXT_LENGTH),
		"main_personality": trim_text(raw_character.get("main_personality", ""), 24),
		"sub_personalities": summarize_strings(raw_character.get("sub_personalities", []), MAX_STYLE_TRAITS, 20),
		"speech_style": trim_text(raw_character.get("speech_style", ""), 72),
		"speech_examples": summarize_strings(raw_character.get("speech_examples", []), MAX_STYLE_EXAMPLES, 72),
		"goal": trim_text(raw_character.get("goal", ""), 72),
		"relationship_score": relationship_score,
		"relationship_state": describe_relationship_state(relationship_score),
	}


def get_character_profiles_by_id(source_payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
	persona = source_payload.get("persona", {})
	profiles_by_id: dict[str, dict[str, Any]] = {}
	main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
	for raw_character in main_characters:
		if not isinstance(raw_character, dict):
			continue
		character_id = str(raw_character.get("id", "")).strip()
		if character_id:
			profiles_by_id[character_id] = raw_character

	player_character = persona.get("player_character", {}) if isinstance(persona.get("player_character", {}), dict) else {}
	player_character_id = str(player_character.get("id", "")).strip()
	if player_character_id:
		profiles_by_id[player_character_id] = player_character

	return profiles_by_id


def get_character_profile_image_path(character_profile: Any) -> str:
	if not isinstance(character_profile, dict):
		return ""
	emotion_images = character_profile.get("emotion_images", {}) if isinstance(character_profile.get("emotion_images", {}), dict) else {}
	neutral_path = str(emotion_images.get("neutral", "")).strip()
	if neutral_path:
		return neutral_path
	return str(character_profile.get("thumbnail_path", "")).strip()


def build_sprite_candidates_by_character(sprite_candidates: list[dict[str, Any]]) -> dict[str, list[dict[str, Any]]]:
	candidates_by_character: dict[str, list[dict[str, Any]]] = {}
	for candidate in sprite_candidates:
		if not isinstance(candidate, dict):
			continue
		character_id = str(candidate.get("character_id", "")).strip()
		if not character_id:
			continue
		candidates_by_character.setdefault(character_id, []).append(candidate)
	return candidates_by_character


def pick_sprite_candidate_id(character_id: str, candidates_by_character: dict[str, list[dict[str, Any]]], character_profile: Any, requested_sprite_id: str = "") -> str:
	candidates = candidates_by_character.get(character_id, [])
	if not candidates:
		return ""

	available_ids = {str(candidate.get("id", "")).strip() for candidate in candidates if isinstance(candidate, dict)}
	clean_requested_sprite_id = requested_sprite_id.strip()
	if clean_requested_sprite_id and clean_requested_sprite_id in available_ids:
		return clean_requested_sprite_id

	if isinstance(character_profile, dict):
		for preferred_sprite_id in character_profile.get("preferred_sprite_ids", []):
			preferred_id = str(preferred_sprite_id).strip()
			if preferred_id and preferred_id in available_ids:
				return preferred_id

	for candidate in candidates:
		candidate_id = str(candidate.get("id", "")).strip()
		if candidate_id:
			return candidate_id

	return ""


def build_default_character_state(source_payload: dict[str, Any], sprite_candidates: list[dict[str, Any]], character_profiles_by_id: dict[str, dict[str, Any]]) -> dict[str, str]:
	persona = source_payload.get("persona", {})
	main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
	candidates_by_character = build_sprite_candidates_by_character(sprite_candidates)
	lead_character_profile: dict[str, Any] = {}
	# 사용자 캐릭터가 있으면 demo 캐릭터보다 우선
	user_main_chars = [c for c in main_characters if isinstance(c, dict) and not str(c.get('id', '')).startswith('demo_')]
	priority_main_chars = user_main_chars if user_main_chars else main_characters
	if priority_main_chars and isinstance(priority_main_chars[0], dict):
		lead_character_profile = priority_main_chars[0]
	else:
		lead_character_profile = persona.get("player_character", {}) if isinstance(persona.get("player_character", {}), dict) else {}

	lead_character_id = str(lead_character_profile.get("id", "")).strip()
	if not lead_character_id:
		return {}

	profile_image_path = get_character_profile_image_path(lead_character_profile)
	if profile_image_path:
		return {
			"character_id": lead_character_id,
			"image_path": profile_image_path,
			"position": "center",
		}

	resolved_sprite_id = pick_sprite_candidate_id(lead_character_id, candidates_by_character, character_profiles_by_id.get(lead_character_id, lead_character_profile))
	if resolved_sprite_id:
		return {
			"character_id": lead_character_id,
			"sprite_id": resolved_sprite_id,
			"position": "center",
		}

	return {}


def build_story_template_hint(raw_template: str) -> str:
	template = str(raw_template or "").strip().lower()
	template_hints = {
		"basic": "story.template=basic이면 인물 관계와 장면 전진을 우선한다.",
		"romance": "story.template=romance이면 미묘한 감정선, 말끝의 온도, 호감의 흔들림을 대사와 침묵에 녹인다.",
		"mystery": "story.template=mystery이면 단서를 한 번에 다 풀지 말고 의심, 여백, 숨은 정보의 긴장을 남긴다.",
		"horror": "story.template=horror이면 감각 묘사, 불안한 기척, 짧은 정적을 살려 서늘한 긴장을 만든다.",
		"adult": "story.template=adult이면 현재 rating 범위 안에서 성숙한 긴장과 감정의 밀도를 우선한다.",
	}
	return template_hints.get(template, "")


def get_dialogue_base_language_label() -> str:
	if OLLAMA_DIALOGUE_BASE_LANGUAGE == "en":
		return "영어"
	if OLLAMA_DIALOGUE_BASE_LANGUAGE == "auto":
		return "영어 또는 일본어"
	return "일본어"


def build_hybrid_dialogue_strategy_hint(lead_character_profile: dict[str, Any]) -> str:
	lead_name = trim_text(lead_character_profile.get("name", ""), 32) or "리드 캐릭터"
	main_personality = trim_text(lead_character_profile.get("main_personality", ""), 24)
	speech_style = trim_text(lead_character_profile.get("speech_style", ""), 48)
	has_examples = bool(lead_character_profile.get("speech_examples", []))
	parts = [
		f"1단계: {lead_name}의 캐릭터성을 살리기 위해 내부적으로 먼저 {get_dialogue_base_language_label()} 기반의 짧은 대사 초안을 구상한다.",
	]
	if main_personality:
		parts.append(f"성격 축은 {main_personality}이다.")
	if speech_style:
		parts.append(f"말투 축은 {speech_style}이다.")
	if has_examples:
		parts.append("speech_examples의 리듬과 호흡을 우선 참고한다.")
	parts.extend([
		"2단계: 그 초안을 KR 서비스용 자연스러운 한국어로 리라이팅한다.",
		"직역하지 말고 감정, 장난기, 거리감, 태도만 보존한다.",
	])
	return " ".join(parts)


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
	asset_candidates = source_payload.get("asset_candidates", {})
	default_rating = str(world.get("rating_lane", "general") or world.get("profile", {}).get("default_rating_lane", "general"))

	content = model_payload.get("content", {}) if isinstance(model_payload.get("content", {}), dict) else {}
	direction = model_payload.get("direction", {}) if isinstance(model_payload.get("direction", {}), dict) else {}
	state_update = model_payload.get("state_update", {}) if isinstance(model_payload.get("state_update", {}), dict) else {}
	memory_hint = model_payload.get("memory_hint", {}) if isinstance(model_payload.get("memory_hint", {}), dict) else {}
	audio = model_payload.get("audio", {}) if isinstance(model_payload.get("audio", {}), dict) else {}
	character_profiles_by_id = get_character_profiles_by_id(source_payload)

	background_id = coerce_asset_id(direction.get("background_id", ""), asset_candidates.get("backgrounds", []))
	character_states = normalize_character_states(direction.get("character_states", []), asset_candidates.get("sprites", []), character_profiles_by_id)
	if not character_states:
		default_character_state = build_default_character_state(source_payload, asset_candidates.get("sprites", []), character_profiles_by_id)
		if default_character_state:
			character_states = [default_character_state]
	cg_id = coerce_asset_id(direction.get("cg_id", ""), asset_candidates.get("cgs", []))
	bgm_id = coerce_asset_id(audio.get("bgm_id", ""), asset_candidates.get("bgms", []))
	sfx_id = coerce_asset_id(audio.get("sfx_id", ""), asset_candidates.get("sfxs", []))
	content_defaults = build_contextual_content_defaults(source_payload)
	primary_speaker_name = get_primary_speaker_name(source_payload)
	raw_narration = normalize_story_text(coerce_string(content.get("narration"), ""))
	raw_dialogue = sanitize_dialogue_text(coerce_string(content.get("dialogue"), ""), primary_speaker_name)
	raw_action = normalize_story_text(coerce_string(content.get("action"), ""))
	resolved_narration = raw_narration or content_defaults["narration"]
	resolved_dialogue = raw_dialogue or content_defaults["dialogue"]
	resolved_action = raw_action or content_defaults["action"]
	set_flags = state_update.get("set_flags", []) if isinstance(state_update.get("set_flags", []), list) else []
	missing_content_fields: list[str] = []
	if not raw_narration:
		missing_content_fields.append("narration")
	if not raw_dialogue:
		missing_content_fields.append("dialogue")
	if not raw_action:
		missing_content_fields.append("action")
	if missing_content_fields and "backend_partial_content_fallback" not in set_flags:
		set_flags = [*set_flags, "backend_partial_content_fallback"]

	return {
		"content": {
			"narration": resolved_narration,
			"dialogue": resolved_dialogue,
			"action": resolved_action,
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
			"set_flags": set_flags,
			"content_rating": coerce_rating(state_update.get("content_rating", default_rating), default_rating),
		},
		"memory_hint": {
			"summary_candidate": coerce_string(memory_hint.get("summary_candidate"), content_defaults["summary_candidate"]),
		},
		"audio": {
			"bgm_id": bgm_id,
			"sfx_id": sfx_id,
			"volume_profile": coerce_volume_profile(audio.get("volume_profile", "default")),
		},
	}


def normalize_for_compare(raw_value: Any) -> str:
	return " ".join(str(raw_value or "").strip().split()).lower()


def contains_non_korean_cjk(raw_value: Any) -> bool:
	for character in str(raw_value or ""):
		code_point = ord(character)
		if 0x4E00 <= code_point <= 0x9FFF:
			return True
	return False


def pick_variant(seed_text: str, variants: list[str]) -> str:
	if not variants:
		return ""
	seed_value = sum(ord(character) for character in seed_text)
	return variants[seed_value % len(variants)]


def contains_any_keyword(text: str, keywords: list[str]) -> bool:
	return any(keyword in text for keyword in keywords)


def normalize_story_text(raw_value: Any) -> str:
	value = " ".join(str(raw_value or "").strip().replace("\n", " ").replace("\r", " ").replace("\t", " ").split())
	if value.startswith("*") and value.endswith("*") and len(value) >= 2:
		value = value[1:-1].strip()
	return value


def strip_wrapping_quotes(raw_value: Any) -> str:
	value = normalize_story_text(raw_value)
	quote_pairs = [("\"", "\""), ("“", "”"), ("'", "'")]
	changed = True
	while changed and len(value) >= 2:
		changed = False
		for opening, closing in quote_pairs:
			if value.startswith(opening) and value.endswith(closing):
				value = value[len(opening) : len(value) - len(closing)].strip()
				changed = True
				break
	return value.strip("\"'“”‘’「」『』").strip()


def normalize_dialogue_prefix_token(raw_value: Any) -> str:
	return normalize_for_compare(raw_value).replace(" ", "").strip("\"'“”‘’「」『』")


def is_compact_hangul_text(raw_value: Any) -> bool:
	value = str(raw_value or "").replace(" ", "")
	if not value:
		return False
	return all(0xAC00 <= ord(character) <= 0xD7A3 for character in value)


def build_dialogue_speaker_aliases(speaker_name: str) -> set[str]:
	aliases: set[str] = set()
	normalized_speaker = normalize_dialogue_prefix_token(speaker_name)
	if normalized_speaker:
		aliases.add(normalized_speaker)

	for token in str(speaker_name or "").split():
		normalized_token = normalize_dialogue_prefix_token(token)
		if len(normalized_token) >= 2:
			aliases.add(normalized_token)

	if len(normalized_speaker) >= 3 and is_compact_hangul_text(normalized_speaker):
		aliases.add(normalized_speaker[1:])
		aliases.add(normalized_speaker[-2:])

	return {alias for alias in aliases if len(alias) >= 2}


def looks_like_internal_dialogue_prefix(raw_prefix: Any) -> bool:
	value = normalize_dialogue_prefix_token(raw_prefix)
	if value.endswith(":"):
		value = value[:-1]
	if len(value) < 3 or len(value) > 64:
		return False
	if "_" not in value and "-" not in value:
		return False
	allowed_characters = set("abcdefghijklmnopqrstuvwxyz0123456789_-")
	return all(character in allowed_characters for character in value)


def is_dialogue_metadata_prefix(raw_prefix: Any, speaker_name: str) -> bool:
	normalized_prefix = normalize_dialogue_prefix_token(raw_prefix)
	speaker_aliases = build_dialogue_speaker_aliases(speaker_name)
	prefix_without_colon = normalized_prefix[:-1] if normalized_prefix.endswith(":") else normalized_prefix
	prefix_parts = [part for part in prefix_without_colon.split(":") if part]
	if normalized_prefix in {
		"대사",
		"대사:",
		"화자",
		"화자:",
	} | speaker_aliases | {f"{alias}:" for alias in speaker_aliases} | {f"대사:{alias}" for alias in speaker_aliases}:
		return True
	if any(part in {"대사", "화자"} or part in speaker_aliases for part in prefix_parts):
		return True
	if any(looks_like_internal_dialogue_prefix(part) for part in prefix_parts):
		return True
	return looks_like_internal_dialogue_prefix(prefix_without_colon)


def sanitize_dialogue_text(raw_value: Any, speaker_name: str) -> str:
	value = normalize_story_text(raw_value)
	if not value:
		return value

	for prefix in [
		f"대사 : {speaker_name}",
		f"대사:{speaker_name}",
		f"{speaker_name} :",
		f"{speaker_name}:",
		"대사 :",
		"대사:",
		"화자 :",
		"화자:",
	]:
		if value.startswith(prefix):
			value = value[len(prefix) :].strip()
			break
	while value.startswith(":") or value.startswith("|"):
		value = value[1:].strip()

	colon_index = value.find(":")
	if colon_index != -1:
		possible_prefix = value[:colon_index].strip()
		if is_dialogue_metadata_prefix(possible_prefix, speaker_name):
			value = value[colon_index + 1 :].strip()

	if "|" in value:
		possible_prefix, possible_dialogue = value.split("|", 1)
		if is_dialogue_metadata_prefix(possible_prefix, speaker_name):
			value = possible_dialogue.strip()
			while value.startswith(":") or value.startswith("|"):
				value = value[1:].strip()

	return strip_wrapping_quotes(value)


def estimate_content_length(content: dict[str, Any]) -> int:
	return sum(
		len(normalize_story_text(content.get(key, "")))
		for key in ["narration", "dialogue", "action"]
	)


def get_primary_speaker_name(source_payload: dict[str, Any]) -> str:
	persona = source_payload.get("persona", {})
	main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
	if main_characters and isinstance(main_characters[0], dict):
		name = trim_text(main_characters[0].get("name_ko", "") or main_characters[0].get("name", ""), 32)
		if name:
			return name
	return "화자"


def build_contextual_content_defaults(source_payload: dict[str, Any]) -> dict[str, str]:
	persona = source_payload.get("persona", {})
	world = source_payload.get("world", {})
	runtime_state = source_payload.get("runtime_state", {})
	recent_conversation = source_payload.get("recent_conversation", [])
	world_profile = world.get("profile", {}) if isinstance(world.get("profile", {}), dict) else {}
	main_characters = persona.get("main_characters", []) if isinstance(persona.get("main_characters", []), list) else []
	player_character = persona.get("player_character", {}) if isinstance(persona.get("player_character", {}), dict) else {}
	world_name = trim_text(world_profile.get("story_title", "") or world_profile.get("name_ko", "선택된 세계관"), 80)
	player_input = trim_text(runtime_state.get("pending_player_input", ""), MAX_TEXT_LENGTH) or "다음 장면을 진행해 줘"
	player_name = trim_text(player_character.get("name_ko", "") or persona.get("player_name", "플레이어"), 32)
	lead_character_name = "상대"
	if main_characters and isinstance(main_characters[0], dict):
		lead_character_name = trim_text(main_characters[0].get("name_ko", "") or lead_character_name, 32)
	seed_text = f"{player_input}|{world_name}|{lead_character_name}|{len(recent_conversation)}"
	lower_input = player_input.lower()
	recent_lines = summarize_recent_conversation(recent_conversation)
	recent_seed = "|".join(recent_lines[-2:])
	seed_text = f"{seed_text}|{recent_seed}"

	if contains_any_keyword(lower_input, ["안녕", "반가", "처음"]):
		return {
			"narration": pick_variant(seed_text, [
				f"{world_name}의 저녁 공기는 아직 낯선 사람의 숨결을 경계하듯 가늘게 떨리고 있었지만, 네가 먼저 건넨 짧은 인사 한마디는 그 팽팽한 막을 의외로 쉽게 흔들었다. 책상 위에 흩어진 종이와 미처 닫히지 않은 창문 틈새까지도 조용히 숨을 죽인 채, 이제 막 시작될 대화의 방향을 기다리는 듯했다. {lead_character_name}은 손끝의 움직임을 멈추고 네 표정을 한 번 더 읽어 낸 뒤, 이번만큼은 형식적인 응대가 아니라 진짜 이야기를 들어 보겠다는 눈빛으로 시선을 맞춘다.",
			]),
			"dialogue": pick_variant(seed_text, [
				f"안녕, {player_name}. 이렇게 먼저 말을 걸어 주면 나도 조금 편해져. 서두르지 말고, 네가 여기까지 오면서 가장 오래 붙잡고 있던 생각부터 차근히 들려줘.",
			]),
			"action": pick_variant(seed_text, [
				f"{lead_character_name}이(가) 의자 등받이에서 몸을 살짝 떼고, 네가 다음 말을 고를 수 있도록 맞은편의 조용한 자리를 천천히 비워 둔다.",
			]),
			"summary_candidate": f"인사를 계기로 {world_name}의 첫 대화 흐름이 열렸다.",
		}

	if player_input.endswith("?") or contains_any_keyword(lower_input, ["왜", "어떻게", "뭐", "무슨", "정말"]):
		return {
			"narration": pick_variant(seed_text, [
				f"네 질문이 조용히 떨어지는 순간, {world_name}을 덮고 있던 느슨한 분위기는 눈에 띄게 팽팽해졌다. 그 말은 단순한 호기심이라기보다 지금까지 흘려보냈던 단서들을 한자리에 끌어모으는 힘을 지니고 있었고, {lead_character_name}도 곧바로 대답을 꺼내기보다 무엇이 사실이고 무엇이 불안에서 비롯된 추측인지부터 가늠하려는 얼굴로 숨을 고른다. 서둘러 결론을 내리면 오히려 핵심이 흐려질 수 있다는 걸 알기에, 장면은 한층 낮아진 목소리 속에서 더 정교하게 움직이기 시작한다.",
			]),
			"dialogue": pick_variant(seed_text, [
				"좋은 질문이야. 지금은 한 줄짜리 답으로 끝낼 수 있는 문제가 아니야. 먼저 우리가 본 것과 믿고 싶은 것을 나눠 놓으면, 놓친 실마리도 훨씬 선명하게 드러날 거야.",
			]),
			"action": pick_variant(seed_text, [
				f"{lead_character_name}이(가) 책상 위 메모를 손끝으로 끌어오며, 성급한 단정 대신 다음 판단에 필요한 순서를 차분히 정리하기 시작한다.",
			]),
			"summary_candidate": f"질문을 계기로 상황의 핵심 단서를 다시 정리하는 흐름이 만들어졌다.",
		}

	if contains_any_keyword(lower_input, ["도와", "도와줘", "부탁", "함께", "같이"]):
		return {
			"narration": pick_variant(seed_text, [
				f"네가 도움을 청하자 방 안을 조이던 긴장감도 아주 조금은 숨을 돌렸다. 혼자 감당하라는 말 대신 함께 움직일 수 있다는 가능성이 생기자, {world_name}의 무거운 공기 속에도 처음으로 분명한 틈이 생겨났다. {lead_character_name}은 네 요청을 부담으로 밀어내지 않고, 지금 당장 손에 쥘 수 있는 선택지부터 나눠 보자는 듯 자세를 고쳐 앉는다. 혼란이 사라진 것은 아니었지만 적어도 이 장면이 더 이상 혼자의 싸움처럼 느껴지지는 않았다.",
			]),
			"dialogue": pick_variant(seed_text, [
				"알겠어. 이번에는 내가 먼저 흐름을 정리할게. 너는 지금 가장 급한 것과 절대 놓치고 싶지 않은 것, 그 두 가지만 분명하게 말해 줘. 그러면 다음 선택은 내가 함께 좁혀 줄 수 있어.",
			]),
			"action": pick_variant(seed_text, [
				f"{lead_character_name}이(가) 네 쪽으로 몸을 조금 기울이며, 같은 편이라는 뜻을 분명히 하듯 낮은 목소리로 계획의 순서를 맞춰 간다.",
			]),
			"summary_candidate": f"도움을 요청한 뒤 협력 중심의 장면 전개가 시작되었다.",
		}

	if contains_any_keyword(lower_input, ["싫", "화나", "짜증", "불안", "무서", "답답"]):
		return {
			"narration": pick_variant(seed_text, [
				f"흔들리는 감정이 말끝에 그대로 묻어나오자 방 안의 온도도 눈에 띄게 가라앉았다. 억눌렀던 짜증과 불안이 한꺼번에 표면으로 떠오르면서, 지금 이 대화는 단순한 의견 교환이 아니라 무너지기 직전의 균형을 붙드는 시간이 되어 버렸다. {world_name}의 적막은 오히려 그 감정을 더 선명하게 되돌려 주었고, {lead_character_name}은 네 마음을 성급히 눌러 버리지 않으면서도 여기서 방향을 잃지 않게 하려는 듯 조심스럽게 호흡을 맞춘다.",
			]),
			"dialogue": pick_variant(seed_text, [
				"네가 그렇게 느끼는 건 당연해. 지금은 화를 참으라고 말할 생각 없어. 대신 그 감정이 어디서 시작됐는지만 붙잡자. 원인을 놓치지 않으면, 다음 선택이 감정에 끌려가는 대신 답에 더 가까워질 수 있어.",
			]),
			"action": pick_variant(seed_text, [
				f"{lead_character_name}이(가) 즉시 반박하지 않고 한 박자 쉬어 주며, 네가 삼킨 말을 더 꺼낼 수 있도록 침묵의 틈을 조용히 남긴다.",
			]),
			"summary_candidate": f"격해진 감정을 다루며 장면을 통제하려는 흐름이 이어졌다.",
		}

	return {
		"narration": pick_variant(seed_text, [
			f"방금 네가 건넨 말 한마디가 조용히 내려앉자 {world_name}의 공기도 미세하게 방향을 바꾸기 시작했다. 겉으로는 사소한 말처럼 보여도, 지금 이 장면에서는 다음 사건을 어디로 밀어 넣을지 결정하는 작은 추처럼 작용하고 있었다. {lead_character_name}은 그 뜻을 곧바로 단정하지 않고, 네가 끝내 입 밖으로 꺼내지 않은 뒷말과 망설임까지 읽어 내려가려는 표정으로 너를 바라본다. 그래서 침묵조차 단순한 공백이 아니라, 새로운 선택을 예고하는 준비 동작처럼 길고 선명하게 남았다.",
		]),
		"dialogue": pick_variant(seed_text, [
			"방금 네가 꺼낸 말은 그냥 흘려보내기엔 너무 선명해. 네가 정말 원하는 게 경고인지, 확인인지, 아니면 결심인지부터 분명히 해 보자. 방향만 선명해지면 다음 장면은 지금보다 훨씬 또렷하게 움직일 거야.",
		]),
		"action": pick_variant(seed_text, [
			f"{lead_character_name}이(가) 네 말의 무게를 재듯 시선을 고정한 채, 다음 반응이 자연스럽게 이어질 수 있도록 장면의 호흡을 차분히 열어 둔다.",
		]),
		"summary_candidate": "플레이어의 최근 입력을 계기로 다음 장면의 방향이 한 단계 구체화되었다.",
	}


def is_low_signal_content(content: dict[str, Any], recent_conversation: Any) -> bool:
	narration = normalize_story_text(content.get("narration", ""))
	dialogue = sanitize_dialogue_text(content.get("dialogue", ""), "화자")
	action = normalize_story_text(content.get("action", ""))
	normalized_narration = normalize_for_compare(narration)
	normalized_dialogue = normalize_for_compare(dialogue)
	normalized_action = normalize_for_compare(action)
	if not narration or not dialogue or not action:
		return True
	if len(narration) < MIN_NARRATION_LENGTH or len(dialogue) < MIN_DIALOGUE_LENGTH or len(action) < MIN_ACTION_LENGTH:
		return True
	if estimate_content_length({"narration": narration, "dialogue": dialogue, "action": action}) < MIN_ACCEPTABLE_SCRIPT_LENGTH:
		return True
	if any(contains_non_korean_cjk(content.get(key, "")) for key in ["narration", "dialogue", "action"]):
		return True
	recent_texts = summarize_recent_conversation(recent_conversation)
	normalized_recent = [normalize_for_compare(item) for item in recent_texts]
	repeated_matches = 0
	for value in [normalized_narration, normalized_dialogue, normalized_action]:
		if any(value and value in recent_value for recent_value in normalized_recent):
			repeated_matches += 1
	return repeated_matches >= 2


def normalize_character_states(raw_states: Any, sprite_candidates: list[dict[str, Any]], character_profiles_by_id: dict[str, dict[str, Any]]) -> list[dict[str, str]]:
	print(f"[DEBUG normalize_character_states] raw AI states: {raw_states}, known char ids: {list(character_profiles_by_id.keys())}")
	if not isinstance(raw_states, list):
		return []

	valid_positions = {"left", "center", "right"}
	candidates_by_character = build_sprite_candidates_by_character(sprite_candidates)

	resolved: list[dict[str, str]] = []
	seen_positions: set[str] = set()
	for raw_state in raw_states:
		if not isinstance(raw_state, dict):
			continue
		position = str(raw_state.get("position", "")).lower()
		character_id = str(raw_state.get("character_id", "")).strip()
		sprite_id = str(raw_state.get("sprite_id", "")).strip()
		image_path = str(raw_state.get("image_path", "")).strip()
		if position not in valid_positions or position in seen_positions or not character_id:
			continue

		# 알려진 프로필 목록이 있는데 character_id가 목록에 없으면 무시한다.
		# (AI가 demo_guide 등 잘못된 character_id를 생성한 경우를 방지)
		if character_profiles_by_id and character_id not in character_profiles_by_id:
			continue
		# AI가 demo_guide를 선택했지만 사용자 캐릭터가 있으면 사용자 캐릭터로 리다이렉트
		if character_id.startswith('demo_') and len(character_profiles_by_id) > 1:
			user_ids = [cid for cid in character_profiles_by_id if not cid.startswith('demo_')]
			if user_ids:
				character_id = user_ids[0]
				sprite_id = ''  # 사용자 캐릭터는 매니페스트 스프라이트 없음
		var_profile = character_profiles_by_id.get(character_id, {})
		resolved_sprite_id = pick_sprite_candidate_id(character_id, candidates_by_character, var_profile, sprite_id)
		if resolved_sprite_id:
			resolved.append({
				"character_id": character_id,
				"sprite_id": resolved_sprite_id,
				"position": position,
			})
		else:
			# emotion 필드로 캐릭터 프로필의 감정별 이미지를 선택한다.
			emotion = str(raw_state.get("emotion", "")).strip().lower()
			emotion_path = ""
			if emotion in ("neutral", "joy", "sad", "angry") and isinstance(var_profile.get("emotion_images"), dict):
				emotion_path = str(var_profile["emotion_images"].get(emotion, "")).strip()
			resolved_image_path = emotion_path or image_path or get_character_profile_image_path(var_profile)
			if not resolved_image_path:
				continue
			resolved.append({
				"character_id": character_id,
				"image_path": resolved_image_path,
				"position": position,
			})
		seen_positions.add(position)

	print(f"[DEBUG normalize_character_states] input states={len(raw_states) if isinstance(raw_states, list) else raw_states}, profiles={list(character_profiles_by_id.keys())}, sprite_candidates={len(sprite_candidates)}, resolved={resolved}")
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
	asset_candidates = source_payload.get("asset_candidates", {})
	world_profile = world.get("profile", {}) if isinstance(world.get("profile", {}), dict) else {}
	content_defaults = build_contextual_content_defaults(source_payload)
	sprite_candidates = asset_candidates.get("sprites", [])
	character_profiles_by_id = get_character_profiles_by_id(source_payload)
	background_id = coerce_asset_id("", asset_candidates.get("backgrounds", []))
	bgm_id = coerce_asset_id("", asset_candidates.get("bgms", []))
	character_states = []
	default_character_state = build_default_character_state(source_payload, sprite_candidates, character_profiles_by_id)
	if default_character_state:
		character_states.append(default_character_state)

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
			"narration": content_defaults["narration"],
			"dialogue": content_defaults["dialogue"],
			"action": content_defaults["action"],
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
			"summary_candidate": content_defaults["summary_candidate"],
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


def build_turn_prompt(payload: dict[str, Any], prompt_summary_cache: str = "") -> str:
	return build_direct_kr_prompt(payload, prompt_summary_cache=prompt_summary_cache)


def summarize_relationship_changes(turn_rows: list[dict[str, Any]]) -> str:
	relationship_totals: dict[str, int] = {}
	for turn_row in turn_rows:
		relationship_delta = turn_row.get("relationship_delta", {})
		if not isinstance(relationship_delta, dict):
			continue
		for key, value in relationship_delta.items():
			try:
				clean_value = int(value)
			except (TypeError, ValueError):
				continue
			if clean_value == 0:
				continue
			relationship_totals[str(key)] = relationship_totals.get(str(key), 0) + clean_value

	if not relationship_totals:
		return ""

	parts: list[str] = []
	for character_id, delta in list(sorted(relationship_totals.items(), key=lambda item: item[0]))[:3]:
		direction = "상승" if delta > 0 else "하락"
		parts.append(f"{character_id}:{direction}({delta:+d})")
	return ", ".join(parts)


def summarize_flag_changes(turn_rows: list[dict[str, Any]]) -> str:
	collected_flags: list[str] = []
	for turn_row in turn_rows:
		set_flags = turn_row.get("set_flags", [])
		if not isinstance(set_flags, list):
			continue
		for raw_flag in set_flags:
			flag_name = trim_text(raw_flag, 40)
			if flag_name and flag_name not in collected_flags:
				collected_flags.append(flag_name)
	if not collected_flags:
		return ""
	return ", ".join(collected_flags[:4])


def build_conservative_prompt_summary(turn_rows: list[dict[str, Any]]) -> str:
	if not turn_rows:
		return ""

	recent_rows = turn_rows[-3:]
	latest_turn = recent_rows[-1]
	lines: list[str] = []

	visual_parts: list[str] = []
	background_id = trim_text(latest_turn.get("background_id", ""), 40)
	cg_id = trim_text(latest_turn.get("cg_id", ""), 40)
	scene_mode = trim_text(latest_turn.get("scene_mode", ""), 16)
	if scene_mode:
		visual_parts.append(f"scene_mode={scene_mode}")
	if background_id:
		visual_parts.append(f"background={background_id}")
	if cg_id:
		visual_parts.append(f"cg={cg_id}")
	if visual_parts:
		lines.append("최근 시각 상태: " + ", ".join(visual_parts))

	relationship_summary = summarize_relationship_changes(recent_rows)
	if relationship_summary:
		lines.append("최근 관계 변화: " + relationship_summary)

	flag_summary = summarize_flag_changes(recent_rows)
	if flag_summary:
		lines.append("최근 플래그: " + flag_summary)

	flow_parts: list[str] = []
	for turn_row in recent_rows[-2:]:
		content_bits: list[str] = []
		narration = trim_text(turn_row.get("narration", ""), 60)
		dialogue = trim_text(strip_wrapping_quotes(turn_row.get("dialogue", "")), 48)
		action = trim_text(turn_row.get("action", ""), 40)
		if narration:
			content_bits.append(f"narration={narration}")
		if dialogue:
			content_bits.append(f"dialogue={dialogue}")
		if action:
			content_bits.append(f"action={action}")
		if content_bits:
			flow_parts.append(" / ".join(content_bits))
	if flow_parts:
		lines.append("직전 흐름: " + " || ".join(flow_parts))

	return trim_text("\n".join(lines), MAX_PROMPT_SUMMARY_LENGTH)
