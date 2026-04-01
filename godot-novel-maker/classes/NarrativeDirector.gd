extends Node
class_name NarrativeDirectorService

signal turn_started()
signal render_state_changed(render_state: Dictionary)
signal turn_failed(error_state: Dictionary)

var m_turn_in_progress := false
var m_pending_player_input := ""


func _ready() -> void:
	ai_client.turn_succeeded.connect(_on_turn_succeeded)
	ai_client.turn_failed.connect(_on_turn_failed)
	settings_manager.settings_changed.connect(_on_runtime_context_changed)
	asset_library.library_loaded.connect(_on_asset_library_loaded)
	story_profile_store.content_changed.connect(_on_content_profiles_changed)


func request_turn(player_input: String) -> void:
	if m_turn_in_progress:
		var error_state := {
			"kind": "busy",
			"message": "이미 다음 턴을 생성하고 있습니다."
		}
		game_state.m_last_status_message = str(error_state.get("message", ""))
		turn_failed.emit(error_state)
		return

	m_turn_in_progress = true
	m_pending_player_input = player_input.strip_edges()
	game_state.sync_runtime_snapshots()
	turn_started.emit()
	ai_client.request_turn(_build_turn_request(m_pending_player_input))


func emit_current_render_state() -> void:
	audio_manager.sync_audio_state(game_state.m_current_audio_state)
	render_state_changed.emit(game_state.build_render_snapshot())


func _build_turn_request(player_input: String) -> Dictionary:
	return {
		"persona": {
			"player_name": game_state.m_player_name,
			"player_character": game_state.m_selected_player_character_profile.duplicate(true),
			"relationship_scores": game_state.m_relationship_scores.duplicate(true),
			"main_characters": game_state.m_selected_main_character_profiles.duplicate(true)
		},
		"world": {
			"location_id": game_state.m_current_location_id,
			"rating_lane": game_state.m_current_rating_lane,
			"flags": game_state.m_flags.duplicate(true),
			"selected_world_id": game_state.m_selected_world_id,
			"profile": game_state.m_selected_world_profile.duplicate(true)
		},
		"runtime_state": {
			"pending_player_input": player_input,
			"scene_mode": str(game_state.m_current_visual_state.get("scene_mode", "layered")),
			"current_visual_state": game_state.m_current_visual_state.duplicate(true),
			"current_audio_state": game_state.m_current_audio_state.duplicate(true),
			"settings_snapshot": game_state.m_settings_snapshot.duplicate(true),
			"library_snapshot": game_state.m_library_snapshot.duplicate(true),
			"story_setup": game_state.build_story_setup_snapshot()
		},
		"recent_conversation": game_state.get_recent_conversation(10),
		"asset_candidates": asset_library.build_candidate_bundle(game_state)
	}


func _on_turn_succeeded(payload: Dictionary) -> void:
	m_turn_in_progress = false
	var player_input := m_pending_player_input
	m_pending_player_input = ""

	_apply_turn_payload(player_input, payload)
	audio_manager.apply_turn_audio_state(game_state.m_current_audio_state)
	render_state_changed.emit(game_state.build_render_snapshot())


func _on_turn_failed(error_state: Dictionary) -> void:
	m_turn_in_progress = false
	m_pending_player_input = ""
	game_state.m_last_status_message = str(error_state.get("message", "턴 생성에 실패했습니다."))
	turn_failed.emit(error_state)


func _on_runtime_context_changed(_settings: Dictionary) -> void:
	game_state.sync_runtime_snapshots()
	audio_manager.sync_audio_state(game_state.m_current_audio_state)
	render_state_changed.emit(game_state.build_render_snapshot())


func _on_asset_library_loaded(_snapshot: Dictionary) -> void:
	game_state.sync_runtime_snapshots()
	audio_manager.sync_audio_state(game_state.m_current_audio_state)
	render_state_changed.emit(game_state.build_render_snapshot())


func _on_content_profiles_changed() -> void:
	render_state_changed.emit(game_state.build_render_snapshot())


