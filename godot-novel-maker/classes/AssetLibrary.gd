extends Node
class_name AssetLibraryService

signal library_loaded(snapshot: Dictionary)

const MANIFEST_FILE_NAME := "manifest.json"
const SUPPORTED_RATINGS := ["general", "mature", "adult", "extreme"]
const SUPPORTED_AUDIO_EXTENSIONS := ["wav", "ogg", "mp3"]
const MAX_BACKGROUND_CANDIDATES := 8
const MAX_SPRITE_CANDIDATES := 12
const MAX_CG_CANDIDATES := 10
const MAX_BGM_CANDIDATES := 6
const MAX_SFX_CANDIDATES := 10

var m_library_root_path := ""
var m_manifest_data: Dictionary = {}
var m_backgrounds_by_id: Dictionary = {}
var m_sprites_by_id: Dictionary = {}
var m_cgs_by_id: Dictionary = {}
var m_bgms_by_id: Dictionary = {}
var m_sfxs_by_id: Dictionary = {}
var m_texture_cache: Dictionary = {}
var m_audio_cache: Dictionary = {}
var m_validation_status := "unconfigured"
var m_validation_errors: Array = []
var m_validation_warnings: Array = []


func _ready() -> void:
	settings_manager.settings_changed.connect(_on_settings_changed)
	call_deferred("_reload_from_settings")


func _reload_from_settings() -> void:
	reload_library(settings_manager.get_asset_library_path())


func reload_library(optional_root_path: String = "") -> void:
	var target_root := optional_root_path.strip_edges()
	if target_root.is_empty():
		target_root = settings_manager.get_asset_library_path().strip_edges()

	_clear_library_state()
	m_library_root_path = target_root

	if m_library_root_path.is_empty():
		m_validation_status = "unconfigured"
		settings_manager.set_last_validation_status(m_validation_status)
		library_loaded.emit(get_snapshot())
		return

	var manifest_path := m_library_root_path.path_join(MANIFEST_FILE_NAME)
	if not FileAccess.file_exists(manifest_path):
		m_validation_status = "invalid"
		m_validation_errors.append("자산 라이브러리 루트에 manifest.json이 없습니다: %s" % m_library_root_path)
		settings_manager.set_last_validation_status(m_validation_status)
		library_loaded.emit(get_snapshot())
		return

	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		m_validation_status = "invalid"
		m_validation_errors.append("manifest.json을 열 수 없습니다: %s" % manifest_path)
		settings_manager.set_last_validation_status(m_validation_status)
		library_loaded.emit(get_snapshot())
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		m_validation_status = "invalid"
		m_validation_errors.append("manifest.json의 루트는 JSON 객체여야 합니다.")
		settings_manager.set_last_validation_status(m_validation_status)
		library_loaded.emit(get_snapshot())
		return

	m_manifest_data = parsed.duplicate(true)
	var id_registry := {}

	_validate_root_field_exists("version")
	_index_background_entries(m_manifest_data.get("backgrounds", []), id_registry)
	_index_sprite_entries(m_manifest_data.get("sprites", []), id_registry)
	_index_cg_entries(m_manifest_data.get("cgs", []), id_registry)
	_index_bgm_entries(m_manifest_data.get("bgms", []), id_registry)
	_index_sfx_entries(m_manifest_data.get("sfxs", []), id_registry)

	if m_validation_errors.is_empty():
		m_validation_status = "valid"
	else:
		m_validation_status = "invalid"

	settings_manager.set_last_validation_status(m_validation_status)
	library_loaded.emit(get_snapshot())


func get_snapshot() -> Dictionary:
	return {
		"root_path": m_library_root_path,
		"validation_status": m_validation_status,
		"error_count": m_validation_errors.size(),
		"warning_count": m_validation_warnings.size(),
		"background_count": m_backgrounds_by_id.size(),
		"sprite_count": m_sprites_by_id.size(),
		"cg_count": m_cgs_by_id.size(),
		"bgm_count": m_bgms_by_id.size(),
		"sfx_count": m_sfxs_by_id.size(),
		"summary": get_status_line()
	}


