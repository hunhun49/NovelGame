extends Node
class_name AiClientService

signal turn_succeeded(payload: Dictionary)
signal turn_failed(error_state: Dictionary)
signal health_status_changed(status_state: Dictionary)

const TURN_TIMEOUT_SECONDS := 90.0
const HEALTH_TIMEOUT_SECONDS := 5.0

var m_turn_request: HTTPRequest
var m_health_request: HTTPRequest
var m_turn_in_flight := false
var m_health_in_flight := false
var m_last_health_state := {
	"status": "not_checked",
	"message": "백엔드 상태를 아직 확인하지 않았습니다.",
	"ready": false,
	"provider": "unknown",
	"model": "미확인"
}


func _ready() -> void:
	m_turn_request = HTTPRequest.new()
	m_turn_request.timeout = TURN_TIMEOUT_SECONDS
	m_turn_request.request_completed.connect(_on_turn_request_completed)
	add_child(m_turn_request)

	m_health_request = HTTPRequest.new()
	m_health_request.timeout = HEALTH_TIMEOUT_SECONDS
	m_health_request.request_completed.connect(_on_health_request_completed)
	add_child(m_health_request)

	request_backend_health_check()


func get_active_backend_mode() -> String:
	return settings_manager.get_backend_mode()


func get_last_health_state() -> Dictionary:
	return m_last_health_state.duplicate(true)


func is_backend_ready() -> bool:
	if settings_manager.uses_stub_backend():
		return true
	return bool(m_last_health_state.get("ready", false))


func get_active_model_name() -> String:
	if settings_manager.uses_stub_backend():
		return "stub-local"
	return str(m_last_health_state.get("model", "미확인"))


func get_active_provider_name() -> String:
	if settings_manager.uses_stub_backend():
		return "stub"
	return str(m_last_health_state.get("provider", "backend"))


func get_active_backend_summary() -> String:
	if settings_manager.uses_stub_backend():
		return "stub-local"

	var provider := get_active_provider_name()
	var model := get_active_model_name()
	if model.is_empty() or model == "미확인":
		return provider
	return "%s / %s" % [provider, model]


func request_backend_health_check() -> void:
	if settings_manager.uses_stub_backend():
		m_last_health_state = {
			"status": "stub",
			"message": "Stub 백엔드 모드가 활성화되어 있습니다.",
			"ready": true,
			"provider": "stub",
			"model": "stub-local"
		}
		health_status_changed.emit(get_last_health_state())
		return

	if m_health_in_flight:
		return

	var request_error := m_health_request.request(settings_manager.get_health_url(), PackedStringArray(), HTTPClient.METHOD_GET)
	if request_error != OK:
		m_last_health_state = {
			"status": "request_error",
			"message": "백엔드 헬스 체크를 시작하지 못했습니다. (오류 %d)" % request_error,
			"ready": false,
			"provider": "backend",
			"model": "미확인"
		}
		health_status_changed.emit(get_last_health_state())
		return

	m_health_in_flight = true
	m_last_health_state = {
		"status": "checking",
		"message": "백엔드 상태를 확인하고 있습니다...",
		"ready": false,
		"provider": "backend",
		"model": "확인 중"
	}
	health_status_changed.emit(get_last_health_state())


