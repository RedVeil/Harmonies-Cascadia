extends CanvasLayer
class_name TutorialOverlay

var COLOR_BROWN := Color.html("#918478")
const NAV_BUTTON_SIZE := Vector2(36.0, 36.0)
const CLOSE_BUTTON_SIZE := Vector2(32.0, 36.0)
const NAV_GAP := 20.0
const CLOSE_ROW_HEIGHT := 36.0
const IMAGE_TO_NAV_GAP := 8.0

@export var slides: Array[Texture2D] = []
@export var max_image_size: Vector2 = Vector2(880.0, 460.0)
@export var panel_padding: Vector2 = Vector2(32.0, 32.0)

var _current_index: int = 0

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _click_blocker: Panel = $PopupRoot/ClickBlocker
@onready var _image_display: Sprite2D = $PopupRoot/ImageDisplay
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _nav_buttons: Node2D = $PopupRoot/NavButtons
@onready var _previous_button: Control = $PopupRoot/NavButtons/PreviousButton
@onready var _next_button: Control = $PopupRoot/NavButtons/NextButton

## ----- Initialisation ----- ##

func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_set_nav_button_hover(_previous_button, false)
	_set_nav_button_hover(_next_button, false)
	_refresh_slide()

## ----- Public API ----- ##

func open() -> void:
	if slides.is_empty():
		return
	_current_index = 0
	_refresh_slide()
	show()

func close() -> void:
	hide()

func show_slide(index: int) -> void:
	if slides.is_empty():
		return
	_current_index = clampi(index, 0, slides.size() - 1)
	_refresh_slide()

## ----- Layout ----- ##

func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0

func _get_scaled_image_size(texture: Texture2D) -> Vector2:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO
	var scale_factor := minf(
		max_image_size.x / texture_size.x,
		max_image_size.y / texture_size.y
	)
	return texture_size * scale_factor

func _set_panel_rect(panel: Panel, width: float, height: float) -> void:
	panel.offset_left = -width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_right = width / 2.0
	panel.offset_bottom = height / 2.0

func _set_control_rect(control: Control, center: Vector2, size: Vector2) -> void:
	control.offset_left = center.x - size.x / 2.0
	control.offset_top = center.y - size.y / 2.0
	control.offset_right = center.x + size.x / 2.0
	control.offset_bottom = center.y + size.y / 2.0

func _refresh_slide() -> void:
	if slides.is_empty():
		_image_display.texture = null
		_image_display.scale = Vector2.ONE
		return

	var texture := slides[_current_index]
	_image_display.texture = texture
	var image_size := _get_scaled_image_size(texture)
	_image_display.scale = Vector2.ONE
	if texture.get_size().x > 0.0 and texture.get_size().y > 0.0:
		_image_display.scale = image_size / texture.get_size()

	var nav_row_width := NAV_BUTTON_SIZE.x * 2.0 + NAV_GAP
	var content_width := maxf(image_size.x, nav_row_width)
	var panel_width := panel_padding.x * 2.0 + content_width
	var panel_height := CLOSE_ROW_HEIGHT + image_size.y + IMAGE_TO_NAV_GAP + NAV_BUTTON_SIZE.y + IMAGE_TO_NAV_GAP

	_set_panel_rect(_popup_panel, panel_width, panel_height)
	_set_panel_rect(_click_blocker, panel_width, panel_height)

	var image_center_y := -panel_height / 2.0 + CLOSE_ROW_HEIGHT + image_size.y / 2.0
	_image_display.position = Vector2(0.0, image_center_y)

	_set_control_rect(
		_close_button,
		Vector2(
			panel_width / 2.0 - panel_padding.x - CLOSE_BUTTON_SIZE.x / 2.0,
			-panel_height / 2.0 + CLOSE_ROW_HEIGHT / 2.0
		),
		CLOSE_BUTTON_SIZE
	)

	var nav_center_y := panel_height / 2.0 - IMAGE_TO_NAV_GAP - NAV_BUTTON_SIZE.y / 2.0
	_nav_buttons.position = Vector2(0.0, nav_center_y)

	var show_previous := _current_index > 0
	_previous_button.visible = show_previous

	if show_previous:
		_set_control_rect(
			_previous_button,
			Vector2(-NAV_BUTTON_SIZE.x / 2.0 - NAV_GAP / 2.0, 0.0),
			NAV_BUTTON_SIZE
		)
		_set_control_rect(
			_next_button,
			Vector2(NAV_BUTTON_SIZE.x / 2.0 + NAV_GAP / 2.0, 0.0),
			NAV_BUTTON_SIZE
		)
	else:
		_set_control_rect(_next_button, Vector2.ZERO, NAV_BUTTON_SIZE)

## ----- Navigation ----- ##

func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close()

func _on_previous_pressed() -> void:
	if _current_index <= 0:
		return
	GameFeedback.play_click_button()
	_current_index -= 1
	_refresh_slide()

func _on_next_pressed() -> void:
	GameFeedback.play_click_button()
	if _current_index >= slides.size() - 1:
		close()
	else:
		_current_index += 1
		_refresh_slide()

## ----- Button Hover ----- ##

func _on_close_mouse_entered() -> void:
	_close_button.get_node("Label").add_theme_color_override("font_color", Color.WHITE)

func _on_close_mouse_exited() -> void:
	_close_button.get_node("Label").add_theme_color_override("font_color", COLOR_BROWN)

func _on_previous_mouse_entered() -> void:
	_set_nav_button_hover(_previous_button, true)

func _on_previous_mouse_exited() -> void:
	_set_nav_button_hover(_previous_button, false)

func _on_next_mouse_entered() -> void:
	_set_nav_button_hover(_next_button, true)

func _on_next_mouse_exited() -> void:
	_set_nav_button_hover(_next_button, false)

func _set_nav_button_hover(button: Control, hovered: bool) -> void:
	var background: TextureRect = button.get_node("Background")
	var icon: Label = button.get_node("Icon")
	if hovered:
		background.self_modulate = COLOR_BROWN
		icon.add_theme_color_override("font_color", Color.WHITE)
	else:
		background.self_modulate = Color.WHITE
		icon.add_theme_color_override("font_color", COLOR_BROWN)

func _handle_gui_click(event: InputEvent, callback: Callable) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			callback.call()
			get_viewport().set_input_as_handled()

func _on_close_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_close_pressed)

func _on_previous_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_previous_pressed)

func _on_next_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_next_pressed)

func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
