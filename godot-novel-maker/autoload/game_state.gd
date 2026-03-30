extends Node

const DEFAULT_PLAYER_NAME := "Player"
const DEFAULT_LOCATION_ID := "prototype_room_night"
const DEFAULT_RATING_LANE := "general"
const SLOT_NAMES := ["left", "center", "right"]

var player_name := DEFAULT_PLAYER_NAME
var current_scene_name := "main_menu"
var current_location_id := DEFAULT_LOCATION_ID
var current_rating_lane := DEFAULT_RATING_LANE
var relationship_scores: Dictionary = {}
var flags: Dictionary = {}
var current_visual_state: Dictionary = {}
var current_content: Dictionary = {}
var conversation_log: Array = []
var last_summary := ""
var last_status_message := ""
var last_fallback_messages: Array = []
var settings_snapshot: Dictionary = {}
var library_snapshot: Dictionary = {}


func _ready() -> void:
	reset_for_new_game()
	current_scene_name = "main_menu"


func reset_for_new_game() -> void:
	player_name = DEFAULT_PLAYER_NAME
	current_scene_name = "novel_scene"
	current_location_id = DEFAULT_LOCATION_ID
	current_rating_lane = DEFAULT_RATING_LANE
	relationship_scores = {"prototype_heroine": 0}
	flags = {}
	current_visual_state = build_default_visual_state()
	current_content = {
		"narration": "Session ready. Configure a library or enable stub mode, then enter a prompt.",
		"speaker_name": "System",
		"dialogue": "The visual novel shell is waiting for the first turn.",
		"action": "No scene has been generated yet."
	}
	conversation_log = []
	last_summary = ""
	last_status_message = "Ready."
	last_fallback_messages = []
	sync_runtime_snapshots()


func sync_runtime_snapshots() -> void:
	if SettingsManager != null:
		settings_snapshot = SettingsManager.get_settings_snapshot()

	if AssetLibrary != null:
		library_snapshot = AssetLibrary.get_snapshot()


func build_default_visual_state() -> Dictionary:
	return {
		"scene_mode": "layered",
		"background_id": "",
		"cg_id": "",
		"character_slots": build_empty_character_slots(),
		"transition": "fade",
		"camera_fx": "none"
	}


func build_empty_character_slots() -> Dictionary:
	var slots := {}
	for slot_name in SLOT_NAMES:
		slots[slot_name] = {}
	return slots


func apply_save_payload(payload: Dictionary) -> void:
	player_name = str(payload.get("player_name", DEFAULT_PLAYER_NAME))
	current_scene_name = str(payload.get("current_scene_name", "novel_scene"))
	current_location_id = str(payload.get("current_location_id", DEFAULT_LOCATION_ID))
	current_rating_lane = str(payload.get("current_rating_lane", DEFAULT_RATING_LANE))
	relationship_scores = _duplicate_dictionary(payload.get("relationship_scores", {"prototype_heroine": 0}), {"prototype_heroine": 0})
	flags = _duplicate_dictionary(payload.get("flags", {}), {})
	current_visual_state = _normalize_visual_state(payload.get("current_visual_state", build_default_visual_state()))
	current_content = _normalize_content(payload.get("current_content", {}))
	conversation_log = _duplicate_array(payload.get("conversation_log", []))
	last_summary = str(payload.get("last_summary", ""))
	last_status_message = str(payload.get("last_status_message", ""))
	last_fallback_messages = _duplicate_array(payload.get("last_fallback_messages", []))
	settings_snapshot = _duplicate_dictionary(payload.get("settings_snapshot", {}), {})
	library_snapshot = _duplicate_dictionary(payload.get("library_snapshot", {}), {})


func build_save_payload() -> Dictionary:
	sync_runtime_snapshots()

	return {
		"player_name": player_name,
		"current_scene_name": current_scene_name,
		"current_location_id": current_location_id,
		"current_rating_lane": current_rating_lane,
		"relationship_scores": relationship_scores.duplicate(true),
		"flags": flags.duplicate(true),
		"current_visual_state": current_visual_state.duplicate(true),
		"current_content": current_content.duplicate(true),
		"conversation_log": conversation_log.duplicate(true),
		"last_summary": last_summary,
		"last_status_message": last_status_message,
		"last_fallback_messages": last_fallback_messages.duplicate(true),
		"settings_snapshot": settings_snapshot.duplicate(true),
		"library_snapshot": library_snapshot.duplicate(true)
	}


func build_render_snapshot() -> Dictionary:
	sync_runtime_snapshots()

	return {
		"scene_name": current_scene_name,
		"location_id": current_location_id,
		"rating_lane": current_rating_lane,
		"visual_state": current_visual_state.duplicate(true),
		"content": current_content.duplicate(true),
		"status_message": last_status_message,
		"fallback_messages": last_fallback_messages.duplicate(true),
		"settings_snapshot": settings_snapshot.duplicate(true),
		"library_snapshot": library_snapshot.duplicate(true),
		"relationship_scores": relationship_scores.duplicate(true),
		"flags": flags.duplicate(true)
	}


func append_conversation_entry(role: String, text: String, metadata: Dictionary = {}) -> void:
	var clean_text := text.strip_edges()
	if clean_text.is_empty():
		return

	conversation_log.append({
		"role": role,
		"text": clean_text,
		"metadata": metadata.duplicate(true)
	})

	if conversation_log.size() > 40:
		conversation_log.remove_at(0)


func get_recent_conversation(limit: int = 10) -> Array:
	if limit <= 0:
		return []

	var start_index := maxi(conversation_log.size() - limit, 0)
	var recent_entries: Array = []
	for index in range(start_index, conversation_log.size()):
		recent_entries.append(conversation_log[index])
	return recent_entries


func set_current_scene_name(scene_name: String) -> void:
	current_scene_name = scene_name


func set_flag(flag_name: String, enabled: bool = true) -> void:
	flags[flag_name] = enabled


func has_flag(flag_name: String) -> bool:
	return bool(flags.get(flag_name, false))


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


func _normalize_content(raw_value: Variant) -> Dictionary:
	var base_content := {
		"narration": "",
		"speaker_name": "Narrator",
		"dialogue": "",
		"action": ""
	}

	if raw_value is Dictionary:
		base_content["narration"] = str(raw_value.get("narration", ""))
		base_content["speaker_name"] = str(raw_value.get("speaker_name", "Narrator"))
		base_content["dialogue"] = str(raw_value.get("dialogue", ""))
		base_content["action"] = str(raw_value.get("action", ""))

	return base_content


func _duplicate_dictionary(raw_value: Variant, fallback: Dictionary) -> Dictionary:
	if raw_value is Dictionary:
		return raw_value.duplicate(true)
	return fallback.duplicate(true)


func _duplicate_array(raw_value: Variant) -> Array:
	if raw_value is Array:
		return raw_value.duplicate(true)
	return []
