extends Node

signal turn_succeeded(payload: Dictionary)
signal turn_failed(error_state: Dictionary)
signal health_status_changed(status_state: Dictionary)

const TURN_TIMEOUT_SECONDS := 20.0
const HEALTH_TIMEOUT_SECONDS := 5.0

var _turn_request: HTTPRequest
var _health_request: HTTPRequest
var _turn_in_flight := false
var _health_in_flight := false
var _last_health_state := {
	"status": "not_checked",
	"message": "Backend health has not been checked yet.",
	"ready": false
}


func _ready() -> void:
	_turn_request = HTTPRequest.new()
	_turn_request.timeout = TURN_TIMEOUT_SECONDS
	_turn_request.request_completed.connect(_on_turn_request_completed)
	add_child(_turn_request)

	_health_request = HTTPRequest.new()
	_health_request.timeout = HEALTH_TIMEOUT_SECONDS
	_health_request.request_completed.connect(_on_health_request_completed)
	add_child(_health_request)

	request_backend_health_check()


func get_active_backend_mode() -> String:
	return SettingsManager.get_backend_mode()


func get_last_health_state() -> Dictionary:
	return _last_health_state.duplicate(true)


func is_backend_ready() -> bool:
	if SettingsManager.uses_stub_backend():
		return true
	return bool(_last_health_state.get("ready", false))


func request_backend_health_check() -> void:
	if SettingsManager.uses_stub_backend():
		_last_health_state = {
			"status": "stub",
			"message": "Stub backend mode is enabled.",
			"ready": true
		}
		health_status_changed.emit(get_last_health_state())
		return

	if _health_in_flight:
		return

	var request_error := _health_request.request(SettingsManager.get_health_url(), PackedStringArray(), HTTPClient.METHOD_GET)
	if request_error != OK:
		_last_health_state = {
			"status": "request_error",
			"message": "Could not start backend health check (error %d)." % request_error,
			"ready": false
		}
		health_status_changed.emit(get_last_health_state())
		return

	_health_in_flight = true
	_last_health_state = {
		"status": "checking",
		"message": "Checking backend health...",
		"ready": false
	}
	health_status_changed.emit(get_last_health_state())


func request_turn(payload: Dictionary) -> void:
	if SettingsManager.uses_stub_backend():
		_emit_stub_turn(payload)
		return

	if _turn_in_flight:
		emit_turn_failure("busy", "A turn request is already in flight.")
		return

	var headers := PackedStringArray(["Content-Type: application/json"])
	var request_error := _turn_request.request(SettingsManager.get_turn_url(), headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if request_error != OK:
		emit_turn_failure("request_error", "Could not start HTTP turn request (error %d)." % request_error)
		return

	_turn_in_flight = true


func emit_turn_failure(kind: String, message: String, http_code: int = 0, raw_body: String = "") -> void:
	turn_failed.emit({
		"kind": kind,
		"message": message,
		"http_code": http_code,
		"raw_body": raw_body
	})


func _emit_stub_turn(payload: Dictionary) -> void:
	var runtime_state: Dictionary = payload.get("runtime_state", {})
	var asset_candidates: Dictionary = payload.get("asset_candidates", {})
	var pending_input := str(runtime_state.get("pending_player_input", "")).strip_edges()
	var scene_mode := "layered"

	var background_candidates: Array = asset_candidates.get("backgrounds", [])
	var sprite_candidates: Array = asset_candidates.get("sprites", [])
	var cg_candidates: Array = asset_candidates.get("cgs", [])

	if pending_input.to_lower().contains("#cg") and not cg_candidates.is_empty():
		scene_mode = "cg"

	var background_id := ""
	if not background_candidates.is_empty():
		background_id = str((background_candidates[0] as Dictionary).get("id", ""))

	var character_states: Array = []
	if not sprite_candidates.is_empty():
		var sprite_candidate: Dictionary = sprite_candidates[0]
		character_states.append({
			"character_id": str(sprite_candidate.get("character_id", "prototype_heroine")),
			"sprite_id": str(sprite_candidate.get("id", "")),
			"position": "center"
		})

	var cg_id := ""
	if scene_mode == "cg" and not cg_candidates.is_empty():
		cg_id = str((cg_candidates[0] as Dictionary).get("id", ""))

	turn_succeeded.emit({
		"content": {
			"narration": "Stub turn accepted the input \"%s\" and produced a structured local response." % pending_input,
			"dialogue": "The real backend can now replace this stub without changing the scene shell.",
			"action": "The prototype shell updates visuals, state, and save data from one response."
		},
		"direction": {
			"scene_mode": scene_mode,
			"background_id": background_id,
			"character_states": character_states,
			"cg_id": cg_id,
			"transition": "fade",
			"camera_fx": "none"
		},
		"state_update": {
			"relationship_delta": {
				"prototype_heroine": 1
			},
			"set_flags": [
				"prototype_session_started"
			],
			"content_rating": "general"
		},
		"memory_hint": {
			"summary_candidate": "The prototype shell accepted player input and updated the VN state."
		}
	})


func _on_turn_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_turn_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		emit_turn_failure("network_error", "HTTP turn request failed with engine result %d." % result, response_code)
		return

	if response_code < 200 or response_code >= 300:
		emit_turn_failure("http_error", "Backend returned HTTP %d for the turn request." % response_code, response_code, body.get_string_from_utf8())
		return

	var raw_body := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_body)
	if not (parsed is Dictionary):
		emit_turn_failure("invalid_json", "Backend returned invalid JSON.", response_code, raw_body)
		return

	var validation := _validate_turn_payload(parsed)
	if not bool(validation.get("ok", false)):
		emit_turn_failure("schema_error", str(validation.get("message", "Turn payload validation failed.")), response_code, raw_body)
		return

	turn_succeeded.emit(parsed)


