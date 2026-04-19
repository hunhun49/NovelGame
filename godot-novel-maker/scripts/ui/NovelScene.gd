extends Control
class_name NovelScene

@onready var m_background_layer: TextureRect = $BackgroundLayer
@onready var m_character_layer: Control = $CharacterLayer
@onready var m_cg_layer: TextureRect = $CgLayer
@onready var m_fx_layer: ColorRect = $FxLayer
@onready var m_left_slot: TextureRect = $CharacterLayer/LeftSlot
@onready var m_center_slot: TextureRect = $CharacterLayer/CenterSlot
@onready var m_right_slot: TextureRect = $CharacterLayer/RightSlot
@onready var m_vn_dialog_layer: VBoxContainer = $UiLayer/VnDialogLayer
@onready var m_scene_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/SceneLabel
@onready var m_mode_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/ModeLabel
@onready var m_menu_button: Button = $UiLayer/TopBar/Margin/VBox/InfoRow/MenuButton
@onready var m_quick_save_button: Button = $UiLayer/TopBar/Margin/VBox/InfoRow/QuickSaveButton
@onready var m_speaker_name_label: Label = $UiLayer/VnDialogLayer/SpeakerRow/SpeakerTab/SpeakerTabMargin/SpeakerName
@onready var m_dialogue_label: RichTextLabel = $UiLayer/VnDialogLayer/DialogBox/DialogMargin/DialogueLabel
@onready var m_player_input_panel: PanelContainer = $UiLayer/PlayerInputPanel
@onready var m_generate_button: Button = $UiLayer/PlayerInputPanel/PlayerInputMargin/PlayerInputHBox/GenerateButton
@onready var m_input_edit: TextEdit = $UiLayer/PlayerInputPanel/PlayerInputMargin/PlayerInputHBox/InputEdit
@onready var m_settings_panel = $UiLayer/SettingsPanel
@onready var m_save_load_panel = $UiLayer/SaveLoadPanel
@onready var m_onboarding_overlay: Control = $OverlayLayer/OnboardingOverlay
@onready var m_onboarding_title: Label = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/TitleLabel
@onready var m_onboarding_body: Label = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/BodyLabel
@onready var m_onboarding_demo_button: Button = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/Buttons/UseDemoLibraryButton
@onready var m_onboarding_demo_session_button: Button = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/Buttons/EnableDemoSessionButton
@onready var m_onboarding_settings_button: Button = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/Buttons/OpenSettingsButton
@onready var m_game_menu_overlay: Control = $OverlayLayer/GameMenuOverlay
@onready var m_game_menu_world_title: Label = $OverlayLayer/GameMenuOverlay/GameMenuPanel/GameMenuMargin/GameMenuVBox/WorldTitleLabel
@onready var m_game_menu_shade: ColorRect = $OverlayLayer/GameMenuOverlay/GameMenuShade
@onready var m_game_menu_settings_button: Button = $OverlayLayer/GameMenuOverlay/GameMenuPanel/GameMenuMargin/GameMenuVBox/GameMenuSettingsButton
@onready var m_game_menu_save_button: Button = $OverlayLayer/GameMenuOverlay/GameMenuPanel/GameMenuMargin/GameMenuVBox/GameMenuSaveButton
@onready var m_game_menu_load_button: Button = $OverlayLayer/GameMenuOverlay/GameMenuPanel/GameMenuMargin/GameMenuVBox/GameMenuLoadButton
@onready var m_game_menu_exit_button: Button = $OverlayLayer/GameMenuOverlay/GameMenuPanel/GameMenuMargin/GameMenuVBox/GameMenuExitButton

var m_turn_in_progress := false
var m_is_typing := false
var m_typing_tween: Tween = null
var m_input_expanded := false
var m_all_segments_done := false
var m_dialog_segments: Array[String] = []
var m_current_segment_index := 0
var m_current_world_name := "세계관"
var m_dot_timer := 0.0
var m_dot_count := 0
const TYPING_CHARS_PER_SEC := 30.0
const INPUT_PANEL_HIDDEN_OFFSET := 120.0
const INPUT_PANEL_COLLAPSED_OFFSET := -54.0
const INPUT_PANEL_EXPANDED_OFFSET := -160.0
const SIDE_SLOT_WIDTH_RATIO := 0.18
const CENTER_SLOT_WIDTH_RATIO := 0.24
const SLOT_TOP_RATIO := 0.08
const CENTER_SLOT_TOP_RATIO := 0.05
const SLOT_BOTTOM_MARGIN_RATIO := 0.04


