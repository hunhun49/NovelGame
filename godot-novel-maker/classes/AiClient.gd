extends Node
class_name AiClientService

signal turn_succeeded(payload: Dictionary)
signal turn_failed(error_state: Dictionary)
signal health_status_changed(status_state: Dictionary)

const TURN_TIMEOUT_SECONDS := 90.0
const HEALTH_TIMEOUT_SECONDS := 5.0
const PREWARM_TIMEOUT_SECONDS := 20.0
const UNKNOWN_MODEL := "model-unknown"

var m_turn_request: HTTPRequest
var m_health_request: HTTPRequest
var m_prewarm_request: HTTPRequest
var m_turn_in_flight := false
var m_health_in_flight := false
var m_prewarm_in_flight := false
var m_pending_turn_payload: Dictionary = {}
var m_pending_turn_prewarm_retries := 0
var m_last_health_state := {
	"status": "not_checked",
	"message": "백엔드 상태를 아직 확인하지 않았습니다.",
	"ready": false,
	"warm": false,
	"warm_fail_reasons": ["not_checked"],
	"provider": "unknown",
	"model": UNKNOWN_MODEL,
	"effective_num_ctx": 0,
	"context_length": 0,
	"size_vram": 0,
	"expires_at": ""
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

	m_prewarm_request = HTTPRequest.new()
	m_prewarm_request.timeout = PREWARM_TIMEOUT_SECONDS
	m_prewarm_request.request_completed.connect(_on_prewarm_request_completed)
	add_child(m_prewarm_request)

	request_backend_health_check()


func get_active_backend_mode() -> String:
	return settings_manager.get_backend_mode()


func get_last_health_state() -> Dictionary:
	return m_last_health_state.duplicate(true)


func is_backend_ready() -> bool:
	if settings_manager.uses_stub_backend():
		return true
	return bool(m_last_health_state.get("ready", false))


func is_backend_warm() -> bool:
	if settings_manager.uses_stub_backend():
		return true
	return bool(m_last_health_state.get("warm", false))


func ensure_backend_warm(reason: String = "manual") -> void:
	if settings_manager.uses_stub_backend():
		return
	if m_prewarm_in_flight or is_backend_warm():
		return
	_start_prewarm_request(reason)


func get_request_phase() -> String:
	if m_prewarm_in_flight:
		return "warming"
	if m_turn_in_flight:
		return "generating"
	return "idle"


func get_active_model_name() -> String:
	if settings_manager.uses_stub_backend():
		return "stub-local"
	return str(m_last_health_state.get("model", UNKNOWN_MODEL))


func get_active_provider_name() -> String:
	if settings_manager.uses_stub_backend():
		return "stub"
	return str(m_last_health_state.get("provider", "backend"))


func get_active_backend_summary() -> String:
	if settings_manager.uses_stub_backend():
		return "stub-local"

	var provider := get_active_provider_name()
	var model := get_active_model_name()
	if model.is_empty() or model == UNKNOWN_MODEL:
		return provider
	return "%s / %s" % [provider, model]


func request_backend_health_check() -> void:
	if settings_manager.uses_stub_backend():
		m_last_health_state = _build_health_state(
			"stub",
			"Stub backend mode is enabled.",
			true,
			true,
			[],
			"stub",
			"stub-local"
		)
		health_status_changed.emit(get_last_health_state())
		return

	if m_health_in_flight:
		return

	var request_error := m_health_request.request(settings_manager.get_health_url(), PackedStringArray(), HTTPClient.METHOD_GET)
	if request_error != OK:
		m_last_health_state = _build_health_state(
			"request_error",
			"백엔드 상태 확인을 시작하지 못했습니다. (%d)" % request_error,
			false,
			false,
			["health_request_error"]
		)
		health_status_changed.emit(get_last_health_state())
		return

	m_health_in_flight = true
	m_last_health_state = _build_health_state(
		"checking",
		"백엔드 상태 확인 중...",
		false,
		false,
		["health_check_in_progress"],
		"backend",
		"checking",
		int(m_last_health_state.get("effective_num_ctx", 0))
	)
	health_status_changed.emit(get_last_health_state())


func request_turn(payload: Dictionary) -> void:
	if settings_manager.uses_stub_backend():
		_emit_stub_turn(payload)
		return

	if m_turn_in_flight or not m_pending_turn_payload.is_empty():
		emit_turn_failure("busy", "이미 다른 요청을 처리하고 있습니다.")
		return

	if not is_backend_warm():
		m_pending_turn_payload = payload.duplicate(true)
		m_pending_turn_prewarm_retries = 1
		ensure_backend_warm("turn_request")
		return

	_start_turn_request(payload)


func emit_turn_failure(kind: String, message: String, http_code: int = 0, raw_body: String = "") -> void:
	turn_failed.emit({
		"kind": kind,
		"message": message,
		"http_code": http_code,
		"raw_body": raw_body
	})


func _start_turn_request(payload: Dictionary) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var request_error := m_turn_request.request(
		settings_manager.get_turn_url(),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if request_error != OK:
		emit_turn_failure("request_error", "턴 요청을 시작하지 못했습니다. (%d)" % request_error)
		return

	m_turn_in_flight = true


func _start_prewarm_request(reason: String) -> void:
	if settings_manager.uses_stub_backend() or m_prewarm_in_flight:
		return

	var headers := PackedStringArray(["Content-Type: application/json"])
	var request_error := m_prewarm_request.request(
		settings_manager.get_prewarm_url(),
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify({"reason": reason})
	)
	if request_error != OK:
		_handle_prewarm_failure("prewarm_request_error", "Prewarm 요청을 시작하지 못했습니다. (%d)" % request_error)
		return

	m_prewarm_in_flight = true


func _on_prewarm_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	m_prewarm_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_prewarm_failure("prewarm_network_error", "Prewarm 요청이 실패했습니다. 결과 코드: %d" % result)
		return

	if response_code < 200 or response_code >= 300:
		_handle_prewarm_failure(
			"prewarm_http_error",
			"Prewarm 요청이 HTTP %d를 반환했습니다." % response_code,
			body.get_string_from_utf8()
		)
		return

	var raw_body := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_body)
	if not (parsed is Dictionary):
		_handle_prewarm_failure("prewarm_invalid_json", "Prewarm 응답이 JSON 객체가 아닙니다.", raw_body)
		return

	_apply_health_state(parsed as Dictionary)
	health_status_changed.emit(get_last_health_state())

	if is_backend_warm():
		_resume_pending_turn()
		return

	_handle_prewarm_failure("prewarm_not_warm", "Prewarm 이후에도 backend가 warm 상태가 아닙니다.", raw_body)


func _handle_prewarm_failure(kind: String, message: String, raw_body: String = "") -> void:
	var warm_fail_reasons: Array = []
	for raw_reason in m_last_health_state.get("warm_fail_reasons", []):
		var reason_text := str(raw_reason).strip_edges()
		if not reason_text.is_empty() and not warm_fail_reasons.has(reason_text):
			warm_fail_reasons.append(reason_text)
	if warm_fail_reasons.is_empty():
		warm_fail_reasons.append(kind)

	m_last_health_state["warm"] = false
	m_last_health_state["message"] = message
	m_last_health_state["warm_fail_reasons"] = warm_fail_reasons
	m_last_health_state["raw_body"] = raw_body
	health_status_changed.emit(get_last_health_state())

	if m_pending_turn_payload.is_empty():
		return

	if m_pending_turn_prewarm_retries > 0:
		m_pending_turn_prewarm_retries -= 1
		_start_prewarm_request("turn_retry")
		return

	_resume_pending_turn(true)


func _resume_pending_turn(force_direct_turn: bool = false) -> void:
	if m_pending_turn_payload.is_empty():
		return
	if not force_direct_turn and not is_backend_warm():
		return

	var queued_payload := m_pending_turn_payload.duplicate(true)
	m_pending_turn_payload = {}
	m_pending_turn_prewarm_retries = 0
	_start_turn_request(queued_payload)


func _emit_stub_turn(payload: Dictionary) -> void:
	var persona: Dictionary = payload.get("persona", {})
	var world: Dictionary = payload.get("world", {})
	var runtime_state: Dictionary = payload.get("runtime_state", {})
	var asset_candidates: Dictionary = payload.get("asset_candidates", {})
	var main_characters: Array = persona.get("main_characters", [])
	var world_profile: Dictionary = world.get("profile", {})
	var pending_input := str(runtime_state.get("pending_player_input", "")).strip_edges()
	var world_name := str(world_profile.get("story_title", world_profile.get("name_ko", "Story"))).strip_edges()
	var lead_character: Dictionary = {}
	if not main_characters.is_empty() and main_characters[0] is Dictionary:
		lead_character = (main_characters[0] as Dictionary).duplicate(true)
	var lead_character_id := str(lead_character.get("id", "lead")).strip_edges()
	var lead_character_name := str(lead_character.get("name_ko", lead_character.get("name", "Guide"))).strip_edges()
	var background_id := _get_first_candidate_id(asset_candidates.get("backgrounds", []))
	var cg_id := _get_first_candidate_id(asset_candidates.get("cgs", []))
	var bgm_id := _get_first_candidate_id(asset_candidates.get("bgms", []))
	var sfx_id := _get_first_candidate_id(asset_candidates.get("sfxs", []))
	var sprite_id := _pick_sprite_candidate_id(asset_candidates.get("sprites", []), lead_character_id)
	var scene_mode := "cg" if pending_input.to_lower().contains("#cg") and not cg_id.is_empty() else "layered"
	var character_states: Array = []
	if scene_mode == "layered" and not sprite_id.is_empty():
		character_states.append({
			"character_id": lead_character_id,
			"sprite_id": sprite_id,
			"position": "center"
		})

	if pending_input.is_empty():
		pending_input = "다음 장면을 이어 가 줘."

	turn_succeeded.emit({
		"content": {
			"narration": "%s의 공기가 조금 더 팽팽해지고, 다음 선택을 기다리는 정적이 길게 이어진다." % world_name,
			"dialogue": "%s, 방금 한 말을 바탕으로 다음 장면을 더 밀어 보자." % lead_character_name,
			"action": "%s가 시선을 들어 다음 반응을 재촉하듯 한 걸음 가까워진다." % lead_character_name
		},
		"direction": {
			"scene_mode": scene_mode,
			"background_id": background_id,
			"character_states": character_states,
			"cg_id": cg_id if scene_mode == "cg" else "",
			"transition": "crossfade" if scene_mode == "cg" else "fade",
			"camera_fx": "dim" if scene_mode == "cg" else "none"
		},
		"state_update": {
			"relationship_delta": {lead_character_id: 1},
			"set_flags": ["stub_turn"],
			"content_rating": str(world.get("rating_lane", "general"))
		},
		"memory_hint": {
			"summary_candidate": "%s에서 %s와의 대화가 한 단계 진행됐다." % [world_name, lead_character_name]
		},
		"audio": {
			"bgm_id": bgm_id,
			"sfx_id": sfx_id if pending_input.to_lower().contains("#sfx") else "",
			"volume_profile": "quiet"
		}
	})


func _get_first_candidate_id(raw_value: Variant) -> String:
	if not (raw_value is Array) or (raw_value as Array).is_empty():
		return ""
	for raw_item in raw_value:
		if raw_item is Dictionary:
			var item_id := str((raw_item as Dictionary).get("id", "")).strip_edges()
			if not item_id.is_empty():
				return item_id
	return ""


func _pick_sprite_candidate_id(raw_value: Variant, character_id: String) -> String:
	if not (raw_value is Array):
		return ""
	for raw_item in raw_value:
		if not (raw_item is Dictionary):
			continue
		var item := raw_item as Dictionary
		if str(item.get("character_id", "")).strip_edges() != character_id:
			continue
		var item_id := str(item.get("id", "")).strip_edges()
		if not item_id.is_empty():
			return item_id
	return _get_first_candidate_id(raw_value)


func _on_turn_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	m_turn_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		if result == HTTPRequest.RESULT_TIMEOUT:
			emit_turn_failure("timeout", "응답 대기 시간이 초과되었습니다.", response_code)
			return
		emit_turn_failure("network_error", "HTTP 요청이 실패했습니다. 결과 코드: %d" % result, response_code)
		return

	if response_code < 200 or response_code >= 300:
		emit_turn_failure("http_error", "백엔드가 HTTP %d를 반환했습니다." % response_code, response_code, body.get_string_from_utf8())
		return

	var raw_body := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_body)
	if not (parsed is Dictionary):
		emit_turn_failure("invalid_json", "백엔드가 올바른 JSON을 반환하지 않았습니다.", response_code, raw_body)
		return

	var validation := _validate_turn_payload(parsed as Dictionary)
	if not bool(validation.get("ok", false)):
		emit_turn_failure("schema_error", str(validation.get("message", "응답 스키마 검증에 실패했습니다.")), response_code, raw_body)
		return

	turn_succeeded.emit(parsed)


