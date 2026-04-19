extends Control
class_name StorySetupPanel

signal closed
signal story_requested(world_profile: Dictionary, character_profiles: Array, player_character_profile: Dictionary)

const STEP_WORLD := 0
const STEP_CHARACTERS := 1
const STEP_PLAYER := 2

@onready var m_title_label: Label = $Dimmer/Panel/Margin/VBox/Header/TitleLabel
@onready var m_step_label: Label = $Dimmer/Panel/Margin/VBox/Header/StepLabel
@onready var m_summary_label: Label = $Dimmer/Panel/Margin/VBox/SummaryLabel
@onready var m_world_step: VBoxContainer = $Dimmer/Panel/Margin/VBox/BodyStack/WorldStep
@onready var m_character_step: VBoxContainer = $Dimmer/Panel/Margin/VBox/BodyStack/CharacterStep
@onready var m_player_step: VBoxContainer = $Dimmer/Panel/Margin/VBox/BodyStack/PlayerStep
@onready var m_world_list: ItemList = $Dimmer/Panel/Margin/VBox/BodyStack/WorldStep/Body/LeftColumn/WorldList
@onready var m_world_info_scroll: ScrollContainer = $Dimmer/Panel/Margin/VBox/BodyStack/WorldStep/Body/RightColumn/WorldInfoScroll
@onready var m_world_info_label: Label = $Dimmer/Panel/Margin/VBox/BodyStack/WorldStep/Body/RightColumn/WorldInfoScroll/WorldInfoLabel
@onready var m_selected_world_label: Label = $Dimmer/Panel/Margin/VBox/BodyStack/CharacterStep/SelectedWorldLabel
@onready var m_character_list_container: VBoxContainer = $Dimmer/Panel/Margin/VBox/BodyStack/CharacterStep/CharacterScroll/CharacterListContainer
@onready var m_selected_cast_label: Label = $Dimmer/Panel/Margin/VBox/BodyStack/PlayerStep/SelectedCastLabel
@onready var m_player_list_container: VBoxContainer = $Dimmer/Panel/Margin/VBox/BodyStack/PlayerStep/PlayerScroll/PlayerListContainer
@onready var m_status_label: Label = $Dimmer/Panel/Margin/VBox/StatusLabel
@onready var m_back_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/BackButton
@onready var m_next_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/NextButton
@onready var m_start_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/StartButton
@onready var m_close_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/CloseButton

var m_selected_world_id := ""
var m_step_index := STEP_WORLD
var m_character_checkboxes := {}
var m_player_checkboxes := {}
var m_selected_player_character_id := ""


func _ready() -> void:
	visible = false
	m_title_label.text = "이야기 시작"
	m_world_list.item_selected.connect(_on_world_selected)
	m_back_button.pressed.connect(_on_back_pressed)
	m_next_button.pressed.connect(_on_next_pressed)
	m_start_button.pressed.connect(_on_start_pressed)
	m_close_button.pressed.connect(_on_close_pressed)
	story_profile_store.worlds_changed.connect(_on_profiles_changed)
	story_profile_store.characters_changed.connect(_on_profiles_changed)
	asset_library.library_loaded.connect(_on_runtime_changed)
	ai_client.health_status_changed.connect(_on_runtime_changed)
	_refresh_all(true)
	audio_manager.wire_button_sounds(self)


func open_panel() -> void:
	visible = true
	m_step_index = STEP_WORLD
	m_selected_player_character_id = ""
	_refresh_all(true)


func _refresh_all(p_apply_defaults: bool) -> void:
	_refresh_worlds()
	_refresh_world_info()
	_refresh_character_cards(p_apply_defaults)
	_refresh_player_cards()
	_refresh_step_state()
	_refresh_status()


func _refresh_worlds() -> void:
	var m_previous_world_id := m_selected_world_id
	m_world_list.clear()
	for m_world in story_profile_store.get_worlds():
		var m_world_dict := m_world as Dictionary
		m_world_list.add_item(story_profile_store.get_world_display_title(m_world_dict))
		m_world_list.set_item_metadata(m_world_list.item_count - 1, str(m_world_dict.get("id", "")))

	if m_previous_world_id.is_empty():
		if m_world_list.item_count > 0:
			m_selected_world_id = str(m_world_list.get_item_metadata(0))
			m_world_list.select(0)
	else:
		var m_restored := false
		for m_index in range(m_world_list.item_count):
			if str(m_world_list.get_item_metadata(m_index)) == m_previous_world_id:
				m_world_list.select(m_index)
				m_selected_world_id = m_previous_world_id
				m_restored = true
				break
		if not m_restored:
			m_selected_world_id = ""
			if m_world_list.item_count > 0:
				m_selected_world_id = str(m_world_list.get_item_metadata(0))
				m_world_list.select(0)

	if m_world_list.item_count == 0:
		m_selected_world_id = ""