func get_status_line() -> String:
	match m_validation_status:
		"valid":
			return "라이브러리 정상: 배경 %d / 스프라이트 %d / CG %d / BGM %d / SFX %d" % [m_backgrounds_by_id.size(), m_sprites_by_id.size(), m_cgs_by_id.size(), m_bgms_by_id.size(), m_sfxs_by_id.size()]
		"invalid":
			return "라이브러리 오류: 문제 %d개, 경고 %d개" % [m_validation_errors.size(), m_validation_warnings.size()]
		"unconfigured":
			return "외부 자산 라이브러리가 아직 선택되지 않았습니다."
		_:
			return "자산 라이브러리 상태를 확인할 수 없습니다."


func has_valid_library() -> bool:
	return m_validation_status == "valid"


func get_validation_messages(limit: int = 6) -> Array:
	var messages: Array = []

	for message in m_validation_errors:
		messages.append("오류: %s" % message)
		if messages.size() >= limit:
			return messages

	for message in m_validation_warnings:
		messages.append("경고: %s" % message)
		if messages.size() >= limit:
			return messages

	if messages.is_empty():
		messages.append(get_status_line())

	return messages


func build_candidate_bundle(game_state: Node) -> Dictionary:
	var rating_lane := str(game_state.m_current_rating_lane)
	var active_character_ids := _get_active_character_ids(game_state)

	return {
		"backgrounds": _build_background_candidates(str(game_state.m_current_location_id), rating_lane),
		"sprites": _build_sprite_candidates(active_character_ids, rating_lane),
		"cgs": _build_cg_candidates(game_state.m_flags, rating_lane),
		"bgms": _build_audio_candidates(m_bgms_by_id, "bgm", rating_lane, MAX_BGM_CANDIDATES),
		"sfxs": _build_audio_candidates(m_sfxs_by_id, "sfx", rating_lane, MAX_SFX_CANDIDATES)
	}


func get_background_texture(background_id: String) -> Texture2D:
	return _load_texture_for_entry(m_backgrounds_by_id.get(background_id, {}))


func get_sprite_texture(sprite_id: String) -> Texture2D:
	return _load_texture_for_entry(m_sprites_by_id.get(sprite_id, {}))


func get_character_thumbnail_texture(character_profile: Dictionary) -> Texture2D:
	if character_profile.is_empty():
		return null

	var thumbnail_path := str(character_profile.get("thumbnail_path", "")).strip_edges()
	if not thumbnail_path.is_empty():
		var thumbnail_texture := get_texture_from_path(thumbnail_path)
		if thumbnail_texture != null:
			return thumbnail_texture

	for preferred_sprite_id in character_profile.get("preferred_sprite_ids", []):
		var preferred_texture := get_sprite_texture(str(preferred_sprite_id))
		if preferred_texture != null:
			return preferred_texture

	var fallback_entry := _find_fallback_sprite(str(character_profile.get("id", "")), "extreme")
	if fallback_entry.is_empty():
		return null

	return _load_texture_for_entry(fallback_entry)


func get_texture_from_path(raw_path: String) -> Texture2D:
	var resolved_path := _normalize_external_path(raw_path)
	if resolved_path.is_empty():
		return null

	return _load_texture_from_path(resolved_path)


func get_cg_texture(cg_id: String) -> Texture2D:
	return _load_texture_for_entry(m_cgs_by_id.get(cg_id, {}))


func get_bgm_stream(bgm_id: String) -> AudioStream:
	return _load_audio_stream_for_entry(m_bgms_by_id.get(bgm_id, {}))


func get_sfx_stream(sfx_id: String) -> AudioStream:
	return _load_audio_stream_for_entry(m_sfxs_by_id.get(sfx_id, {}))


