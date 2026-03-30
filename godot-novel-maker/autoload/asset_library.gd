extends Node

signal library_loaded(snapshot: Dictionary)

const MANIFEST_FILE_NAME := "manifest.json"
const SUPPORTED_RATINGS := ["general", "mature", "adult", "extreme"]
const MAX_BACKGROUND_CANDIDATES := 8
const MAX_SPRITE_CANDIDATES := 12
const MAX_CG_CANDIDATES := 10

var _library_root_path := ""
var _manifest_data: Dictionary = {}
var _backgrounds_by_id: Dictionary = {}
var _sprites_by_id: Dictionary = {}
var _cgs_by_id: Dictionary = {}
var _texture_cache: Dictionary = {}
var validation_status := "unconfigured"
var validation_errors: Array = []
var validation_warnings: Array = []


func _ready() -> void:
	SettingsManager.settings_changed.connect(_on_settings_changed)
	call_deferred("_reload_from_settings")


func _reload_from_settings() -> void:
	reload_library(SettingsManager.get_asset_library_path())


func reload_library(optional_root_path: String = "") -> void:
	var target_root := optional_root_path.strip_edges()
	if target_root.is_empty():
		target_root = SettingsManager.get_asset_library_path().strip_edges()

	_clear_library_state()
	_library_root_path = target_root

	if _library_root_path.is_empty():
		validation_status = "unconfigured"
		SettingsManager.set_last_validation_status(validation_status)
		library_loaded.emit(get_snapshot())
		return

	var manifest_path := _library_root_path.path_join(MANIFEST_FILE_NAME)
	if not FileAccess.file_exists(manifest_path):
		validation_status = "invalid"
		validation_errors.append("Missing manifest.json in asset library root: %s" % _library_root_path)
		SettingsManager.set_last_validation_status(validation_status)
		library_loaded.emit(get_snapshot())
		return

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		validation_status = "invalid"
		validation_errors.append("Could not open manifest.json: %s" % manifest_path)
		SettingsManager.set_last_validation_status(validation_status)
		library_loaded.emit(get_snapshot())
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		validation_status = "invalid"
		validation_errors.append("Manifest root must be a JSON object.")
		SettingsManager.set_last_validation_status(validation_status)
		library_loaded.emit(get_snapshot())
		return

	_manifest_data = parsed.duplicate(true)
	var id_registry := {}

	_validate_root_field_exists("version")
	_index_background_entries(_manifest_data.get("backgrounds", []), id_registry)
	_index_sprite_entries(_manifest_data.get("sprites", []), id_registry)
	_index_cg_entries(_manifest_data.get("cgs", []), id_registry)

	if validation_errors.is_empty():
		validation_status = "valid"
	else:
		validation_status = "invalid"

	SettingsManager.set_last_validation_status(validation_status)
	library_loaded.emit(get_snapshot())


func get_snapshot() -> Dictionary:
	return {
		"root_path": _library_root_path,
		"validation_status": validation_status,
		"error_count": validation_errors.size(),
		"warning_count": validation_warnings.size(),
		"background_count": _backgrounds_by_id.size(),
		"sprite_count": _sprites_by_id.size(),
		"cg_count": _cgs_by_id.size(),
		"summary": get_status_line()
	}


func get_status_line() -> String:
	match validation_status:
		"valid":
			return "Library valid: %d backgrounds / %d sprites / %d CGs" % [_backgrounds_by_id.size(), _sprites_by_id.size(), _cgs_by_id.size()]
		"invalid":
			return "Library invalid: %d error(s), %d warning(s)" % [validation_errors.size(), validation_warnings.size()]
		"unconfigured":
			return "No external asset library selected."
		_:
			return "Asset library status is unknown."


func get_validation_messages(limit: int = 6) -> Array:
	var messages: Array = []

	for message in validation_errors:
		messages.append("Error: %s" % message)
		if messages.size() >= limit:
			return messages

	for message in validation_warnings:
		messages.append("Warning: %s" % message)
		if messages.size() >= limit:
			return messages

	if messages.is_empty():
		messages.append(get_status_line())

	return messages


