extends Node
class_name StoryProfileStoreService

signal worlds_changed(worlds: Array)
signal characters_changed(characters: Array)
signal content_changed()

const CONTENT_DIR := "user://content"
const WORLDS_PATH := "user://content/worlds.json"
const CHARACTERS_PATH := "user://content/characters.json"
const DATA_VERSION := "3"
const RATING_LANES := ["general", "mature", "adult", "extreme"]
const PROMPT_TEMPLATES := ["basic", "romance", "mystery", "horror", "adult"]
const DEMO_WORLD := {
	"id": "demo_world",
	"name_ko": "데모 세계관",
	"story_title": "데모 스토리",
	"summary": "로컬 테스트와 기본 흐름 점검을 위한 샘플 세계관입니다.",
	"genre": "비주얼 노벨",
	"tone": "차분함",
	"premise": "플레이어 입력에 맞춰 서사와 연출이 이어지는 테스트 세션입니다.",
	"core_rules": ["로컬 테스트 세션", "샘플 자산 우선 사용"],
	"notable_places": ["demo_room"],
	"story_prompt_template": "basic",
	"story_examples": ["일상적인 대화로 장면을 시작하고 관계 변화를 확인합니다."],
	"start_setup_name": "기본 시작",
	"prologue": "안내자가 플레이어를 맞이하며 로컬 테스트용 이야기를 시작합니다.",
	"initial_situation": "플레이어는 데모 세계관의 첫 장면에서 안내자와 마주합니다.",
	"player_guide": "짧은 입력이나 상황 설명을 적으면 다음 장면이 생성됩니다.",
	"default_main_character_ids": ["demo_guide"],
	"square_cover_path": "",
	"portrait_cover_path": "",
	"default_rating_lane": "general",
	"notes": "초기 샘플 데이터"
}
const DEMO_CHARACTER := {
	"id": "demo_guide",
	"name_ko": "안내자",
	"role": "메인 캐릭터",
	"summary": "플레이어에게 현재 테스트 세션의 흐름을 설명하는 기본 캐릭터입니다.",
	"thumbnail_path": "",
	"main_personality": "차분함",
	"sub_personalities": ["다정함"],
	"speech_examples": ["처음에는 천천히 안내할게요."],
	"appearance": "정돈된 복장과 차분한 표정이 인상적인 안내자.",
	"emotion_images": {
		"neutral": "",
		"joy": "",
		"sad": "",
		"angry": ""
	},
	"event_images": [],
	"personality_tags": ["차분함", "다정함"],
	"speech_style": "명료하고 차분한 설명 위주",
	"goal": "플레이어가 로컬 세션 흐름을 이해하도록 돕는다.",
	"preferred_sprite_ids": ["demo_guide_neutral", "demo_guide_smile"],
	"notes": "초기 샘플 데이터"
}

var m_worlds: Array = []
var m_characters: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTENT_DIR))
	_load_all()


func get_worlds() -> Array:
	return m_worlds.duplicate(true)


func get_characters() -> Array:
	return m_characters.duplicate(true)


func get_world_count() -> int:
	return m_worlds.size()


func get_character_count() -> int:
	return m_characters.size()


func get_world_by_id(world_id: String) -> Dictionary:
	var clean_id := world_id.strip_edges()
	for world in m_worlds:
		if str(world.get("id", "")) == clean_id:
			return world.duplicate(true)
	return {}


func get_world_display_title(world_profile: Dictionary) -> String:
	if world_profile.is_empty():
		return ""

	var story_title := str(world_profile.get("story_title", "")).strip_edges()
	if not story_title.is_empty():
		return story_title

	return str(world_profile.get("name_ko", world_profile.get("id", ""))).strip_edges()


func get_character_by_id(character_id: String) -> Dictionary:
	var clean_id := character_id.strip_edges()
	for character in m_characters:
		if str(character.get("id", "")) == clean_id:
			return character.duplicate(true)
	return {}


