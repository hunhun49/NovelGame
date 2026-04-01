extends Control
class_name StoryBuilderPanel

signal closed

const PROFILE_IMAGE_MAX_WIDTH := 1024
const PROFILE_IMAGE_MAX_HEIGHT := 1536
const WORLD_NAME_MIN_LENGTH := 2
const WORLD_NAME_MAX_LENGTH := 30
const SUMMARY_MAX_LENGTH := 30
const WORLD_SETTING_MAX_LENGTH := 3000
const PROLOGUE_MAX_LENGTH := 1000
const INITIAL_SITUATION_MAX_LENGTH := 1000

@onready var m_title_label: Label = $Dimmer/Panel/Margin/Root/Header/HeaderText/TitleLabel
@onready var m_status_label: Label = $Dimmer/Panel/Margin/Root/Header/HeaderText/StatusLabel
@onready var m_existing_profile_option: OptionButton = $Dimmer/Panel/Margin/Root/Header/ActionButtons/ExistingProfileOption
@onready var m_new_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/NewButton
@onready var m_save_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/SaveButton
@onready var m_delete_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/DeleteButton
@onready var m_close_button: Button = $Dimmer/Panel/Margin/Root/Header/ActionButtons/CloseButton
@onready var m_tab_container: TabContainer = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer
@onready var m_profile_image_rect: TextureRect = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ProfileImageFrame/ProfileImageRect
@onready var m_profile_image_path_label: Label = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ProfileImagePathLabel
@onready var m_upload_button: Button = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ProfileImageButtons/UploadButton
@onready var m_delete_image_button: Button = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/ProfileImageButtons/DeleteButton
@onready var m_world_name_edit: LineEdit = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/WorldNameEdit
@onready var m_world_name_count_label: Label = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/WorldNameCountLabel
@onready var m_summary_edit: LineEdit = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/SummaryEdit
@onready var m_summary_count_label: Label = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/ProfileTab/ProfileScroll/ProfileVBox/SummaryCountLabel
@onready var m_world_setting_edit: TextEdit = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/WorldSettingTab/WorldSettingScroll/WorldSettingVBox/WorldSettingEdit
@onready var m_world_setting_count_label: Label = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/WorldSettingTab/WorldSettingScroll/WorldSettingVBox/WorldSettingCountLabel
@onready var m_prologue_edit: TextEdit = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/StartSettingTab/StartSettingScroll/StartSettingVBox/PrologueEdit
@onready var m_prologue_count_label: Label = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/StartSettingTab/StartSettingScroll/StartSettingVBox/PrologueCountLabel
@onready var m_start_setup_name_edit: LineEdit = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/StartSettingTab/StartSettingScroll/StartSettingVBox/StartSetupNameEdit
@onready var m_initial_situation_edit: TextEdit = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/StartSettingTab/StartSettingScroll/StartSettingVBox/InitialSituationEdit
@onready var m_initial_situation_count_label: Label = $Dimmer/Panel/Margin/Root/Content/FormPanel/FormMargin/FormVBox/TabContainer/StartSettingTab/StartSettingScroll/StartSettingVBox/InitialSituationCountLabel
@onready var m_preview_image_rect: TextureRect = $Dimmer/Panel/Margin/Root/Content/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/PreviewImageFrame/PreviewImageRect
@onready var m_preview_title_label: Label = $Dimmer/Panel/Margin/Root/Content/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/PreviewTitleLabel
@onready var m_preview_summary_label: Label = $Dimmer/Panel/Margin/Root/Content/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/PreviewSummaryLabel
@onready var m_preview_world_setting_label: Label = $Dimmer/Panel/Margin/Root/Content/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/PreviewWorldSettingLabel
@onready var m_preview_start_setting_label: Label = $Dimmer/Panel/Margin/Root/Content/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/PreviewStartSettingLabel
@onready var m_preview_image_hint_label: Label = $Dimmer/Panel/Margin/Root/Content/PreviewPanel/PreviewMargin/PreviewScroll/PreviewVBox/PreviewImageHintLabel
@onready var m_file_dialog: FileDialog = $FileDialog
@onready var m_image_cropper_popup: ImageCropperPopup = $ImageCropperPopup

