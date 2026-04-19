extends Control
class_name WorldEditorPanel

signal closed

@onready var m_title_label: Label = $Dimmer/Panel/Margin/VBox/TitleLabel
@onready var m_status_label: Label = $Dimmer/Panel/Margin/VBox/StatusLabel
@onready var m_world_list: ItemList = $Dimmer/Panel/Margin/VBox/Body/LeftColumn/WorldList
@onready var m_new_button: Button = $Dimmer/Panel/Margin/VBox/Body/LeftColumn/LeftButtons/NewButton
@onready var m_delete_button: Button = $Dimmer/Panel/Margin/VBox/Body/LeftColumn/LeftButtons/DeleteButton
@onready var m_id_edit: LineEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/IdEdit
@onready var m_name_edit: LineEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/NameEdit
@onready var m_summary_edit: TextEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/SummaryEdit
@onready var m_genre_edit: LineEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/GenreEdit
@onready var m_tone_edit: LineEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/ToneEdit
@onready var m_premise_edit: TextEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/PremiseEdit
@onready var m_rules_edit: LineEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/RulesEdit
@onready var m_places_edit: LineEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/PlacesEdit
@onready var m_rating_option: OptionButton = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/RatingOption
@onready var m_notes_edit: TextEdit = $Dimmer/Panel/Margin/VBox/Body/RightColumn/Scroll/FormVBox/NotesEdit
@onready var m_save_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/SaveButton
@onready var m_close_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/CloseButton

const RATING_LABELS := {
	"general": "일반",
	"mature": "성인",
	"adult": "청불",
	"extreme": "강수위"
}

var m_selected_world_id := ""
var m_is_new_record := true


func _ready() -> void:
	visible = false
	m_title_label.text = "세계관 만들기"
	for m_text_edit in [m_summary_edit, m_premise_edit, m_notes_edit]:
		_configure_wrapping_text_edit(m_text_edit)
	_populate_rating_options()
	m_world_list.item_selected.connect(_on_world_selected)
	m_new_button.pressed.connect(_on_new_pressed)
	m_delete_button.pressed.connect(_on_delete_pressed)
	m_save_button.pressed.connect(_on_save_pressed)
	m_close_button.pressed.connect(_on_close_pressed)
	story_profile_store.worlds_changed.connect(_on_worlds_changed)
	_refresh_world_list()
	_load_world(story_profile_store.build_empty_world(), true)
	audio_manager.wire_button_sounds(self)


func open_panel() -> void:
	visible = true
	_refresh_world_list()
	if m_selected_world_id.is_empty():
		var worlds := story_profile_store.get_worlds()
		if not worlds.is_empty():
			_select_world_by_id(str((worlds[0] as Dictionary).get("id", "")))
		else:
			_load_world(story_profile_store.build_empty_world(), true)


