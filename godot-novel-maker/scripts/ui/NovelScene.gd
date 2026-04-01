extends Control
class_name NovelScene

@onready var m_background_layer: TextureRect = $BackgroundLayer
@onready var m_character_layer: Control = $CharacterLayer
@onready var m_cg_layer: TextureRect = $CgLayer
@onready var m_fx_layer: ColorRect = $FxLayer
@onready var m_left_slot: TextureRect = $CharacterLayer/LeftSlot
@onready var m_center_slot: TextureRect = $CharacterLayer/CenterSlot
@onready var m_right_slot: TextureRect = $CharacterLayer/RightSlot
@onready var m_scene_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/SceneLabel
@onready var m_backend_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/BackendLabel
@onready var m_location_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/LocationLabel
@onready var m_mode_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/ModeLabel
@onready var m_library_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/LibraryLabel
@onready var m_render_status_label: Label = $UiLayer/TopBar/Margin/VBox/RenderStatusLabel
@onready var m_settings_button: Button = $UiLayer/TopBar/Margin/VBox/InfoRow/SettingsButton
@onready var m_story_scroll: ScrollContainer = $UiLayer/DialoguePanel/Margin/VBox/StoryScroll
@onready var m_narration_label: Label = $UiLayer/DialoguePanel/Margin/VBox/StoryScroll/StoryVBox/NarrationLabel
@onready var m_speaker_label: Label = $UiLayer/DialoguePanel/Margin/VBox/StoryScroll/StoryVBox/SpeakerLabel
@onready var m_dialogue_label: Label = $UiLayer/DialoguePanel/Margin/VBox/StoryScroll/StoryVBox/DialogueLabel
@onready var m_action_label: Label = $UiLayer/DialoguePanel/Margin/VBox/StoryScroll/StoryVBox/ActionLabel
@onready var m_input_edit: TextEdit = $UiLayer/DialoguePanel/Margin/VBox/InputEdit
@onready var m_footer_status_label: Label = $UiLayer/DialoguePanel/Margin/VBox/FooterStatusLabel
@onready var m_generate_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/GenerateButton
@onready var m_quick_save_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/QuickSaveButton
@onready var m_save_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/SaveButton
@onready var m_load_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/LoadButton
@onready var m_rollback_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/RollbackButton
@onready var m_menu_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/MenuButton
@onready var m_settings_panel = $UiLayer/SettingsPanel
@onready var m_save_load_panel = $UiLayer/SaveLoadPanel
@onready var m_onboarding_overlay: Control = $OverlayLayer/OnboardingOverlay
@onready var m_onboarding_title: Label = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/TitleLabel
@onready var m_onboarding_body: Label = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/BodyLabel
@onready var m_onboarding_demo_button: Button = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/Buttons/UseDemoLibraryButton
@onready var m_onboarding_demo_session_button: Button = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/Buttons/EnableDemoSessionButton
@onready var m_onboarding_settings_button: Button = $OverlayLayer/OnboardingOverlay/Panel/Margin/VBox/Buttons/OpenSettingsButton

var m_turn_in_progress := false


func _ready() -> void:
	m_generate_button.pressed.connect(_on_generate_pressed)
	m_quick_save_button.pressed.connect(_on_quick_save_pressed)
	m_save_button.pressed.connect(_on_save_pressed)
	m_load_button.pressed.connect(_on_load_pressed)
	m_rollback_button.pressed.connect(_on_rollback_pressed)
	m_menu_button.pressed.connect(_on_menu_pressed)
	m_settings_button.pressed.connect(_on_settings_pressed)
	m_input_edit.gui_input.connect(_on_input_gui_input)
	m_settings_panel.closed.connect(_on_settings_panel_closed)
	m_settings_panel.settings_applied.connect(_on_settings_panel_closed)
	m_save_load_panel.closed.connect(_on_save_load_closed)
	m_save_load_panel.save_requested.connect(_on_save_requested)
	m_save_load_panel.load_requested.connect(_on_load_requested)
	m_onboarding_demo_button.pressed.connect(_on_use_demo_library_pressed)
	m_onboarding_demo_session_button.pressed.connect(_on_enable_demo_session_pressed)
	m_onboarding_settings_button.pressed.connect(_on_settings_pressed)
	narrative_director.render_state_changed.connect(_on_render_state_changed)
	narrative_director.turn_started.connect(_on_turn_started)
	narrative_director.turn_failed.connect(_on_turn_failed)
	asset_library.library_loaded.connect(_on_library_loaded)
	ai_client.health_status_changed.connect(_on_backend_health_changed)
	_configure_text_inputs()
	narrative_director.emit_current_render_state()


func _exit_tree() -> void:
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

	var is_submit_key := key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER
	if is_submit_key and key_event.ctrl_pressed:
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


func _on_quick_save_pressed() -> void:
	if save_manager.quick_save():
		m_footer_status_label.text = "빠른 저장을 업데이트했습니다."
	else:
		m_footer_status_label.text = "빠른 저장에 실패했습니다."


func _on_save_pressed() -> void:
	m_save_load_panel.open_panel("save")


func _on_load_pressed() -> void:
	m_save_load_panel.open_panel("load")


