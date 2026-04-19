extends Control
class_name CharacterEditorPanel

signal closed

const CHARACTER_NAME_MAX_LENGTH := 30
const SUMMARY_MAX_LENGTH := 30
const APPEARANCE_MAX_LENGTH := 200
const EVENT_SITUATION_MAX_LENGTH := 50
const MAX_SUB_PERSONALITIES := 3
const MAX_SPEECH_EXAMPLES := 5
const MAX_EVENT_IMAGES := 8
const CHARACTER_IMAGE_DIR := "user://content/character_images"
const CHARACTER_IMAGE_TARGET_WIDTH := 600
const CHARACTER_IMAGE_TARGET_HEIGHT := 1500

const TAB_PROFILE := 0
const TAB_PERSONALITY := 1
const TAB_APPEARANCE := 2

const IMAGE_TARGET_THUMBNAIL := "thumbnail"
const IMAGE_TARGET_EMOTION := "emotion"
const IMAGE_TARGET_EVENT := "event"

const EMOTION_KEYS := ["neutral", "joy", "sad", "angry"]
const EMOTION_LABELS := {
	"neutral": "일반",
	"joy": "기쁨",
	"sad": "슬픔",
	"angry": "화남"
}
const PERSONALITY_OPTIONS := [
	"차분함",
	"냉철함",
	"다정함",
	"열정적",
	"장난기",
	"당당함",
	"섬세함",
	"집요함",
	"지적임",
	"직진형",
	"비관적",
	"보호본능",
	"직설적",
	"내향적",
	"외향적",
	"카리스마",
	"신중함",
	"반항적"
]

@onready var m_title_label: Label = $Dimmer/Panel/Margin/Root/Header/HeaderText/TitleLabel
@onready var m_status_label: Label = $Dimmer/Panel/Margin/Root/Header/HeaderText/StatusLabel
@onready var m_character_list: ItemList = $Dimmer/Panel/Margin/Root/ContentScroll/Content/LeftColumn/CharacterList
@onready var m_new_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/NewButton
@onready var m_save_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/SaveButton
@onready var m_delete_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/DeleteButton
@onready var m_close_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/CloseButton
@onready var m_tab_container: TabContainer = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer

@onready var m_thumbnail_rect: TextureRect = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ThumbnailSection/ThumbnailRow/ThumbnailFrame/ThumbnailRect
@onready var m_thumbnail_path_label: Label = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ThumbnailSection/ThumbnailRow/ThumbnailInfo/ThumbnailPathLabel
@onready var m_thumbnail_upload_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ThumbnailSection/ThumbnailRow/ThumbnailInfo/ThumbnailButtons/UploadButton
@onready var m_thumbnail_delete_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ThumbnailSection/ThumbnailRow/ThumbnailInfo/ThumbnailButtons/DeleteButton
@onready var m_name_edit: LineEdit = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/NameSection/NameEdit
@onready var m_name_count_label: Label = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/NameSection/NameCountLabel
@onready var m_summary_edit: LineEdit = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/SummarySection/SummaryEdit
@onready var m_summary_count_label: Label = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/SummarySection/SummaryCountLabel

@onready var m_main_personality_option: OptionButton = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/PersonalityTab/PersonalityScroll/PersonalityVBox/MainPersonalitySection/MainPersonalityOption
@onready var m_sub_personality_list: VBoxContainer = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/PersonalityTab/PersonalityScroll/PersonalityVBox/SubPersonalitySection/SubPersonalityList
@onready var m_add_sub_personality_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/PersonalityTab/PersonalityScroll/PersonalityVBox/SubPersonalitySection/SubHeader/AddSubPersonalityButton
@onready var m_speech_example_list: VBoxContainer = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/PersonalityTab/PersonalityScroll/PersonalityVBox/SpeechExampleSection/SpeechExampleList
@onready var m_add_speech_example_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/PersonalityTab/PersonalityScroll/PersonalityVBox/SpeechExampleSection/SpeechHeader/AddSpeechExampleButton

@onready var m_appearance_edit: TextEdit = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/AppearanceTab/AppearanceScroll/AppearanceVBox/AppearanceSection/AppearanceEdit
@onready var m_appearance_count_label: Label = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/AppearanceTab/AppearanceScroll/AppearanceVBox/AppearanceSection/AppearanceCountLabel
@onready var m_event_image_list: VBoxContainer = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/AppearanceTab/AppearanceScroll/AppearanceVBox/EventImageSection/EventImageList
@onready var m_add_event_image_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/AppearanceTab/AppearanceScroll/AppearanceVBox/EventImageSection/EventHeader/AddEventImageButton

@onready var m_file_dialog: FileDialog = $FileDialog
@onready var m_image_cropper_popup: ImageCropperPopup = $ImageCropperPopup

