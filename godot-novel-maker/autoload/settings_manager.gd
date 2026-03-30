extends Node

signal settings_loaded(settings: Dictionary)
signal settings_changed(settings: Dictionary)

const SETTINGS_PATH := "user://settings.json"
const DEFAULT_SETTINGS := {
	"asset_library_path": "",
	"backend_mode": "http",
	"backend_base_url": "http://127.0.0.1:8000",
	"use_stub_backend": false,
	"last_validation_status": "unconfigured"
}

var _settings: Dictionary = {}


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	_settings = DEFAULT_SETTINGS.duplicate(true)

	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for key in parsed.keys():
					_settings[str(key)] = parsed[key]

	_normalize_settings()
	_write_settings()
	settings_loaded.emit(get_settings_snapshot())
	settings_changed.emit(get_settings_snapshot())


func update_settings(partial_settings: Dictionary) -> void:
	for key in partial_settings.keys():
		_settings[str(key)] = partial_settings[key]

	_normalize_settings()
	_write_settings()
	settings_changed.emit(get_settings_snapshot())


func get_settings_snapshot() -> Dictionary:
	return _settings.duplicate(true)


func get_asset_library_path() -> String:
	return str(_settings.get("asset_library_path", ""))


func get_backend_mode() -> String:
	return str(_settings.get("backend_mode", "http"))


func get_backend_base_url() -> String:
	return str(_settings.get("backend_base_url", DEFAULT_SETTINGS["backend_base_url"]))


func uses_stub_backend() -> bool:
	return bool(_settings.get("use_stub_backend", false))


func get_turn_url() -> String:
	return "%s/v1/story/turn" % get_backend_base_url()


func get_health_url() -> String:
	return "%s/health" % get_backend_base_url()


func get_last_validation_status() -> String:
	return str(_settings.get("last_validation_status", "unconfigured"))


func set_last_validation_status(status: String) -> void:
	if str(_settings.get("last_validation_status", "")) == status:
		return

	_settings["last_validation_status"] = status
	_write_settings()
	settings_changed.emit(get_settings_snapshot())


func _normalize_settings() -> void:
	_settings["asset_library_path"] = str(_settings.get("asset_library_path", ""))
	_settings["last_validation_status"] = str(_settings.get("last_validation_status", "unconfigured"))
	_settings["backend_base_url"] = _sanitize_base_url(str(_settings.get("backend_base_url", DEFAULT_SETTINGS["backend_base_url"])))

	var use_stub_backend := bool(_settings.get("use_stub_backend", false))
	var backend_mode := str(_settings.get("backend_mode", "http")).to_lower()
	if backend_mode == "stub":
		use_stub_backend = true

	if use_stub_backend:
		backend_mode = "stub"
	else:
		backend_mode = "http"

	_settings["use_stub_backend"] = use_stub_backend
	_settings["backend_mode"] = backend_mode


func _sanitize_base_url(raw_value: String) -> String:
	var value := raw_value.strip_edges()
	if value.is_empty():
		value = str(DEFAULT_SETTINGS["backend_base_url"])

	if value.ends_with("/v1/story/turn"):
		value = value.substr(0, value.length() - "/v1/story/turn".length())

	if value.ends_with("/health"):
		value = value.substr(0, value.length() - "/health".length())

	while value.ends_with("/"):
		value = value.left(value.length() - 1)

	return value


func _write_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(_settings, "\t"))