var m_selected_world_id := ""
var m_is_new_record := true
var m_loaded_world_snapshot: Dictionary = {}
var m_profile_image_path := ""
var m_external_image_cache: Dictionary = {}
var m_name_regex := RegEx.new()


func _ready() -> void:
	visible = false
	m_title_label.text = "세계관 만들기"
	m_status_label.text = "세계관 정보를 입력하고 저장할 수 있습니다."
	m_tab_container.set_tab_title(0, "프로필")
	m_tab_container.set_tab_title(1, "세계관 설정")
	m_tab_container.set_tab_title(2, "시작 설정")
	m_world_name_edit.max_length = WORLD_NAME_MAX_LENGTH
	m_summary_edit.max_length = SUMMARY_MAX_LENGTH
	m_name_regex.compile("^[0-9A-Za-z가-힣 ]+$")
	m_file_dialog.title = "프로필 이미지 선택"
	m_file_dialog.filters = PackedStringArray([
		"*.png ; PNG 이미지",
		"*.jpg, *.jpeg ; JPEG 이미지",
		"*.webp ; WEBP 이미지"
	])

	m_existing_profile_option.item_selected.connect(_on_existing_profile_selected)
	m_new_button.pressed.connect(_on_new_pressed)
	m_save_button.pressed.connect(_on_save_pressed)
	m_delete_button.pressed.connect(_on_delete_pressed)
	m_close_button.pressed.connect(_on_close_pressed)
	m_upload_button.pressed.connect(_on_upload_pressed)
	m_delete_image_button.pressed.connect(_on_delete_image_pressed)
	m_file_dialog.file_selected.connect(_on_profile_image_selected)
	m_image_cropper_popup.crop_applied.connect(_on_profile_image_cropped)
	m_image_cropper_popup.closed.connect(_on_cropper_closed)

	for m_line_edit in [m_world_name_edit, m_summary_edit, m_start_setup_name_edit]:
		m_line_edit.text_changed.connect(_on_form_changed)

	for m_text_edit in [m_world_setting_edit, m_prologue_edit, m_initial_situation_edit]:
		_configure_wrapping_text_edit(m_text_edit)
		m_text_edit.text_changed.connect(_on_form_changed)

	story_profile_store.worlds_changed.connect(_on_worlds_changed)
	_refresh_world_selector()
	_load_world(story_profile_store.build_empty_world(), true)


func open_panel(p_initial_world_id: String = "") -> void:
	visible = true
	_refresh_world_selector(p_initial_world_id)
	if p_initial_world_id.strip_edges().is_empty() and m_selected_world_id.is_empty() and m_existing_profile_option.item_count > 1:
		m_existing_profile_option.select(1)
		_on_existing_profile_selected(1)
	elif p_initial_world_id.strip_edges().is_empty() and m_selected_world_id.is_empty():
		_load_world(story_profile_store.build_empty_world(), true)
	_update_preview()


func _refresh_world_selector(p_preferred_world_id: String = "") -> void:
	var m_target_world_id := p_preferred_world_id.strip_edges()
	if m_target_world_id.is_empty():
		m_target_world_id = m_selected_world_id

	m_existing_profile_option.clear()
	m_existing_profile_option.add_item("새 세계관")
	m_existing_profile_option.set_item_metadata(0, "__new__")

	var m_selected_index := 0
	var m_index := 1
	for m_world in story_profile_store.get_worlds():
		var m_world_profile := m_world as Dictionary
		var m_world_id := str(m_world_profile.get("id", ""))
		m_existing_profile_option.add_item(story_profile_store.get_world_display_title(m_world_profile))
		m_existing_profile_option.set_item_metadata(m_index, m_world_id)
		if not m_target_world_id.is_empty() and m_world_id == m_target_world_id:
			m_selected_index = m_index
		m_index += 1

	m_existing_profile_option.select(m_selected_index)