var m_selected_character_id := ""
var m_is_new_record := true
var m_loaded_character_snapshot: Dictionary = {}
var m_thumbnail_path := ""
var m_emotion_image_paths: Dictionary = {}
var m_sub_personality_rows: Array = []
var m_speech_example_rows: Array = []
var m_event_image_rows: Array = []
var m_external_image_cache: Dictionary = {}
var m_pending_image_target := ""
var m_pending_emotion_key := ""
var m_pending_event_row: Dictionary = {}


func _ready() -> void:
	visible = false
	m_title_label.text = "인물 만들기"
	m_status_label.text = "주요 등장인물을 만들고 저장할 수 있습니다."
	m_tab_container.set_tab_title(TAB_PROFILE, "프로필")
	m_tab_container.set_tab_title(TAB_PERSONALITY, "성격")
	m_tab_container.set_tab_title(TAB_APPEARANCE, "외형")
	m_name_edit.max_length = CHARACTER_NAME_MAX_LENGTH
	m_summary_edit.max_length = SUMMARY_MAX_LENGTH
	_configure_wrapping_text_edit(m_appearance_edit)
	_configure_file_dialog()
	_populate_personality_option(m_main_personality_option, false)
	_setup_emotion_widgets()

	m_character_list.item_selected.connect(_on_character_selected)
	m_new_button.pressed.connect(_on_new_pressed)
	m_save_button.pressed.connect(_on_save_pressed)
	m_delete_button.pressed.connect(_on_delete_pressed)
	m_close_button.pressed.connect(_on_close_pressed)
	m_thumbnail_upload_button.pressed.connect(func() -> void:
		_open_image_picker(IMAGE_TARGET_THUMBNAIL)
	)
	m_thumbnail_delete_button.pressed.connect(_on_thumbnail_delete_pressed)
	m_add_sub_personality_button.pressed.connect(_on_add_sub_personality_pressed)
	m_add_speech_example_button.pressed.connect(_on_add_speech_example_pressed)
	m_add_event_image_button.pressed.connect(_on_add_event_image_pressed)
	m_name_edit.text_changed.connect(_on_form_changed)
	m_summary_edit.text_changed.connect(_on_form_changed)
	m_main_personality_option.item_selected.connect(_on_form_changed)
	m_appearance_edit.text_changed.connect(_on_form_changed)
	m_file_dialog.file_selected.connect(_on_image_file_selected)
	m_image_cropper_popup.crop_applied.connect(_on_image_cropped)
	m_image_cropper_popup.closed.connect(_on_cropper_closed)
	story_profile_store.characters_changed.connect(_on_characters_changed)

	_refresh_character_list()
	_load_character(story_profile_store.build_empty_character(), true)
	audio_manager.wire_button_sounds(self)


func open_panel() -> void:
	visible = true
	_refresh_character_list()
	if m_selected_character_id.is_empty():
		var m_characters := story_profile_store.get_characters()
		if m_characters.is_empty():
			_load_character(story_profile_store.build_empty_character(), true)
		else:
			_select_character_by_id(str((m_characters[0] as Dictionary).get("id", "")))
	_update_count_labels()


func _configure_file_dialog() -> void:
	m_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	m_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	m_file_dialog.title = "이미지 선택"
	m_file_dialog.filters = PackedStringArray([
		"*.png ; PNG 이미지",
		"*.jpg, *.jpeg ; JPEG 이미지",
		"*.webp ; WEBP 이미지"
	])


