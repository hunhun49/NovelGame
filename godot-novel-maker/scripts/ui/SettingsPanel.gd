extends Control
class_name SettingsPanel

signal closed
signal settings_applied

@onready var m_library_path_edit: LineEdit = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/LibraryPathEdit
@onready var m_library_status_label: Label = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/LibraryStatusLabel
@onready var m_backend_url_edit: LineEdit = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/BackendUrlEdit
@onready var m_backend_mode_label: Label = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/BackendModeLabel
@onready var m_backend_status_label: Label = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/BackendStatusLabel
@onready var m_stub_checkbox: CheckBox = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/StubCheckBox
@onready var m_choose_folder_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/LibraryButtons/ChooseFolderButton
@onready var m_use_demo_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/LibraryButtons/UseDemoLibraryButton
@onready var m_reload_library_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/LibraryButtons/ReloadLibraryButton
@onready var m_check_backend_button: Button = $Dimmer/Panel/Margin/Root/ContentScroll/ContentVBox/BackendButtons/CheckBackendButton
@onready var m_apply_button: Button = $Dimmer/Panel/Margin/Root/FooterButtons/ApplyButton
@onready var m_close_button: Button = $Dimmer/Panel/Margin/Root/FooterButtons/CloseButton
@onready var m_file_dialog: FileDialog = $FileDialog


func _ready() -> void:
	visible = false
	m_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	m_file_dialog.dir_selected.connect(_on_directory_selected)
	m_choose_folder_button.pressed.connect(_on_choose_folder_pressed)
	m_use_demo_button.pressed.connect(_on_use_demo_pressed)
	m_reload_library_button.pressed.connect(_on_reload_library_pressed)
	m_check_backend_button.pressed.connect(_on_check_backend_pressed)
	m_apply_button.pressed.connect(_on_apply_pressed)
	m_close_button.pressed.connect(_on_close_pressed)
	m_stub_checkbox.toggled.connect(_on_stub_toggled)
	settings_manager.settings_changed.connect(_on_settings_changed)
	asset_library.library_loaded.connect(_on_library_loaded)
	ai_client.health_status_changed.connect(_on_health_status_changed)
	_refresh_from_settings(settings_manager.get_settings_snapshot())
	_refresh_library_status()
	_refresh_backend_status(ai_client.get_last_health_state())


func open_panel() -> void:
	_refresh_from_settings(settings_manager.get_settings_snapshot())
	_refresh_library_status()
	_refresh_backend_status(ai_client.get_last_health_state())
	visible = true


func _on_choose_folder_pressed() -> void:
	m_file_dialog.popup_centered_ratio(0.75)


func _on_use_demo_pressed() -> void:
	m_library_path_edit.text = settings_manager.get_demo_library_path()
	asset_library.reload_library(m_library_path_edit.text)
	_refresh_library_status()


func _on_directory_selected(directory_path: String) -> void:
	m_library_path_edit.text = directory_path


func _on_reload_library_pressed() -> void:
	asset_library.reload_library(m_library_path_edit.text)
	_refresh_library_status()


func _on_check_backend_pressed() -> void:
	ai_client.request_backend_health_check()


func _on_apply_pressed() -> void:
	settings_manager.update_settings({
		"asset_library_path": m_library_path_edit.text.strip_edges(),
		"backend_base_url": m_backend_url_edit.text.strip_edges(),
		"use_stub_backend": m_stub_checkbox.button_pressed,
		"backend_mode": "stub" if m_stub_checkbox.button_pressed else "http"
	})

	if settings_manager.get_asset_library_path() == m_library_path_edit.text.strip_edges():
		asset_library.reload_library(m_library_path_edit.text.strip_edges())

	ai_client.request_backend_health_check()
	settings_applied.emit()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_stub_toggled(is_enabled: bool) -> void:
	m_backend_url_edit.editable = not is_enabled
	m_check_backend_button.disabled = is_enabled
	m_backend_mode_label.text = "모드: %s" % ("stub" if is_enabled else "http")


func _on_settings_changed(settings: Dictionary) -> void:
	_refresh_from_settings(settings)


func _on_library_loaded(_snapshot: Dictionary) -> void:
	_refresh_library_status()


func _on_health_status_changed(status_state: Dictionary) -> void:
	_refresh_backend_status(status_state)


func _refresh_from_settings(settings: Dictionary) -> void:
	m_library_path_edit.text = str(settings.get("asset_library_path", ""))
	m_backend_url_edit.text = str(settings.get("backend_base_url", ""))
	m_stub_checkbox.button_pressed = bool(settings.get("use_stub_backend", false))
	_on_stub_toggled(m_stub_checkbox.button_pressed)


func _refresh_library_status() -> void:
	var messages := asset_library.get_validation_messages()
	var demo_line := "데모 라이브러리\n%s" % settings_manager.get_demo_library_path()
	m_library_status_label.text = "라이브러리\n%s\n\n%s" % ["\n".join(messages), demo_line]


func _refresh_backend_status(status_state: Dictionary) -> void:
	m_backend_mode_label.text = "모드: %s | 턴 URL: %s" % [settings_manager.get_backend_mode(), settings_manager.get_turn_url()]
	var provider := str(status_state.get("provider", ai_client.get_active_provider_name()))
	var model := str(status_state.get("model", ai_client.get_active_model_name()))
	var message := str(status_state.get("message", "백엔드 상태 정보가 없습니다."))
	m_backend_status_label.text = "백엔드\n공급자: %s\n모델: %s\n%s" % [provider, model, message]