func _configure_wrapping_text_edit(p_text_edit: TextEdit) -> void:
	_set_optional_property(p_text_edit, "wrap_mode", TextServer.AUTOWRAP_WORD_SMART)
	_set_optional_property(p_text_edit, "fit_content_height", false)


func _set_optional_property(p_target: Object, p_property_name: String, p_value: Variant) -> void:
	for m_property_info in p_target.get_property_list():
		if str(m_property_info.get("name", "")) == p_property_name:
			p_target.set(p_property_name, p_value)
			return


func _load_world(p_world_profile: Dictionary, p_is_new_record: bool) -> void:
	m_is_new_record = p_is_new_record
	m_selected_world_id = "" if p_is_new_record else str(p_world_profile.get("id", ""))
	m_loaded_world_snapshot = p_world_profile.duplicate(true) if not p_world_profile.is_empty() else story_profile_store.build_empty_world()
	m_profile_image_path = str(p_world_profile.get("portrait_cover_path", "")).strip_edges()

	m_world_name_edit.text = str(p_world_profile.get("name_ko", ""))
	m_summary_edit.text = str(p_world_profile.get("summary", ""))
	m_world_setting_edit.text = str(p_world_profile.get("premise", ""))
	m_prologue_edit.text = str(p_world_profile.get("prologue", ""))
	m_start_setup_name_edit.text = str(p_world_profile.get("start_setup_name", ""))
	m_initial_situation_edit.text = str(p_world_profile.get("initial_situation", ""))

	m_delete_button.disabled = p_is_new_record
	m_status_label.text = "세계관 정보를 입력하고 저장할 수 있습니다."
	_update_count_labels()
	_update_profile_image_widgets()
	_update_preview()


func _collect_form_data() -> Dictionary:
	var m_data := m_loaded_world_snapshot.duplicate(true)
	if m_data.is_empty():
		m_data = story_profile_store.build_empty_world()

	var m_world_name := m_world_name_edit.text.strip_edges()
	m_data["id"] = m_selected_world_id if not m_is_new_record and not m_selected_world_id.is_empty() else _build_suggested_id(m_world_name)
	m_data["name_ko"] = m_world_name
	m_data["story_title"] = m_world_name
	m_data["summary"] = m_summary_edit.text.strip_edges()
	m_data["premise"] = m_world_setting_edit.text.strip_edges()
	m_data["prologue"] = m_prologue_edit.text.strip_edges()
	m_data["start_setup_name"] = m_start_setup_name_edit.text.strip_edges()
	m_data["initial_situation"] = m_initial_situation_edit.text.strip_edges()
	m_data["portrait_cover_path"] = m_profile_image_path
	m_data["square_cover_path"] = ""
	m_data["genre"] = str(m_data.get("genre", "")).strip_edges()
	m_data["tone"] = str(m_data.get("tone", "")).strip_edges()
	m_data["notes"] = str(m_data.get("notes", "")).strip_edges()
	m_data["default_rating_lane"] = str(m_data.get("default_rating_lane", "general")).strip_edges()
	return m_data


func _build_suggested_id(p_world_name: String) -> String:
	var m_base_name := p_world_name.strip_edges().to_lower()
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
		m_builder = "world_%d" % int(Time.get_unix_time_from_system())
	return m_builder


