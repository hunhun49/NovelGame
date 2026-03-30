extends Control

signal closed
signal settings_applied

@onready var library_path_edit: LineEdit = $Dimmer/Panel/Margin/VBox/LibraryPathEdit
@onready var library_status_label: Label = $Dimmer/Panel/Margin/VBox/LibraryStatusLabel
@onready var backend_url_edit: LineEdit = $Dimmer/Panel/Margin/VBox/BackendUrlEdit
@onready var backend_mode_label: Label = $Dimmer/Panel/Margin/VBox/BackendModeLabel
@onready var backend_status_label: Label = $Dimmer/Panel/Margin/VBox/BackendStatusLabel
@onready var stub_checkbox: CheckBox = $Dimmer/Panel/Margin/VBox/StubCheckBox
@onready var choose_folder_button: Button = $Dimmer/Panel/Margin/VBox/LibraryButtons/ChooseFolderButton
@onready var reload_library_button: Button = $Dimmer/Panel/Margin/VBox/LibraryButtons/ReloadLibraryButton
@onready var check_backend_button: Button = $Dimmer/Panel/Margin/VBox/BackendButtons/CheckBackendButton
@onready var apply_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/ApplyButton
@onready var close_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/CloseButton
@onready var file_dialog: FileDialog = $FileDialog


func _ready() -> void:
	visible = false
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.dir_selected.connect(_on_directory_selected)
	choose_folder_button.pressed.connect(_on_choose_folder_pressed)
	reload_library_button.pressed.connect(_on_reload_library_pressed)
	check_backend_button.pressed.connect(_on_check_backend_pressed)
	apply_button.pressed.connect(_on_apply_pressed)
	close_button.pressed.connect(_on_close_pressed)
	stub_checkbox.toggled.connect(_on_stub_toggled)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	AssetLibrary.library_loaded.connect(_on_library_loaded)
	AiClient.health_status_changed.connect(_on_health_status_changed)
	_refresh_from_settings(SettingsManager.get_settings_snapshot())
	_refresh_library_status()
	_refresh_backend_status(AiClient.get_last_health_state())


func open_panel() -> void:
	_refresh_from_settings(SettingsManager.get_settings_snapshot())
	_refresh_library_status()
	_refresh_backend_status(AiClient.get_last_health_state())
	visible = true


func _on_choose_folder_pressed() -> void:
	file_dialog.popup_centered_ratio(0.75)


func _on_directory_selected(directory_path: String) -> void:
	library_path_edit.text = directory_path


func _on_reload_library_pressed() -> void:
	AssetLibrary.reload_library(library_path_edit.text)
	_refresh_library_status()


func _on_check_backend_pressed() -> void:
	AiClient.request_backend_health_check()


func _on_apply_pressed() -> void:
	SettingsManager.update_settings({
		"asset_library_path": library_path_edit.text.strip_edges(),
		"backend_base_url": backend_url_edit.text.strip_edges(),
		"use_stub_backend": stub_checkbox.button_pressed,
		"backend_mode": "stub" if stub_checkbox.button_pressed else "http"
	})

	if SettingsManager.get_asset_library_path() == library_path_edit.text.strip_edges():
		AssetLibrary.reload_library(library_path_edit.text.strip_edges())

	AiClient.request_backend_health_check()
	settings_applied.emit()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_stub_toggled(is_enabled: bool) -> void:
	backend_url_edit.editable = not is_enabled
	check_backend_button.disabled = is_enabled
	backend_mode_label.text = "Mode: %s" % ("stub" if is_enabled else "http")


func _on_settings_changed(settings: Dictionary) -> void:
	_refresh_from_settings(settings)


func _on_library_loaded(_snapshot: Dictionary) -> void:
	_refresh_library_status()


func _on_health_status_changed(status_state: Dictionary) -> void:
	_refresh_backend_status(status_state)


func _refresh_from_settings(settings: Dictionary) -> void:
	library_path_edit.text = str(settings.get("asset_library_path", ""))
	backend_url_edit.text = str(settings.get("backend_base_url", ""))
	stub_checkbox.button_pressed = bool(settings.get("use_stub_backend", false))
	_on_stub_toggled(stub_checkbox.button_pressed)


func _refresh_library_status() -> void:
	var messages := AssetLibrary.get_validation_messages()
	library_status_label.text = "Library\n%s" % "\n".join(messages)


func _refresh_backend_status(status_state: Dictionary) -> void:
	backend_mode_label.text = "Mode: %s | Turn URL: %s" % [SettingsManager.get_backend_mode(), SettingsManager.get_turn_url()]
	backend_status_label.text = "Backend\n%s" % str(status_state.get("message", "No backend status available."))