func get_characters_for_world(_world_id: String) -> Array:
	return get_characters()


func get_character_name(character_id: String) -> String:
	var character := get_character_by_id(character_id)
	if not character.is_empty():
		return str(character.get("name_ko", character_id))
	return character_id.capitalize()


func save_world(world_data: Dictionary, previous_id: String = "") -> Dictionary:
	var normalized := _normalize_world(world_data, previous_id)
	var world_id := str(normalized.get("id", ""))
	if world_id.is_empty():
		return {"ok": false, "message": "세계관 ID를 만들 수 없습니다."}

	if _id_conflicts(m_worlds, world_id, previous_id):
		return {"ok": false, "message": "같은 ID를 가진 세계관이 이미 존재합니다."}

	var updated := false
	if not previous_id.strip_edges().is_empty():
		for index in range(m_worlds.size()):
			if str((m_worlds[index] as Dictionary).get("id", "")) == previous_id:
				m_worlds[index] = normalized
				updated = true
				break

	if not updated:
		for index in range(m_worlds.size()):
			if str((m_worlds[index] as Dictionary).get("id", "")) == world_id:
				m_worlds[index] = normalized
				updated = true
				break

	if not updated:
		m_worlds.append(normalized)

	_sort_worlds()
	_write_worlds()
	worlds_changed.emit(get_worlds())
	content_changed.emit()
	return {"ok": true, "id": world_id, "message": "세계관 정보가 저장되었습니다."}


func save_character(character_data: Dictionary, previous_id: String = "") -> Dictionary:
	var normalized := _normalize_character(character_data, previous_id)
	var character_id := str(normalized.get("id", ""))
	if character_id.is_empty():
		return {"ok": false, "message": "인물 ID를 만들 수 없습니다."}

	if _id_conflicts(m_characters, character_id, previous_id):
		return {"ok": false, "message": "같은 ID를 가진 인물이 이미 존재합니다."}

	var updated := false
	if not previous_id.strip_edges().is_empty():
		for index in range(m_characters.size()):
			if str((m_characters[index] as Dictionary).get("id", "")) == previous_id:
				m_characters[index] = normalized
				updated = true
				break

	if not updated:
		for index in range(m_characters.size()):
			if str((m_characters[index] as Dictionary).get("id", "")) == character_id:
				m_characters[index] = normalized
				updated = true
				break

	if not updated:
		m_characters.append(normalized)

	_sort_characters()
	_write_characters()
	characters_changed.emit(get_characters())
	content_changed.emit()
	return {"ok": true, "id": character_id, "message": "인물 정보가 저장되었습니다."}


func delete_world(world_id: String) -> bool:
	var clean_id := world_id.strip_edges()
	if clean_id.is_empty():
		return false

	for index in range(m_worlds.size() - 1, -1, -1):
		if str((m_worlds[index] as Dictionary).get("id", "")) == clean_id:
			m_worlds.remove_at(index)
			_write_worlds()
			worlds_changed.emit(get_worlds())
			content_changed.emit()
			return true

	return false


func delete_character(character_id: String) -> bool:
	var clean_id := character_id.strip_edges()
	if clean_id.is_empty():
		return false

	for index in range(m_characters.size() - 1, -1, -1):
		if str((m_characters[index] as Dictionary).get("id", "")) == clean_id:
			m_characters.remove_at(index)
			for world_index in range(m_worlds.size()):
				var world := (m_worlds[world_index] as Dictionary).duplicate(true)
				var default_ids: Array = _normalize_string_array(world.get("default_main_character_ids", []))
				default_ids.erase(clean_id)
				world["default_main_character_ids"] = default_ids
				m_worlds[world_index] = world
			_write_worlds()
			_write_characters()
			worlds_changed.emit(get_worlds())
			characters_changed.emit(get_characters())
			content_changed.emit()
			return true

	return false