func _validate_form() -> Dictionary:
	var m_world_name := m_world_name_edit.text.strip_edges()
	var m_summary := m_summary_edit.text.strip_edges()
	var m_world_setting := m_world_setting_edit.text.strip_edges()
	var m_prologue := m_prologue_edit.text.strip_edges()
	var m_start_setup_name := m_start_setup_name_edit.text.strip_edges()
	var m_initial_situation := m_initial_situation_edit.text.strip_edges()

	if m_world_name.length() < WORLD_NAME_MIN_LENGTH or m_world_name.length() > WORLD_NAME_MAX_LENGTH:
		return {"ok": false, "message": "세계관 이름은 2~30자 사이여야 합니다."}
	if m_name_regex.search(m_world_name) == null:
		return {"ok": false, "message": "세계관 이름에는 한글, 영문, 숫자, 공백만 사용할 수 있습니다."}
	if m_summary.is_empty() or m_summary.length() > SUMMARY_MAX_LENGTH:
		return {"ok": false, "message": "한 줄 소개는 30자 이내로 입력해 주세요."}
	if m_world_setting.is_empty() or m_world_setting.length() > WORLD_SETTING_MAX_LENGTH:
		return {"ok": false, "message": "세계관 설정은 3000자 이내로 입력해 주세요."}
	if m_prologue.is_empty() or m_prologue.length() > PROLOGUE_MAX_LENGTH:
		return {"ok": false, "message": "프롤로그는 1000자 이내로 입력해 주세요."}
	if m_start_setup_name.is_empty():
		return {"ok": false, "message": "시작설정 이름을 입력해 주세요."}
	if m_initial_situation.is_empty() or m_initial_situation.length() > INITIAL_SITUATION_MAX_LENGTH:
		return {"ok": false, "message": "시작 상황은 1000자 이내로 입력해 주세요."}
	return {"ok": true}


func _update_count_labels() -> void:
	m_world_name_count_label.text = "%d/%d" % [m_world_name_edit.text.length(), WORLD_NAME_MAX_LENGTH]
	m_summary_count_label.text = "%d/%d" % [m_summary_edit.text.length(), SUMMARY_MAX_LENGTH]
	m_world_setting_count_label.text = "%d/%d" % [m_world_setting_edit.text.length(), WORLD_SETTING_MAX_LENGTH]
	m_prologue_count_label.text = "%d/%d" % [m_prologue_edit.text.length(), PROLOGUE_MAX_LENGTH]
	m_initial_situation_count_label.text = "%d/%d" % [m_initial_situation_edit.text.length(), INITIAL_SITUATION_MAX_LENGTH]


func _update_profile_image_widgets() -> void:
	m_profile_image_rect.texture = _load_external_texture(m_profile_image_path)
	m_profile_image_path_label.text = m_profile_image_path.get_file() if not m_profile_image_path.is_empty() else "등록된 이미지가 없습니다."
	m_delete_image_button.disabled = m_profile_image_path.is_empty()


func _update_preview() -> void:
	_update_count_labels()
	var m_world_name := m_world_name_edit.text.strip_edges()
	var m_summary := m_summary_edit.text.strip_edges()
	var m_world_setting := m_world_setting_edit.text.strip_edges()
	var m_prologue := m_prologue_edit.text.strip_edges()
	var m_start_setup_name := m_start_setup_name_edit.text.strip_edges()
	var m_initial_situation := m_initial_situation_edit.text.strip_edges()

	m_preview_image_rect.texture = _load_external_texture(m_profile_image_path)
	m_preview_image_hint_label.text = "2:3 비율, 최대 1024 x 1536" if m_profile_image_path.is_empty() else m_profile_image_path.get_file()
	m_preview_title_label.text = m_world_name if not m_world_name.is_empty() else "세계관 이름"
	m_preview_summary_label.text = m_summary if not m_summary.is_empty() else "어떤 스토리인지 설명할 수 있는 간단한 소개가 여기에 표시됩니다."
	m_preview_world_setting_label.text = m_world_setting if not m_world_setting.is_empty() else "세계관 설정을 입력하면 이곳에 미리보기가 표시됩니다."

	var m_start_lines: Array = []
	if not m_start_setup_name.is_empty():
		m_start_lines.append("시작설정: %s" % m_start_setup_name)
	if not m_prologue.is_empty():
		m_start_lines.append("프롤로그\n%s" % m_prologue)
	if not m_initial_situation.is_empty():
		m_start_lines.append("시작 상황\n%s" % m_initial_situation)
	m_preview_start_setting_label.text = "\n\n".join(m_start_lines) if not m_start_lines.is_empty() else "프롤로그와 시작 상황을 작성하면 시작 설정 미리보기가 여기에 표시됩니다."


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