func _configure_wrapping_text_edit(p_text_edit: TextEdit) -> void:
	_set_optional_property(p_text_edit, "wrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	_set_optional_property(p_text_edit, "fit_content_height", false)


func _set_optional_property(p_target: Object, p_property_name: String, p_value: Variant) -> void:
	for m_property_info in p_target.get_property_list():
		if str(m_property_info.get("name", "")) == p_property_name:
			p_target.set(p_property_name, p_value)
			return


func _setup_emotion_widgets() -> void:
	m_emotion_image_paths = {}
	for m_emotion_key in EMOTION_KEYS:
		m_emotion_image_paths[m_emotion_key] = ""
		var m_emotion_block := _get_emotion_block(m_emotion_key)
		var m_upload_button: Button = m_emotion_block.get_node("Buttons/UploadButton")
		var emotion_delete_button: Button = m_emotion_block.get_node("Buttons/DeleteButton")
		m_upload_button.pressed.connect(func() -> void:
			_open_image_picker(IMAGE_TARGET_EMOTION, m_emotion_key)
		)
		emotion_delete_button.pressed.connect(func() -> void:
			_on_emotion_delete_pressed(m_emotion_key)
		)


func _refresh_character_list() -> void:
	var m_previous_id := m_selected_character_id
	m_character_list.clear()
	for m_character in story_profile_store.get_characters():
		var m_profile := m_character as Dictionary
		var m_character_id := str(m_profile.get("id", ""))
		m_character_list.add_item(str(m_profile.get("name_ko", m_character_id)))
		m_character_list.set_item_metadata(m_character_list.item_count - 1, m_character_id)

	if not m_previous_id.is_empty():
		_select_character_by_id(m_previous_id)

	m_delete_button.disabled = m_selected_character_id.is_empty()


func _load_character(p_character_profile: Dictionary, p_is_new_record: bool) -> void:
	m_is_new_record = p_is_new_record
	m_selected_character_id = "" if p_is_new_record else str(p_character_profile.get("id", ""))
	m_loaded_character_snapshot = p_character_profile.duplicate(true) if not p_character_profile.is_empty() else story_profile_store.build_empty_character()
	m_thumbnail_path = str(p_character_profile.get("thumbnail_path", "")).strip_edges()
	m_name_edit.text = str(p_character_profile.get("name_ko", ""))
	m_summary_edit.text = str(p_character_profile.get("summary", ""))
	m_appearance_edit.text = str(p_character_profile.get("appearance", ""))
	_set_option_to_value(m_main_personality_option, str(p_character_profile.get("main_personality", "")))
	_load_emotion_paths(p_character_profile.get("emotion_images", {}))
	_rebuild_sub_personality_rows(p_character_profile.get("sub_personalities", []))
	_rebuild_speech_example_rows(p_character_profile.get("speech_examples", []))
	_rebuild_event_image_rows(p_character_profile.get("event_images", []))
	_update_thumbnail_widgets()
	_update_emotion_widgets()
	_update_count_labels()
	_refresh_dynamic_limits()
	m_delete_button.disabled = p_is_new_record
	m_tab_container.current_tab = TAB_PROFILE
	m_status_label.text = "인물 정보를 입력하거나 수정해 주세요."


func _load_emotion_paths(p_raw_emotion_images: Variant) -> void:
	m_emotion_image_paths = {}
	var m_emotion_images: Dictionary = p_raw_emotion_images if p_raw_emotion_images is Dictionary else {}
	for m_emotion_key in EMOTION_KEYS:
		m_emotion_image_paths[m_emotion_key] = str(m_emotion_images.get(m_emotion_key, "")).strip_edges()


func _rebuild_sub_personality_rows(p_raw_values: Variant) -> void:
	_clear_container_children(m_sub_personality_list)
	m_sub_personality_rows = []
	for m_value in (p_raw_values if p_raw_values is Array else []):
		_add_sub_personality_row(str(m_value))


func _rebuild_speech_example_rows(p_raw_values: Variant) -> void:
	_clear_container_children(m_speech_example_list)
	m_speech_example_rows = []
	for m_value in (p_raw_values if p_raw_values is Array else []):
		_add_speech_example_row(str(m_value))


func _rebuild_event_image_rows(p_raw_values: Variant) -> void:
	_clear_container_children(m_event_image_list)
	m_event_image_rows = []
	for m_value in (p_raw_values if p_raw_values is Array else []):
		if m_value is Dictionary:
			_add_event_image_row((m_value as Dictionary).duplicate(true))


func _add_sub_personality_row(p_initial_value: String = "") -> void:
	if m_sub_personality_rows.size() >= MAX_SUB_PERSONALITIES:
		return

	var m_row := HBoxContainer.new()
	m_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_row.add_theme_constant_override("separation", 8)

	var m_option_button := OptionButton.new()
	m_option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_personality_option(m_option_button, true)
	_set_option_to_value(m_option_button, p_initial_value)
	m_option_button.item_selected.connect(_on_form_changed)
	m_row.add_child(m_option_button)

	var m_remove_button := Button.new()
	m_remove_button.text = "삭제"
	m_remove_button.pressed.connect(func() -> void:
		_remove_sub_personality_row(m_row)
	)
	m_row.add_child(m_remove_button)

	m_sub_personality_list.add_child(m_row)
	m_sub_personality_rows.append({
		"row": m_row,
		"option": m_option_button
	})
	_refresh_dynamic_limits()


func _add_speech_example_row(p_initial_value: String = "") -> void:
	if m_speech_example_rows.size() >= MAX_SPEECH_EXAMPLES:
		return

	var m_row := HBoxContainer.new()
	m_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_row.add_theme_constant_override("separation", 8)

	var m_example_edit := LineEdit.new()
	m_example_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_example_edit.placeholder_text = "말투 예시를 입력해 주세요."
	m_example_edit.text = p_initial_value
	m_example_edit.text_changed.connect(_on_form_changed)
	m_row.add_child(m_example_edit)

	var m_remove_button := Button.new()
	m_remove_button.text = "삭제"
	m_remove_button.pressed.connect(func() -> void:
		_remove_speech_example_row(m_row)
	)
	m_row.add_child(m_remove_button)

	m_speech_example_list.add_child(m_row)
	m_speech_example_rows.append({
		"row": m_row,
		"edit": m_example_edit
	})
	_refresh_dynamic_limits()


func _add_event_image_row(p_initial_value: Dictionary = {}) -> void:
	if m_event_image_rows.size() >= MAX_EVENT_IMAGES:
		return

	var m_panel := PanelContainer.new()
	m_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_event_image_list.add_child(m_panel)

	var m_margin := MarginContainer.new()
	m_margin.add_theme_constant_override("margin_left", 12)
	m_margin.add_theme_constant_override("margin_top", 12)
	m_margin.add_theme_constant_override("margin_right", 12)
	m_margin.add_theme_constant_override("margin_bottom", 12)
	m_panel.add_child(m_margin)

	var m_root := VBoxContainer.new()
	m_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_root.add_theme_constant_override("separation", 10)
	m_margin.add_child(m_root)

	var event_title_label := Label.new()
	event_title_label.text = "이벤트 이미지"
	m_root.add_child(event_title_label)

	var m_content_row := HBoxContainer.new()
	m_content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_content_row.add_theme_constant_override("separation", 12)
	m_root.add_child(m_content_row)

	var m_preview_rect := TextureRect.new()
	m_preview_rect.custom_minimum_size = Vector2(96, 240)
	m_preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m_preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m_content_row.add_child(m_preview_rect)

	var m_info_column := VBoxContainer.new()
	m_info_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_info_column.add_theme_constant_override("separation", 6)
	m_content_row.add_child(m_info_column)

	var m_situation_label := Label.new()
	m_situation_label.text = "상황 설명"
	m_info_column.add_child(m_situation_label)

	var m_situation_edit := LineEdit.new()
	m_situation_edit.max_length = EVENT_SITUATION_MAX_LENGTH
	m_situation_edit.placeholder_text = "어떤 상황에서 이 이미지를 보여줄지 입력해 주세요."
	m_situation_edit.text = str(p_initial_value.get("situation", ""))
	m_situation_edit.text_changed.connect(_on_form_changed)
	m_info_column.add_child(m_situation_edit)

	var m_count_label := Label.new()
	m_info_column.add_child(m_count_label)

	var m_path_label := Label.new()
	m_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_info_column.add_child(m_path_label)

	var m_buttons := HBoxContainer.new()
	m_buttons.add_theme_constant_override("separation", 8)
	m_info_column.add_child(m_buttons)

	var m_upload_button := Button.new()
	m_upload_button.text = "이미지 업로드"
	m_buttons.add_child(m_upload_button)

	var event_delete_button := Button.new()
	event_delete_button.text = "이미지 삭제"
	m_buttons.add_child(event_delete_button)

	var m_remove_button := Button.new()
	m_remove_button.text = "행 삭제"
	m_buttons.add_child(m_remove_button)

	var m_row_data := {
		"panel": m_panel,
		"preview": m_preview_rect,
		"path_label": m_path_label,
		"situation_edit": m_situation_edit,
		"count_label": m_count_label,
		"image_path": str(p_initial_value.get("image_path", "")).strip_edges()
	}

	m_upload_button.pressed.connect(func() -> void:
		_open_image_picker(IMAGE_TARGET_EVENT, "", m_row_data)
	)
	event_delete_button.pressed.connect(func() -> void:
		m_row_data["image_path"] = ""
		_update_event_row_widgets(m_row_data)
		_on_form_changed()
	)
	m_remove_button.pressed.connect(func() -> void:
		_remove_event_image_row(m_panel)
	)

	m_event_image_rows.append(m_row_data)
	_update_event_row_widgets(m_row_data)
	_refresh_dynamic_limits()


func _remove_sub_personality_row(p_row: Control) -> void:
	_remove_row_reference(m_sub_personality_rows, p_row)
	p_row.queue_free()
	_refresh_dynamic_limits()
	_on_form_changed()


func _remove_speech_example_row(p_row: Control) -> void:
	_remove_row_reference(m_speech_example_rows, p_row)
	p_row.queue_free()
	_refresh_dynamic_limits()
	_on_form_changed()


func _remove_event_image_row(p_panel: Control) -> void:
	_remove_row_reference(m_event_image_rows, p_panel, "panel")
	p_panel.queue_free()
	_refresh_dynamic_limits()
	_on_form_changed()


func _remove_row_reference(p_row_refs: Array, p_row_node: Control, p_key_name: String = "row") -> void:
	for m_index in range(p_row_refs.size() - 1, -1, -1):
		var m_row_ref := p_row_refs[m_index] as Dictionary
		if m_row_ref.get(p_key_name) == p_row_node:
			p_row_refs.remove_at(m_index)
			return


func _clear_container_children(p_container: Control) -> void:
	while p_container.get_child_count() > 0:
		var m_child := p_container.get_child(0)
		p_container.remove_child(m_child)
		m_child.queue_free()


func _refresh_dynamic_limits() -> void:
	m_add_sub_personality_button.disabled = m_sub_personality_rows.size() >= MAX_SUB_PERSONALITIES
	m_add_speech_example_button.disabled = m_speech_example_rows.size() >= MAX_SPEECH_EXAMPLES
	m_add_event_image_button.disabled = m_event_image_rows.size() >= MAX_EVENT_IMAGES


func _populate_personality_option(p_option_button: OptionButton, p_allow_empty: bool) -> void:
	p_option_button.clear()
	if p_allow_empty:
		p_option_button.add_item("선택 안 함")
		p_option_button.set_item_metadata(0, "")
	for m_personality_name in PERSONALITY_OPTIONS:
		p_option_button.add_item(m_personality_name)
		p_option_button.set_item_metadata(p_option_button.item_count - 1, m_personality_name)


func _set_option_to_value(p_option_button: OptionButton, p_value: String) -> void:
	var m_clean_value := p_value.strip_edges()
	for m_index in range(p_option_button.item_count):
		if str(p_option_button.get_item_metadata(m_index)) == m_clean_value:
			p_option_button.select(m_index)
			return
	p_option_button.select(0)


func _get_option_value(p_option_button: OptionButton) -> String:
	var m_selected_index := p_option_button.selected
	if m_selected_index < 0:
		return ""
	return str(p_option_button.get_item_metadata(m_selected_index)).strip_edges()


func _get_sub_personality_values() -> Array:
	var m_values: Array = []
	for m_row_ref in m_sub_personality_rows:
		var m_option_button: OptionButton = m_row_ref.get("option")
		var m_value := _get_option_value(m_option_button)
		if not m_value.is_empty() and not m_values.has(m_value):
			m_values.append(m_value)
	return m_values


func _get_speech_examples() -> Array:
	var m_examples: Array = []
	for m_row_ref in m_speech_example_rows:
		var m_example_edit: LineEdit = m_row_ref.get("edit")
		var m_example_text := m_example_edit.text.strip_edges()
		if not m_example_text.is_empty():
			m_examples.append(m_example_text)
	return m_examples


func _get_event_images() -> Array:
	var m_event_images: Array = []
	for m_row_ref in m_event_image_rows:
		var m_image_path := str(m_row_ref.get("image_path", "")).strip_edges()
		var m_situation_edit: LineEdit = m_row_ref.get("situation_edit")
		var m_situation_text := m_situation_edit.text.strip_edges()
		if m_image_path.is_empty() and m_situation_text.is_empty():
			continue
		m_event_images.append({
			"image_path": m_image_path,
			"situation": m_situation_text
		})
	return m_event_images


func _update_thumbnail_widgets() -> void:
	m_thumbnail_rect.texture = _load_external_texture(m_thumbnail_path)
	m_thumbnail_path_label.text = m_thumbnail_path.get_file() if not m_thumbnail_path.is_empty() else "등록된 썸네일이 없습니다."
	m_thumbnail_delete_button.disabled = m_thumbnail_path.is_empty()


func _update_emotion_widgets() -> void:
	for m_emotion_key in EMOTION_KEYS:
		var m_emotion_block := _get_emotion_block(m_emotion_key)
		var m_texture_rect: TextureRect = m_emotion_block.get_node("PreviewFrame/EmotionRect")
		var m_path_label: Label = m_emotion_block.get_node("PathLabel")
		var emotion_refresh_delete_button: Button = m_emotion_block.get_node("Buttons/DeleteButton")
		var m_image_path := str(m_emotion_image_paths.get(m_emotion_key, "")).strip_edges()
		m_texture_rect.texture = _load_external_texture(m_image_path)
		m_path_label.text = m_image_path.get_file() if not m_image_path.is_empty() else "등록된 이미지가 없습니다."
		emotion_refresh_delete_button.disabled = m_image_path.is_empty()


func _update_event_row_widgets(p_row_data: Dictionary) -> void:
	var m_image_path := str(p_row_data.get("image_path", "")).strip_edges()
	var m_preview_rect: TextureRect = p_row_data.get("preview")
	var m_path_label: Label = p_row_data.get("path_label")
	var m_count_label: Label = p_row_data.get("count_label")
	var m_situation_edit: LineEdit = p_row_data.get("situation_edit")
	m_preview_rect.texture = _load_external_texture(m_image_path)
	m_path_label.text = m_image_path.get_file() if not m_image_path.is_empty() else "등록된 이미지가 없습니다."
	m_count_label.text = "%d/%d" % [m_situation_edit.text.length(), EVENT_SITUATION_MAX_LENGTH]


func _update_count_labels() -> void:
	m_name_count_label.text = "%d/%d" % [m_name_edit.text.length(), CHARACTER_NAME_MAX_LENGTH]
	m_summary_count_label.text = "%d/%d" % [m_summary_edit.text.length(), SUMMARY_MAX_LENGTH]
	m_appearance_count_label.text = "%d/%d" % [m_appearance_edit.text.length(), APPEARANCE_MAX_LENGTH]
	for m_row_ref in m_event_image_rows:
		_update_event_row_widgets(m_row_ref)


func _validate_form() -> Dictionary:
	var m_character_name := m_name_edit.text.strip_edges()
	var m_summary := m_summary_edit.text.strip_edges()
	var m_main_personality := _get_option_value(m_main_personality_option)
	var m_appearance := m_appearance_edit.text.strip_edges()
	var m_sub_personalities := _get_sub_personality_values()
	var m_event_images := _get_event_images()

	if m_character_name.is_empty() or m_character_name.length() > CHARACTER_NAME_MAX_LENGTH:
		m_tab_container.current_tab = TAB_PROFILE
		return {"ok": false, "message": "이름은 1자 이상 30자 이하로 입력해 주세요."}

	if m_summary.length() > SUMMARY_MAX_LENGTH:
		m_tab_container.current_tab = TAB_PROFILE
		return {"ok": false, "message": "한 줄 소개는 30자 이내로 입력해 주세요."}

	if m_thumbnail_path.is_empty():
		m_tab_container.current_tab = TAB_PROFILE
		return {"ok": false, "message": "썸네일 이미지를 등록해 주세요."}

	if m_main_personality.is_empty():
		m_tab_container.current_tab = TAB_PERSONALITY
		return {"ok": false, "message": "메인 성격은 필수입니다."}

	if m_sub_personalities.has(m_main_personality):
		m_tab_container.current_tab = TAB_PERSONALITY
		return {"ok": false, "message": "서브 성격에는 메인 성격과 같은 값을 넣을 수 없습니다."}

	if m_appearance.length() > APPEARANCE_MAX_LENGTH:
		m_tab_container.current_tab = TAB_APPEARANCE
		return {"ok": false, "message": "외형 설명은 200자 이내로 입력해 주세요."}

	for m_emotion_key in EMOTION_KEYS:
		if str(m_emotion_image_paths.get(m_emotion_key, "")).strip_edges().is_empty():
			m_tab_container.current_tab = TAB_APPEARANCE
			return {"ok": false, "message": "%s 감정 이미지는 필수입니다." % EMOTION_LABELS.get(m_emotion_key, m_emotion_key)}

	for m_event_image in m_event_images:
		var m_image_path := str((m_event_image as Dictionary).get("image_path", "")).strip_edges()
		var m_situation := str((m_event_image as Dictionary).get("situation", "")).strip_edges()
		if m_image_path.is_empty():
			m_tab_container.current_tab = TAB_APPEARANCE
			return {"ok": false, "message": "이벤트 이미지를 추가했다면 이미지 파일도 등록해 주세요."}
		if m_situation.is_empty():
			m_tab_container.current_tab = TAB_APPEARANCE
			return {"ok": false, "message": "이벤트 이미지 설명을 입력해 주세요."}
		if m_situation.length() > EVENT_SITUATION_MAX_LENGTH:
			m_tab_container.current_tab = TAB_APPEARANCE
			return {"ok": false, "message": "이벤트 상황 설명은 50자 이내로 입력해 주세요."}

	return {"ok": true}


func _collect_form_data() -> Dictionary:
	var m_data := m_loaded_character_snapshot.duplicate(true)
	if m_data.is_empty():
		m_data = story_profile_store.build_empty_character()

	var m_character_name := m_name_edit.text.strip_edges()
	var m_suggested_id := _build_suggested_id(m_character_name)
	var m_sub_personalities := _get_sub_personality_values()
	var m_main_personality := _get_option_value(m_main_personality_option)
	var m_personality_tags: Array = []
	if not m_main_personality.is_empty():
		m_personality_tags.append(m_main_personality)
	for m_sub_personality in m_sub_personalities:
		if not m_personality_tags.has(m_sub_personality):
			m_personality_tags.append(m_sub_personality)

	m_data["id"] = m_selected_character_id if not m_is_new_record and not m_selected_character_id.is_empty() else m_suggested_id
	m_data["name_ko"] = m_character_name
	m_data["summary"] = m_summary_edit.text.strip_edges()
	m_data["thumbnail_path"] = m_thumbnail_path
	m_data["main_personality"] = m_main_personality
	m_data["sub_personalities"] = m_sub_personalities
	m_data["speech_examples"] = _get_speech_examples()
	m_data["appearance"] = m_appearance_edit.text.strip_edges()
	m_data["emotion_images"] = m_emotion_image_paths.duplicate(true)
	m_data["event_images"] = _get_event_images()
	m_data["personality_tags"] = m_personality_tags
	m_data["role"] = "메인 캐릭터"
	m_data["speech_style"] = ""
	if not (m_data["speech_examples"] as Array).is_empty():
		m_data["speech_style"] = str((m_data["speech_examples"] as Array)[0])
	m_data["goal"] = str(m_data.get("goal", "")).strip_edges()
	var m_preferred_sprite_ids: Variant = m_data.get("preferred_sprite_ids", [])
	m_data["preferred_sprite_ids"] = m_preferred_sprite_ids.duplicate(true) if m_preferred_sprite_ids is Array else []
	m_data["notes"] = str(m_data.get("notes", "")).strip_edges()
	return m_data


func _build_suggested_id(p_character_name: String) -> String:
	var m_base_name := p_character_name.strip_edges().to_lower()
	var m_builder := ""
	for m_index in range(m_base_name.length()):
		var m_code := m_base_name.unicode_at(m_index)
		var m_allowed_ascii := (m_code >= 48 and m_code <= 57) or (m_code >= 97 and m_code <= 122)
		if m_allowed_ascii:
			m_builder += char(m_code)
		elif m_code == 32 or m_code == 45 or m_code == 95:
			m_builder += "_"

	while m_builder.contains("__"):
		m_builder = m_builder.replace("__", "_")

	m_builder = m_builder.strip_edges()
	if m_builder.is_empty():
		m_builder = "character_%d" % int(Time.get_unix_time_from_system())
	return m_builder


func _open_image_picker(p_target_type: String, p_emotion_key: String = "", p_event_row: Dictionary = {}) -> void:
	m_pending_image_target = p_target_type
	m_pending_emotion_key = p_emotion_key
	m_pending_event_row = p_event_row
	m_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	m_file_dialog.popup_centered_ratio(0.72)


func _on_image_file_selected(p_path: String) -> void:
	if not FileAccess.file_exists(p_path):
		m_status_label.text = "선택한 이미지 파일을 찾을 수 없습니다."
		return

	var m_image := Image.load_from_file(p_path)
	if m_image == null or m_image.is_empty():
		m_status_label.text = "이미지를 불러오지 못했습니다."
		return

	m_image_cropper_popup.open_with_image(m_image, p_path, CHARACTER_IMAGE_TARGET_WIDTH, CHARACTER_IMAGE_TARGET_HEIGHT)
	m_status_label.text = "드래그와 줌으로 영역을 맞춘 뒤 적용해 주세요."


func _on_image_cropped(p_cropped_image: Image) -> void:
	var m_image_path := _save_cropped_image(p_cropped_image)
	if m_image_path.is_empty():
		m_status_label.text = "이미지를 저장하지 못했습니다."
		return

	match m_pending_image_target:
		IMAGE_TARGET_THUMBNAIL:
			m_thumbnail_path = m_image_path
			_update_thumbnail_widgets()
			m_tab_container.current_tab = TAB_PROFILE
			m_status_label.text = "썸네일 이미지를 등록했습니다."
		IMAGE_TARGET_EMOTION:
			if not m_pending_emotion_key.is_empty():
				m_emotion_image_paths[m_pending_emotion_key] = m_image_path
				_update_emotion_widgets()
				m_tab_container.current_tab = TAB_APPEARANCE
				m_status_label.text = "%s 감정 이미지를 등록했습니다." % EMOTION_LABELS.get(m_pending_emotion_key, m_pending_emotion_key)
		IMAGE_TARGET_EVENT:
			if not m_pending_event_row.is_empty():
				m_pending_event_row["image_path"] = m_image_path
				_update_event_row_widgets(m_pending_event_row)
				m_tab_container.current_tab = TAB_APPEARANCE
				m_status_label.text = "이벤트 이미지를 등록했습니다."

	m_pending_image_target = ""
	m_pending_emotion_key = ""
	m_pending_event_row = {}
	_on_form_changed()


func _save_cropped_image(p_cropped_image: Image) -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHARACTER_IMAGE_DIR))
	var m_base_id := m_selected_character_id if not m_selected_character_id.is_empty() else _build_suggested_id(m_name_edit.text)
	var m_file_suffix := "image"
	match m_pending_image_target:
		IMAGE_TARGET_THUMBNAIL:
			m_file_suffix = "thumbnail"
		IMAGE_TARGET_EMOTION:
			m_file_suffix = "emotion_%s" % m_pending_emotion_key
		IMAGE_TARGET_EVENT:
			m_file_suffix = "event_%d" % int(Time.get_unix_time_from_system())
		_:
			m_file_suffix = "image"

	var m_output_path := "%s/%s_%s_%d.png" % [CHARACTER_IMAGE_DIR, m_base_id, m_file_suffix, int(Time.get_unix_time_from_system())]
	if p_cropped_image.save_png(m_output_path) != OK:
		return ""
	m_external_image_cache.erase(m_output_path)
	return m_output_path