func _configure_wrapping_text_edit(p_text_edit: TextEdit) -> void:
	_set_optional_property(p_text_edit, "wrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	_set_optional_property(p_text_edit, "fit_content_height", false)


func _set_optional_property(p_target: Object, p_property_name: String, p_value: Variant) -> void:
	for m_property_info in p_target.get_property_list():
		if str(m_property_info.get("name", "")) == p_property_name:
			p_target.set(p_property_name, p_value)
			return


func _populate_rating_options() -> void:
	m_rating_option.clear()
	for rating_id in ["general", "mature", "adult", "extreme"]:
		m_rating_option.add_item(RATING_LABELS.get(rating_id, rating_id))
		m_rating_option.set_item_metadata(m_rating_option.item_count - 1, rating_id)


func _refresh_world_list() -> void:
	var previous_id := m_selected_world_id
	m_world_list.clear()
	for world in story_profile_store.get_worlds():
		var world_dict := world as Dictionary
		m_world_list.add_item(str(world_dict.get("name_ko", world_dict.get("id", ""))))
		m_world_list.set_item_metadata(m_world_list.item_count - 1, str(world_dict.get("id", "")))

	if not previous_id.is_empty():
		_select_world_by_id(previous_id)

	m_delete_button.disabled = m_selected_world_id.is_empty()


func _on_world_selected(index: int) -> void:
	var world_id := str(m_world_list.get_item_metadata(index))
	var world := story_profile_store.get_world_by_id(world_id)
	if world.is_empty():
		return
	_load_world(world, false)


func _on_new_pressed() -> void:
	m_status_label.text = "새 세계관 정보를 입력하세요."
	_load_world(story_profile_store.build_empty_world(), true)


func _on_delete_pressed() -> void:
	if m_selected_world_id.is_empty():
		return

	if story_profile_store.delete_world(m_selected_world_id):
		m_status_label.text = "세계관을 삭제했습니다."
		m_selected_world_id = ""
		var worlds := story_profile_store.get_worlds()
		if worlds.is_empty():
			_load_world(story_profile_store.build_empty_world(), true)
		else:
			_select_world_by_id(str((worlds[0] as Dictionary).get("id", "")))
	else:
		m_status_label.text = "세계관을 삭제하지 못했습니다."


func _on_save_pressed() -> void:
	var result := story_profile_store.save_world(_collect_form_data(), m_selected_world_id if not m_is_new_record else "")
	m_status_label.text = str(result.get("message", "세계관 저장 결과를 확인할 수 없습니다."))
	if bool(result.get("ok", false)):
		m_selected_world_id = str(result.get("id", ""))
		m_is_new_record = false
		_refresh_world_list()
		_select_world_by_id(m_selected_world_id)


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_worlds_changed(_worlds: Array) -> void:
	_refresh_world_list()


func _load_world(world: Dictionary, is_new_record: bool) -> void:
	m_selected_world_id = "" if is_new_record else str(world.get("id", ""))
	m_is_new_record = is_new_record
	m_id_edit.text = str(world.get("id", ""))
	m_name_edit.text = str(world.get("name_ko", ""))
	m_summary_edit.text = str(world.get("summary", ""))
	m_genre_edit.text = str(world.get("genre", ""))
	m_tone_edit.text = str(world.get("tone", ""))
	m_premise_edit.text = str(world.get("premise", ""))
	m_rules_edit.text = ", ".join(world.get("core_rules", []))
	m_places_edit.text = ", ".join(world.get("notable_places", []))
	_select_rating(str(world.get("default_rating_lane", "general")))
	m_notes_edit.text = str(world.get("notes", ""))
	m_delete_button.disabled = is_new_record


func _collect_form_data() -> Dictionary:
	return {
		"id": m_id_edit.text.strip_edges(),
		"name_ko": m_name_edit.text.strip_edges(),
		"summary": m_summary_edit.text.strip_edges(),
		"genre": m_genre_edit.text.strip_edges(),
		"tone": m_tone_edit.text.strip_edges(),
		"premise": m_premise_edit.text.strip_edges(),
		"core_rules": _parse_csv(m_rules_edit.text),
		"notable_places": _parse_csv(m_places_edit.text),
		"default_rating_lane": str(m_rating_option.get_item_metadata(m_rating_option.selected)),
		"notes": m_notes_edit.text.strip_edges()
	}


func _parse_csv(raw_text: String) -> Array:
	var values: Array = []
	for chunk in raw_text.split(",", false):
		var clean_chunk := chunk.strip_edges()
		if not clean_chunk.is_empty() and not values.has(clean_chunk):
			values.append(clean_chunk)
	return values


func _select_world_by_id(world_id: String) -> void:
	for index in range(m_world_list.item_count):
		if str(m_world_list.get_item_metadata(index)) == world_id:
			m_world_list.select(index)
			var world := story_profile_store.get_world_by_id(world_id)
			if not world.is_empty():
				_load_world(world, false)
			return


func _select_rating(rating_id: String) -> void:
	for index in range(m_rating_option.item_count):
		if str(m_rating_option.get_item_metadata(index)) == rating_id:
			m_rating_option.select(index)
			return
	m_rating_option.select(0)