func _on_existing_profile_selected(p_index: int) -> void:
	var m_world_id := str(m_existing_profile_option.get_item_metadata(p_index))
	if m_world_id == "__new__":
		_load_world(story_profile_store.build_empty_world(), true)
		return

	var m_world_profile := story_profile_store.get_world_by_id(m_world_id)
	if m_world_profile.is_empty():
		_load_world(story_profile_store.build_empty_world(), true)
		return

	_load_world(m_world_profile, false)


func _on_new_pressed() -> void:
	_refresh_world_selector()
	m_existing_profile_option.select(0)
	_load_world(story_profile_store.build_empty_world(), true)
	m_status_label.text = "새 세계관을 작성해 주세요."


func _on_save_pressed() -> void:
	var m_validation := _validate_form()
	if not bool(m_validation.get("ok", false)):
		m_status_label.text = str(m_validation.get("message", "입력값을 확인해 주세요."))
		return

	var m_previous_id := m_selected_world_id if not m_is_new_record else ""
	var m_result := story_profile_store.save_world(_collect_form_data(), m_previous_id)
	m_status_label.text = str(m_result.get("message", "저장 결과를 확인할 수 없습니다."))
	if bool(m_result.get("ok", false)):
		m_selected_world_id = str(m_result.get("id", ""))
		m_is_new_record = false
		_refresh_world_selector(m_selected_world_id)
		var m_saved_world := story_profile_store.get_world_by_id(m_selected_world_id)
		if not m_saved_world.is_empty():
			_load_world(m_saved_world, false)


func _on_delete_pressed() -> void:
	if m_selected_world_id.is_empty():
		m_status_label.text = "삭제할 세계관이 없습니다."
		return

	if story_profile_store.delete_world(m_selected_world_id):
		m_status_label.text = "세계관을 삭제했습니다."
		m_selected_world_id = ""
		m_profile_image_path = ""
		_refresh_world_selector()
		m_existing_profile_option.select(0)
		_load_world(story_profile_store.build_empty_world(), true)
	else:
		m_status_label.text = "세계관을 삭제하지 못했습니다."


func _on_upload_pressed() -> void:
	m_file_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	m_file_dialog.popup_centered_ratio(0.7)


func _on_delete_image_pressed() -> void:
	m_profile_image_path = ""
	_update_profile_image_widgets()
	_update_preview()


func _on_profile_image_selected(p_path: String) -> void:
	if not FileAccess.file_exists(p_path):
		m_status_label.text = "선택한 이미지를 찾을 수 없습니다."
		return

	var m_image := Image.load_from_file(p_path)
	if m_image == null or m_image.is_empty():
		m_status_label.text = "이미지를 불러오지 못했습니다."
		return

	m_image_cropper_popup.open_with_image(m_image, p_path)
	m_status_label.text = "팝업에서 보이는 영역을 조정한 뒤 적용해 주세요."


func _on_profile_image_cropped(p_cropped_image: Image) -> void:
	var m_output_dir := "user://content/world_profile_images"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(m_output_dir))

	var m_old_path := m_profile_image_path
	var m_base_id := m_selected_world_id if not m_selected_world_id.is_empty() else _build_suggested_id(m_world_name_edit.text)
	var m_output_path := "%s/%s_%d.png" % [m_output_dir, m_base_id, int(Time.get_unix_time_from_system())]
	if p_cropped_image.save_png(m_output_path) != OK:
		m_status_label.text = "프로필 이미지를 저장하지 못했습니다."
		return

	m_profile_image_path = m_output_path
	m_external_image_cache.erase(m_profile_image_path)
	if m_old_path.begins_with("user://content/world_profile_images/") and m_old_path != m_profile_image_path and FileAccess.file_exists(m_old_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(m_old_path))

	m_status_label.text = "프로필 이미지를 등록했습니다."
	_update_profile_image_widgets()
	_update_preview()


func _on_cropper_closed() -> void:
	if m_profile_image_path.is_empty():
		m_status_label.text = "이미지 업로드를 취소했습니다."


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_worlds_changed(_p_worlds: Array) -> void:
	_refresh_world_selector(m_selected_world_id)
	_update_preview()


func _on_form_changed(_p_value = null) -> void:
	_update_preview()