func _ready() -> void:
	m_generate_button.pressed.connect(_on_generate_pressed)
	m_quick_save_button.pressed.connect(_on_quick_save_pressed)
	m_menu_button.pressed.connect(_on_menu_button_pressed)
	m_input_edit.gui_input.connect(_on_input_gui_input)
	m_input_edit.focus_entered.connect(_on_input_focus_entered)
	m_input_edit.focus_exited.connect(_on_input_focus_exited)
	m_settings_panel.closed.connect(_on_settings_panel_closed)
	m_settings_panel.settings_applied.connect(_on_settings_panel_closed)
	m_save_load_panel.closed.connect(_on_save_load_closed)
	m_save_load_panel.save_requested.connect(_on_save_requested)
	m_save_load_panel.load_requested.connect(_on_load_requested)
	m_onboarding_demo_button.pressed.connect(_on_use_demo_library_pressed)
	m_onboarding_demo_session_button.pressed.connect(_on_enable_demo_session_pressed)
	m_onboarding_settings_button.pressed.connect(_on_settings_pressed)
	m_game_menu_shade.gui_input.connect(_on_game_menu_shade_input)
	m_game_menu_settings_button.pressed.connect(_on_game_menu_settings_pressed)
	m_game_menu_save_button.pressed.connect(_on_game_menu_save_pressed)
	m_game_menu_load_button.pressed.connect(_on_game_menu_load_pressed)
	m_game_menu_exit_button.pressed.connect(_on_game_menu_exit_pressed)
	narrative_director.render_state_changed.connect(_on_render_state_changed)
	narrative_director.turn_started.connect(_on_turn_started)
	narrative_director.turn_failed.connect(_on_turn_failed)
	asset_library.library_loaded.connect(_on_library_loaded)
	ai_client.health_status_changed.connect(_on_backend_health_changed)
	m_dialogue_label.gui_input.connect(_on_dialog_box_input)
	_configure_character_slots()
	_configure_text_inputs()
	narrative_director.emit_current_render_state()
	audio_manager.wire_button_sounds(self)
	audio_manager.sync_audio_state.call_deferred(game_state.m_current_audio_state)
	ai_client.ensure_backend_warm("scene_entry")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_character_slot_layout()


func _process(delta: float) -> void:
	if m_is_typing and m_dialogue_label != null:
		_scroll_dialogue_to_bottom()
	if m_turn_in_progress:
		m_dot_timer += delta
		if m_dot_timer >= 0.4:
			m_dot_timer = 0.0
			m_dot_count = (m_dot_count % 3) + 1
			var dots := ".".repeat(m_dot_count)
			var phase := ai_client.get_request_phase()
			var base_text := "모델을 예열하고 있습니다" if phase == "warming" else "다음 턴을 생성하고 있습니다"
			m_dialogue_label.text = "[color=#c5afa5]%s%s[/color]" % [base_text, dots]
			m_dialogue_label.visible_characters = -1


func _exit_tree() -> void:
	if m_typing_tween != null and m_typing_tween.is_valid():
		m_typing_tween.kill()
	if narrative_director.render_state_changed.is_connected(_on_render_state_changed):
		narrative_director.render_state_changed.disconnect(_on_render_state_changed)
	if narrative_director.turn_started.is_connected(_on_turn_started):
		narrative_director.turn_started.disconnect(_on_turn_started)
	if narrative_director.turn_failed.is_connected(_on_turn_failed):
		narrative_director.turn_failed.disconnect(_on_turn_failed)
	if asset_library.library_loaded.is_connected(_on_library_loaded):
		asset_library.library_loaded.disconnect(_on_library_loaded)
	if ai_client.health_status_changed.is_connected(_on_backend_health_changed):
		ai_client.health_status_changed.disconnect(_on_backend_health_changed)


func _on_generate_pressed() -> void:
	_request_turn()


func _on_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	var is_enter := key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
	if is_enter and key_event.shift_pressed:
		accept_event()
		_request_turn()


func _request_turn() -> void:
	if m_generate_button.disabled:
		return
	var prompt := m_input_edit.text.strip_edges()
	if prompt.is_empty():
		return
	narrative_director.request_turn(prompt)
	m_input_edit.text = ""
	m_input_edit.release_focus()
	if m_input_expanded:
		m_input_expanded = false
		_animate_input_expand(false)


func _on_quick_save_pressed() -> void:
	save_manager.quick_save()


func _on_save_pressed() -> void:
	m_save_load_panel.open_panel("save")


