extends Control
class_name SaveLoadPanel

signal closed
signal save_requested(slot_id: int)
signal load_requested(slot_id: int)

const SAVE_MODE := "save"
const LOAD_MODE := "load"

@onready var m_title_label: Label = $Dimmer/Panel/Margin/VBox/TitleLabel
@onready var m_slots_container: VBoxContainer = $Dimmer/Panel/Margin/VBox/SlotsScroll/SlotsContainer
@onready var m_footer_label: Label = $Dimmer/Panel/Margin/VBox/FooterLabel
@onready var m_close_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/CloseButton

var m_mode := LOAD_MODE


func _ready() -> void:
	visible = false
	m_close_button.pressed.connect(_on_close_pressed)
	audio_manager.wire_button_sounds(self)


func open_panel(panel_mode: String) -> void:
	m_mode = SAVE_MODE if panel_mode == SAVE_MODE else LOAD_MODE
	_rebuild_slots()
	m_footer_label.text = ""
	visible = true


func refresh_slots() -> void:
	if visible:
		_rebuild_slots()


func set_footer_message(message: String) -> void:
	m_footer_label.text = message


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _rebuild_slots() -> void:
	m_title_label.text = "저장 슬롯" if m_mode == SAVE_MODE else "불러오기"
	for child in m_slots_container.get_children():
		child.queue_free()

	for slot_info in save_manager.list_manual_saves():
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var button := Button.new()
		var slot_id := int(slot_info.get("slot_id", 0))
		button.text = ("%s %02d" % ["저장" if m_mode == SAVE_MODE else "불러오기", slot_id])
		button.custom_minimum_size = Vector2(100, 0)
		button.disabled = m_mode == LOAD_MODE and not bool(slot_info.get("exists", false))
		button.pressed.connect(_on_slot_pressed.bind(slot_id))

		var summary_label := Label.new()
		summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		summary_label.text = _build_slot_summary(slot_info)

		row.add_child(button)
		row.add_child(summary_label)
		m_slots_container.add_child(row)
		audio_manager.wire_button_sounds(row)


func _on_slot_pressed(slot_id: int) -> void:
	if m_mode == SAVE_MODE:
		save_requested.emit(slot_id)
	else:
		load_requested.emit(slot_id)


func _build_slot_summary(slot_info: Dictionary) -> String:
	if not bool(slot_info.get("exists", false)):
		return "비어 있는 슬롯"

	var saved_at := str(slot_info.get("saved_at", ""))
	var world_name := str(slot_info.get("world_name", "미선택"))
	var speaker := str(slot_info.get("speaker", "화자"))
	var summary := str(slot_info.get("summary", "")).strip_edges()
	if summary.is_empty():
		summary = "요약이 없습니다."

	return "저장 시간: %s\n세계관: %s\n화자: %s\n요약: %s" % [saved_at, world_name, speaker, summary]