func build_candidate_bundle(game_state: Node) -> Dictionary:
	var rating_lane := str(game_state.current_rating_lane)
	var active_character_ids := _get_active_character_ids(game_state)

	return {
		"backgrounds": _build_background_candidates(str(game_state.current_location_id), rating_lane),
		"sprites": _build_sprite_candidates(active_character_ids, rating_lane),
		"cgs": _build_cg_candidates(game_state.flags, rating_lane)
	}


func get_background_texture(background_id: String) -> Texture2D:
	return _load_texture_for_entry(_backgrounds_by_id.get(background_id, {}))


func get_sprite_texture(sprite_id: String) -> Texture2D:
	return _load_texture_for_entry(_sprites_by_id.get(sprite_id, {}))


func get_cg_texture(cg_id: String) -> Texture2D:
	return _load_texture_for_entry(_cgs_by_id.get(cg_id, {}))


func validate_background_request(background_id: String, rating_lane: String) -> Dictionary:
	var clean_id := background_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "id": "", "message": ""}

	var entry: Dictionary = _backgrounds_by_id.get(clean_id, {})
	if entry.is_empty():
		return {"ok": false, "id": "", "message": "Unknown background '%s'; keeping the previous background." % clean_id}

	if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
		return {"ok": false, "id": "", "message": "Background '%s' is above the active rating lane; keeping the previous background." % clean_id}

	return {"ok": true, "id": clean_id, "entry": entry.duplicate(true), "message": ""}


func validate_cg_request(cg_id: String, rating_lane: String, flags: Dictionary) -> Dictionary:
	var clean_id := cg_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "id": "", "message": "CG mode was requested without a cg_id; falling back to layered mode."}

	var entry: Dictionary = _cgs_by_id.get(clean_id, {})
	if entry.is_empty():
		return {"ok": false, "id": "", "message": "Unknown CG '%s'; falling back to layered mode." % clean_id}

	if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
		return {"ok": false, "id": "", "message": "CG '%s' is above the active rating lane; falling back to layered mode." % clean_id}

	if not _flags_allow_entry(entry, flags):
		return {"ok": false, "id": "", "message": "CG '%s' does not satisfy its flag requirements; falling back to layered mode." % clean_id}

	return {"ok": true, "id": clean_id, "entry": entry.duplicate(true), "message": ""}


func resolve_sprite_state(requested_state: Dictionary, rating_lane: String) -> Dictionary:
	var position := str(requested_state.get("position", "")).to_lower()
	if position != "left" and position != "center" and position != "right":
		return {"ok": false, "slot": position, "message": "Unsupported character slot '%s'; hiding that slot." % position}

	var requested_sprite_id := str(requested_state.get("sprite_id", "")).strip_edges()
	var requested_character_id := str(requested_state.get("character_id", "")).strip_edges()
	var requested_entry: Dictionary = _sprites_by_id.get(requested_sprite_id, {})

	if not requested_entry.is_empty() and _rating_allows(str(requested_entry.get("rating", "general")), rating_lane):
		var resolved_character_id := requested_character_id
		if resolved_character_id.is_empty():
			resolved_character_id = str(requested_entry.get("character_id", ""))

		return {
			"ok": true,
			"slot": position,
			"sprite_state": {
				"character_id": resolved_character_id,
				"sprite_id": requested_sprite_id,
				"position": position
			},
			"message": ""
		}

	var fallback_entry := _find_fallback_sprite(requested_character_id, rating_lane)
	if fallback_entry.is_empty():
		if requested_sprite_id.is_empty():
			return {"ok": false, "slot": position, "message": ""}
		return {"ok": false, "slot": position, "message": "Unknown or blocked sprite '%s'; hiding the %s slot." % [requested_sprite_id, position]}

	return {
		"ok": true,
		"slot": position,
		"sprite_state": {
			"character_id": str(fallback_entry.get("character_id", requested_character_id)),
			"sprite_id": str(fallback_entry.get("id", "")),
			"position": position
		},
		"message": "Sprite '%s' could not be used; a neutral fallback was used in the %s slot." % [requested_sprite_id, position]
	}


