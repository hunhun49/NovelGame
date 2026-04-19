extends Control
class_name ImageCropperPopup

signal crop_applied(cropped_image: Image)
signal closed

const DEFAULT_TARGET_WIDTH := 1024
const DEFAULT_TARGET_HEIGHT := 1536
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.0

@onready var m_title_label: Label = $Dimmer/Panel/Margin/VBox/Header/TitleLabel
@onready var m_source_info_label: Label = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/ControlColumn/SourceInfoLabel
@onready var m_help_label: Label = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/ControlColumn/HelpLabel
@onready var m_crop_area: Control = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/CropColumn/CropFrame/CropArea
@onready var m_image_rect: TextureRect = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/CropColumn/CropFrame/CropArea/ImageRect
@onready var m_zoom_out_button: Button = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/ControlColumn/ZoomRow/ZoomOutButton
@onready var m_zoom_slider: HSlider = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/ControlColumn/ZoomRow/ZoomSlider
@onready var m_zoom_in_button: Button = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/ControlColumn/ZoomRow/ZoomInButton
@onready var m_zoom_value_label: Label = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/ControlColumn/ZoomValueLabel
@onready var m_reset_button: Button = $Dimmer/Panel/Margin/VBox/BodyScroll/Body/ControlColumn/ResetButton
@onready var m_cancel_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/CancelButton
@onready var m_apply_button: Button = $Dimmer/Panel/Margin/VBox/FooterButtons/ApplyButton

var m_source_image: Image
var m_source_texture: Texture2D
var m_source_path := ""
var m_base_scale := 1.0
var m_zoom := 1.0
var m_image_offset := Vector2.ZERO
var m_drag_active := false
var m_target_width := DEFAULT_TARGET_WIDTH
var m_target_height := DEFAULT_TARGET_HEIGHT


func _ready() -> void:
	visible = false
	m_title_label.text = "프로필 이미지 자르기"
	m_zoom_slider.min_value = MIN_ZOOM
	m_zoom_slider.max_value = MAX_ZOOM
	m_zoom_slider.step = 0.01
	m_zoom_slider.value = MIN_ZOOM
	m_zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	m_zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	m_zoom_slider.value_changed.connect(_on_zoom_changed)
	m_reset_button.pressed.connect(_on_reset_pressed)
	m_cancel_button.pressed.connect(_on_cancel_pressed)
	m_apply_button.pressed.connect(_on_apply_pressed)
	m_crop_area.gui_input.connect(_on_crop_area_gui_input)
	m_crop_area.resized.connect(_on_crop_area_resized)
	m_image_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	audio_manager.wire_button_sounds(self)


func open_with_image(p_image: Image, p_source_path: String, p_target_width: int = DEFAULT_TARGET_WIDTH, p_target_height: int = DEFAULT_TARGET_HEIGHT) -> void:
	m_source_image = p_image.duplicate()
	m_source_texture = ImageTexture.create_from_image(m_source_image)
	m_source_path = p_source_path
	m_target_width = p_target_width
	m_target_height = p_target_height
	m_image_rect.texture = m_source_texture
	m_source_info_label.text = "%s\n원본 해상도: %d x %d\n결과 해상도: %d x %d" % [
		p_source_path.get_file(),
		m_source_image.get_width(),
		m_source_image.get_height(),
		m_target_width,
		m_target_height
	]
	m_help_label.text = "표시된 프레임 영역이 최종 이미지로 저장됩니다. 적용하면 %d x %d PNG로 저장됩니다." % [m_target_width, m_target_height]
	visible = true
	call_deferred("_reset_view")


func _reset_view() -> void:
	if m_source_image == null or m_source_image.is_empty():
		return
	var m_crop_size := _get_crop_size()
	if m_crop_size.x <= 0.0 or m_crop_size.y <= 0.0:
		return

	m_zoom = MIN_ZOOM
	m_zoom_slider.set_value_no_signal(m_zoom)
	m_base_scale = maxf(
		m_crop_size.x / float(m_source_image.get_width()),
		m_crop_size.y / float(m_source_image.get_height())
	)
	_center_image()
	_apply_transform()


func _center_image() -> void:
	var m_crop_size := _get_crop_size()
	var m_displayed_size := _get_displayed_size(m_zoom)
	m_image_offset = (m_crop_size - m_displayed_size) * 0.5
	_clamp_offset()


