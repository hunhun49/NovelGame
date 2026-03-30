extends Node

signal turn_started()
signal render_state_changed(render_state: Dictionary)
signal turn_failed(error_state: Dictionary)

var _turn_in_progress := false
var _pending_player_input := ""


func _ready() -> void:
	AiClient.turn_succeeded.connect(_on_turn_succeeded)
	AiClient.turn_failed.connect(_on_turn_failed)
	SettingsManager.settings_changed.connect(_on_runtime_context_changed)
	AssetLibrary.library_loaded.connect(_on_asset_library_loaded)


func request_turn(player_input: String) -> void:
	if _turn_in_progress:
		var error_state := {
			"kind": "busy",
			"message": "A turn is already being generated."
		}
		GameState.last_status_message = str(error_state.get("message", ""))
		turn_failed.emit(error_state)
		return

	_turn_in_progress = true
	_pending_player_input = player_input.strip_edges()
	GameState.sync_runtime_snapshots()
	turn_started.emit()
	AiClient.request_turn(_build_turn_request(_pending_player_input))


func emit_current_render_state() -> void:
	render_state_changed.emit(GameState.build_render_snapshot())


func _build_turn_request(player_input: String) -> Dictionary:
	return {
		"persona": {
			"player_name": GameState.player_name,
			"relationship_scores": GameState.relationship_scores.duplicate(true)
		},
		"world": {
			"location_id": GameState.current_location_id,
			"rating_lane": GameState.current_rating_lane,
			"flags": GameState.flags.duplicate(true)
		},
		"runtime_state": {
			"pending_player_input": player_input,
			"scene_mode": str(GameState.current_visual_state.get("scene_mode", "layered")),
			"current_visual_state": GameState.current_visual_state.duplicate(true),
			"settings_snapshot": GameState.settings_snapshot.duplicate(true),
			"library_snapshot": GameState.library_snapshot.duplicate(true)
		},
		"recent_conversation": GameState.get_recent_conversation(10),
		"asset_candidates": AssetLibrary.build_candidate_bundle(GameState)
	}


func _on_turn_succeeded(payload: Dictionary) -> void:
	_turn_in_progress = false
	var player_input := _pending_player_input
	_pending_player_input = ""

	_apply_turn_payload(player_input, payload)
	render_state_changed.emit(GameState.build_render_snapshot())


func _on_turn_failed(error_state: Dictionary) -> void:
	_turn_in_progress = false
	_pending_player_input = ""
	GameState.last_status_message = str(error_state.get("message", "Turn generation failed."))
	turn_failed.emit(error_state)


func _on_runtime_context_changed(_settings: Dictionary) -> void:
	GameState.sync_runtime_snapshots()
	render_state_changed.emit(GameState.build_render_snapshot())


func _on_asset_library_loaded(_snapshot: Dictionary) -> void:
	GameState.sync_runtime_snapshots()
	render_state_changed.emit(GameState.build_render_snapshot())


func _apply_turn_payload(player_input: String, payload: Dictionary) -> void:
	var content: Dictionary = payload.get("content", {})
	var direction: Dictionary = payload.get("direction", {})
	var state_update: Dictionary = payload.get("state_update", {})
	var memory_hint: Dictionary = payload.get("memory_hint", {})

	var next_rating_lane := _resolve_rating_lane(str(state_update.get("content_rating", GameState.current_rating_lane)))
	var resolved_visuals := _resolve_visual_state(direction, next_rating_lane)

	GameState.current_content = {
		"narration": str(content.get("narration", "")),
		"speaker_name": _derive_speaker_name(resolved_visuals.get("visual_state", {})),
		"dialogue": str(content.get("dialogue", "")),
		"action": str(content.get("action", ""))
	}

	GameState.current_visual_state = resolved_visuals.get("visual_state", GameState.build_default_visual_state())
	GameState.last_fallback_messages = resolved_visuals.get("fallback_messages", []).duplicate(true)
	GameState.last_status_message = str(resolved_visuals.get("status_message", "Turn applied."))
	GameState.last_summary = str(memory_hint.get("summary_candidate", ""))
	GameState.current_rating_lane = next_rating_lane

	var resolved_background_id := str(GameState.current_visual_state.get("background_id", ""))
	if not resolved_background_id.is_empty():
		GameState.current_location_id = resolved_background_id

	_apply_relationship_delta(state_update.get("relationship_delta", {}))
	_apply_flags(state_update.get("set_flags", []))

	GameState.append_conversation_entry("player", player_input, {"type": "player_input"})
	GameState.append_conversation_entry("narration", str(content.get("narration", "")), {"type": "narration"})
	GameState.append_conversation_entry("character", str(content.get("dialogue", "")), {"speaker": GameState.current_content.get("speaker_name", "Narrator")})
	GameState.append_conversation_entry("system", str(content.get("action", "")), {"type": "action"})
	GameState.sync_runtime_snapshots()