func _refresh_world_info() -> void:
	var m_world_profile := story_profile_store.get_world_by_id(m_selected_world_id)
	if m_world_profile.is_empty():
		m_world_info_label.text = "먼저 세계관을 하나 이상 만들어 주세요."
		m_selected_world_label.text = "선택된 세계관이 없습니다."
		m_world_info_scroll.scroll_vertical = 0
		return

	m_world_info_label.text = _build_world_info(m_world_profile)
	m_selected_world_label.text = "선택된 세계관: %s" % story_profile_store.get_world_display_title(m_world_profile)
	m_world_info_scroll.scroll_vertical = 0


func _refresh_character_cards(p_apply_defaults: bool = false) -> void:
	var m_previous_checked_ids := _get_checked_character_ids()
	for m_child in m_character_list_container.get_children():
		m_child.queue_free()
	m_character_checkboxes = {}

	if m_selected_world_id.is_empty():
		var m_empty_label := Label.new()
		m_empty_label.text = "먼저 세계관을 선택해 주세요."
		m_character_list_container.add_child(m_empty_label)
		return

	var m_world_profile := story_profile_store.get_world_by_id(m_selected_world_id)
	var m_characters := story_profile_store.get_characters_for_world(m_selected_world_id)
	if m_characters.is_empty():
		var m_empty_label := Label.new()
		m_empty_label.text = "선택 가능한 등장인물이 없습니다. 인물 만들기에서 캐릭터를 먼저 추가해 주세요."
		m_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_character_list_container.add_child(m_empty_label)
		return

	var m_selected_ids := m_previous_checked_ids
	if p_apply_defaults and m_selected_ids.is_empty():
		var m_default_ids: Variant = m_world_profile.get("default_main_character_ids", [])
		m_selected_ids = m_default_ids.duplicate(true) if m_default_ids is Array else []

	for m_character in m_characters:
		var m_character_profile := m_character as Dictionary
		var m_character_id := str(m_character_profile.get("id", ""))
		var m_checkbox := CheckBox.new()
		m_checkbox.text = "등장인물로 선택"
		m_checkbox.button_pressed = m_selected_ids.has(m_character_id)
		m_checkbox.toggled.connect(_on_character_toggled)
		var m_card := _build_character_card(m_character_profile, m_checkbox)
		m_character_list_container.add_child(m_card)
		m_character_checkboxes[m_character_id] = m_checkbox


func _refresh_player_cards() -> void:
	var m_selected_ids := _get_checked_character_ids()
	var m_available_characters := _get_player_candidate_profiles()
	for m_child in m_player_list_container.get_children():
		m_child.queue_free()
	m_player_checkboxes = {}

	var m_selected_names: Array = []
	for m_character_id in m_selected_ids:
		m_selected_names.append(story_profile_store.get_character_name(str(m_character_id)))
	m_selected_cast_label.text = "선택된 등장인물: %s" % ("없음" if m_selected_names.is_empty() else ", ".join(m_selected_names))

	if m_selected_ids.is_empty():
		m_selected_player_character_id = ""
		var m_empty_before_cast := Label.new()
		m_empty_before_cast.text = "먼저 등장인물을 한 명 이상 선택해 주세요."
		m_player_list_container.add_child(m_empty_before_cast)
		return

	if m_available_characters.is_empty():
		m_selected_player_character_id = ""
		var m_empty_label := Label.new()
		m_empty_label.text = "플레이어 캐릭터로 고를 수 있는 인물이 없습니다. 등장인물로 선택하지 않은 다른 캐릭터를 하나 이상 준비해 주세요."
		m_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_player_list_container.add_child(m_empty_label)
		return

	var m_still_valid := false
	for m_profile in m_available_characters:
		if str((m_profile as Dictionary).get("id", "")) == m_selected_player_character_id:
			m_still_valid = true
			break
	if not m_still_valid:
		m_selected_player_character_id = ""

	for m_character_profile in m_available_characters:
		var m_character_id := str((m_character_profile as Dictionary).get("id", ""))
		var m_checkbox := CheckBox.new()
		m_checkbox.text = "플레이어 캐릭터"
		m_checkbox.button_pressed = m_character_id == m_selected_player_character_id
		m_checkbox.toggled.connect(func(p_toggled: bool) -> void:
			_on_player_toggled(m_character_id, p_toggled)
		)
		var m_card := _build_character_card(m_character_profile, m_checkbox)
		m_player_list_container.add_child(m_card)
		m_player_checkboxes[m_character_id] = m_checkbox