func _get_crop_size() -> Vector2:
	return m_crop_area.size


func _get_displayed_size(p_zoom_value: float) -> Vector2:
	if m_source_image == null or m_source_image.is_empty():
		return Vector2.ZERO
	var m_total_scale := m_base_scale * p_zoom_value
	return Vector2(
		float(m_source_image.get_width()) * m_total_scale,
		float(m_source_image.get_height()) * m_total_scale
	)


func _apply_transform() -> void:
	m_image_rect.position = m_image_offset
	m_image_rect.size = _get_displayed_size(m_zoom)
	m_zoom_value_label.text = "줌 %.0f%%" % (m_zoom * 100.0)


func _clamp_offset() -> void:
	var m_crop_size := _get_crop_size()
	var m_displayed_size := _get_displayed_size(m_zoom)
	if m_displayed_size.x <= m_crop_size.x:
		m_image_offset.x = (m_crop_size.x - m_displayed_size.x) * 0.5
	else:
		m_image_offset.x = clampf(m_image_offset.x, m_crop_size.x - m_displayed_size.x, 0.0)

	if m_displayed_size.y <= m_crop_size.y:
		m_image_offset.y = (m_crop_size.y - m_displayed_size.y) * 0.5
	else:
		m_image_offset.y = clampf(m_image_offset.y, m_crop_size.y - m_displayed_size.y, 0.0)


func _adjust_zoom(p_delta: float) -> void:
	var m_new_zoom := clampf(m_zoom + p_delta, MIN_ZOOM, MAX_ZOOM)
	m_zoom_slider.value = m_new_zoom


func _on_zoom_out_pressed() -> void:
	_adjust_zoom(-0.1)


func _on_zoom_in_pressed() -> void:
	_adjust_zoom(0.1)


func _on_zoom_changed(p_value: float) -> void:
	if m_source_image == null or m_source_image.is_empty():
		return

	var m_crop_center := _get_crop_size() * 0.5
	var m_old_scale := m_base_scale * m_zoom
	var m_focus_point := (m_crop_center - m_image_offset) / m_old_scale
	m_zoom = p_value
	var m_new_scale := m_base_scale * m_zoom
	m_image_offset = m_crop_center - m_focus_point * m_new_scale
	_clamp_offset()
	_apply_transform()


func _on_reset_pressed() -> void:
	_reset_view()


func _on_cancel_pressed() -> void:
	visible = false
	closed.emit()


func _on_apply_pressed() -> void:
	if m_source_image == null or m_source_image.is_empty():
		return

	var m_total_scale := m_base_scale * m_zoom
	var m_crop_size := _get_crop_size()
	var m_src_x := maxi(int(round(-m_image_offset.x / m_total_scale)), 0)
	var m_src_y := maxi(int(round(-m_image_offset.y / m_total_scale)), 0)
	var m_src_w := maxi(int(round(m_crop_size.x / m_total_scale)), 1)
	var m_src_h := maxi(int(round(m_crop_size.y / m_total_scale)), 1)

	m_src_w = mini(m_src_w, m_source_image.get_width() - m_src_x)
	m_src_h = mini(m_src_h, m_source_image.get_height() - m_src_y)

	var m_cropped_image := m_source_image.get_region(Rect2i(m_src_x, m_src_y, m_src_w, m_src_h))
	m_cropped_image.resize(m_target_width, m_target_height, Image.INTERPOLATE_LANCZOS)
	visible = false
	crop_applied.emit(m_cropped_image)


func _on_crop_area_gui_input(p_event: InputEvent) -> void:
	if m_source_image == null or m_source_image.is_empty():
		return

	if p_event is InputEventMouseButton:
		var m_mouse_event := p_event as InputEventMouseButton
		match m_mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				m_drag_active = m_mouse_event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if m_mouse_event.pressed:
					_adjust_zoom(0.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if m_mouse_event.pressed:
					_adjust_zoom(-0.1)
	elif p_event is InputEventMouseMotion and m_drag_active:
		var m_motion_event := p_event as InputEventMouseMotion
		m_image_offset += m_motion_event.relative
		_clamp_offset()
		_apply_transform()


func _on_crop_area_resized() -> void:
	if visible:
		_reset_view()
