extends Node
class_name GameStateService

const DEFAULT_PLAYER_NAME := "플레이어"
const DEFAULT_LOCATION_ID := "demo_room"
const DEFAULT_RATING_LANE := "general"
const SLOT_NAMES := ["left", "center", "right"]
const MAX_ROLLBACK_DEPTH := 20

var m_player_name := DEFAULT_PLAYER_NAME
var m_current_scene_name := "main_menu"
var m_current_location_id := DEFAULT_LOCATION_ID
var m_current_rating_lane := DEFAULT_RATING_LANE
var m_relationship_scores: Dictionary = {}
var m_flags: Dictionary = {}
var m_current_visual_state: Dictionary = {}
var m_current_audio_state: Dictionary = {}
var m_current_content: Dictionary = {}
var m_conversation_log: Array = []
var m_last_summary := ""
var m_last_status_message := ""
var m_last_fallback_messages: Array = []
var m_settings_snapshot: Dictionary = {}
var m_library_snapshot: Dictionary = {}
var m_rollback_snapshots: Array = []
var m_selected_world_id := ""
var m_selected_world_profile: Dictionary = {}
var m_selected_main_character_ids: Array = []
var m_selected_main_character_profiles: Array = []
var m_selected_player_character_id := ""
var m_selected_player_character_profile: Dictionary = {}
var m_dynamic_npc_enabled := true


func _ready() -> void:
	reset_for_new_game()
	m_current_scene_name = "main_menu"


func reset_for_new_game(selected_world: Dictionary = {}, selected_characters: Array = [], selected_player_character: Dictionary = {}) -> void:
	m_current_scene_name = "novel_scene"
	m_selected_world_profile = _normalize_world_profile(selected_world)
	m_selected_world_id = str(m_selected_world_profile.get("id", ""))
	m_selected_main_character_profiles = _normalize_character_profiles(selected_characters)
	m_selected_main_character_ids = _extract_character_ids(m_selected_main_character_profiles)
	m_selected_player_character_profile = _normalize_character_profile(selected_player_character)
	m_selected_player_character_id = str(m_selected_player_character_profile.get("id", ""))
	m_player_name = _derive_player_name()
	m_dynamic_npc_enabled = true
	m_current_rating_lane = str(m_selected_world_profile.get("default_rating_lane", DEFAULT_RATING_LANE))
	m_current_location_id = _derive_initial_location(m_selected_world_profile)
	m_relationship_scores = _build_initial_relationship_scores(m_selected_main_character_profiles)
	m_flags = {}
	m_current_visual_state = build_default_visual_state()
	m_current_audio_state = build_default_audio_state()
	m_current_content = {
		"narration": "이야기를 시작할 준비가 되었습니다.",
		"speaker_name": "시스템",
		"dialogue": _build_startup_dialogue(),
		"action": "입력창에 다음 장면으로 이어질 행동이나 대사를 적어 보세요."
	}
	m_conversation_log = []
	m_last_summary = ""
	m_last_status_message = _build_startup_status()
	m_last_fallback_messages = []
	sync_runtime_snapshots()
	reset_rollback_history()


func sync_runtime_snapshots() -> void:
	if settings_manager != null:
		m_settings_snapshot = settings_manager.get_settings_snapshot()

	if asset_library != null:
		m_library_snapshot = asset_library.get_snapshot()


func build_default_visual_state() -> Dictionary:
	return {
		"scene_mode": "layered",
		"background_id": "",
		"cg_id": "",
		"character_slots": build_empty_character_slots(),
		"transition": "fade",
		"camera_fx": "none"
	}


func build_default_audio_state() -> Dictionary:
	return {
		"bgm_id": "",
		"sfx_id": "",
		"volume_profile": "default"
	}


func build_empty_character_slots() -> Dictionary:
	var slots := {}
	for slot_name in SLOT_NAMES:
		slots[slot_name] = {}
	return slots