func _build_character_card(p_character_profile: Dictionary, p_selector: CheckBox) -> PanelContainer:
	var m_character_id := str(p_character_profile.get("id", ""))
	var m_card := PanelContainer.new()
	m_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var m_margin := MarginContainer.new()
	m_margin.add_theme_constant_override("margin_left", 12)
	m_margin.add_theme_constant_override("margin_top", 12)
	m_margin.add_theme_constant_override("margin_right", 12)
	m_margin.add_theme_constant_override("margin_bottom", 12)
	m_card.add_child(m_margin)

	var m_row := HBoxContainer.new()
	m_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_row.add_theme_constant_override("separation", 12)
	m_margin.add_child(m_row)

	var m_thumbnail := TextureRect.new()
	m_thumbnail.custom_minimum_size = Vector2(72, 180)
	m_thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m_thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	m_thumbnail.texture = asset_library.get_character_thumbnail_texture(p_character_profile)
	m_row.add_child(m_thumbnail)

	var m_text_column := VBoxContainer.new()
	m_text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m_text_column.add_theme_constant_override("separation", 6)
	m_row.add_child(m_text_column)

	var m_name_label := Label.new()
	m_name_label.text = str(p_character_profile.get("name_ko", m_character_id))
	m_name_label.add_theme_font_size_override("font_size", 20)
	m_text_column.add_child(m_name_label)

	var m_role_label := Label.new()
	m_role_label.text = str(p_character_profile.get("role", "역할 미정"))
	m_text_column.add_child(m_role_label)

	var m_summary_label_node := Label.new()
	m_summary_label_node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m_summary_label_node.text = str(p_character_profile.get("summary", "소개가 아직 없습니다."))
	m_text_column.add_child(m_summary_label_node)

	var m_personality_label := Label.new()
	var m_main_personality := str(p_character_profile.get("main_personality", "")).strip_edges()
	m_personality_label.text = "메인 성격: %s" % ("미정" if m_main_personality.is_empty() else m_main_personality)
	m_text_column.add_child(m_personality_label)

	m_row.add_child(p_selector)
	return m_card


func _refresh_step_state() -> void:
	m_world_step.visible = m_step_index == STEP_WORLD
	m_character_step.visible = m_step_index == STEP_CHARACTERS
	m_player_step.visible = m_step_index == STEP_PLAYER
	m_back_button.visible = m_step_index != STEP_WORLD
	m_next_button.visible = m_step_index != STEP_PLAYER
	m_start_button.visible = m_step_index == STEP_PLAYER

	match m_step_index:
		STEP_WORLD:
			m_step_label.text = "1 / 3 단계: 세계관 선택"
			m_summary_label.text = "이번 이야기에서 사용할 세계관을 먼저 골라 주세요."
		STEP_CHARACTERS:
			m_step_label.text = "2 / 3 단계: 등장인물 선택"
			m_summary_label.text = "이 세계관에서 주로 등장할 메인 캐릭터를 선택해 주세요."
		STEP_PLAYER:
			m_step_label.text = "3 / 3 단계: 플레이어 캐릭터 선택"
			m_summary_label.text = "플레이어가 조작할 캐릭터를 골라 주세요. 등장인물과는 별도로 관리됩니다."


func _refresh_status() -> void:
	var m_library_ready := asset_library.has_valid_library()
	var m_backend_ready := settings_manager.uses_stub_backend() or ai_client.is_backend_ready()
	var m_world_ready := not m_selected_world_id.is_empty()
	var m_character_ready := not _get_checked_character_ids().is_empty()
	var m_player_ready := not m_selected_player_character_id.is_empty()

	m_next_button.disabled = false
	if m_step_index == STEP_WORLD:
		m_next_button.disabled = not m_world_ready
	elif m_step_index == STEP_CHARACTERS:
		m_next_button.disabled = not m_character_ready
	m_start_button.disabled = not (m_library_ready and m_backend_ready and m_world_ready and m_character_ready and m_player_ready)

	if m_step_index == STEP_WORLD:
		m_status_label.text = "세계관을 고른 뒤 다음 단계로 이동해 주세요." if m_world_ready else "이야기를 시작하려면 세계관을 하나 선택해야 합니다."
		return

	if m_step_index == STEP_CHARACTERS:
		m_status_label.text = "등장인물을 선택한 뒤 다음 단계에서 플레이어 캐릭터를 고릅니다." if m_character_ready else "메인 등장인물을 한 명 이상 선택해 주세요."
		return

	if not m_library_ready:
		m_status_label.text = "먼저 유효한 자산 라이브러리를 불러와 주세요."
	elif not m_backend_ready:
		m_status_label.text = "백엔드 연결 또는 stub 모드 활성화가 필요합니다."
	elif not m_player_ready:
		m_status_label.text = "플레이어 캐릭터를 반드시 한 명 선택해 주세요."
	else:
		m_status_label.text = "준비가 끝났습니다. 현재 선택으로 이야기를 시작할 수 있습니다."