func _resolve_visual_state(direction: Dictionary, rating_lane: String) -> Dictionary:
	var visual_state: Dictionary = GameState.current_visual_state.duplicate(true)
	if visual_state.is_empty():
		visual_state = GameState.build_default_visual_state()

	var fallback_messages: Array = []
	var requested_scene_mode := str(direction.get("scene_mode", visual_state.get("scene_mode", "layered")))
	if requested_scene_mode != "cg":
		requested_scene_mode = "layered"

	if direction.has("background_id"):
		var background_result := AssetLibrary.validate_background_request(str(direction.get("background_id", "")), rating_lane)
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
		var cg_result := AssetLibrary.validate_cg_request(str(direction.get("cg_id", "")), rating_lane, GameState.flags)
		if bool(cg_result.get("ok", false)):
			visual_state["scene_mode"] = "cg"
			visual_state["cg_id"] = str(cg_result.get("id", ""))
			visual_state["character_slots"] = GameState.build_empty_character_slots()
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

	visual_state["transition"] = str(direction.get("transition", visual_state.get("transition", "fade")))
	visual_state["camera_fx"] = str(direction.get("camera_fx", visual_state.get("camera_fx", "none")))

	var status_message := "Turn applied."
	if not fallback_messages.is_empty():
		status_message = " | ".join(fallback_messages)

	return {
		"visual_state": visual_state,
		"fallback_messages": fallback_messages,
		"status_message": status_message
	}


func _resolve_character_slots(raw_character_states: Array, rating_lane: String, fallback_messages: Array) -> Dictionary:
	var resolved_slots := GameState.build_empty_character_slots()
	var seen_slots := {}

	for raw_state in raw_character_states:
		if not (raw_state is Dictionary):
			fallback_messages.append("A malformed character state was ignored.")
			continue

		var resolved_state := AssetLibrary.resolve_sprite_state(raw_state, rating_lane)
		var slot_name := str(resolved_state.get("slot", "")).to_lower()
		if slot_name.is_empty():
			continue

		if seen_slots.has(slot_name):
			fallback_messages.append("Multiple character states targeted the %s slot; only the first was used." % slot_name)
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
	for slot_name in GameState.SLOT_NAMES:
		var slot_state: Variant = character_slots.get(slot_name, {})
		if slot_state is Dictionary:
			var character_id := str(slot_state.get("character_id", "")).strip_edges()
			if not character_id.is_empty():
				return character_id.capitalize()
	return "Narrator"


func _apply_relationship_delta(raw_delta: Variant) -> void:
	if not (raw_delta is Dictionary):
		return

	for key in raw_delta.keys():
		var relationship_key := str(key)
		var old_value := int(GameState.relationship_scores.get(relationship_key, 0))
		GameState.relationship_scores[relationship_key] = old_value + int(raw_delta[key])


func _apply_flags(raw_flags: Variant) -> void:
	if not (raw_flags is Array):
		return

	for raw_flag in raw_flags:
		var flag_name := str(raw_flag).strip_edges()
		if not flag_name.is_empty():
			GameState.set_flag(flag_name)


func _resolve_rating_lane(raw_rating: String) -> String:
	match raw_rating:
		"general", "mature", "adult", "extreme":
			return raw_rating
		_:
			return GameState.current_rating_lane