func request_turn(payload: Dictionary) -> void:
	if settings_manager.uses_stub_backend():
		_emit_stub_turn(payload)
		return

	if m_turn_in_flight:
		emit_turn_failure("busy", "이미 다른 턴 요청을 처리하고 있습니다.")
		return

	var headers := PackedStringArray(["Content-Type: application/json"])
	var request_error := m_turn_request.request(settings_manager.get_turn_url(), headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if request_error != OK:
		emit_turn_failure("request_error", "HTTP 턴 요청을 시작하지 못했습니다. (오류 %d)" % request_error)
		return

	m_turn_in_flight = true


func emit_turn_failure(kind: String, message: String, http_code: int = 0, raw_body: String = "") -> void:
	turn_failed.emit({
		"kind": kind,
		"message": message,
		"http_code": http_code,
		"raw_body": raw_body
	})


func _emit_stub_turn(payload: Dictionary) -> void:
	var persona: Dictionary = payload.get("persona", {})
	var world: Dictionary = payload.get("world", {})
	var runtime_state: Dictionary = payload.get("runtime_state", {})
	var asset_candidates: Dictionary = payload.get("asset_candidates", {})
	var pending_input := str(runtime_state.get("pending_player_input", "")).strip_edges()
	var lowercase_input := pending_input.to_lower()
	var scene_mode := "layered"

	var main_characters: Array = persona.get("main_characters", [])
	var player_character: Dictionary = persona.get("player_character", {})
	var world_profile: Dictionary = world.get("profile", {})
	var world_name := str(world_profile.get("story_title", "")).strip_edges()
	if world_name.is_empty():
		world_name = str(world_profile.get("name_ko", "선택된 세계관"))
	var lead_character_id := "demo_guide"
	var lead_character_name := "안내자"
	var lead_character_profile: Dictionary = {}
	var player_character_name := str(player_character.get("name_ko", "")).strip_edges()
	if player_character_name.is_empty():
		player_character_name = str(persona.get("player_name", "?뚮젅?댁뼱"))
	var preferred_sprite_ids: Array = []
	if not main_characters.is_empty():
		var main_character: Dictionary = main_characters[0]
		lead_character_profile = main_character.duplicate(true)
		lead_character_id = str(main_character.get("id", lead_character_id))
		lead_character_name = str(main_character.get("name_ko", lead_character_name))
		preferred_sprite_ids = main_character.get("preferred_sprite_ids", []).duplicate(true)

	var background_candidates: Array = asset_candidates.get("backgrounds", [])
	var sprite_candidates: Array = asset_candidates.get("sprites", [])
	var cg_candidates: Array = asset_candidates.get("cgs", [])
	var bgm_candidates: Array = asset_candidates.get("bgms", [])
	var sfx_candidates: Array = asset_candidates.get("sfxs", [])

	if lowercase_input.contains("#cg") and not cg_candidates.is_empty():
		scene_mode = "cg"

	var background_id := ""
	if not background_candidates.is_empty():
		background_id = str((background_candidates[0] as Dictionary).get("id", ""))

	var neutral_emotion_path := _get_preferred_stub_image_path(lead_character_profile)
	var sprite_candidate := _pick_sprite_candidate(sprite_candidates, lead_character_id, preferred_sprite_ids)
	var character_states: Array = []
	if not neutral_emotion_path.is_empty():
		character_states.append({
			"character_id": lead_character_id,
			"image_path": neutral_emotion_path,
			"position": "center"
		})
	elif not sprite_candidate.is_empty():
		character_states.append({
			"character_id": lead_character_id,
			"sprite_id": str(sprite_candidate.get("id", "")),
			"position": "center"
		})

	var cg_id := ""
	if scene_mode == "cg" and not cg_candidates.is_empty():
		cg_id = str((cg_candidates[0] as Dictionary).get("id", ""))

	var audio_payload := {}
	if not bgm_candidates.is_empty():
		audio_payload["bgm_id"] = str((bgm_candidates[0] as Dictionary).get("id", ""))
		audio_payload["volume_profile"] = "quiet"

	if lowercase_input.contains("#sfx") and not sfx_candidates.is_empty():
		audio_payload["sfx_id"] = str((sfx_candidates[0] as Dictionary).get("id", ""))

	var player_line := pending_input
	if player_line.is_empty():
		player_line = "다음 장면을 진행해 줘"

	var stub_content := _build_stub_content(player_line, lowercase_input, world_name, lead_character_name, player_character_name)

	turn_succeeded.emit({
		"content": stub_content,
		"direction": {
			"scene_mode": scene_mode,
			"background_id": background_id,
			"character_states": character_states,
			"cg_id": cg_id,
			"transition": "crossfade" if scene_mode == "cg" else "fade",
			"camera_fx": "dim" if scene_mode == "cg" else "none"
		},
		"state_update": {
			"relationship_delta": {
				lead_character_id: 1
			},
			"set_flags": [
				"story_started_%s" % str(world.get("selected_world_id", "demo_world"))
			],
			"content_rating": str(world_profile.get("default_rating_lane", "general"))
		},
		"memory_hint": {
			"summary_candidate": "%s 세계관에서 %s 중심의 로컬 테스트 턴이 한 번 진행되었습니다." % [world_name, lead_character_name]
		},
		"audio": audio_payload
	})


func _build_stub_content(player_line: String, lowercase_input: String, world_name: String, lead_character_name: String, player_character_name: String) -> Dictionary:
	var narration := "%s에서 %s의 말에 반응해 다음 장면이 이어집니다." % [world_name, player_character_name]
	var dialogue := "좋아. 방금 한 말을 바탕으로 다음 흐름을 이어 볼게."
	var action := "%s이(가) 플레이어의 의도를 받아 장면 분위기를 정리합니다." % lead_character_name

	if lowercase_input.contains("안녕") or lowercase_input.contains("반가"):
		narration = "%s의 공기가 조금 부드러워지며 첫 대화가 자연스럽게 시작됩니다." % world_name
		dialogue = "안녕. 긴장하지 말고, 지금 떠오른 말을 그대로 이어 줘."
		action = "%s이(가) 경계심을 풀고 대화를 이어 갈 준비를 합니다." % lead_character_name
	elif player_line.ends_with("?") or lowercase_input.contains("왜") or lowercase_input.contains("어떻게") or lowercase_input.contains("뭐"):
		narration = "%s의 질문이 장면의 중심으로 떠오르며, 주변의 시선이 %s에게 모입니다." % [player_character_name, lead_character_name]
		dialogue = "좋은 질문이야. 단정하지 말고 하나씩 확인해 보자. 지금 상황에서 가장 중요한 건 네가 무엇을 원하는지야."
		action = "%s이(가) 바로 답을 주기보다, 다음 선택으로 이어질 단서를 건넵니다." % lead_character_name
	elif lowercase_input.contains("도와") or lowercase_input.contains("도와줘") or lowercase_input.contains("부탁"):
		narration = "%s의 요청에 장면의 긴장감이 조금 누그러지고 협력의 분위기가 생깁니다." % player_character_name
		dialogue = "알겠어. 내가 앞을 정리할 테니 너는 핵심만 말해 줘."
		action = "%s이(가) 플레이어 편에 서서 다음 행동의 실마리를 제공합니다." % lead_character_name
	elif lowercase_input.contains("싫") or lowercase_input.contains("화나") or lowercase_input.contains("짜증"):
		narration = "%s의 감정이 거칠게 흔들리자 장면의 공기도 즉시 무거워집니다." % player_character_name
		dialogue = "지금 감정이 큰 건 이해해. 하지만 여기서 무너지면 네가 원하는 답에 더 멀어질 수도 있어."
		action = "%s이(가) 감정을 받아 주면서도 장면을 통제하려 합니다." % lead_character_name
	else:
		narration = "%s 세계관에서 입력한 말이 다음 사건의 방향을 정하는 신호로 반영됩니다. 입력은 \"%s\"입니다." % [world_name, player_line]
		dialogue = "\"%s\"라면, 그 말에는 분명 의도가 있어. 그 의도부터 따라가 보자." % player_line
		action = "%s이(가) 플레이어의 말을 단서로 삼아 다음 장면 전환을 준비합니다." % lead_character_name

	return {
		"narration": narration,
		"dialogue": dialogue,
		"action": action
	}


func _pick_sprite_candidate(sprite_candidates: Array, lead_character_id: String, preferred_sprite_ids: Array) -> Dictionary:
	for preferred_sprite_id in preferred_sprite_ids:
		for raw_candidate in sprite_candidates:
			var candidate := raw_candidate as Dictionary
			if str(candidate.get("id", "")) == str(preferred_sprite_id):
				return candidate

	for raw_candidate in sprite_candidates:
		var candidate := raw_candidate as Dictionary
		if str(candidate.get("character_id", "")) == lead_character_id:
			return candidate

	if not sprite_candidates.is_empty():
		return sprite_candidates[0]

	return {}


func _get_preferred_stub_image_path(character_profile: Dictionary) -> String:
	if character_profile.is_empty():
		return ""

	var emotion_images: Variant = character_profile.get("emotion_images", {})
	if emotion_images is Dictionary:
		var neutral_path := str((emotion_images as Dictionary).get("neutral", "")).strip_edges()
		if not neutral_path.is_empty():
			return neutral_path

	return str(character_profile.get("thumbnail_path", "")).strip_edges()


func _on_turn_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	m_turn_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		if result == HTTPRequest.RESULT_TIMEOUT:
			emit_turn_failure("timeout", "턴 생성 시간이 초과되었습니다. 로컬 모델 응답이 늦어 백엔드 대기 시간을 늘렸거나 더 가벼운 모델이 필요할 수 있습니다.", response_code)
			return

		emit_turn_failure("network_error", "HTTP 턴 요청이 실패했습니다. 엔진 결과 코드: %d" % result, response_code)
		return

	if response_code < 200 or response_code >= 300:
		emit_turn_failure("http_error", "백엔드가 턴 요청에 HTTP %d를 반환했습니다." % response_code, response_code, body.get_string_from_utf8())
		return

	var raw_body := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_body)
	if not (parsed is Dictionary):
		emit_turn_failure("invalid_json", "백엔드가 올바른 JSON을 반환하지 않았습니다.", response_code, raw_body)
		return

	var validation := _validate_turn_payload(parsed)
	if not bool(validation.get("ok", false)):
		emit_turn_failure("schema_error", str(validation.get("message", "턴 응답 검증에 실패했습니다.")), response_code, raw_body)
		return

	turn_succeeded.emit(parsed)