func _on_health_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	m_health_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		m_last_health_state = _build_health_state(
			"network_error",
			"백엔드 상태 확인에 실패했습니다. 결과 코드: %d" % result,
			false,
			false,
			["health_network_error"]
		)
		health_status_changed.emit(get_last_health_state())
		return

	if response_code < 200 or response_code >= 300:
		m_last_health_state = _build_health_state(
			"http_error",
			"백엔드 상태 확인이 HTTP %d를 반환했습니다." % response_code,
			false,
			false,
			["health_http_error"]
		)
		m_last_health_state["raw_body"] = body.get_string_from_utf8()
		health_status_changed.emit(get_last_health_state())
		return

	var raw_body := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_body)
	if parsed is Dictionary:
		_apply_health_state(parsed as Dictionary)
	else:
		m_last_health_state = _build_health_state(
			"invalid_json",
			"백엔드 상태 응답이 JSON 객체가 아닙니다.",
			false,
			false,
			["health_invalid_json"]
		)
		m_last_health_state["raw_body"] = raw_body

	health_status_changed.emit(get_last_health_state())

	if bool(m_last_health_state.get("ready", false)) and not is_backend_warm():
		ensure_backend_warm("health_success")


func _apply_health_state(status_state: Dictionary) -> void:
	var warm_fail_reasons: Array = []
	for raw_reason in status_state.get("warm_fail_reasons", []):
		var reason_text := str(raw_reason).strip_edges()
		if not reason_text.is_empty() and not warm_fail_reasons.has(reason_text):
			warm_fail_reasons.append(reason_text)

	m_last_health_state = _build_health_state(
		str(status_state.get("status", "unknown")),
		str(status_state.get("message", "No backend status available.")),
		bool(status_state.get("ready", false)),
		bool(status_state.get("warm", false)),
		warm_fail_reasons,
		str(status_state.get("provider", "backend")),
		str(status_state.get("model", UNKNOWN_MODEL)),
		int(status_state.get("effective_num_ctx", 0))
	)
	m_last_health_state["context_length"] = int(status_state.get("context_length", 0))
	m_last_health_state["size_vram"] = int(status_state.get("size_vram", 0))
	m_last_health_state["expires_at"] = str(status_state.get("expires_at", ""))
	if status_state.has("prewarm"):
		m_last_health_state["prewarm"] = status_state.get("prewarm")