func _on_load_pressed() -> void:
	m_save_load_panel.open_panel("load")


func _on_menu_pressed() -> void:
	scene_router.go_to_main_menu()


func _on_menu_button_pressed() -> void:
	_open_game_menu()


func _open_game_menu() -> void:
	m_game_menu_world_title.text = m_current_world_name
	m_game_menu_overlay.visible = true


func _close_game_menu() -> void:
	m_game_menu_overlay.visible = false


func _on_game_menu_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_game_menu()


func _on_game_menu_settings_pressed() -> void:
	_close_game_menu()
	m_settings_panel.open_panel()


func _on_game_menu_save_pressed() -> void:
	_close_game_menu()
	m_save_load_panel.open_panel("save")


func _on_game_menu_load_pressed() -> void:
	_close_game_menu()
	m_save_load_panel.open_panel("load")


func _on_game_menu_exit_pressed() -> void:
	_close_game_menu()
	scene_router.go_to_main_menu()


func _on_settings_pressed() -> void:
	m_settings_panel.open_panel()


func _on_settings_panel_closed() -> void:
	narrative_director.emit_current_render_state()


func _on_save_load_closed() -> void:
	narrative_director.emit_current_render_state()


func _on_turn_started() -> void:
	m_turn_in_progress = true
	m_all_segments_done = false
	m_dot_timer = 0.0
	m_dot_count = 0
	if m_typing_tween != null and m_typing_tween.is_valid():
		m_typing_tween.kill()
		m_typing_tween = null
	m_is_typing = false
	_slide_input_panel(false)
	m_dialogue_label.text = "[color=#c5afa5]다음 턴을 생성하고 있습니다.[/color]"
	m_dialogue_label.visible_characters = -1
	_refresh_interaction_state(game_state.build_render_snapshot())


func _on_turn_failed(error_state: Dictionary) -> void:
	m_turn_in_progress = false
	var msg := str(error_state.get("message", "턴 생성에 실패했습니다."))
	m_dialogue_label.text = "[color=#e08080]%s[/color]" % _escape_bbcode(msg)
	m_dialogue_label.visible_characters = -1
	_refresh_interaction_state(game_state.build_render_snapshot())


func _on_render_state_changed(render_state: Dictionary) -> void:
	m_turn_in_progress = false
	_render_snapshot(render_state)


func _on_library_loaded(_snapshot: Dictionary) -> void:
	_render_snapshot(game_state.build_render_snapshot())


func _on_backend_health_changed(_status_state: Dictionary) -> void:
	_render_snapshot(game_state.build_render_snapshot())


func _on_save_requested(slot_id: int) -> void:
	if save_manager.save_to_slot(slot_id):
		m_save_load_panel.set_footer_message("슬롯 %02d에 저장했습니다." % slot_id)
		m_save_load_panel.refresh_slots()
	else:
		m_save_load_panel.set_footer_message("슬롯 %02d 저장에 실패했습니다." % slot_id)


func _on_load_requested(slot_id: int) -> void:
	var payload := save_manager.load_from_slot(slot_id)
	if payload.is_empty():
		m_save_load_panel.set_footer_message("슬롯 %02d이 비어 있습니다." % slot_id)
		return

	game_state.apply_save_payload(payload)
	audio_manager.sync_audio_state(game_state.m_current_audio_state)
	m_save_load_panel.set_footer_message("슬롯 %02d을 불러왔습니다." % slot_id)
	m_save_load_panel.visible = false
	narrative_director.emit_current_render_state()


func _on_use_demo_library_pressed() -> void:
	settings_manager.apply_demo_library()
	ai_client.request_backend_health_check()


func _on_enable_demo_session_pressed() -> void:
	settings_manager.apply_demo_session()
	ai_client.request_backend_health_check()


func _render_snapshot(render_state: Dictionary) -> void:
	var visual_state: Dictionary = render_state.get("visual_state", {})
	var content: Dictionary = render_state.get("content", {})
	var library_snapshot: Dictionary = render_state.get("library_snapshot", {})
	var story_setup: Dictionary = render_state.get("story_setup", {})
	var world_name := str(story_setup.get("world_name", "미선택"))
	var location_id := str(render_state.get("location_id", ""))

	m_current_world_name = world_name
	m_scene_label.text = _truncate_text(world_name, 22)
	m_scene_label.tooltip_text = world_name
	m_mode_label.text = _format_info_label("위치", location_id, 16)
	m_mode_label.tooltip_text = location_id

	var speaker := _normalize_story_text(str(content.get("speaker_name", "")))
	m_speaker_name_label.text = speaker if not speaker.is_empty() else "화자"
	_load_dialog_segments(content)

	audio_manager.sync_audio_state(render_state.get("audio_state", {}))
	_render_background(str(visual_state.get("background_id", "")), str(visual_state.get("transition", "fade")))
	_render_slots(visual_state.get("character_slots", {}))
	_render_cg_mode(str(visual_state.get("scene_mode", "layered")), str(visual_state.get("cg_id", "")), str(visual_state.get("transition", "fade")))
	_apply_camera_fx(str(visual_state.get("camera_fx", "none")))
	_refresh_onboarding_overlay(library_snapshot)
	_refresh_interaction_state(render_state)
	_refresh_onboarding_overlay(library_snapshot)
	_refresh_interaction_state(render_state)