func apply_save_payload(payload: Dictionary, reset_rollback_history_state: bool = true) -> void:
	m_player_name = str(payload.get("player_name", DEFAULT_PLAYER_NAME))
	m_current_scene_name = str(payload.get("current_scene_name", "novel_scene"))
	m_current_location_id = str(payload.get("current_location_id", DEFAULT_LOCATION_ID))
	m_current_rating_lane = str(payload.get("current_rating_lane", DEFAULT_RATING_LANE))
	m_relationship_scores = _duplicate_dictionary(payload.get("relationship_scores", {}), {})
	m_flags = _duplicate_dictionary(payload.get("flags", {}), {})
	m_current_visual_state = _normalize_visual_state(payload.get("current_visual_state", build_default_visual_state()))
	m_current_audio_state = _normalize_audio_state(payload.get("current_audio_state", build_default_audio_state()))
	m_current_content = _normalize_content(payload.get("current_content", {}))
	m_conversation_log = _duplicate_array(payload.get("conversation_log", []))
	m_last_summary = str(payload.get("last_summary", ""))
	m_last_status_message = str(payload.get("last_status_message", ""))
	m_last_fallback_messages = _duplicate_array(payload.get("last_fallback_messages", []))
	m_settings_snapshot = _duplicate_dictionary(payload.get("settings_snapshot", {}), {})
	m_library_snapshot = _duplicate_dictionary(payload.get("library_snapshot", {}), {})
	m_selected_world_id = str(payload.get("selected_world_id", ""))
	m_selected_world_profile = _normalize_world_profile(payload.get("selected_world_profile", {}))
	m_selected_main_character_ids = _duplicate_array(payload.get("selected_main_character_ids", []))
	m_selected_main_character_profiles = _normalize_character_profiles(payload.get("selected_main_character_profiles", []))
	m_selected_player_character_id = str(payload.get("selected_player_character_id", ""))
	m_selected_player_character_profile = _normalize_character_profile(payload.get("selected_player_character_profile", {}))
	m_dynamic_npc_enabled = bool(payload.get("dynamic_npc_enabled", true))

	if m_selected_world_profile.is_empty() and not m_selected_world_id.is_empty():
		m_selected_world_profile = _normalize_world_profile(story_profile_store.get_world_by_id(m_selected_world_id))

	if m_selected_main_character_profiles.is_empty():
		var resolved_profiles: Array = []
		for character_id in m_selected_main_character_ids:
			var profile := story_profile_store.get_character_by_id(str(character_id))
			if not profile.is_empty():
				resolved_profiles.append(profile)
		m_selected_main_character_profiles = _normalize_character_profiles(resolved_profiles)

	if m_selected_main_character_ids.is_empty():
		m_selected_main_character_ids = _extract_character_ids(m_selected_main_character_profiles)

	if m_selected_player_character_profile.is_empty() and not m_selected_player_character_id.is_empty():
		m_selected_player_character_profile = _normalize_character_profile(story_profile_store.get_character_by_id(m_selected_player_character_id))

	if m_selected_player_character_id.is_empty() and not m_selected_player_character_profile.is_empty():
		m_selected_player_character_id = str(m_selected_player_character_profile.get("id", ""))

	m_player_name = _derive_player_name()

	if reset_rollback_history_state:
		reset_rollback_history()


func build_save_payload() -> Dictionary:
	sync_runtime_snapshots()

	return {
		"player_name": m_player_name,
		"current_scene_name": m_current_scene_name,
		"current_location_id": m_current_location_id,
		"current_rating_lane": m_current_rating_lane,
		"relationship_scores": m_relationship_scores.duplicate(true),
		"flags": m_flags.duplicate(true),
		"current_visual_state": m_current_visual_state.duplicate(true),
		"current_audio_state": m_current_audio_state.duplicate(true),
		"current_content": m_current_content.duplicate(true),
		"conversation_log": m_conversation_log.duplicate(true),
		"last_summary": m_last_summary,
		"last_status_message": m_last_status_message,
		"last_fallback_messages": m_last_fallback_messages.duplicate(true),
		"settings_snapshot": m_settings_snapshot.duplicate(true),
		"library_snapshot": m_library_snapshot.duplicate(true),
		"selected_world_id": m_selected_world_id,
		"selected_world_profile": m_selected_world_profile.duplicate(true),
		"selected_main_character_ids": m_selected_main_character_ids.duplicate(true),
		"selected_main_character_profiles": m_selected_main_character_profiles.duplicate(true),
		"selected_player_character_id": m_selected_player_character_id,
		"selected_player_character_profile": m_selected_player_character_profile.duplicate(true),
		"dynamic_npc_enabled": m_dynamic_npc_enabled
	}


