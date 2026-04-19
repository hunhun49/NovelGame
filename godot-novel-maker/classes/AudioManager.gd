extends Node
class_name AudioManagerService

const BGM_CROSSFADE_SECONDS := 0.4
const MIN_VOLUME_DB := -40.0

var m_bgm_a: AudioStreamPlayer
var m_bgm_b: AudioStreamPlayer
var m_sfx_player: AudioStreamPlayer
var m_active_bgm_player: AudioStreamPlayer
var m_inactive_bgm_player: AudioStreamPlayer
var m_current_bgm_id := ""


func _ready() -> void:
	m_bgm_a = AudioStreamPlayer.new()
	m_bgm_a.bus = &"Master"
	add_child(m_bgm_a)

	m_bgm_b = AudioStreamPlayer.new()
	m_bgm_b.bus = &"Master"
	add_child(m_bgm_b)

	m_sfx_player = AudioStreamPlayer.new()
	m_sfx_player.bus = &"Master"
	add_child(m_sfx_player)

	m_active_bgm_player = m_bgm_a
	m_inactive_bgm_player = m_bgm_b
	m_bgm_a.volume_db = MIN_VOLUME_DB
	m_bgm_b.volume_db = MIN_VOLUME_DB


func sync_audio_state(audio_state: Dictionary) -> void:
	_apply_bgm(audio_state, false)


func apply_turn_audio_state(audio_state: Dictionary) -> void:
	_apply_bgm(audio_state, true)
	_apply_sfx(audio_state)


func play_sfx(sfx_id: String) -> void:
	_apply_sfx({"sfx_id": sfx_id})


func wire_button_sounds(root_node: Node) -> void:
	for child in root_node.get_children():
		if child is Button:
			if not child.mouse_entered.is_connected(_on_ui_button_hover):
				child.mouse_entered.connect(_on_ui_button_hover)
			if not child.button_down.is_connected(Callable(self, "_on_ui_button_down")):
				child.button_down.connect(Callable(self, "_on_ui_button_down"))
			if not child.button_up.is_connected(Callable(self, "_on_ui_button_up")):
				child.button_up.connect(Callable(self, "_on_ui_button_up"))
		wire_button_sounds(child)


func stop_all() -> void:
	m_bgm_a.stop()
	m_bgm_b.stop()
	m_sfx_player.stop()
	m_current_bgm_id = ""


func _apply_bgm(audio_state: Dictionary, animate: bool) -> void:
	var requested_bgm_id := str(audio_state.get("bgm_id", "")).strip_edges()
	if requested_bgm_id.is_empty():
		if m_current_bgm_id.is_empty():
			return
		_fade_out_active_bgm()
		m_current_bgm_id = ""
		return

	if requested_bgm_id == m_current_bgm_id and m_active_bgm_player.playing:
		m_active_bgm_player.volume_db = _resolve_volume_db(str(audio_state.get("volume_profile", "default")))
		return

	var stream := asset_library.get_bgm_stream(requested_bgm_id)
	if stream == null:
		return

	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	var target_volume := _resolve_volume_db(str(audio_state.get("volume_profile", "default")))
	m_inactive_bgm_player.stop()
	m_inactive_bgm_player.stream = stream
	m_inactive_bgm_player.volume_db = MIN_VOLUME_DB
	m_inactive_bgm_player.play()

	if animate and m_active_bgm_player.playing:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(m_active_bgm_player, "volume_db", MIN_VOLUME_DB, BGM_CROSSFADE_SECONDS)
		tween.tween_property(m_inactive_bgm_player, "volume_db", target_volume, BGM_CROSSFADE_SECONDS)
		tween.finished.connect(_swap_bgm_players, CONNECT_ONE_SHOT)
	else:
		m_active_bgm_player.stop()
		_swap_bgm_players()
		m_active_bgm_player.volume_db = target_volume

	m_current_bgm_id = requested_bgm_id


func _apply_sfx(audio_state: Dictionary) -> void:
	var requested_sfx_id := str(audio_state.get("sfx_id", "")).strip_edges()
	if requested_sfx_id.is_empty():
		return

	var stream := asset_library.get_sfx_stream(requested_sfx_id)
	if stream == null:
		return

	m_sfx_player.stream = stream
	m_sfx_player.play()


func _fade_out_active_bgm() -> void:
	if not m_active_bgm_player.playing:
		return

	var tween := create_tween()
	tween.tween_property(m_active_bgm_player, "volume_db", MIN_VOLUME_DB, BGM_CROSSFADE_SECONDS * 0.75)
	tween.tween_callback(Callable(m_active_bgm_player, "stop"))


func _swap_bgm_players() -> void:
	if m_active_bgm_player.playing:
		m_active_bgm_player.stop()

	var old_active := m_active_bgm_player
	m_active_bgm_player = m_inactive_bgm_player
	m_inactive_bgm_player = old_active


func _resolve_volume_db(volume_profile: String) -> float:
	match volume_profile:
		"quiet":
			return -10.0
		"quiet_tense":
			return -8.0
		"loud":
			return -2.0
		_:
			return 0.0


func _on_ui_button_hover() -> void:
	play_sfx("button_hover")


func _on_ui_button_down() -> void:
	play_sfx("button_down")


func _on_ui_button_up() -> void:
	play_sfx("button_up")