func _build_story_script_bbcode(content: Dictionary) -> String:
	var narration := _normalize_story_text(str(content.get("narration", "")))
	var speaker_name := _normalize_story_text(str(content.get("speaker_name", "화자")))
	var dialogue := _sanitize_dialogue_text(str(content.get("dialogue", "")), speaker_name)
	var action := _normalize_story_text(str(content.get("action", "")))
	var blocks: Array[String] = []

	if speaker_name.is_empty():
		speaker_name = "화자"

	if not narration.is_empty():
		blocks.append("[color=#d8c4bc][i]*%s*[/i][/color]" % _escape_bbcode(narration))
	if not dialogue.is_empty():
		blocks.append("[color=#fff2ea][b]대사 : %s[/b] | \"%s\"[/color]" % [_escape_bbcode(speaker_name), _escape_bbcode(dialogue)])
	if not action.is_empty():
		blocks.append("[color=#c6afa5][i]*%s*[/i][/color]" % _escape_bbcode(action))

	if blocks.is_empty():
		return "[color=#c5afa5][i]*장면 생성 결과가 아직 없습니다.*[/i][/color]"
	return "\n\n".join(blocks)


func _build_dialog_segments(content: Dictionary) -> Array[String]:
	var narration := _normalize_story_text(str(content.get("narration", "")))
	var speaker_name := _normalize_story_text(str(content.get("speaker_name", "화자")))
	var dialogue := _sanitize_dialogue_text(str(content.get("dialogue", "")), speaker_name)
	var action := _normalize_story_text(str(content.get("action", "")))
	if speaker_name.is_empty():
		speaker_name = "화자"

	var segments: Array[String] = []

	for sentence in _split_into_sentences(narration):
		segments.append("[color=#d8c4bc][i]*%s*[/i][/color]" % _escape_bbcode(sentence))
	for sentence in _split_into_sentences(dialogue):
		segments.append("[color=#fff2ea]\"%s\"[/color]" % _escape_bbcode(sentence))
	for sentence in _split_into_sentences(action):
		segments.append("[color=#c6afa5][i]*%s*[/i][/color]" % _escape_bbcode(sentence))

	if segments.is_empty():
		segments.append("[color=#c5afa5][i]*장면 생성 결과가 아직 없습니다.*[/i][/color]")
	return segments


func _split_into_sentences(text: String) -> Array[String]:
	var result: Array[String] = []
	if text.is_empty():
		return result

	# 종결 구두점(. ! ? … 。 ！ ？) + 닫는 따옴표/괄호 뒤에서 분리
	var regex := RegEx.new()
	regex.compile(r'([^.!?…。！？]*[.!?…。！？]+["\'」』）\)]*)\s*')
	var search_start := 0
	for match_result in regex.search_all(text):
		var seg := match_result.get_string().strip_edges()
		if not seg.is_empty():
			result.append(seg)
		search_start = match_result.get_end()

	# 종결 부호 없는 나머지(마지막 문장)
	var remainder := text.substr(search_start).strip_edges()
	if not remainder.is_empty():
		result.append(remainder)

	# 분리 결과 없으면 원본 그대로
	if result.is_empty():
		result.append(text)
	return result


func _load_dialog_segments(content: Dictionary) -> void:
	if m_typing_tween != null and m_typing_tween.is_valid():
		m_typing_tween.kill()
		m_typing_tween = null
	m_is_typing = false
	m_all_segments_done = false
	m_input_expanded = false
	_slide_input_panel(false)
	m_dialog_segments = _build_dialog_segments(content)
	m_current_segment_index = 0
	_show_current_segment()


func _show_current_segment() -> void:
	if m_dialog_segments.is_empty():
		return
	var seg := m_dialog_segments[m_current_segment_index]
	_start_typing_effect(seg)


