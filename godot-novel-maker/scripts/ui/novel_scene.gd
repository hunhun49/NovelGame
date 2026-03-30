extends Control

@onready var background_layer: TextureRect = $BackgroundLayer
@onready var cg_layer: TextureRect = $CgLayer
@onready var left_slot: TextureRect = $CharacterLayer/LeftSlot
@onready var center_slot: TextureRect = $CharacterLayer/CenterSlot
@onready var right_slot: TextureRect = $CharacterLayer/RightSlot
@onready var scene_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/SceneLabel
@onready var backend_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/BackendLabel
@onready var location_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/LocationLabel
@onready var mode_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/ModeLabel
@onready var library_label: Label = $UiLayer/TopBar/Margin/VBox/InfoRow/LibraryLabel
@onready var render_status_label: Label = $UiLayer/TopBar/Margin/VBox/RenderStatusLabel
@onready var settings_button: Button = $UiLayer/TopBar/Margin/VBox/InfoRow/SettingsButton
@onready var narration_label: Label = $UiLayer/DialoguePanel/Margin/VBox/NarrationLabel
@onready var speaker_label: Label = $UiLayer/DialoguePanel/Margin/VBox/SpeakerLabel
@onready var dialogue_label: Label = $UiLayer/DialoguePanel/Margin/VBox/DialogueLabel
@onready var action_label: Label = $UiLayer/DialoguePanel/Margin/VBox/ActionLabel
@onready var input_edit: LineEdit = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/InputEdit
@onready var footer_status_label: Label = $UiLayer/DialoguePanel/Margin/VBox/FooterStatusLabel
@onready var generate_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/GenerateButton
@onready var quick_save_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/QuickSaveButton
@onready var menu_button: Button = $UiLayer/DialoguePanel/Margin/VBox/ControlsRow/MenuButton
@onready var settings_panel: Control = $UiLayer/SettingsPanel


func _ready() -> void:
	generate_button.pressed.connect(_on_generate_pressed)
	quick_save_button.pressed.connect(_on_quick_save_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	input_edit.text_submitted.connect(_on_input_submitted)
	settings_panel.closed.connect(_on_settings_panel_closed)
	settings_panel.settings_applied.connect(_on_settings_panel_closed)
	NarrativeDirector.render_state_changed.connect(_on_render_state_changed)
	NarrativeDirector.turn_started.connect(_on_turn_started)
	NarrativeDirector.turn_failed.connect(_on_turn_failed)
	AssetLibrary.library_loaded.connect(_on_library_loaded)
	AiClient.health_status_changed.connect(_on_backend_health_changed)
	NarrativeDirector.emit_current_render_state()


func _exit_tree() -> void:
	if NarrativeDirector.render_state_changed.is_connected(_on_render_state_changed):
		NarrativeDirector.render_state_changed.disconnect(_on_render_state_changed)

	if NarrativeDirector.turn_started.is_connected(_on_turn_started):
		NarrativeDirector.turn_started.disconnect(_on_turn_started)

	if NarrativeDirector.turn_failed.is_connected(_on_turn_failed):
		NarrativeDirector.turn_failed.disconnect(_on_turn_failed)

	if AssetLibrary.library_loaded.is_connected(_on_library_loaded):
		AssetLibrary.library_loaded.disconnect(_on_library_loaded)

	if AiClient.health_status_changed.is_connected(_on_backend_health_changed):
		AiClient.health_status_changed.disconnect(_on_backend_health_changed)


func _on_generate_pressed() -> void:
	_request_turn()


func _on_input_submitted(_submitted_text: String) -> void:
	_request_turn()


func _request_turn() -> void:
	NarrativeDirector.request_turn(input_edit.text)
	input_edit.clear()


func _on_quick_save_pressed() -> void:
	if SaveManager.quick_save():
		footer_status_label.text = "Quick save written to user://saves/quick_save.json"
	else:
		footer_status_label.text = "Quick save failed."


func _on_menu_pressed() -> void:
	SceneRouter.go_to_main_menu()


func _on_settings_pressed() -> void:
	settings_panel.open_panel()


func _on_settings_panel_closed() -> void:
	NarrativeDirector.emit_current_render_state()


func _on_turn_started() -> void:
	footer_status_label.text = "Generating a turn..."


func _on_turn_failed(error_state: Dictionary) -> void:
	footer_status_label.text = str(error_state.get("message", "Turn generation failed."))


func _on_render_state_changed(render_state: Dictionary) -> void:
	_render_snapshot(render_state)


func _on_library_loaded(_snapshot: Dictionary) -> void:
	_render_snapshot(GameState.build_render_snapshot())


func _on_backend_health_changed(_status_state: Dictionary) -> void:
	_render_snapshot(GameState.build_render_snapshot())


func _render_snapshot(render_state: Dictionary) -> void:
	var visual_state: Dictionary = render_state.get("visual_state", {})
	var content: Dictionary = render_state.get("content", {})
	var library_snapshot: Dictionary = render_state.get("library_snapshot", {})

	scene_label.text = "Scene: %s" % str(render_state.get("scene_name", "novel_scene"))
	backend_label.text = "Backend: %s" % SettingsManager.get_backend_mode()
	location_label.text = "Location: %s" % str(render_state.get("location_id", ""))
	mode_label.text = "Mode: %s" % str(visual_state.get("scene_mode", "layered"))
	library_label.text = "Library: %s" % str(library_snapshot.get("validation_status", "unconfigured"))
	render_status_label.text = str(render_state.get("status_message", AssetLibrary.get_status_line()))

	narration_label.text = str(content.get("narration", ""))
	speaker_label.text = str(content.get("speaker_name", "Narrator"))
	dialogue_label.text = str(content.get("dialogue", ""))
	action_label.text = str(content.get("action", ""))

	_render_background(str(visual_state.get("background_id", "")))
	_render_slots(visual_state.get("character_slots", {}))
	_render_cg_mode(str(visual_state.get("scene_mode", "layered")), str(visual_state.get("cg_id", "")))


func _render_background(background_id: String) -> void:
	var texture := AssetLibrary.get_background_texture(background_id)
	background_layer.texture = texture
	background_layer.visible = texture != null


func _render_slots(slot_map: Dictionary) -> void:
	_render_single_slot(left_slot, slot_map.get("left", {}))
	_render_single_slot(center_slot, slot_map.get("center", {}))
	_render_single_slot(right_slot, slot_map.get("right", {}))


func _render_single_slot(slot_node: TextureRect, slot_state: Variant) -> void:
	if not (slot_state is Dictionary):
		slot_node.texture = null
		slot_node.visible = false
		return

	var texture := AssetLibrary.get_sprite_texture(str(slot_state.get("sprite_id", "")))
	slot_node.texture = texture
	slot_node.visible = texture != null


func _render_cg_mode(scene_mode: String, cg_id: String) -> void:
	if scene_mode == "cg":
		var texture := AssetLibrary.get_cg_texture(cg_id)
		cg_layer.texture = texture
		cg_layer.visible = texture != null
		left_slot.visible = false
		center_slot.visible = false
		right_slot.visible = false
	else:
		cg_layer.texture = null
		cg_layer.visible = false

		if left_slot.texture != null:
			left_slot.visible = true
		if center_slot.texture != null:
			center_slot.visible = true
		if right_slot.texture != null:
			right_slot.visible = true