func _on_health_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	m_health_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		m_last_health_state = {
			"status": "network_error",
			"message": "백엔드 헬스 체크가 실패했습니다. 엔진 결과 코드: %d" % result,
			"ready": false,
			"provider": "backend",
			"model": "미확인"
		}
		health_status_changed.emit(get_last_health_state())
		return

	if response_code < 200 or response_code >= 300:
		m_last_health_state = {
			"status": "http_error",
			"message": "백엔드 헬스 엔드포인트가 HTTP %d를 반환했습니다." % response_code,
			"ready": false,
			"raw_body": body.get_string_from_utf8(),
			"provider": "backend",
			"model": "미확인"
		}
		health_status_changed.emit(get_last_health_state())
		return

	var raw_body := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_body)
	var provider := "backend"
	var model := "미확인"
	var message := "백엔드 연결이 정상입니다."
	var ready := true
	var status := "healthy"

	if parsed is Dictionary:
		provider = str(parsed.get("provider", provider)).strip_edges()
		model = str(parsed.get("model", model)).strip_edges()
		message = str(parsed.get("message", message)).strip_edges()
		ready = bool(parsed.get("ready", true))
		status = str(parsed.get("status", status)).strip_edges()

	if provider.is_empty():
		provider = "backend"
	if model.is_empty():
		model = "미확인"
	if message.is_empty():
		message = "백엔드 연결이 정상입니다."
	if status.is_empty():
		status = "healthy"

	m_last_health_state = {
		"status": status,
		"message": message,
		"ready": ready,
		"provider": provider,
		"model": model
	}
	health_status_changed.emit(get_last_health_state())