func _build_health_state(
	status: String,
	message: String,
	ready: bool,
	warm: bool,
	warm_fail_reasons: Array,
	provider: String = "backend",
	model: String = UNKNOWN_MODEL,
	effective_num_ctx: int = 0
) -> Dictionary:
	return {
		"status": status,
		"message": message,
		"ready": ready,
		"warm": warm,
		"warm_fail_reasons": warm_fail_reasons.duplicate(),
		"provider": provider,
		"model": model,
		"effective_num_ctx": effective_num_ctx,
		"context_length": 0,
		"size_vram": 0,
		"expires_at": ""
	}


func _validate_turn_payload(payload: Dictionary) -> Dictionary:
	for key in ["content", "direction", "state_update", "memory_hint", "audio"]:
		if not (payload.get(key, {}) is Dictionary):
			return {"ok": false, "message": "%s must be a Dictionary." % key}

	var content: Dictionary = payload.get("content", {})
	if not _all_string_fields(content, ["narration", "dialogue", "action"]):
		return {"ok": false, "message": "content fields must be strings."}

	var direction: Dictionary = payload.get("direction", {})
	if not _all_string_fields(direction, ["scene_mode", "background_id", "cg_id", "transition", "camera_fx"]):
		return {"ok": false, "message": "direction fields must be strings."}

	var scene_mode := str(direction.get("scene_mode", ""))
	if scene_mode != "layered" and scene_mode != "cg":
		return {"ok": false, "message": "direction.scene_mode is invalid."}

	var raw_character_states_value: Variant = direction.get("character_states", [])
	if not (raw_character_states_value is Array):
		return {"ok": false, "message": "direction.character_states must be an Array."}
	var raw_character_states: Array = raw_character_states_value
	for raw_state in raw_character_states:
		if not (raw_state is Dictionary):
			return {"ok": false, "message": "character_states entries must be Dictionary values."}
		var state := raw_state as Dictionary
		if not _all_string_fields(state, ["character_id", "position"]):
			return {"ok": false, "message": "character_state.character_id and position must be strings."}
		if not state.has("sprite_id") and not state.has("image_path"):
			return {"ok": false, "message": "character_state requires sprite_id or image_path."}
		if state.has("sprite_id") and typeof(state.get("sprite_id", "")) != TYPE_STRING:
			return {"ok": false, "message": "character_state.sprite_id must be a string."}
		if state.has("image_path") and typeof(state.get("image_path", "")) != TYPE_STRING:
			return {"ok": false, "message": "character_state.image_path must be a string."}

	var state_update: Dictionary = payload.get("state_update", {})
	if not (state_update.get("relationship_delta", {}) is Dictionary):
		return {"ok": false, "message": "state_update.relationship_delta must be a Dictionary."}
	if not (state_update.get("set_flags", []) is Array):
		return {"ok": false, "message": "state_update.set_flags must be an Array."}
	if typeof(state_update.get("content_rating", "")) != TYPE_STRING:
		return {"ok": false, "message": "state_update.content_rating must be a string."}

	var memory_hint: Dictionary = payload.get("memory_hint", {})
	if typeof(memory_hint.get("summary_candidate", "")) != TYPE_STRING:
		return {"ok": false, "message": "memory_hint.summary_candidate must be a string."}

	var audio: Dictionary = payload.get("audio", {})
	if not _all_string_fields(audio, ["bgm_id", "sfx_id", "volume_profile"]):
		return {"ok": false, "message": "audio fields must be strings."}

	return {"ok": true}


func _all_string_fields(target: Dictionary, field_names: Array) -> bool:
	for raw_name in field_names:
		var field_name := str(raw_name)
		if typeof(target.get(field_name, "")) != TYPE_STRING:
			return false
	return true