func _on_world_selected(p_index: int) -> void:
	m_selected_world_id = str(m_world_list.get_item_metadata(p_index))
	m_selected_player_character_id = ""
	_refresh_world_info()
	_refresh_character_cards(true)
	_refresh_player_cards()
	_refresh_status()


func _on_back_pressed() -> void:
	if m_step_index == STEP_PLAYER:
		m_step_index = STEP_CHARACTERS
	else:
		m_step_index = STEP_WORLD
	_refresh_step_state()
	_refresh_status()


func _on_next_pressed() -> void:
	if m_step_index == STEP_WORLD:
		if m_selected_world_id.is_empty():
			_refresh_status()
			return
		m_step_index = STEP_CHARACTERS
	elif m_step_index == STEP_CHARACTERS:
		if _get_checked_character_ids().is_empty():
			_refresh_status()
			return
		m_step_index = STEP_PLAYER
	_refresh_step_state()
	_refresh_status()


func _on_start_pressed() -> void:
	var m_world_profile := story_profile_store.get_world_by_id(m_selected_world_id)
	if m_world_profile.is_empty():
		_refresh_status()
		return

	var m_character_profiles: Array = []
	for m_character_id in _get_checked_character_ids():
		var m_character_profile := story_profile_store.get_character_by_id(str(m_character_id))
		if not m_character_profile.is_empty():
			m_character_profiles.append(m_character_profile)

	var m_player_character_profile := story_profile_store.get_character_by_id(m_selected_player_character_id)
	if m_character_profiles.is_empty() or m_player_character_profile.is_empty():
		_refresh_status()
		return

	visible = false
	story_requested.emit(m_world_profile, m_character_profiles, m_player_character_profile)
	closed.emit()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func _on_character_toggled(_p_toggled: bool) -> void:
	_refresh_player_cards()
	_refresh_status()


func _on_player_toggled(p_character_id: String, p_toggled: bool) -> void:
	if p_toggled:
		m_selected_player_character_id = p_character_id
		for m_other_character_id in m_player_checkboxes.keys():
			if str(m_other_character_id) == p_character_id:
				continue
			var m_checkbox: CheckBox = m_player_checkboxes[m_other_character_id]
			if m_checkbox.button_pressed:
				m_checkbox.set_pressed_no_signal(false)
	else:
		if m_selected_player_character_id == p_character_id:
			m_selected_player_character_id = ""
	_refresh_status()


func _on_profiles_changed(_p_payload = null) -> void:
	if visible:
		_refresh_all(false)


func _on_runtime_changed(_p_payload = null) -> void:
	if visible:
		_refresh_status()


func _get_checked_character_ids() -> Array:
	var m_ids: Array = []
	for m_character_id in m_character_checkboxes.keys():
		var m_checkbox: CheckBox = m_character_checkboxes[m_character_id]
		if m_checkbox.button_pressed:
			m_ids.append(m_character_id)
	return m_ids


func _get_player_candidate_profiles() -> Array:
	var m_selected_cast_ids := _get_checked_character_ids()
	var m_candidates: Array = []
	for m_character in story_profile_store.get_characters_for_world(m_selected_world_id):
		var m_profile := m_character as Dictionary
		var m_character_id := str(m_profile.get("id", ""))
		if m_selected_cast_ids.has(m_character_id):
			continue
		m_candidates.append(m_profile)
	return m_candidates


func _build_world_info(p_world_profile: Dictionary) -> String:
	if p_world_profile.is_empty():
		return "세계관을 선택하면 설명이 표시됩니다."

	var m_story_title := story_profile_store.get_world_display_title(p_world_profile)
	var m_name := str(p_world_profile.get("name_ko", "")).strip_edges()
	var m_summary := str(p_world_profile.get("summary", "")).strip_edges()
	var m_premise := str(p_world_profile.get("premise", "")).strip_edges()
	var m_prologue := str(p_world_profile.get("prologue", "")).strip_edges()
	var m_start_setup_name := str(p_world_profile.get("start_setup_name", "")).strip_edges()
	var m_initial_situation := str(p_world_profile.get("initial_situation", "")).strip_edges()

	return "스토리 제목: %s\n세계관 이름: %s\n\n한 줄 소개\n%s\n\n세계관 설정\n%s\n\n시작 설정\n%s\n\n프롤로그\n%s\n\n시작 상황\n%s" % [
		m_story_title,
		m_name,
		m_summary if not m_summary.is_empty() else "소개가 아직 없습니다.",
		m_premise if not m_premise.is_empty() else "세계관 설정이 아직 없습니다.",
		m_start_setup_name if not m_start_setup_name.is_empty() else "기본 시작 설정",
		m_prologue if not m_prologue.is_empty() else "프롤로그가 아직 없습니다.",
		m_initial_situation if not m_initial_situation.is_empty() else "시작 상황이 아직 없습니다."
	]