func build_render_snapshot() -> Dictionary:
	sync_runtime_snapshots()

	return {
		"scene_name": m_current_scene_name,
		"location_id": m_current_location_id,
		"rating_lane": m_current_rating_lane,
		"visual_state": m_current_visual_state.duplicate(true),
		"audio_state": m_current_audio_state.duplicate(true),
		"content": m_current_content.duplicate(true),
		"status_message": m_last_status_message,
		"fallback_messages": m_last_fallback_messages.duplicate(true),
		"settings_snapshot": m_settings_snapshot.duplicate(true),
		"library_snapshot": m_library_snapshot.duplicate(true),
		"relationship_scores": m_relationship_scores.duplicate(true),
		"flags": m_flags.duplicate(true),
		"selected_world_id": m_selected_world_id,
		"selected_world_profile": m_selected_world_profile.duplicate(true),
		"selected_main_character_ids": m_selected_main_character_ids.duplicate(true),
		"selected_main_character_profiles": m_selected_main_character_profiles.duplicate(true),
		"selected_player_character_id": m_selected_player_character_id,
		"selected_player_character_profile": m_selected_player_character_profile.duplicate(true),
		"story_setup": build_story_setup_snapshot(),
		"can_rollback": can_rollback()
	}


func build_story_setup_snapshot() -> Dictionary:
	return {
		"world_id": m_selected_world_id,
		"world_name": get_selected_world_name(),
		"main_character_ids": m_selected_main_character_ids.duplicate(true),
		"main_character_names": get_selected_main_character_names(),
		"player_character_id": m_selected_player_character_id,
		"player_character_name": get_selected_player_character_name(),
		"dynamic_npc_enabled": m_dynamic_npc_enabled,
		"start_setup_name": str(m_selected_world_profile.get("start_setup_name", "")),
		"prologue": str(m_selected_world_profile.get("prologue", "")),
		"initial_situation": str(m_selected_world_profile.get("initial_situation", ""))
	}


func get_selected_world_name() -> String:
	if not m_selected_world_profile.is_empty():
		var display_title := story_profile_store.get_world_display_title(m_selected_world_profile)
		if not display_title.is_empty():
			return display_title
	return "미선택"


func get_selected_main_character_names() -> Array:
	var names: Array = []
	for profile in m_selected_main_character_profiles:
		var name_text := str((profile as Dictionary).get("name_ko", ""))
		if not name_text.is_empty():
			names.append(name_text)
	return names


func get_selected_player_character_name() -> String:
	if not m_selected_player_character_profile.is_empty():
		var name_text := str(m_selected_player_character_profile.get("name_ko", "")).strip_edges()
		if not name_text.is_empty():
			return name_text
	return DEFAULT_PLAYER_NAME


func get_main_character_summary_text() -> String:
	var names := get_selected_main_character_names()
	if names.is_empty():
		return "미선택"
	return ", ".join(names)


func get_character_display_name(character_id: String) -> String:
	var clean_id := character_id.strip_edges()
	if clean_id == m_selected_player_character_id and not m_selected_player_character_profile.is_empty():
		return get_selected_player_character_name()
	for profile in m_selected_main_character_profiles:
		if str((profile as Dictionary).get("id", "")) == clean_id:
			return str((profile as Dictionary).get("name_ko", clean_id))
	return story_profile_store.get_character_name(clean_id)


func append_conversation_entry(role: String, text: String, metadata: Dictionary = {}) -> void:
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return

	m_conversation_log.append({
		"role": role,
		"text": clean_text,
		"metadata": metadata.duplicate(true)
	})

	if m_conversation_log.size() > 40:
		m_conversation_log.remove_at(0)


func get_recent_conversation(limit: int = 10) -> Array:
	if limit <= 0:
		return []

	var start_index := maxi(m_conversation_log.size() - limit, 0)
	var recent_entries: Array = []
	for index in range(start_index, m_conversation_log.size()):
		recent_entries.append(m_conversation_log[index])
	return recent_entries


func set_current_scene_name(scene_name: String) -> void:
	m_current_scene_name = scene_name


func set_flag(flag_name: String, enabled: bool = true) -> void:
	m_flags[flag_name] = enabled


func has_flag(flag_name: String) -> bool:
	return bool(m_flags.get(flag_name, false))


func capture_rollback_snapshot() -> void:
	var snapshot := build_save_payload()
	m_rollback_snapshots.append(snapshot)
	while m_rollback_snapshots.size() > MAX_ROLLBACK_DEPTH:
		m_rollback_snapshots.remove_at(0)