func _on_rollback_pressed() -> void:
	if game_state.rollback_to_previous_snapshot():
		audio_manager.sync_audio_state(game_state.m_current_audio_state)
		m_footer_status_label.text = "직전 턴으로 되돌렸습니다."
		narrative_director.emit_current_render_state()
	else:
		m_footer_status_label.text = "되돌릴 수 있는 이전 턴이 없습니다."


func _on_menu_pressed() -> void:
	scene_router.go_to_main_menu()


func _on_settings_pressed() -> void:
	m_settings_panel.open_panel()


func _on_settings_panel_closed() -> void:
	narrative_director.emit_current_render_state()


func _on_save_load_closed() -> void:
	narrative_director.emit_current_render_state()


func _on_turn_started() -> void:
	m_turn_in_progress = true
	m_footer_status_label.text = "다음 턴을 생성하고 있습니다..."
	_refresh_interaction_state(game_state.build_render_snapshot())


func _on_turn_failed(error_state: Dictionary) -> void:
	m_turn_in_progress = false
	m_footer_status_label.text = str(error_state.get("message", "턴 생성에 실패했습니다."))
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
	m_footer_status_label.text = "슬롯 %02d을 불러왔습니다." % slot_id
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
	var library_status := str(library_snapshot.get("validation_status", "unconfigured"))
	var world_name := str(story_setup.get("world_name", "미선택"))
	var cast_names: Array = story_setup.get("main_character_names", [])
	var lead_cast := "미선택" if cast_names.is_empty() else ", ".join(cast_names)
	var location_id := str(render_state.get("location_id", ""))
	var status_message := str(render_state.get("status_message", asset_library.get_status_line()))

	m_scene_label.text = _format_info_label("세계관", world_name, 20)
	m_backend_label.text = _format_info_label("모델", ai_client.get_active_backend_summary(), 24)
	m_location_label.text = _format_info_label("주연", lead_cast, 16)
	m_mode_label.text = _format_info_label("위치", location_id, 18)
	m_library_label.text = _format_info_label("라이브러리", library_status, 10)
	m_render_status_label.text = _truncate_text(status_message, 84)
	m_scene_label.tooltip_text = world_name
	m_backend_label.tooltip_text = ai_client.get_active_backend_summary()
	m_location_label.tooltip_text = lead_cast
	m_mode_label.tooltip_text = location_id
	m_library_label.tooltip_text = library_status
	m_render_status_label.tooltip_text = status_message

	m_narration_label.text = str(content.get("narration", ""))
	m_speaker_label.text = str(content.get("speaker_name", "화자"))
	m_dialogue_label.text = str(content.get("dialogue", ""))
	m_action_label.text = str(content.get("action", ""))
	_scroll_story_to_bottom()

	audio_manager.sync_audio_state(render_state.get("audio_state", {}))
	_render_background(str(visual_state.get("background_id", "")), str(visual_state.get("transition", "fade")))
	_render_slots(visual_state.get("character_slots", {}))
	_render_cg_mode(str(visual_state.get("scene_mode", "layered")), str(visual_state.get("cg_id", "")), str(visual_state.get("transition", "fade")))
	_apply_camera_fx(str(visual_state.get("camera_fx", "none")))
	_refresh_onboarding_overlay(library_snapshot)
	_refresh_interaction_state(render_state)


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
	slot_node.texture = texture
	slot_node.visible = m_character_layer.visible and texture != null


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
	_set_optional_property(m_input_edit, "placeholder_text", "다음 장면에 대한 행동이나 대사를 입력하세요...\nCtrl+Enter로 전송")


func _set_optional_property(target: Object, property_name: String, value: Variant) -> void:
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			target.set(property_name, value)
			return


func _scroll_story_to_bottom() -> void:
	call_deferred("_apply_story_scroll")


func _apply_story_scroll() -> void:
	if m_story_scroll == null:
		return
	var scroll_bar := m_story_scroll.get_v_scroll_bar()
	if scroll_bar == null:
		return
	m_story_scroll.scroll_vertical = int(scroll_bar.max_value)


func _refresh_interaction_state(render_state: Dictionary) -> void:
	var library_snapshot: Dictionary = render_state.get("library_snapshot", {})
	var library_ready := str(library_snapshot.get("validation_status", "unconfigured")) == "valid"
	var backend_ready := settings_manager.uses_stub_backend() or ai_client.is_backend_ready()
	var can_generate := library_ready and backend_ready and not m_turn_in_progress

	m_input_edit.editable = can_generate
	m_generate_button.disabled = not can_generate
	m_rollback_button.disabled = not bool(render_state.get("can_rollback", false)) or m_turn_in_progress
	m_load_button.disabled = not save_manager.has_any_manual_saves()
	m_save_button.disabled = m_turn_in_progress
	m_quick_save_button.disabled = m_turn_in_progress

	if not library_ready:
		m_footer_status_label.text = "먼저 유효한 라이브러리를 불러온 뒤 턴을 생성하세요."
	elif not backend_ready:
		m_footer_status_label.text = "stub 모드를 켜거나 백엔드 연결을 확인한 뒤 턴을 생성하세요."
	elif not m_turn_in_progress and m_footer_status_label.text.is_empty():
		m_footer_status_label.text = "다음 장면에 대한 입력을 적고 생성 버튼을 눌러 주세요."