func _apply_turn_payload(player_input: String, payload: Dictionary) -> void:
	var content: Dictionary = payload.get("content", {})
	var direction: Dictionary = payload.get("direction", {})
	var state_update: Dictionary = payload.get("state_update", {})
	var memory_hint: Dictionary = payload.get("memory_hint", {})
	var audio: Dictionary = payload.get("audio", {})

	var next_rating_lane := _resolve_rating_lane(str(state_update.get("content_rating", game_state.m_current_rating_lane)))
	var resolved_visuals := _resolve_visual_state(direction, next_rating_lane)
	var resolved_audio := _resolve_audio_state(audio, next_rating_lane)
	var fallback_messages: Array = resolved_visuals.get("fallback_messages", []).duplicate(true)
	for message in resolved_audio.get("fallback_messages", []):
		fallback_messages.append(message)

	game_state.m_current_content = {
		"narration": str(content.get("narration", "")),
		"speaker_name": _derive_speaker_name(resolved_visuals.get("visual_state", {})),
		"dialogue": str(content.get("dialogue", "")),
		"action": str(content.get("action", ""))
	}

	game_state.m_current_visual_state = resolved_visuals.get("visual_state", game_state.build_default_visual_state())
	game_state.m_current_audio_state = resolved_audio.get("audio_state", game_state.build_default_audio_state())
	game_state.m_last_fallback_messages = fallback_messages
	game_state.m_last_status_message = _merge_status_messages([
		"출력 모드: %s" % str(game_state.m_current_visual_state.get("scene_mode", "layered")),
		str(resolved_visuals.get("status_message", "")),
		str(resolved_audio.get("status_message", ""))
	], "장면을 적용했습니다.")
	game_state.m_last_summary = str(memory_hint.get("summary_candidate", ""))
	game_state.m_current_rating_lane = next_rating_lane

	var resolved_background_id := str(game_state.m_current_visual_state.get("background_id", ""))
	if not resolved_background_id.is_empty():
		game_state.m_current_location_id = resolved_background_id

	_apply_relationship_delta(state_update.get("relationship_delta", {}))
	_apply_flags(state_update.get("set_flags", []))

	game_state.append_conversation_entry("player", player_input, {"type": "player_input"})
	game_state.append_conversation_entry("narration", str(content.get("narration", "")), {"type": "narration"})
	game_state.append_conversation_entry("character", str(content.get("dialogue", "")), {"speaker": game_state.m_current_content.get("speaker_name", "화자")})
	game_state.append_conversation_entry("system", str(content.get("action", "")), {"type": "action"})
	game_state.sync_runtime_snapshots()
	game_state.capture_rollback_snapshot()


func _resolve_visual_state(direction: Dictionary, rating_lane: String) -> Dictionary:
	var visual_state: Dictionary = game_state.m_current_visual_state.duplicate(true)
	if visual_state.is_empty():
		visual_state = game_state.build_default_visual_state()

	var fallback_messages: Array = []
	var requested_scene_mode := str(direction.get("scene_mode", visual_state.get("scene_mode", "layered")))
	if requested_scene_mode != "cg":
		requested_scene_mode = "layered"

	if direction.has("background_id"):
		var background_result := asset_library.validate_background_request(str(direction.get("background_id", "")), rating_lane)
		if bool(background_result.get("ok", false)):
			visual_state["background_id"] = str(background_result.get("id", visual_state.get("background_id", "")))
		else:
			var background_message := str(background_result.get("message", ""))
			if not background_message.is_empty():
				fallback_messages.append(background_message)

	if requested_scene_mode == "layered":
		var raw_character_states: Variant = direction.get("character_states", [])
		if raw_character_states is Array:
			visual_state["character_slots"] = _resolve_character_slots(raw_character_states, rating_lane, fallback_messages)
		visual_state["cg_id"] = ""
	else:
		var cg_result := asset_library.validate_cg_request(str(direction.get("cg_id", "")), rating_lane, game_state.m_flags)
		if bool(cg_result.get("ok", false)):
			visual_state["scene_mode"] = "cg"
			visual_state["cg_id"] = str(cg_result.get("id", ""))
			visual_state["character_slots"] = game_state.build_empty_character_slots()
		else:
			requested_scene_mode = "layered"
			visual_state["cg_id"] = ""
			var cg_message := str(cg_result.get("message", ""))
			if not cg_message.is_empty():
				fallback_messages.append(cg_message)

			var raw_character_states_fallback: Variant = direction.get("character_states", [])
			if raw_character_states_fallback is Array:
				visual_state["character_slots"] = _resolve_character_slots(raw_character_states_fallback, rating_lane, fallback_messages)

	if requested_scene_mode == "layered":
		visual_state["scene_mode"] = "layered"

	visual_state["transition"] = _resolve_transition(str(direction.get("transition", visual_state.get("transition", "fade"))))
	visual_state["camera_fx"] = _resolve_camera_fx(str(direction.get("camera_fx", visual_state.get("camera_fx", "none"))))

	var status_message := "장면을 적용했습니다."
	if not fallback_messages.is_empty():
		status_message = " | ".join(fallback_messages)

	return {
		"visual_state": visual_state,
		"fallback_messages": fallback_messages,
		"status_message": status_message
	}