func reset_rollback_history() -> void:
	m_rollback_snapshots = []
	capture_rollback_snapshot()


func can_rollback() -> bool:
	return m_rollback_snapshots.size() > 1


func rollback_to_previous_snapshot() -> bool:
	if not can_rollback():
		return false

	m_rollback_snapshots.remove_at(m_rollback_snapshots.size() - 1)
	var previous_snapshot: Dictionary = m_rollback_snapshots[m_rollback_snapshots.size() - 1]
	apply_save_payload(previous_snapshot, false)
	return true


func _build_initial_relationship_scores(character_profiles: Array) -> Dictionary:
	var scores := {}
	for profile in character_profiles:
		var character_id := str((profile as Dictionary).get("id", "")).strip_edges()
		if not character_id.is_empty():
			scores[character_id] = 0
	if scores.is_empty():
		scores["demo_guide"] = 0
	return scores


func _derive_player_name() -> String:
	if not m_selected_player_character_profile.is_empty():
		var name_text := str(m_selected_player_character_profile.get("name_ko", "")).strip_edges()
		if not name_text.is_empty():
			return name_text
	return DEFAULT_PLAYER_NAME


func _derive_initial_location(world_profile: Dictionary) -> String:
	var notable_places: Array = world_profile.get("notable_places", [])
	if not notable_places.is_empty():
		return str(notable_places[0])
	return DEFAULT_LOCATION_ID


func _build_startup_dialogue() -> String:
	var world_name := get_selected_world_name()
	var main_characters := get_main_character_summary_text()
	var prologue := str(m_selected_world_profile.get("prologue", "")).strip_edges()
	if world_name == "미선택":
		return "메인 메뉴에서 세계관과 메인 캐릭터를 고른 뒤 이야기를 시작해 주세요."
	if not prologue.is_empty():
		return "%s\n\n주요 인물: %s" % [prologue, main_characters]
	return "%s 세계관과 %s 중심으로 장면을 생성할 준비가 끝났습니다." % [world_name, main_characters]


func _build_startup_status() -> String:
	var world_name := get_selected_world_name()
	var start_setup_name := str(m_selected_world_profile.get("start_setup_name", "")).strip_edges()
	if world_name == "미선택":
		return "세계관과 메인 캐릭터를 선택하면 로컬 세션을 시작할 수 있습니다."
	if start_setup_name.is_empty():
		return "%s 설정으로 새 이야기를 시작했습니다." % world_name
	return "%s의 '%s' 설정으로 이야기를 시작했습니다." % [world_name, start_setup_name]


func _normalize_visual_state(raw_value: Variant) -> Dictionary:
	var base_state := build_default_visual_state()
	if raw_value is Dictionary:
		base_state["scene_mode"] = str(raw_value.get("scene_mode", base_state["scene_mode"]))
		base_state["background_id"] = str(raw_value.get("background_id", base_state["background_id"]))
		base_state["cg_id"] = str(raw_value.get("cg_id", base_state["cg_id"]))
		base_state["transition"] = str(raw_value.get("transition", base_state["transition"]))
		base_state["camera_fx"] = str(raw_value.get("camera_fx", base_state["camera_fx"]))

		var raw_slots: Variant = raw_value.get("character_slots", {})
		if raw_slots is Dictionary:
			var normalized_slots := build_empty_character_slots()
			for slot_name in SLOT_NAMES:
				var slot_value: Variant = raw_slots.get(slot_name, {})
				if slot_value is Dictionary:
					normalized_slots[slot_name] = slot_value.duplicate(true)
			base_state["character_slots"] = normalized_slots

	if str(base_state["scene_mode"]) != "cg":
		base_state["scene_mode"] = "layered"

	return base_state


func _normalize_audio_state(raw_value: Variant) -> Dictionary:
	var base_state := build_default_audio_state()
	if raw_value is Dictionary:
		base_state["bgm_id"] = str(raw_value.get("bgm_id", ""))
		base_state["sfx_id"] = str(raw_value.get("sfx_id", ""))
		base_state["volume_profile"] = str(raw_value.get("volume_profile", "default"))
	return base_state