func _on_health_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_health_in_flight = false

	if result != HTTPRequest.RESULT_SUCCESS:
		_last_health_state = {
			"status": "network_error",
			"message": "Backend health check failed with engine result %d." % result,
			"ready": false
		}
		health_status_changed.emit(get_last_health_state())
		return

	if response_code < 200 or response_code >= 300:
		_last_health_state = {
			"status": "http_error",
			"message": "Backend health endpoint returned HTTP %d." % response_code,
			"ready": false,
			"raw_body": body.get_string_from_utf8()
		}
		health_status_changed.emit(get_last_health_state())
		return

	_last_health_state = {
		"status": "healthy",
		"message": "Backend health check succeeded.",
		"ready": true
	}
	health_status_changed.emit(get_last_health_state())


func _validate_turn_payload(payload: Dictionary) -> Dictionary:
	var required_sections := ["content", "direction", "state_update", "memory_hint"]
	for section_name in required_sections:
		if not (payload.get(section_name, {}) is Dictionary):
			return {
				"ok": false,
				"message": "Turn payload is missing dictionary section '%s'." % section_name
			}

	var content: Dictionary = payload["content"]
	if not _all_string_fields(content, ["narration", "dialogue", "action"]):
		return {
			"ok": false,
			"message": "Turn payload 'content' must contain string fields narration, dialogue, and action."
		}

	var direction: Dictionary = payload["direction"]
	var scene_mode := str(direction.get("scene_mode", ""))
	if scene_mode != "layered" and scene_mode != "cg":
		return {
			"ok": false,
			"message": "Turn payload 'direction.scene_mode' must be 'layered' or 'cg'."
		}

	var character_states: Variant = direction.get("character_states", [])
	if not (character_states is Array):
		return {
			"ok": false,
			"message": "Turn payload 'direction.character_states' must be an array."
		}

	for state in character_states:
		if not (state is Dictionary):
			return {
				"ok": false,
				"message": "Each item in 'direction.character_states' must be a dictionary."
			}

		var position := str(state.get("position", ""))
		if position != "left" and position != "center" and position != "right":
			return {
				"ok": false,
				"message": "Character state positions must be left, center, or right."
			}

		if str(state.get("character_id", "")).strip_edges().is_empty():
			return {
				"ok": false,
				"message": "Each character state must include a character_id."
			}

		if str(state.get("sprite_id", "")).strip_edges().is_empty():
			return {
				"ok": false,
				"message": "Each character state must include a sprite_id."
			}

	if str((payload["state_update"] as Dictionary).get("content_rating", "")).strip_edges().is_empty():
		return {
			"ok": false,
			"message": "Turn payload must include state_update.content_rating."
		}

	return {
		"ok": true
	}


func _all_string_fields(target: Dictionary, field_names: Array) -> bool:
	for field_name in field_names:
		if not (target.get(field_name, "") is String):
			return false
	return true
