extends Control

@onready var status_label: Label = $CenterPanel/Margin/VBox/StatusLabel
@onready var configuration_label: Label = $CenterPanel/Margin/VBox/ConfigurationLabel
@onready var continue_button: Button = $CenterPanel/Margin/VBox/ContinueButton
@onready var new_game_button: Button = $CenterPanel/Margin/VBox/NewGameButton
@onready var settings_button: Button = $CenterPanel/Margin/VBox/SettingsButton
@onready var quit_button: Button = $CenterPanel/Margin/VBox/QuitButton
@onready var settings_panel: Control = $SettingsPanel


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	new_game_button.pressed.connect(_on_new_game_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	settings_panel.closed.connect(_refresh_menu_state)
	settings_panel.settings_applied.connect(_refresh_menu_state)
	SettingsManager.settings_changed.connect(_on_runtime_changed)
	AssetLibrary.library_loaded.connect(_on_runtime_changed)
	AiClient.health_status_changed.connect(_on_runtime_changed)
	AiClient.request_backend_health_check()
	_refresh_menu_state()


func _refresh_menu_state() -> void:
	var has_quick_save := SaveManager.has_quick_save()
	var backend_ready := SettingsManager.uses_stub_backend() or AiClient.is_backend_ready()
	continue_button.disabled = not has_quick_save or not backend_ready
	new_game_button.disabled = not backend_ready

	var backend_state := AiClient.get_last_health_state()
	var backend_mode := SettingsManager.get_backend_mode()
	var library_summary := AssetLibrary.get_status_line()
	var backend_summary := str(backend_state.get("message", "No backend status available."))
	configuration_label.text = "Backend: %s\n%s\n\nLibrary: %s" % [backend_mode, backend_summary, library_summary]

	if backend_ready:
		if has_quick_save:
			status_label.text = "Quick save detected. Continue resumes the latest local VN state."
		else:
			status_label.text = "Start Prototype begins a fresh local session."
	else:
		status_label.text = "The local HTTP backend is not ready. Open Settings and enable stub mode or fix the backend URL."


func _on_continue_pressed() -> void:
	SceneRouter.continue_from_quick_save()


func _on_new_game_pressed() -> void:
	SceneRouter.start_new_game()


func _on_settings_pressed() -> void:
	settings_panel.open_panel()


func _on_quit_pressed() -> void:
	SceneRouter.quit_game()


func _on_runtime_changed(_payload = null) -> void:
	_refresh_menu_state()