func _on_settings_changed(settings: Dictionary) -> void:
	var new_root := str(settings.get("asset_library_path", "")).strip_edges()
	if new_root != _library_root_path:
		reload_library(new_root)


func _validate_root_field_exists(field_name: String) -> void:
	if not _manifest_data.has(field_name):
		validation_errors.append("Manifest root is missing field '%s'." % field_name)


func _index_background_entries(raw_entries: Variant, id_registry: Dictionary) -> void:
	if not (raw_entries is Array):
		validation_errors.append("Manifest field 'backgrounds' must be an array.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			validation_errors.append("Each background entry must be an object.")
			continue

		var entry_id := str(raw_entry.get("id", "")).strip_edges()
		if not _validate_common_entry(entry_id, raw_entry, "background", id_registry):
			continue

		var location := str(raw_entry.get("location", "")).strip_edges()
		var time_of_day := str(raw_entry.get("time_of_day", "")).strip_edges()
		var weather := str(raw_entry.get("weather", "")).strip_edges()
		var rating := str(raw_entry.get("rating", "")).strip_edges()
		if location.is_empty() or time_of_day.is_empty() or weather.is_empty():
			validation_errors.append("Background '%s' is missing one of location/time_of_day/weather." % entry_id)
			continue

		if not _is_supported_rating(rating):
			validation_errors.append("Background '%s' uses unsupported rating '%s'." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			validation_errors.append("Background '%s' points to a missing file." % entry_id)
			continue

		_backgrounds_by_id[entry_id] = {
			"id": entry_id,
			"file": str(raw_entry.get("file", "")),
			"absolute_path": absolute_path,
			"location": location,
			"time_of_day": time_of_day,
			"weather": weather,
			"rating": rating,
			"mood_tags": _normalize_string_array(raw_entry.get("mood_tags", []))
		}


func _index_sprite_entries(raw_entries: Variant, id_registry: Dictionary) -> void:
	if not (raw_entries is Array):
		validation_errors.append("Manifest field 'sprites' must be an array.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			validation_errors.append("Each sprite entry must be an object.")
			continue

		var entry_id := str(raw_entry.get("id", "")).strip_edges()
		if not _validate_common_entry(entry_id, raw_entry, "sprite", id_registry):
			continue

		var character_id := str(raw_entry.get("character_id", "")).strip_edges()
		var expression := str(raw_entry.get("expression", "")).strip_edges()
		var pose := str(raw_entry.get("pose", "")).strip_edges()
		var outfit := str(raw_entry.get("outfit", "")).strip_edges()
		var rating := str(raw_entry.get("rating", "")).strip_edges()
		if character_id.is_empty() or expression.is_empty() or pose.is_empty() or outfit.is_empty():
			validation_errors.append("Sprite '%s' is missing one of character_id/expression/pose/outfit." % entry_id)
			continue

		if not _is_supported_rating(rating):
			validation_errors.append("Sprite '%s' uses unsupported rating '%s'." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			validation_errors.append("Sprite '%s' points to a missing file." % entry_id)
			continue

		_sprites_by_id[entry_id] = {
			"id": entry_id,
			"file": str(raw_entry.get("file", "")),
			"absolute_path": absolute_path,
			"character_id": character_id,
			"expression": expression,
			"pose": pose,
			"outfit": outfit,
			"rating": rating,
			"state_tags": _normalize_string_array(raw_entry.get("state_tags", []))
		}


func _index_cg_entries(raw_entries: Variant, id_registry: Dictionary) -> void:
	if not (raw_entries is Array):
		validation_errors.append("Manifest field 'cgs' must be an array.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			validation_errors.append("Each CG entry must be an object.")
			continue

		var entry_id := str(raw_entry.get("id", "")).strip_edges()
		if not _validate_common_entry(entry_id, raw_entry, "cg", id_registry):
			continue

		var event_type := str(raw_entry.get("event_type", "")).strip_edges()
		var character_ids := _normalize_string_array(raw_entry.get("character_ids", []))
		var rating := str(raw_entry.get("rating", "")).strip_edges()
		var required_flags := _normalize_string_array(raw_entry.get("required_flags", []))
		var blocked_flags := _normalize_string_array(raw_entry.get("blocked_flags", []))
		if event_type.is_empty() or character_ids.is_empty():
			validation_errors.append("CG '%s' must include event_type and a non-empty character_ids array." % entry_id)
			continue

		if not _is_supported_rating(rating):
			validation_errors.append("CG '%s' uses unsupported rating '%s'." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			validation_errors.append("CG '%s' points to a missing file." % entry_id)
			continue

		_cgs_by_id[entry_id] = {
			"id": entry_id,
			"file": str(raw_entry.get("file", "")),
			"absolute_path": absolute_path,
			"event_type": event_type,
			"character_ids": character_ids,
			"rating": rating,
			"required_flags": required_flags,
			"blocked_flags": blocked_flags,
			"mood_tags": _normalize_string_array(raw_entry.get("mood_tags", []))
		}


func _validate_common_entry(entry_id: String, raw_entry: Dictionary, category_name: String, id_registry: Dictionary) -> bool:
	if entry_id.is_empty():
		validation_errors.append("%s entry is missing an id." % category_name.capitalize())
		return false

	if not raw_entry.has("file") or str(raw_entry.get("file", "")).strip_edges().is_empty():
		validation_errors.append("%s '%s' is missing a file path." % [category_name.capitalize(), entry_id])
		return false

	if id_registry.has(entry_id):
		validation_errors.append("Duplicate asset id '%s' found in manifest." % entry_id)
		return false

	id_registry[entry_id] = category_name
	return true


func _normalize_string_array(raw_value: Variant) -> Array:
	var normalized: Array = []
	if not (raw_value is Array):
		return normalized

	for value in raw_value:
		var text := str(value).strip_edges()
		if not text.is_empty():
			normalized.append(text)

	return normalized


func _resolve_asset_path(raw_path: String) -> String:
	var clean_path := raw_path.strip_edges()
	if clean_path.is_empty():
		return ""

	if clean_path.is_absolute_path():
		return clean_path

	return _library_root_path.path_join(clean_path)


func _is_supported_rating(rating: String) -> bool:
	return SUPPORTED_RATINGS.has(rating)


func _rating_allows(asset_rating: String, active_rating: String) -> bool:
	var asset_rank := SUPPORTED_RATINGS.find(asset_rating)
	var active_rank := SUPPORTED_RATINGS.find(active_rating)
	if asset_rank == -1 or active_rank == -1:
		return false
	return asset_rank <= active_rank


func _flags_allow_entry(entry: Dictionary, flags: Dictionary) -> bool:
	for required_flag in entry.get("required_flags", []):
		if not bool(flags.get(required_flag, false)):
			return false

	for blocked_flag in entry.get("blocked_flags", []):
		if bool(flags.get(blocked_flag, false)):
			return false

	return true


func _build_background_candidates(location_id: String, rating_lane: String) -> Array:
	var preferred: Array = []
	var fallback: Array = []
	var sorted_ids: Array = _backgrounds_by_id.keys()
	sorted_ids.sort()

	for background_id in sorted_ids:
		var entry: Dictionary = _backgrounds_by_id[background_id]
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		var candidate := _build_candidate_entry(entry, "background")
		if location_id.is_empty():
			fallback.append(candidate)
		elif str(entry.get("location", "")) == location_id or str(entry.get("id", "")).contains(location_id) or location_id.contains(str(entry.get("location", ""))):
			preferred.append(candidate)
		else:
			fallback.append(candidate)

	if preferred.is_empty():
		preferred = fallback
	else:
		for candidate in fallback:
			if preferred.size() >= MAX_BACKGROUND_CANDIDATES:
				break
			preferred.append(candidate)

	return preferred.slice(0, MAX_BACKGROUND_CANDIDATES)


func _build_sprite_candidates(active_character_ids: Array, rating_lane: String) -> Array:
	var preferred: Array = []
	var fallback: Array = []
	var sorted_ids: Array = _sprites_by_id.keys()
	sorted_ids.sort()

	for sprite_id in sorted_ids:
		var entry: Dictionary = _sprites_by_id[sprite_id]
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		var candidate := _build_candidate_entry(entry, "sprite")
		if active_character_ids.has(str(entry.get("character_id", ""))):
			preferred.append(candidate)
		else:
			fallback.append(candidate)

	if preferred.is_empty():
		preferred = fallback
	else:
		for candidate in fallback:
			if preferred.size() >= MAX_SPRITE_CANDIDATES:
				break
			preferred.append(candidate)

	return preferred.slice(0, MAX_SPRITE_CANDIDATES)


func _build_cg_candidates(flags: Dictionary, rating_lane: String) -> Array:
	var candidates: Array = []
	var sorted_ids: Array = _cgs_by_id.keys()
	sorted_ids.sort()

	for cg_id in sorted_ids:
		var entry: Dictionary = _cgs_by_id[cg_id]
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		if not _flags_allow_entry(entry, flags):
			continue

		candidates.append(_build_candidate_entry(entry, "cg"))
		if candidates.size() >= MAX_CG_CANDIDATES:
			break

	return candidates


func _build_candidate_entry(entry: Dictionary, entry_type: String) -> Dictionary:
	var candidate := {
		"id": str(entry.get("id", "")),
		"type": entry_type,
		"rating": str(entry.get("rating", "general"))
	}

	match entry_type:
		"background":
			candidate["location"] = str(entry.get("location", ""))
			candidate["time_of_day"] = str(entry.get("time_of_day", ""))
			candidate["weather"] = str(entry.get("weather", ""))
		"sprite":
			candidate["character_id"] = str(entry.get("character_id", ""))
			candidate["expression"] = str(entry.get("expression", ""))
			candidate["pose"] = str(entry.get("pose", ""))
			candidate["outfit"] = str(entry.get("outfit", ""))
		"cg":
			candidate["event_type"] = str(entry.get("event_type", ""))
			candidate["character_ids"] = entry.get("character_ids", []).duplicate(true)

	return candidate


func _get_active_character_ids(game_state: Node) -> Array:
	var character_ids: Array = []
	var visual_state: Dictionary = game_state.current_visual_state
	var slot_map: Dictionary = visual_state.get("character_slots", {})
	for slot_name in slot_map.keys():
		var slot_value: Variant = slot_map.get(slot_name, {})
		if slot_value is Dictionary:
			var character_id := str(slot_value.get("character_id", "")).strip_edges()
			if not character_id.is_empty() and not character_ids.has(character_id):
				character_ids.append(character_id)

	if character_ids.is_empty():
		for relationship_key in game_state.relationship_scores.keys():
			var key_text := str(relationship_key).strip_edges()
			if not key_text.is_empty():
				character_ids.append(key_text)

	return character_ids


func _find_fallback_sprite(character_id: String, rating_lane: String) -> Dictionary:
	var sorted_ids: Array = _sprites_by_id.keys()
	sorted_ids.sort()

	for sprite_id in sorted_ids:
		var entry: Dictionary = _sprites_by_id[sprite_id]
		if str(entry.get("character_id", "")) != character_id:
			continue
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		var expression := str(entry.get("expression", "")).to_lower()
		if expression == "neutral" or expression == "default":
			return entry.duplicate(true)

	for sprite_id in sorted_ids:
		var entry: Dictionary = _sprites_by_id[sprite_id]
		if str(entry.get("character_id", "")) != character_id:
			continue
		if _rating_allows(str(entry.get("rating", "general")), rating_lane):
			return entry.duplicate(true)

	return {}


func _load_texture_for_entry(entry: Dictionary) -> Texture2D:
	if entry.is_empty():
		return null

	var absolute_path := str(entry.get("absolute_path", ""))
	if absolute_path.is_empty():
		return null

	if _texture_cache.has(absolute_path):
		return _texture_cache[absolute_path]

	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null

	var texture := ImageTexture.create_from_image(image)
	_texture_cache[absolute_path] = texture
	return texture


func _clear_library_state() -> void:
	_manifest_data = {}
	_backgrounds_by_id = {}
	_sprites_by_id = {}
	_cgs_by_id = {}
	_texture_cache = {}
	validation_errors = []
	validation_warnings = []
