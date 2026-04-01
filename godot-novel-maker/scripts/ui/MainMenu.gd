extends Control
class_name MainMenu

@onready var m_status_label: Label = $CenterPanel/Margin/VBox/StatusLabel
@onready var m_configuration_label: Label = $CenterPanel/Margin/VBox/ConfigurationLabel
@onready var m_continue_button: Button = $CenterPanel/Margin/VBox/ContinueButton
@onready var m_load_button: Button = $CenterPanel/Margin/VBox/LoadButton
@onready var m_story_start_button: Button = $CenterPanel/Margin/VBox/StoryStartButton
@onready var m_world_editor_button: Button = $CenterPanel/Margin/VBox/WorldEditorButton
@onready var m_character_editor_button: Button = $CenterPanel/Margin/VBox/CharacterEditorButton
@onready var m_settings_button: Button = $CenterPanel/Margin/VBox/SettingsButton
@onready var m_quit_button: Button = $CenterPanel/Margin/VBox/QuitButton
@onready var m_settings_panel = $SettingsPanel
@onready var m_save_load_panel = $SaveLoadPanel
@onready var m_story_builder_panel = $StoryBuilderPanel
@onready var m_character_editor_panel = $CharacterEditorPanel
@onready var m_story_setup_panel = $StorySetupPanel


func _ready() -> void:
	m_continue_button.pressed.connect(_on_continue_pressed)
	m_load_button.pressed.connect(_on_load_pressed)
	m_story_start_button.pressed.connect(_on_story_start_pressed)
	m_world_editor_button.pressed.connect(_on_world_editor_pressed)
	m_character_editor_button.pressed.connect(_on_character_editor_pressed)
	m_settings_button.pressed.connect(_on_settings_pressed)
	m_quit_button.pressed.connect(_on_quit_pressed)
	m_settings_panel.closed.connect(_refresh_menu_state)
	m_settings_panel.settings_applied.connect(_refresh_menu_state)
	m_save_load_panel.closed.connect(_refresh_menu_state)
	m_save_load_panel.load_requested.connect(_on_slot_load_requested)
	m_story_builder_panel.closed.connect(_refresh_menu_state)
	m_character_editor_panel.closed.connect(_refresh_menu_state)
	m_story_setup_panel.closed.connect(_refresh_menu_state)
	m_story_setup_panel.story_requested.connect(_on_story_requested)
	settings_manager.settings_changed.connect(_on_runtime_changed)
	asset_library.library_loaded.connect(_on_runtime_changed)
	ai_client.health_status_changed.connect(_on_runtime_changed)
	story_profile_store.content_changed.connect(_on_runtime_changed)
	ai_client.request_backend_health_check()
	_refresh_menu_state()


func _refresh_menu_state() -> void:
	var m_has_quick_save := save_manager.has_quick_save()
	var m_has_manual_saves := save_manager.has_any_manual_saves()
	var m_library_ready := asset_library.has_valid_library()
	var m_backend_ready := settings_manager.uses_stub_backend() or ai_client.is_backend_ready()
	var m_has_worlds := story_profile_store.get_world_count() > 0
	var m_has_characters := story_profile_store.get_character_count() > 0
	var m_can_start_story := m_library_ready and m_backend_ready and m_has_worlds and m_has_characters

	m_continue_button.disabled = not m_has_quick_save
	m_load_button.disabled = not m_has_manual_saves
	m_story_start_button.disabled = not m_can_start_story

	var m_backend_state := ai_client.get_last_health_state()
	var m_backend_mode := settings_manager.get_backend_mode()
	var m_backend_model := ai_client.get_active_backend_summary()
	var m_library_summary := asset_library.get_status_line()
	var m_backend_summary := str(m_backend_state.get("message", "백엔드 상태 정보가 없습니다."))
	m_configuration_label.text = "백엔드: %s\n모델: %s\n%s\n\n라이브러리: %s\n세계관 %d개 / 인물 %d개" % [
		m_backend_mode,
		m_backend_model,
		m_backend_summary,
		m_library_summary,
		story_profile_store.get_world_count(),
		story_profile_store.get_character_count()
	]

	if not m_library_ready:
		m_status_label.text = "이야기를 시작하려면 먼저 유효한 자산 라이브러리가 필요합니다. 설정에서 데모 라이브러리나 외부 폴더를 선택해 주세요."
	elif not m_backend_ready:
		m_status_label.text = "백엔드 연결이 아직 준비되지 않았습니다. 설정에서 stub 모드를 켜거나 백엔드 URL을 확인해 주세요."
	elif not m_has_worlds:
		m_status_label.text = "이야기를 시작하려면 세계관이 하나 이상 필요합니다."
	elif not m_has_characters:
		m_status_label.text = "이야기를 시작하려면 메인 캐릭터가 하나 이상 필요합니다."
	elif m_has_quick_save:
		m_status_label.text = "최근 퀵세이브가 있습니다. 이어하기로 마지막 상태를 복원할 수 있습니다."
	else:
		m_status_label.text = "준비가 끝났습니다. 이야기 시작에서 세계관과 메인 캐릭터를 골라 주세요."


func _on_continue_pressed() -> void:
	scene_router.continue_from_quick_save()


func _on_load_pressed() -> void:
	m_save_load_panel.open_panel("load")


func _on_story_start_pressed() -> void:
	m_story_setup_panel.open_panel()


func _on_world_editor_pressed() -> void:
	m_story_builder_panel.open_panel()


func _on_character_editor_pressed() -> void:
	m_character_editor_panel.open_panel()


func _on_settings_pressed() -> void:
	m_settings_panel.open_panel()


func _on_quit_pressed() -> void:
	scene_router.quit_game()


func _on_runtime_changed(_p_payload = null) -> void:
	_refresh_menu_state()


func _on_slot_load_requested(p_slot_id: int) -> void:
	m_save_load_panel.visible = false
	scene_router.load_from_slot(p_slot_id)


func _on_story_requested(p_world_profile: Dictionary, p_character_profiles: Array, p_player_character_profile: Dictionary) -> void:
	scene_router.start_new_game(p_world_profile, p_character_profiles, p_player_character_profile)
