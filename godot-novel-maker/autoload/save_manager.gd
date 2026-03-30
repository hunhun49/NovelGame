extends Node

const SAVE_DIR := "user://saves"
const QUICK_SAVE_PATH := "user://saves/quick_save.json"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


func build_save_payload() -> Dictionary:
	var payload := GameState.build_save_payload()
	payload["saved_at"] = Time.get_datetime_string_from_system()
	return payload


func quick_save() -> bool:
	return _write_json(QUICK_SAVE_PATH, build_save_payload())


func has_quick_save() -> bool:
	return FileAccess.file_exists(QUICK_SAVE_PATH)


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


func _write_json(path: String, payload: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true