func build_empty_world() -> Dictionary:
	return {
		"id": "",
		"name_ko": "",
		"story_title": "",
		"summary": "",
		"genre": "",
		"tone": "",
		"premise": "",
		"core_rules": [],
		"notable_places": [],
		"story_prompt_template": "basic",
		"story_examples": [],
		"start_setup_name": "",
		"prologue": "",
		"initial_situation": "",
		"player_guide": "",
		"default_main_character_ids": [],
		"square_cover_path": "",
		"portrait_cover_path": "",
		"default_rating_lane": "general",
		"notes": "",
		"backgrounds": []
	}


func build_empty_character() -> Dictionary:
	return {
		"id": "",
		"name_ko": "",
		"role": "",
		"summary": "",
		"thumbnail_path": "",
		"main_personality": "",
		"sub_personalities": [],
		"speech_examples": [],
		"appearance": "",
		"emotion_images": {
			"neutral": "",
			"joy": "",
			"sad": "",
			"angry": ""
		},
		"event_images": [],
		"personality_tags": [],
		"speech_style": "",
		"goal": "",
		"preferred_sprite_ids": [],
		"notes": ""
	}


func build_story_setup(world_id: String, character_ids: Array) -> Dictionary:
	var world_profile := get_world_by_id(world_id)
	var character_profiles: Array = []
	for character_id in character_ids:
		var character := get_character_by_id(str(character_id))
		if not character.is_empty():
			character_profiles.append(character)

	return {
		"world": world_profile,
		"characters": character_profiles
	}


func _load_all() -> void:
	m_worlds = _load_collection(WORLDS_PATH, [DEMO_WORLD], "world")
	m_characters = _load_collection(CHARACTERS_PATH, [DEMO_CHARACTER], "character")
	_sort_worlds()
	_sort_characters()
	_write_worlds()
	_write_characters()
	worlds_changed.emit(get_worlds())
	characters_changed.emit(get_characters())
	content_changed.emit()


func _load_collection(path: String, defaults: Array, data_type: String) -> Array:
	if not FileAccess.file_exists(path):
		return _normalize_collection(defaults, data_type, true)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _normalize_collection(defaults, data_type, true)

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return _normalize_collection(defaults, data_type, true)

	var items: Variant = parsed.get("items", [])
	if not (items is Array):
		return _normalize_collection(defaults, data_type, true)

	return _normalize_collection(items, data_type, false)


func _normalize_collection(items: Array, data_type: String, use_default_if_empty: bool) -> Array:
	var normalized: Array = []
	for raw_item in items:
		if not (raw_item is Dictionary):
			continue

		match data_type:
			"world":
				normalized.append(_normalize_world(raw_item))
			"character":
				normalized.append(_normalize_character(raw_item))
			_:
				pass

	if normalized.is_empty() and use_default_if_empty:
		match data_type:
			"world":
				normalized.append(_normalize_world(DEMO_WORLD))
			"character":
				normalized.append(_normalize_character(DEMO_CHARACTER))

	return _dedupe_items(normalized)


func _dedupe_items(items: Array) -> Array:
	var deduped: Array = []
	var seen_ids := {}
	for item in items:
		var item_id := str((item as Dictionary).get("id", ""))
		if item_id.is_empty() or seen_ids.has(item_id):
			continue
		seen_ids[item_id] = true
		deduped.append((item as Dictionary).duplicate(true))
	return deduped