func _on_thumbnail_delete_pressed() -> void:
	m_thumbnail_path = ""
	_update_thumbnail_widgets()
	_on_form_changed()


func _on_emotion_delete_pressed(p_emotion_key: String) -> void:
	m_emotion_image_paths[p_emotion_key] = ""
	_update_emotion_widgets()
	_on_form_changed()


func _on_cropper_closed() -> void:
	if not m_pending_image_target.is_empty():
		m_status_label.text = "이미지 업로드를 취소했습니다."
	m_pending_image_target = ""
	m_pending_emotion_key = ""
	m_pending_event_row = {}


func _load_external_texture(p_path: String) -> Texture2D:
	var m_clean_path := p_path.strip_edges()
	if m_clean_path.is_empty():
		return null
	if m_external_image_cache.has(m_clean_path):
		return m_external_image_cache[m_clean_path]
	if not FileAccess.file_exists(m_clean_path):
		return null

	var m_image := Image.load_from_file(m_clean_path)
	if m_image == null or m_image.is_empty():
		return null

	var m_texture := ImageTexture.create_from_image(m_image)
	m_external_image_cache[m_clean_path] = m_texture
	return m_texture


func _get_emotion_block(p_emotion_key: String) -> Control:
	return $Dimmer/Panel/Margin/Root/ContentScroll/Content/RightColumn/TabContainer/AppearanceTab/AppearanceScroll/AppearanceVBox/EmotionSection/EmotionGrid.get_node("%sBlock" % p_emotion_key.capitalize())