func validate_background_request(background_id: String, rating_lane: String) -> Dictionary:
	var clean_id := background_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "id": "", "message": ""}

	var entry: Dictionary = m_backgrounds_by_id.get(clean_id, {})
	if entry.is_empty():
		return {"ok": false, "id": "", "message": "배경 '%s'을(를) 찾지 못해 이전 배경을 유지합니다." % clean_id}

	if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
		return {"ok": false, "id": "", "message": "배경 '%s'은(는) 현재 수위 레인보다 높아서 이전 배경을 유지합니다." % clean_id}

	return {"ok": true, "id": clean_id, "entry": entry.duplicate(true), "message": ""}


func validate_cg_request(cg_id: String, rating_lane: String, flags: Dictionary) -> Dictionary:
	var clean_id := cg_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "id": "", "message": "CG ID 없이 CG 모드가 요청되어 레이어드 모드로 되돌립니다."}

	var entry: Dictionary = m_cgs_by_id.get(clean_id, {})
	if entry.is_empty():
		return {"ok": false, "id": "", "message": "CG '%s'을(를) 찾지 못해 레이어드 모드로 되돌립니다." % clean_id}

	if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
		return {"ok": false, "id": "", "message": "CG '%s'은(는) 현재 수위 레인보다 높아 레이어드 모드로 되돌립니다." % clean_id}

	if not _flags_allow_entry(entry, flags):
		return {"ok": false, "id": "", "message": "CG '%s'은(는) 현재 플래그 조건을 만족하지 않아 레이어드 모드로 되돌립니다." % clean_id}

	return {"ok": true, "id": clean_id, "entry": entry.duplicate(true), "message": ""}


func validate_bgm_request(bgm_id: String, rating_lane: String) -> Dictionary:
	var clean_id := bgm_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "id": "", "message": ""}

	var entry: Dictionary = m_bgms_by_id.get(clean_id, {})
	if entry.is_empty():
		return {"ok": false, "id": "", "message": "BGM '%s'을(를) 찾지 못해 현재 BGM을 유지합니다." % clean_id}

	if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
		return {"ok": false, "id": "", "message": "BGM '%s'은(는) 현재 수위 레인보다 높아 현재 BGM을 유지합니다." % clean_id}

	return {"ok": true, "id": clean_id, "entry": entry.duplicate(true), "message": ""}


func validate_sfx_request(sfx_id: String, rating_lane: String) -> Dictionary:
	var clean_id := sfx_id.strip_edges()
	if clean_id.is_empty():
		return {"ok": false, "id": "", "message": ""}

	var entry: Dictionary = m_sfxs_by_id.get(clean_id, {})
	if entry.is_empty():
		return {"ok": false, "id": "", "message": "SFX '%s'을(를) 찾지 못해 이번 효과음을 건너뜁니다." % clean_id}

	if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
		return {"ok": false, "id": "", "message": "SFX '%s'은(는) 현재 수위 레인보다 높아 이번 효과음을 건너뜁니다." % clean_id}

	return {"ok": true, "id": clean_id, "entry": entry.duplicate(true), "message": ""}