func _normalize_content(raw_value: Variant) -> Dictionary:
	var base_content := {
		"narration": "",
		"speaker_name": "화자",
		"dialogue": "",
		"action": ""
	}

	if raw_value is Dictionary:
		base_content["narration"] = str(raw_value.get("narration", ""))
		base_content["speaker_name"] = str(raw_value.get("speaker_name", "화자"))
		base_content["dialogue"] = str(raw_value.get("dialogue", ""))
		base_content["action"] = str(raw_value.get("action", ""))

	return base_content


func _normalize_world_profile(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return {
			"id": str(raw_value.get("id", "")).strip_edges(),
			"name_ko": str(raw_value.get("name_ko", "")).strip_edges(),
			"story_title": str(raw_value.get("story_title", "")).strip_edges(),
			"summary": str(raw_value.get("summary", "")).strip_edges(),
			"genre": str(raw_value.get("genre", "")).strip_edges(),
			"tone": str(raw_value.get("tone", "")).strip_edges(),
			"premise": str(raw_value.get("premise", "")).strip_edges(),
			"core_rules": _duplicate_array(raw_value.get("core_rules", [])),
			"notable_places": _duplicate_array(raw_value.get("notable_places", [])),
			"story_prompt_template": str(raw_value.get("story_prompt_template", "basic")).strip_edges(),
			"story_examples": _duplicate_array(raw_value.get("story_examples", [])),
			"start_setup_name": str(raw_value.get("start_setup_name", "")).strip_edges(),
			"prologue": str(raw_value.get("prologue", "")).strip_edges(),
			"initial_situation": str(raw_value.get("initial_situation", "")).strip_edges(),
			"player_guide": str(raw_value.get("player_guide", "")).strip_edges(),
			"default_main_character_ids": _duplicate_array(raw_value.get("default_main_character_ids", [])),
			"square_cover_path": str(raw_value.get("square_cover_path", "")).strip_edges(),
			"portrait_cover_path": str(raw_value.get("portrait_cover_path", "")).strip_edges(),
			"default_rating_lane": str(raw_value.get("default_rating_lane", DEFAULT_RATING_LANE)).strip_edges(),
			"notes": str(raw_value.get("notes", "")).strip_edges()
		}
	return {}


func _normalize_character_profiles(raw_value: Variant) -> Array:
	var profiles: Array = []
	if raw_value is Array:
		for entry in raw_value:
			if entry is Dictionary:
				profiles.append(_normalize_character_profile(entry))
	return profiles


func _normalize_character_profile(raw_value: Variant) -> Dictionary:
	if raw_value is Dictionary:
		return {
			"id": str(raw_value.get("id", "")).strip_edges(),
			"name_ko": str(raw_value.get("name_ko", "")).strip_edges(),
			"role": str(raw_value.get("role", "")).strip_edges(),
			"summary": str(raw_value.get("summary", "")).strip_edges(),
			"thumbnail_path": str(raw_value.get("thumbnail_path", "")).strip_edges(),
			"main_personality": str(raw_value.get("main_personality", "")).strip_edges(),
			"sub_personalities": _duplicate_array(raw_value.get("sub_personalities", [])),
			"speech_examples": _duplicate_array(raw_value.get("speech_examples", [])),
			"appearance": str(raw_value.get("appearance", "")).strip_edges(),
			"emotion_images": _duplicate_dictionary(raw_value.get("emotion_images", {}), {}),
			"event_images": _duplicate_array(raw_value.get("event_images", [])),
			"personality_tags": _duplicate_array(raw_value.get("personality_tags", [])),
			"speech_style": str(raw_value.get("speech_style", "")).strip_edges(),
			"goal": str(raw_value.get("goal", "")).strip_edges(),
			"preferred_sprite_ids": _duplicate_array(raw_value.get("preferred_sprite_ids", [])),
			"notes": str(raw_value.get("notes", "")).strip_edges()
		}
	return {}


func _extract_character_ids(profiles: Array) -> Array:
	var ids: Array = []
	for profile in profiles:
		var character_id := str((profile as Dictionary).get("id", "")).strip_edges()
		if not character_id.is_empty():
			ids.append(character_id)
	return ids


func _duplicate_dictionary(raw_value: Variant, fallback: Dictionary) -> Dictionary:
	if raw_value is Dictionary:
		return raw_value.duplicate(true)
	return fallback.duplicate(true)


func _duplicate_array(raw_value: Variant) -> Array:
	if raw_value is Array:
		return raw_value.duplicate(true)
	return []
