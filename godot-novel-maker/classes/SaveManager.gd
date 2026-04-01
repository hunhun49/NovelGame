extends Node
class_name SaveManagerService

const SAVE_DIR := "user://saves"
const QUICK_SAVE_PATH := "user://saves/quick_save.json"
const MANUAL_SLOT_COUNT := 6


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func build_save_payload() -> Dictionary:
	var payload := game_state.build_save_payload()
	payload["saved_at"] = Time.get_datetime_string_from_system()
	return payload


func quick_save() -> bool:
	return _write_json(QUICK_SAVE_PATH, build_save_payload())


func save_to_slot(slot_id: int) -> bool:
	if not _is_valid_slot_id(slot_id):
		return false

	return _write_json(_get_slot_path(slot_id), build_save_payload())


func has_quick_save() -> bool:
	return FileAccess.file_exists(QUICK_SAVE_PATH)


func has_any_manual_saves() -> bool:
	for slot_id in range(1, MANUAL_SLOT_COUNT + 1):
		if has_manual_save(slot_id):
			return true
	return false


func has_manual_save(slot_id: int) -> bool:
	if not _is_valid_slot_id(slot_id):
		return false
	return FileAccess.file_exists(_get_slot_path(slot_id))


func load_quick_save() -> Dictionary:
	if not has_quick_save():
		return {}

	var file := FileAccess.open(QUICK_SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed

	return {}


func load_from_slot(slot_id: int) -> Dictionary:
	if not has_manual_save(slot_id):
		return {}

	var file := FileAccess.open(_get_slot_path(slot_id), FileAccess.READ)
	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed

	return {}


func list_manual_saves() -> Array:
	var slots: Array = []
	for slot_id in range(1, MANUAL_SLOT_COUNT + 1):
		var payload := load_from_slot(slot_id)
		slots.append(_build_slot_metadata(slot_id, payload))
	return slots


func _write_json(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true


func _get_slot_path(slot_id: int) -> String:
	return "%s/manual_slot_%02d.json" % [SAVE_DIR, slot_id]


func _is_valid_slot_id(slot_id: int) -> bool:
	return slot_id >= 1 and slot_id <= MANUAL_SLOT_COUNT


func _build_slot_metadata(slot_id: int, payload: Dictionary) -> Dictionary:
	if payload.is_empty():
		return {
			"slot_id": slot_id,
			"exists": false,
			"label": "빈 슬롯",
			"saved_at": "",
			"scene": "",
			"world_name": "",
			"speaker": "",
			"summary": ""
		}

	var content: Dictionary = payload.get("current_content", {})
	var world_profile: Dictionary = payload.get("selected_world_profile", {})
	var summary := str(payload.get("last_summary", "")).strip_edges()
	if summary.is_empty():
		summary = str(content.get("dialogue", "")).strip_edges()

	var world_name := story_profile_store.get_world_display_title(world_profile)
	if world_name.is_empty():
		world_name = "미선택"

	return {
		"slot_id": slot_id,
		"exists": true,
		"label": "슬롯 %02d" % slot_id,
		"saved_at": str(payload.get("saved_at", "")),
		"scene": str(payload.get("current_scene_name", "")),
		"world_name": world_name,
		"speaker": str(content.get("speaker_name", "화자")),
		"summary": summary
	}