func resolve_sprite_state(requested_state: Dictionary, rating_lane: String) -> Dictionary:
	var position := str(requested_state.get("position", "")).to_lower()
	if position != "left" and position != "center" and position != "right":
		return {"ok": false, "slot": position, "message": "지원하지 않는 캐릭터 슬롯 '%s'은(는) 숨깁니다." % position}

	var requested_image_path := str(requested_state.get("image_path", "")).strip_edges()
	var requested_sprite_id := str(requested_state.get("sprite_id", "")).strip_edges()
	var requested_character_id := str(requested_state.get("character_id", "")).strip_edges()
	var requested_entry: Dictionary = m_sprites_by_id.get(requested_sprite_id, {})

	if not requested_image_path.is_empty() and get_texture_from_path(requested_image_path) != null:
		return {
			"ok": true,
			"slot": position,
			"sprite_state": {
				"character_id": requested_character_id,
				"image_path": requested_image_path,
				"position": position
			},
			"message": ""
		}

	if not requested_entry.is_empty() and _rating_allows(str(requested_entry.get("rating", "general")), rating_lane):
		var entry_character_id := str(requested_entry.get("character_id", "")).strip_edges()
		if not requested_character_id.is_empty() and entry_character_id != requested_character_id:
			requested_entry = {}

	if not requested_entry.is_empty():
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
		return {"ok": false, "slot": position, "message": "스프라이트 '%s'을(를) 쓸 수 없어 %s 슬롯을 숨깁니다." % [requested_sprite_id, position]}

	return {
		"ok": true,
		"slot": position,
		"sprite_state": {
			"character_id": str(fallback_entry.get("character_id", requested_character_id)),
			"sprite_id": str(fallback_entry.get("id", "")),
			"position": position
		},
		"message": "스프라이트 '%s'을(를) 쓸 수 없어 %s 슬롯에 기본 표정을 대신 사용했습니다." % [requested_sprite_id, position]
	}


func _on_settings_changed(settings: Dictionary) -> void:
	var new_root := str(settings.get("asset_library_path", "")).strip_edges()
	if new_root != m_library_root_path:
		reload_library(new_root)


func _validate_root_field_exists(field_name: String) -> void:
	if not m_manifest_data.has(field_name):
		m_validation_errors.append("manifest 루트에 '%s' 필드가 없습니다." % field_name)