func _on_dialog_box_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if m_is_typing:
		_skip_typing()
	else:
		_advance_segment()


func _normalize_story_text(value: String) -> String:
	var collapsed := value.strip_edges().replace("\n", " ").replace("\r", " ").replace("\t", " ")
	var normalized := " ".join(collapsed.split(" ", false))
	if normalized.begins_with("*") and normalized.ends_with("*") and normalized.length() >= 2:
		normalized = normalized.substr(1, normalized.length() - 2).strip_edges()
	return normalized


func _strip_wrapping_quotes(value: String) -> String:
	var trimmed := _normalize_story_text(value)
	var quote_pairs := [
		{"open": "\"", "close": "\""},
		{"open": "“", "close": "”"},
		{"open": "'", "close": "'"},
	]
	var changed := true
	while changed and trimmed.length() >= 2:
		changed = false
		for pair in quote_pairs:
			var opening := str(pair.get("open", ""))
			var closing := str(pair.get("close", ""))
			if trimmed.begins_with(opening) and trimmed.ends_with(closing):
				trimmed = trimmed.substr(opening.length(), trimmed.length() - opening.length() - closing.length()).strip_edges()
				changed = true
				break
	for quote_char in ["\"", "'", "“", "”", "‘", "’", "「", "」", "『", "』"]:
		trimmed = trimmed.trim_prefix(quote_char).trim_suffix(quote_char)
	return trimmed.strip_edges()


func _normalize_dialogue_prefix_token(value: String) -> String:
	var normalized := value.strip_edges().replace(" ", "").to_lower()
	for quote_char in ["\"", "'", "“", "”", "‘", "’", "「", "」", "『", "』"]:
		normalized = normalized.trim_prefix(quote_char).trim_suffix(quote_char)
	return normalized


func _is_compact_hangul_text(value: String) -> bool:
	var compact := value.replace(" ", "")
	if compact.is_empty():
		return false
	for index in range(compact.length()):
		var code_point := compact.unicode_at(index)
		if code_point < 0xAC00 or code_point > 0xD7A3:
			return false
	return true


func _build_dialogue_speaker_aliases(speaker_name: String) -> Array[String]:
	var aliases: Array[String] = []
	var normalized_speaker := _normalize_dialogue_prefix_token(speaker_name)
	if normalized_speaker.length() >= 2:
		aliases.append(normalized_speaker)

	for token in speaker_name.split(" ", false):
		var normalized_token := _normalize_dialogue_prefix_token(token)
		if normalized_token.length() >= 2 and not aliases.has(normalized_token):
			aliases.append(normalized_token)

	if normalized_speaker.length() >= 3 and _is_compact_hangul_text(normalized_speaker):
		var short_name := normalized_speaker.substr(1)
		var tail_name := normalized_speaker.substr(normalized_speaker.length() - 2)
		if short_name.length() >= 2 and not aliases.has(short_name):
			aliases.append(short_name)
		if tail_name.length() >= 2 and not aliases.has(tail_name):
			aliases.append(tail_name)

	return aliases