func _validate_turn_payload(payload: Dictionary) -> Dictionary:
	var required_sections := ["content", "direction", "state_update", "memory_hint"]
	for section_name in required_sections:
		if not (payload.get(section_name, {}) is Dictionary):
			return {
				"ok": false,
				"message": "턴 응답에 '%s' 섹션이 없습니다." % section_name
			}

	var content: Dictionary = payload["content"]
	if not _all_string_fields(content, ["narration", "dialogue", "action"]):
		return {
			"ok": false,
			"message": "content에는 narration, dialogue, action 문자열이 모두 있어야 합니다."
		}

	var direction: Dictionary = payload["direction"]
	var scene_mode := str(direction.get("scene_mode", ""))
	if scene_mode != "layered" and scene_mode != "cg":
		return {
			"ok": false,
			"message": "direction.scene_mode는 'layered' 또는 'cg'여야 합니다."
		}

	var character_states: Variant = direction.get("character_states", [])
	if not (character_states is Array):
		return {
			"ok": false,
			"message": "direction.character_states는 배열이어야 합니다."
		}

	for state in character_states:
		if not (state is Dictionary):
			return {
				"ok": false,
				"message": "character_states의 각 항목은 객체여야 합니다."
			}

		var position := str(state.get("position", ""))
		if position != "left" and position != "center" and position != "right":
			return {
				"ok": false,
				"message": "캐릭터 위치는 left, center, right 중 하나여야 합니다."
			}

		if str(state.get("character_id", "")).strip_edges().is_empty():
			return {
				"ok": false,
				"message": "각 캐릭터 상태에는 character_id가 필요합니다."
			}

		if str(state.get("sprite_id", "")).strip_edges().is_empty():
			return {
				"ok": false,
				"message": "각 캐릭터 상태에는 sprite_id가 필요합니다."
			}

	if str((payload["state_update"] as Dictionary).get("content_rating", "")).strip_edges().is_empty():
		return {
			"ok": false,
			"message": "state_update.content_rating이 비어 있습니다."
		}

	if payload.has("audio"):
		var audio: Variant = payload.get("audio", {})
		if not (audio is Dictionary):
			return {
				"ok": false,
				"message": "audio 섹션은 객체여야 합니다."
			}

		if audio.has("bgm_id") and not (audio.get("bgm_id", "") is String):
			return {
				"ok": false,
				"message": "audio.bgm_id는 문자열이어야 합니다."
			}

		if audio.has("sfx_id") and not (audio.get("sfx_id", "") is String):
			return {
				"ok": false,
				"message": "audio.sfx_id는 문자열이어야 합니다."
			}

		if audio.has("volume_profile") and not (audio.get("volume_profile", "") is String):
			return {
				"ok": false,
				"message": "audio.volume_profile은 문자열이어야 합니다."
			}

	return {
		"ok": true
	}


func _all_string_fields(target: Dictionary, field_names: Array) -> bool:
	for field_name in field_names:
		if not (target.get(field_name, "") is String):
			return false
	return true