func _normalize_world(raw_world: Dictionary, previous_id: String = "") -> Dictionary:
	var world_id := _resolve_id(str(raw_world.get("id", "")), "world", previous_id)
	var default_main_character_ids := _normalize_string_array(raw_world.get("default_main_character_ids", []))
	var prompt_template := str(raw_world.get("story_prompt_template", "basic")).strip_edges().to_lower()
	if not PROMPT_TEMPLATES.has(prompt_template):
		prompt_template = "basic"

	return {
		"id": world_id,
		"name_ko": str(raw_world.get("name_ko", "새 세계관")).strip_edges(),
		"story_title": str(raw_world.get("story_title", "")).strip_edges(),
		"summary": str(raw_world.get("summary", "")).strip_edges(),
		"genre": str(raw_world.get("genre", "")).strip_edges(),
		"tone": str(raw_world.get("tone", "")).strip_edges(),
		"premise": str(raw_world.get("premise", "")).strip_edges(),
		"core_rules": _normalize_string_array(raw_world.get("core_rules", [])),
		"notable_places": _normalize_string_array(raw_world.get("notable_places", [])),
		"story_prompt_template": prompt_template,
		"story_examples": _normalize_string_array(raw_world.get("story_examples", [])),
		"start_setup_name": str(raw_world.get("start_setup_name", "")).strip_edges(),
		"prologue": str(raw_world.get("prologue", "")).strip_edges(),
		"initial_situation": str(raw_world.get("initial_situation", "")).strip_edges(),
		"player_guide": str(raw_world.get("player_guide", "")).strip_edges(),
		"default_main_character_ids": default_main_character_ids,
		"square_cover_path": str(raw_world.get("square_cover_path", "")).strip_edges(),
		"portrait_cover_path": str(raw_world.get("portrait_cover_path", "")).strip_edges(),
		"default_rating_lane": _normalize_rating_lane(str(raw_world.get("default_rating_lane", "general"))),
		"notes": str(raw_world.get("notes", "")).strip_edges(),
		"backgrounds": _normalize_backgrounds(raw_world.get("backgrounds", []))
	}


func _normalize_backgrounds(raw_backgrounds) -> Array:
	var result: Array = []
	if not raw_backgrounds is Array:
		return result
	for raw_bg in raw_backgrounds:
		if not raw_bg is Dictionary:
			continue
		var name_val := str(raw_bg.get("name", "")).strip_edges()
		var description_val := str(raw_bg.get("description", "")).strip_edges()
		var image_path_val := str(raw_bg.get("image_path", "")).strip_edges()
		if name_val.is_empty() and description_val.is_empty() and image_path_val.is_empty():
			continue
		result.append({
			"image_path": image_path_val,
			"name": name_val,
			"description": description_val
		})
	return result


func _normalize_character(raw_character: Dictionary, previous_id: String = "") -> Dictionary:
	var character_id := _resolve_id(str(raw_character.get("id", "")), "character", previous_id)
	var main_personality := str(raw_character.get("main_personality", "")).strip_edges()
	var sub_personalities := _normalize_string_array(raw_character.get("sub_personalities", []))
	var legacy_tags := _normalize_string_array(raw_character.get("personality_tags", []))
	if main_personality.is_empty() and not legacy_tags.is_empty():
		main_personality = str(legacy_tags[0])
	for legacy_tag in legacy_tags:
		if legacy_tag != main_personality and not sub_personalities.has(legacy_tag):
			sub_personalities.append(legacy_tag)
	while sub_personalities.size() > 3:
		sub_personalities.remove_at(sub_personalities.size() - 1)

	var personality_tags: Array = []
	if not main_personality.is_empty():
		personality_tags.append(main_personality)
	for sub_personality in sub_personalities:
		if not personality_tags.has(sub_personality):
			personality_tags.append(sub_personality)

	return {
		"id": character_id,
		"name_ko": str(raw_character.get("name_ko", "새 인물")).strip_edges(),
		"role": str(raw_character.get("role", "")).strip_edges(),
		"summary": str(raw_character.get("summary", "")).strip_edges(),
		"thumbnail_path": str(raw_character.get("thumbnail_path", "")).strip_edges(),
		"main_personality": main_personality,
		"sub_personalities": sub_personalities,
		"speech_examples": _normalize_string_array(raw_character.get("speech_examples", [])),
		"appearance": str(raw_character.get("appearance", "")).strip_edges(),
		"emotion_images": _normalize_emotion_images(raw_character.get("emotion_images", {})),
		"event_images": _normalize_event_images(raw_character.get("event_images", [])),
		"personality_tags": personality_tags,
		"speech_style": str(raw_character.get("speech_style", "")).strip_edges(),
		"goal": str(raw_character.get("goal", "")).strip_edges(),
		"preferred_sprite_ids": _normalize_string_array(raw_character.get("preferred_sprite_ids", [])),
		"notes": str(raw_character.get("notes", "")).strip_edges()
	}