func _sanitize_dialogue_text(value: String, speaker_name: String) -> String:
	var cleaned := _normalize_story_text(value)
	if cleaned.is_empty():
		return cleaned

	for prefix in ["대사 : %s" % speaker_name, "대사:%s" % speaker_name, "%s :" % speaker_name, "%s:" % speaker_name, "대사 :", "대사:", "화자 :", "화자:"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
			break
	while cleaned.begins_with(":") or cleaned.begins_with("|"):
		cleaned = cleaned.substr(1).strip_edges()

	var colon_index := cleaned.find(":")
	if colon_index != -1:
		var possible_colon_prefix := cleaned.substr(0, colon_index).strip_edges()
		if _is_dialogue_metadata_prefix(possible_colon_prefix, speaker_name):
			cleaned = cleaned.substr(colon_index + 1).strip_edges()

	var pipe_index := cleaned.find("|")
	if pipe_index != -1:
		var possible_prefix := cleaned.substr(0, pipe_index).strip_edges().replace(" ", "")
		var possible_dialogue := cleaned.substr(pipe_index + 1).strip_edges()
		if _is_dialogue_metadata_prefix(possible_prefix, speaker_name):
			cleaned = possible_dialogue
			while cleaned.begins_with(":") or cleaned.begins_with("|"):
				cleaned = cleaned.substr(1).strip_edges()

	return _strip_wrapping_quotes(cleaned)


func _is_dialogue_metadata_prefix(prefix: String, speaker_name: String) -> bool:
	var normalized_prefix := _normalize_dialogue_prefix_token(prefix)
	var speaker_aliases := _build_dialogue_speaker_aliases(speaker_name)
	var prefix_without_colon := normalized_prefix
	if prefix_without_colon.ends_with(":"):
		prefix_without_colon = prefix_without_colon.substr(0, prefix_without_colon.length() - 1)
	var prefix_parts := prefix_without_colon.split(":", false)

	if normalized_prefix in ["대사", "대사:", "화자", "화자:"]:
		return true
	for alias in speaker_aliases:
		if normalized_prefix in [alias, "%s:" % alias, "대사:%s" % alias]:
			return true
	for part in prefix_parts:
		if part in ["대사", "화자"] or speaker_aliases.has(part):
			return true
		if _looks_like_internal_dialogue_prefix(part):
			return true
	return _looks_like_internal_dialogue_prefix(prefix_without_colon)


func _looks_like_internal_dialogue_prefix(value: String) -> bool:
	var normalized := value.strip_edges().replace(" ", "").to_lower()
	if normalized.is_empty():
		return false
	if normalized.length() < 3 or normalized.length() > 64:
		return false
	if not normalized.contains("_") and not normalized.contains("-"):
		return false

	for index in range(normalized.length()):
		var code_point := normalized.unicode_at(index)
		var is_lowercase := code_point >= 97 and code_point <= 122
		var is_digit := code_point >= 48 and code_point <= 57
		var is_separator := code_point == 95 or code_point == 45
		if not (is_lowercase or is_digit or is_separator):
			return false

	return true


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _format_info_label(prefix: String, value: String, max_length: int) -> String:
	return "%s: %s" % [prefix, _truncate_text(value, max_length)]


func _truncate_text(value: String, max_length: int) -> String:
	var clean_value := value.strip_edges()
	if clean_value.length() <= max_length:
		return clean_value
	if max_length <= 1:
		return clean_value.left(max_length)
	return "%s…" % clean_value.left(max_length - 1)


func _render_background(background_id: String, transition: String) -> void:
	var texture := asset_library.get_background_texture(background_id)
	_apply_texture_transition(m_background_layer, texture, transition)


func _render_slots(slot_map: Dictionary) -> void:
	_render_single_slot(m_left_slot, slot_map.get("left", {}))
	_render_single_slot(m_center_slot, slot_map.get("center", {}))
	_render_single_slot(m_right_slot, slot_map.get("right", {}))


func _render_single_slot(slot_node: TextureRect, slot_state: Variant) -> void:
	if not (slot_state is Dictionary):
		slot_node.texture = null
		slot_node.visible = false
		return

	var image_path := str(slot_state.get("image_path", "")).strip_edges()
	var texture := asset_library.get_texture_from_path(image_path) if not image_path.is_empty() else asset_library.get_sprite_texture(str(slot_state.get("sprite_id", "")))
	if texture == null:
		texture = _get_character_profile_texture(str(slot_state.get("character_id", "")))
	slot_node.texture = texture
	slot_node.visible = m_character_layer.visible and texture != null


func _configure_character_slots() -> void:
	if m_left_slot == null or m_center_slot == null or m_right_slot == null:
		return
	for slot_node in [m_left_slot, m_center_slot, m_right_slot]:
		slot_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_update_character_slot_layout()


func _update_character_slot_layout() -> void:
	if m_left_slot == null or m_center_slot == null or m_right_slot == null:
		return
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var side_width := clampf(viewport_size.x * SIDE_SLOT_WIDTH_RATIO, 180.0, 320.0)
	var center_width := clampf(viewport_size.x * CENTER_SLOT_WIDTH_RATIO, 240.0, 440.0)
	var side_margin := clampf(viewport_size.x * 0.035, 24.0, 72.0)
	var top_margin := viewport_size.y * SLOT_TOP_RATIO
	var center_top_margin := viewport_size.y * CENTER_SLOT_TOP_RATIO
	var bottom_margin := clampf(viewport_size.y * SLOT_BOTTOM_MARGIN_RATIO, 12.0, 60.0)

	m_left_slot.anchor_left = 0.0
	m_left_slot.anchor_right = 0.0
	m_left_slot.anchor_top = 0.0
	m_left_slot.anchor_bottom = 1.0
	m_left_slot.offset_left = side_margin
	m_left_slot.offset_right = side_margin + side_width
	m_left_slot.offset_top = top_margin
	m_left_slot.offset_bottom = -bottom_margin

	m_center_slot.anchor_left = 0.5
	m_center_slot.anchor_right = 0.5
	m_center_slot.anchor_top = 0.0
	m_center_slot.anchor_bottom = 1.0
	m_center_slot.offset_left = -center_width * 0.5
	m_center_slot.offset_right = center_width * 0.5
	m_center_slot.offset_top = center_top_margin
	m_center_slot.offset_bottom = -bottom_margin

	m_right_slot.anchor_left = 1.0
	m_right_slot.anchor_right = 1.0
	m_right_slot.anchor_top = 0.0
	m_right_slot.anchor_bottom = 1.0
	m_right_slot.offset_left = -(side_margin + side_width)
	m_right_slot.offset_right = -side_margin
	m_right_slot.offset_top = top_margin
	m_right_slot.offset_bottom = -bottom_margin


func _get_character_profile_texture(character_id: String) -> Texture2D:
	var profile := _get_character_profile(character_id)
	if profile.is_empty():
		return null
	return asset_library.get_character_thumbnail_texture(profile)


func _get_character_profile(character_id: String) -> Dictionary:
	var clean_id := character_id.strip_edges()
	if clean_id.is_empty():
		return {}
	if clean_id == str(game_state.m_selected_player_character_id):
		return game_state.m_selected_player_character_profile.duplicate(true)
	for profile in game_state.m_selected_main_character_profiles:
		if str((profile as Dictionary).get("id", "")).strip_edges() == clean_id:
			return (profile as Dictionary).duplicate(true)
	return story_profile_store.get_character_by_id(clean_id)


func _render_cg_mode(scene_mode: String, cg_id: String, transition: String) -> void:
	m_character_layer.visible = scene_mode != "cg"

	if scene_mode == "cg":
		var texture := asset_library.get_cg_texture(cg_id)
		_apply_texture_transition(m_cg_layer, texture, transition)
		m_left_slot.visible = false
		m_center_slot.visible = false
		m_right_slot.visible = false
	else:
		m_cg_layer.texture = null
		m_cg_layer.visible = false
		m_left_slot.visible = m_left_slot.texture != null
		m_center_slot.visible = m_center_slot.texture != null
		m_right_slot.visible = m_right_slot.texture != null


func _apply_texture_transition(target: TextureRect, texture: Texture2D, transition: String) -> void:
	if texture == null:
		target.texture = null
		target.visible = false
		target.modulate.a = 1.0
		return

	match transition:
		"cut":
			target.texture = texture
			target.visible = true
			target.modulate.a = 1.0
		"crossfade":
			if target.visible and target.texture != null and target.texture != texture:
				var tween := create_tween()
				tween.tween_property(target, "modulate:a", 0.0, 0.12)
				tween.tween_callback(Callable(self, "_set_texture_state").bind(target, texture, true))
				tween.tween_property(target, "modulate:a", 1.0, 0.18)
			else:
				target.texture = texture
				target.visible = true
				target.modulate.a = 0.0
				create_tween().tween_property(target, "modulate:a", 1.0, 0.2)
		_:
			target.texture = texture
			target.visible = true
			target.modulate.a = 0.0
			create_tween().tween_property(target, "modulate:a", 1.0, 0.18)


func _set_texture_state(target: TextureRect, texture: Texture2D, should_show: bool) -> void:
	target.texture = texture
	target.visible = should_show and texture != null


func _apply_camera_fx(camera_fx: String) -> void:
	var target_alpha := 0.22 if camera_fx == "dim" else 0.0
	var target_color := Color(0, 0, 0, target_alpha)
	create_tween().tween_property(m_fx_layer, "color", target_color, 0.18)


func _refresh_onboarding_overlay(library_snapshot: Dictionary) -> void:
	var library_status := str(library_snapshot.get("validation_status", "unconfigured"))
	m_onboarding_overlay.visible = library_status != "valid"

	match library_status:
		"invalid":
			m_onboarding_title.text = "라이브러리 검증 실패"
			m_onboarding_body.text = "%s\n\n데모 라이브러리를 쓰거나, 다른 폴더를 고르거나, stub 기반 데모 세션을 켜세요." % "\n".join(asset_library.get_validation_messages())
		_:
			m_onboarding_title.text = "자산 라이브러리를 먼저 준비하세요"
			m_onboarding_body.text = "이 장면은 유효한 이미지/오디오 라이브러리가 있어야 턴을 생성할 수 있습니다.\n\n1. 데모 라이브러리 사용\n2. 외부 폴더 선택\n3. 데모 세션으로 stub 모드 강제"


func _configure_text_inputs() -> void:
	_set_optional_property(m_input_edit, "wrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	_set_optional_property(m_input_edit, "fit_content_height", false)
	_set_optional_property(m_input_edit, "placeholder_text", "클릭하여 입력하세요... (Shift+Enter로 전송)")


func _set_optional_property(target: Object, property_name: String, value: Variant) -> void:
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return


func _scroll_story_to_bottom() -> void:
	pass


func _apply_story_scroll() -> void:
	pass


func _scroll_dialogue_to_bottom() -> void:
	var sb := m_dialogue_label.get_v_scroll_bar()
	if sb != null:
		sb.value = sb.max_value


func _start_typing_effect(full_text: String) -> void:
	if m_typing_tween != null and m_typing_tween.is_valid():
		m_typing_tween.kill()
		m_typing_tween = null

	m_dialogue_label.text = full_text
	m_dialogue_label.visible_characters = 0
	var total_chars := m_dialogue_label.get_total_character_count()
	if total_chars <= 0:
		m_is_typing = false
		_refresh_interaction_state(game_state.build_render_snapshot())
		return

	m_is_typing = true
	_refresh_interaction_state(game_state.build_render_snapshot())
	audio_manager.play_sfx("dialogue_text_next")
	var duration := maxf(float(total_chars) / TYPING_CHARS_PER_SEC, 0.1)
	m_typing_tween = create_tween()
	m_typing_tween.tween_property(m_dialogue_label, "visible_characters", total_chars, duration).set_trans(Tween.TRANS_LINEAR)
	m_typing_tween.tween_callback(_on_typing_finished)


func _skip_typing() -> void:
	if m_typing_tween != null and m_typing_tween.is_valid():
		m_typing_tween.kill()
		m_typing_tween = null
	m_is_typing = false
	m_dialogue_label.visible_characters = -1
	_scroll_dialogue_to_bottom()
	_check_all_segments_done()
	_refresh_interaction_state(game_state.build_render_snapshot())


func _advance_segment() -> void:
	var next_index := m_current_segment_index + 1
	if next_index >= m_dialog_segments.size():
		return
	m_current_segment_index = next_index
	_show_current_segment()


func _on_typing_finished() -> void:
	m_is_typing = false
	m_dialogue_label.visible_characters = -1
	_scroll_dialogue_to_bottom()
	_check_all_segments_done()
	_refresh_interaction_state(game_state.build_render_snapshot())


func _check_all_segments_done() -> void:
	if m_current_segment_index >= m_dialog_segments.size() - 1:
		if not m_all_segments_done:
			m_all_segments_done = true
			_slide_input_panel(true)


func _slide_input_panel(visible_state: bool) -> void:
	var target_offset := INPUT_PANEL_COLLAPSED_OFFSET if visible_state else INPUT_PANEL_HIDDEN_OFFSET
	create_tween() \
		.tween_property(m_player_input_panel, "offset_top", target_offset, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_input_focus_entered() -> void:
	if not m_all_segments_done:
		m_input_edit.release_focus()
		return
	if not m_input_expanded:
		m_input_expanded = true
		_animate_input_expand(true)


func _on_input_focus_exited() -> void:
	pass


func _input(event: InputEvent) -> void:
	# 입력 패널이 펼쳐진 상태에서 패널 영역 밖을 클릭하면 접는다.
	if not m_input_expanded:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var click_pos := mouse_event.position
	var panel_rect := m_player_input_panel.get_global_rect()
	if not panel_rect.has_point(click_pos):
		m_input_edit.release_focus()
		m_input_expanded = false
		_animate_input_expand(false)


func _animate_input_expand(expanded: bool) -> void:
	var target_offset := INPUT_PANEL_EXPANDED_OFFSET if expanded else INPUT_PANEL_COLLAPSED_OFFSET
	create_tween().tween_property(m_player_input_panel, "offset_top", target_offset, 0.15)


func _refresh_interaction_state(render_state: Dictionary) -> void:
	var library_snapshot: Dictionary = render_state.get("library_snapshot", {})
	var library_ready := str(library_snapshot.get("validation_status", "unconfigured")) == "valid"
	var backend_ready := settings_manager.uses_stub_backend() or ai_client.is_backend_ready()
	var can_generate := library_ready and backend_ready and not m_turn_in_progress and m_all_segments_done

	m_input_edit.editable = can_generate
	m_input_edit.mouse_filter = Control.MOUSE_FILTER_STOP
	m_generate_button.disabled = not can_generate
	m_quick_save_button.disabled = m_turn_in_progress