func _on_character_selected(p_index: int) -> void:
	var m_character_id := str(m_character_list.get_item_metadata(p_index))
	var m_character_profile := story_profile_store.get_character_by_id(m_character_id)
	if m_character_profile.is_empty():
		return
	_load_character(m_character_profile, false)


func _on_new_pressed() -> void:
	m_status_label.text = "새 인물 정보를 입력해 주세요."
	_load_character(story_profile_store.build_empty_character(), true)


func _on_save_pressed() -> void:
	var m_validation := _validate_form()
	if not bool(m_validation.get("ok", false)):
		m_status_label.text = str(m_validation.get("message", "입력값을 확인해 주세요."))
		return

	var m_previous_id := m_selected_character_id if not m_is_new_record else ""
	var m_result := story_profile_store.save_character(_collect_form_data(), m_previous_id)
	m_status_label.text = str(m_result.get("message", "인물 저장 결과를 확인할 수 없습니다."))
	if bool(m_result.get("ok", false)):
		m_selected_character_id = str(m_result.get("id", ""))
		m_is_new_record = false
		_refresh_character_list()
		_select_character_by_id(m_selected_character_id)


func _on_delete_pressed() -> void:
	if m_selected_character_id.is_empty():
		return

	if story_profile_store.delete_character(m_selected_character_id):
		m_status_label.text = "인물 정보를 삭제했습니다."
		m_selected_character_id = ""
		var m_characters := story_profile_store.get_characters()
		if m_characters.is_empty():
			_load_character(story_profile_store.build_empty_character(), true)
		else:
			_select_character_by_id(str((m_characters[0] as Dictionary).get("id", "")))
	else:
		m_status_label.text = "인물 정보를 삭제하지 못했습니다."


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_characters_changed(_p_characters: Array) -> void:
	_refresh_character_list()


func _select_character_by_id(p_character_id: String) -> void:
	for m_index in range(m_character_list.item_count):
		if str(m_character_list.get_item_metadata(m_index)) == p_character_id:
			m_character_list.select(m_index)
			var m_character_profile := story_profile_store.get_character_by_id(p_character_id)
			if not m_character_profile.is_empty():
				_load_character(m_character_profile, false)
			return


func _on_add_sub_personality_pressed() -> void:
	_add_sub_personality_row("")
	_on_form_changed()


func _on_add_speech_example_pressed() -> void:
	_add_speech_example_row("")
	_on_form_changed()


func _on_add_event_image_pressed() -> void:
	_add_event_image_row({})
	_on_form_changed()


func _on_form_changed(_p_value = null) -> void:
	_update_count_labels()
	_refresh_dynamic_limits()