func _index_background_entries(raw_entries: Variant, id_registry: Dictionary) -> void:
	if not (raw_entries is Array):
		m_validation_errors.append("'backgrounds' 필드는 배열이어야 합니다.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			m_validation_errors.append("배경 항목은 각각 객체여야 합니다.")
			continue

		var entry_id := str(raw_entry.get("id", "")).strip_edges()
		if not _validate_common_entry(entry_id, raw_entry, "background", id_registry):
			continue

		var location := str(raw_entry.get("location", "")).strip_edges()
		var time_of_day := str(raw_entry.get("time_of_day", "")).strip_edges()
		var weather := str(raw_entry.get("weather", "")).strip_edges()
		var rating := str(raw_entry.get("rating", "")).strip_edges()
		if location.is_empty() or time_of_day.is_empty() or weather.is_empty():
			m_validation_errors.append("배경 '%s'에 location/time_of_day/weather 중 하나가 없습니다." % entry_id)
			continue

		if not _is_supported_rating(rating):
			m_validation_errors.append("배경 '%s'의 rating '%s'은(는) 지원하지 않습니다." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			m_validation_errors.append("배경 '%s'의 파일을 찾을 수 없습니다." % entry_id)
			continue

		m_backgrounds_by_id[entry_id] = {
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
		m_validation_errors.append("'sprites' 필드는 배열이어야 합니다.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			m_validation_errors.append("스프라이트 항목은 각각 객체여야 합니다.")
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
			m_validation_errors.append("스프라이트 '%s'에 character_id/expression/pose/outfit 중 하나가 없습니다." % entry_id)
			continue

		if not _is_supported_rating(rating):
			m_validation_errors.append("스프라이트 '%s'의 rating '%s'은(는) 지원하지 않습니다." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			m_validation_errors.append("스프라이트 '%s'의 파일을 찾을 수 없습니다." % entry_id)
			continue

		m_sprites_by_id[entry_id] = {
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
		m_validation_errors.append("'cgs' 필드는 배열이어야 합니다.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			m_validation_errors.append("CG 항목은 각각 객체여야 합니다.")
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
			m_validation_errors.append("CG '%s'에는 event_type과 비어 있지 않은 character_ids가 필요합니다." % entry_id)
			continue

		if not _is_supported_rating(rating):
			m_validation_errors.append("CG '%s'의 rating '%s'은(는) 지원하지 않습니다." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			m_validation_errors.append("CG '%s'의 파일을 찾을 수 없습니다." % entry_id)
			continue

		m_cgs_by_id[entry_id] = {
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


func _index_bgm_entries(raw_entries: Variant, id_registry: Dictionary) -> void:
	if not (raw_entries is Array):
		m_validation_errors.append("'bgms' 필드는 배열이어야 합니다.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			m_validation_errors.append("BGM 항목은 각각 객체여야 합니다.")
			continue

		var entry_id := str(raw_entry.get("id", "")).strip_edges()
		if not _validate_common_entry(entry_id, raw_entry, "bgm", id_registry):
			continue

		var rating := str(raw_entry.get("rating", "")).strip_edges()
		if not _is_supported_rating(rating):
			m_validation_errors.append("BGM '%s'의 rating '%s'은(는) 지원하지 않습니다." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			m_validation_errors.append("BGM '%s'의 파일을 찾을 수 없습니다." % entry_id)
			continue

		if not _has_supported_audio_extension(absolute_path):
			m_validation_errors.append("BGM '%s'의 오디오 형식은 지원하지 않습니다." % entry_id)
			continue

		m_bgms_by_id[entry_id] = {
			"id": entry_id,
			"file": str(raw_entry.get("file", "")),
			"absolute_path": absolute_path,
			"rating": rating,
			"mood_tags": _normalize_string_array(raw_entry.get("mood_tags", []))
		}


func _index_sfx_entries(raw_entries: Variant, id_registry: Dictionary) -> void:
	if not (raw_entries is Array):
		m_validation_errors.append("'sfxs' 필드는 배열이어야 합니다.")
		return

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			m_validation_errors.append("SFX 항목은 각각 객체여야 합니다.")
			continue

		var entry_id := str(raw_entry.get("id", "")).strip_edges()
		if not _validate_common_entry(entry_id, raw_entry, "sfx", id_registry):
			continue

		var rating := str(raw_entry.get("rating", "")).strip_edges()
		if not _is_supported_rating(rating):
			m_validation_errors.append("SFX '%s'의 rating '%s'은(는) 지원하지 않습니다." % [entry_id, rating])
			continue

		var absolute_path := _resolve_asset_path(str(raw_entry.get("file", "")))
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			m_validation_errors.append("SFX '%s'의 파일을 찾을 수 없습니다." % entry_id)
			continue

		if not _has_supported_audio_extension(absolute_path):
			m_validation_errors.append("SFX '%s'의 오디오 형식은 지원하지 않습니다." % entry_id)
			continue

		m_sfxs_by_id[entry_id] = {
			"id": entry_id,
			"file": str(raw_entry.get("file", "")),
			"absolute_path": absolute_path,
			"rating": rating,
			"trigger_tags": _normalize_string_array(raw_entry.get("trigger_tags", []))
		}


func _validate_common_entry(entry_id: String, raw_entry: Dictionary, category_name: String, id_registry: Dictionary) -> bool:
	if entry_id.is_empty():
		m_validation_errors.append("%s 항목에 id가 없습니다." % category_name.capitalize())
		return false

	if not raw_entry.has("file") or str(raw_entry.get("file", "")).strip_edges().is_empty():
		m_validation_errors.append("%s '%s'에 파일 경로가 없습니다." % [category_name.capitalize(), entry_id])
		return false

	if id_registry.has(entry_id):
		m_validation_errors.append("manifest 안에 중복 자산 id '%s'가 있습니다." % entry_id)
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

	return m_library_root_path.path_join(clean_path)


func _is_supported_rating(rating: String) -> bool:
	return SUPPORTED_RATINGS.has(rating)


func _has_supported_audio_extension(path: String) -> bool:
	return SUPPORTED_AUDIO_EXTENSIONS.has(path.get_extension().to_lower())


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
	var sorted_ids: Array = m_backgrounds_by_id.keys()
	sorted_ids.sort()

	for background_id in sorted_ids:
		var entry: Dictionary = m_backgrounds_by_id[background_id]
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
	var sorted_ids: Array = m_sprites_by_id.keys()
	sorted_ids.sort()

	for sprite_id in sorted_ids:
		var entry: Dictionary = m_sprites_by_id[sprite_id]
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		var candidate := _build_candidate_entry(entry, "sprite")
		if active_character_ids.is_empty() or active_character_ids.has(str(entry.get("character_id", ""))):
			preferred.append(candidate)

	return preferred.slice(0, MAX_SPRITE_CANDIDATES)


func _build_cg_candidates(flags: Dictionary, rating_lane: String) -> Array:
	var candidates: Array = []
	var sorted_ids: Array = m_cgs_by_id.keys()
	sorted_ids.sort()

	for cg_id in sorted_ids:
		var entry: Dictionary = m_cgs_by_id[cg_id]
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		if not _flags_allow_entry(entry, flags):
			continue

		candidates.append(_build_candidate_entry(entry, "cg"))
		if candidates.size() >= MAX_CG_CANDIDATES:
			break

	return candidates


func _build_audio_candidates(entries_by_id: Dictionary, entry_type: String, rating_lane: String, max_items: int) -> Array:
	var candidates: Array = []
	var sorted_ids: Array = entries_by_id.keys()
	sorted_ids.sort()

	for entry_id in sorted_ids:
		var entry: Dictionary = entries_by_id[entry_id]
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		candidates.append(_build_candidate_entry(entry, entry_type))
		if candidates.size() >= max_items:
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
		"bgm":
			candidate["mood_tags"] = entry.get("mood_tags", []).duplicate(true)
		"sfx":
			candidate["trigger_tags"] = entry.get("trigger_tags", []).duplicate(true)

	return candidate


func _get_active_character_ids(game_state: Node) -> Array:
	var character_ids: Array = []
	for selected_character_id in game_state.m_selected_main_character_ids:
		var selected_id := str(selected_character_id).strip_edges()
		if not selected_id.is_empty() and not character_ids.has(selected_id):
			character_ids.append(selected_id)

	var player_character_id := str(game_state.m_selected_player_character_id).strip_edges()
	if not player_character_id.is_empty() and not character_ids.has(player_character_id):
		character_ids.append(player_character_id)

	# 선택된 캐릭터가 없는 경우에만 visual_state 슬롯 캐릭터를 추가한다.
	# 선택된 캐릭터가 있는데 visual_state 슬롯에 이전 세션의 demo_guide가 남아 있으면
	# 잘못된 스프라이트 후보가 추가되는 버그가 발생하므로 제외한다.
	if character_ids.is_empty():
		var visual_state: Dictionary = game_state.m_current_visual_state
		var slot_map: Dictionary = visual_state.get("character_slots", {})
		for slot_name in slot_map.keys():
			var slot_value: Variant = slot_map.get(slot_name, {})
			if slot_value is Dictionary:
				var character_id := str(slot_value.get("character_id", "")).strip_edges()
				if not character_id.is_empty() and not character_ids.has(character_id):
					character_ids.append(character_id)

	if character_ids.is_empty():
		for relationship_key in game_state.m_relationship_scores.keys():
			var key_text := str(relationship_key).strip_edges()
			if not key_text.is_empty():
				character_ids.append(key_text)

	return character_ids


func _find_fallback_sprite(character_id: String, rating_lane: String) -> Dictionary:
	var sorted_ids: Array = m_sprites_by_id.keys()
	sorted_ids.sort()

	for sprite_id in sorted_ids:
		var entry: Dictionary = m_sprites_by_id[sprite_id]
		if str(entry.get("character_id", "")) != character_id:
			continue
		if not _rating_allows(str(entry.get("rating", "general")), rating_lane):
			continue

		var expression := str(entry.get("expression", "")).to_lower()
		if expression == "neutral" or expression == "default":
			return entry.duplicate(true)

	for sprite_id in sorted_ids:
		var entry: Dictionary = m_sprites_by_id[sprite_id]
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

	return _load_texture_from_path(absolute_path)


func _normalize_external_path(raw_path: String) -> String:
	var clean_path := raw_path.strip_edges()
	if clean_path.is_empty():
		return ""
	if clean_path.begins_with("user://") or clean_path.begins_with("res://"):
		return ProjectSettings.globalize_path(clean_path)
	if clean_path.is_absolute_path():
		return clean_path
	return ""


func _load_texture_from_path(absolute_path: String) -> Texture2D:
	if absolute_path.is_empty():
		return null

	if m_texture_cache.has(absolute_path):
		return m_texture_cache[absolute_path]

	var image := Image.load_from_file(absolute_path)
	if image == null or image.is_empty():
		return null

	var texture := ImageTexture.create_from_image(image)
	m_texture_cache[absolute_path] = texture
	return texture


func _load_audio_stream_for_entry(entry: Dictionary) -> AudioStream:
	if entry.is_empty():
		return null

	var absolute_path := str(entry.get("absolute_path", ""))
	if absolute_path.is_empty():
		return null

	if m_audio_cache.has(absolute_path):
		return m_audio_cache[absolute_path]

	var extension := absolute_path.get_extension().to_lower()
	var stream: AudioStream = null
	match extension:
		"wav":
			stream = _load_wav_stream(absolute_path)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(absolute_path)
		"mp3":
			stream = AudioStreamMP3.load_from_file(absolute_path)
		_:
			stream = null

	if stream != null:
		m_audio_cache[absolute_path] = stream

	return stream


func _load_wav_stream(absolute_path: String) -> AudioStreamWAV:
	var data := FileAccess.get_file_as_bytes(absolute_path)
	if data.size() < 44:
		return null

	if data.decode_u32(0) != 0x46464952 or data.decode_u32(8) != 0x45564157:
		return null

	var audio_format := 1
	var channels := 1
	var sample_rate := 44100
	var bits_per_sample := 16
	var pcm_data := PackedByteArray()
	var offset := 12

	while offset + 8 <= data.size():
		var chunk_id := data.decode_u32(offset)
		var chunk_size := data.decode_u32(offset + 4)
		var chunk_start := offset + 8

		match chunk_id:
			0x20746d66:
				if chunk_start + 16 > data.size():
					return null
				audio_format = data.decode_u16(chunk_start)
				channels = data.decode_u16(chunk_start + 2)
				sample_rate = data.decode_u32(chunk_start + 4)
				bits_per_sample = data.decode_u16(chunk_start + 14)
			0x61746164:
				if chunk_start + chunk_size > data.size():
					return null
				pcm_data = data.slice(chunk_start, chunk_start + chunk_size)

		offset = chunk_start + chunk_size
		if chunk_size % 2 == 1:
			offset += 1

	if audio_format != 1 or pcm_data.is_empty():
		return null

	if channels != 1 and channels != 2:
		return null

	if bits_per_sample != 8 and bits_per_sample != 16:
		return null

	var stream := AudioStreamWAV.new()
	stream.data = pcm_data
	stream.mix_rate = sample_rate
	stream.stereo = channels == 2
	stream.format = AudioStreamWAV.FORMAT_8_BITS if bits_per_sample == 8 else AudioStreamWAV.FORMAT_16_BITS
	return stream


func _clear_library_state() -> void:
	m_manifest_data = {}
	m_backgrounds_by_id = {}
	m_sprites_by_id = {}
	m_cgs_by_id = {}
	m_bgms_by_id = {}
	m_sfxs_by_id = {}
	m_texture_cache = {}
	m_audio_cache = {}
	m_validation_errors = []
	m_validation_warnings = []