func _resolve_audio_state(audio: Dictionary, rating_lane: String) -> Dictionary:
	var audio_state := game_state.m_current_audio_state.duplicate(true)
	if audio_state.is_empty():
		audio_state = game_state.build_default_audio_state()

	var fallback_messages: Array = []
	if audio.has("bgm_id"):
		var bgm_result := asset_library.validate_bgm_request(str(audio.get("bgm_id", "")), rating_lane)
		if bool(bgm_result.get("ok", false)):
			audio_state["bgm_id"] = str(bgm_result.get("id", audio_state.get("bgm_id", "")))
		else:
			var bgm_message := str(bgm_result.get("message", ""))
			if not bgm_message.is_empty():
				fallback_messages.append(bgm_message)

	if audio.has("sfx_id"):
		audio_state["sfx_id"] = ""
		var sfx_result := asset_library.validate_sfx_request(str(audio.get("sfx_id", "")), rating_lane)
		if bool(sfx_result.get("ok", false)):
			audio_state["sfx_id"] = str(sfx_result.get("id", ""))
		else:
			var sfx_message := str(sfx_result.get("message", ""))
			if not sfx_message.is_empty():
				fallback_messages.append(sfx_message)
	else:
		audio_state["sfx_id"] = ""

	audio_state["volume_profile"] = str(audio.get("volume_profile", audio_state.get("volume_profile", "default")))
	var status_message := ""
	if not fallback_messages.is_empty():
		status_message = " | ".join(fallback_messages)

	return {
		"audio_state": audio_state,
		"fallback_messages": fallback_messages,
		"status_message": status_message
	}


func _resolve_character_slots(raw_character_states: Array, rating_lane: String, fallback_messages: Array) -> Dictionary:
	var resolved_slots := game_state.build_empty_character_slots()
	var seen_slots := {}

	for raw_state in raw_character_states:
		if not (raw_state is Dictionary):
			fallback_messages.append("형식이 잘못된 캐릭터 상태 하나를 무시했습니다.")
			continue

		var resolved_state := asset_library.resolve_sprite_state(raw_state, rating_lane)
		var slot_name := str(resolved_state.get("slot", "")).to_lower()
		if slot_name.is_empty():
			continue

		if seen_slots.has(slot_name):
			fallback_messages.append("%s 슬롯에는 첫 번째 캐릭터만 유지했습니다." % slot_name)
			continue

		seen_slots[slot_name] = true
		var message := str(resolved_state.get("message", ""))
		if not message.is_empty():
			fallback_messages.append(message)

		if bool(resolved_state.get("ok", false)):
			resolved_slots[slot_name] = resolved_state.get("sprite_state", {}).duplicate(true)

	return resolved_slots


func _derive_speaker_name(visual_state: Dictionary) -> String:
	var character_slots: Dictionary = visual_state.get("character_slots", {})
	for slot_name in game_state.SLOT_NAMES:
		var slot_state: Variant = character_slots.get(slot_name, {})
		if slot_state is Dictionary:
			var character_id := str(slot_state.get("character_id", "")).strip_edges()
			if not character_id.is_empty():
				return game_state.get_character_display_name(character_id)

	var names := game_state.get_selected_main_character_names()
	if not names.is_empty():
		return str(names[0])

	return "화자"


func _apply_relationship_delta(raw_delta: Variant) -> void:
	if not (raw_delta is Dictionary):
		return

	for key in raw_delta.keys():
		var relationship_key := str(key)
		var old_value := int(game_state.m_relationship_scores.get(relationship_key, 0))
		game_state.m_relationship_scores[relationship_key] = old_value + int(raw_delta[key])


func _apply_flags(raw_flags: Variant) -> void:
	if not (raw_flags is Array):
		return

	for raw_flag in raw_flags:
		var flag_name := str(raw_flag).strip_edges()
		if not flag_name.is_empty():
			game_state.set_flag(flag_name)


func _resolve_rating_lane(raw_rating: String) -> String:
	match raw_rating:
		"general", "mature", "adult", "extreme":
			return raw_rating
		_:
			return game_state.m_current_rating_lane


func _resolve_transition(raw_transition: String) -> String:
	match raw_transition:
		"cut", "fade", "crossfade":
			return raw_transition
		_:
			return "fade"


func _resolve_camera_fx(raw_camera_fx: String) -> String:
	match raw_camera_fx:
		"none", "dim":
			return raw_camera_fx
		_:
			return "none"


func _merge_status_messages(messages: Array, fallback: String) -> String:
	var clean_messages: Array = []
	for message in messages:
		var clean_message := str(message).strip_edges()
		if not clean_message.is_empty() and not clean_messages.has(clean_message):
			clean_messages.append(clean_message)

	if clean_messages.is_empty():
		return fallback

	return " | ".join(clean_messages)