func _normalize_emotion_images(raw_value: Variant) -> Dictionary:
	var emotion_images: Dictionary = raw_value if raw_value is Dictionary else {}
	return {
		"neutral": str((emotion_images as Dictionary).get("neutral", "")).strip_edges(),
		"joy": str((emotion_images as Dictionary).get("joy", "")).strip_edges(),
		"sad": str((emotion_images as Dictionary).get("sad", "")).strip_edges(),
		"angry": str((emotion_images as Dictionary).get("angry", "")).strip_edges()
	}


func _normalize_event_images(raw_value: Variant) -> Array:
	var event_images: Array = []
	if not (raw_value is Array):
		return event_images

	for raw_event in raw_value:
		if not (raw_event is Dictionary):
			continue
		event_images.append({
			"image_path": str(raw_event.get("image_path", "")).strip_edges(),
			"situation": str(raw_event.get("situation", "")).strip_edges()
		})

	return event_images


func _resolve_id(raw_id: String, prefix: String, previous_id: String = "") -> String:
	var sanitized := _sanitize_id(raw_id)
	if sanitized.is_empty():
		sanitized = _sanitize_id(previous_id)
	if sanitized.is_empty():
		sanitized = "%s_%d" % [prefix, int(Time.get_unix_time_from_system())]
	return sanitized


func _sanitize_id(raw_id: String) -> String:
	var lowered := raw_id.strip_edges().to_lower()
	var builder := ""
	for index in range(lowered.length()):
		var character := lowered.unicode_at(index)
		var allowed := (character >= 48 and character <= 57) or (character >= 97 and character <= 122) or character == 95 or character == 45
		if allowed:
			builder += char(character)
	return builder


func _normalize_string_array(raw_value: Variant) -> Array:
	var result: Array = []
	if raw_value is Array:
		for value in raw_value:
			var text := str(value).strip_edges()
			if not text.is_empty() and not result.has(text):
				result.append(text)
	elif raw_value is String:
		var normalized_text := str(raw_value).replace("\r\n", "\n").replace("\r", "\n")
		for chunk in normalized_text.split("\n", false):
			var line := chunk.strip_edges()
			if line.is_empty():
				continue
			for item in line.split(",", false):
				var clean_item := item.strip_edges()
				if not clean_item.is_empty() and not result.has(clean_item):
					result.append(clean_item)
	return result


func _normalize_rating_lane(raw_rating: String) -> String:
	var clean_rating := raw_rating.strip_edges().to_lower()
	if RATING_LANES.has(clean_rating):
		return clean_rating
	return "general"


func _id_conflicts(items: Array, candidate_id: String, previous_id: String) -> bool:
	for item in items:
		var item_id := str((item as Dictionary).get("id", ""))
		if item_id == candidate_id and item_id != previous_id:
			return true
	return false


func _sort_worlds() -> void:
	m_worlds.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return get_world_display_title(a).naturalnocasecmp_to(get_world_display_title(b)) < 0
	)


func _sort_characters() -> void:
	m_characters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_name := str(a.get("name_ko", a.get("id", "")))
		var b_name := str(b.get("name_ko", b.get("id", "")))
		return a_name.naturalnocasecmp_to(b_name) < 0
	)


func _write_worlds() -> void:
	_write_collection(WORLDS_PATH, m_worlds)


func _write_characters() -> void:
	_write_collection(CHARACTERS_PATH, m_characters)


func _write_collection(path: String, items: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify({
		"version": DATA_VERSION,
		"items": items
	}, "\t"))
