extends CanvasLayer
class_name TutorialOverlay

signal closed

const CLOSE_BUTTON_HEIGHT := 24.0
const IMAGE_TO_BUTTON_GAP := 8.0

@export var orchestrator: Orchestrator
@export var image: Texture2D
@export var max_image_size: Vector2 = Vector2(880.0, 460.0)
@export var panel_padding: Vector2 = Vector2(32.0, 32.0)

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _click_blocker: Panel = $PopupRoot/ClickBlocker
@onready var _image_display: Sprite2D = $PopupRoot/ImageDisplay
@onready var _close_button: Button = $PopupRoot/CloseButton

## ----- Initialisation ----- ##

func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_refresh_layout()

## ----- Public API ----- ##

func open() -> void:
	if image == null:
		return
	GameFeedback.play_open_popup()
	_refresh_layout()
	show()

func close() -> void:
	if orchestrator and orchestrator.tutorial_bridge.active:
		if not orchestrator.tutorial_bridge.allows_action("close_tutorial"):
			return
	GameFeedback.play_close_popup()
	hide()
	closed.emit()
	if orchestrator:
		orchestrator.tutorial_bridge.notify("tutorial_closed")

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

func _refresh_layout() -> void:
	if image == null:
		_image_display.texture = null
		_image_display.scale = Vector2.ONE
		return

	_image_display.texture = image
	var image_size := _get_scaled_image_size(image)
	_image_display.scale = Vector2.ONE
	if image.get_size().x > 0.0 and image.get_size().y > 0.0:
		_image_display.scale = image_size / image.get_size()

	var close_width := maxf(_close_button.get_combined_minimum_size().x, 96.0)
	var close_size := Vector2(close_width, CLOSE_BUTTON_HEIGHT)
	var content_width := maxf(image_size.x, close_size.x)
	var panel_width := panel_padding.x * 2.0 + content_width
	var panel_height := panel_padding.y + image_size.y + IMAGE_TO_BUTTON_GAP + close_size.y + panel_padding.y

	_set_panel_rect(_popup_panel, panel_width, panel_height)
	_set_panel_rect(_click_blocker, panel_width, panel_height)

	var image_center_y := -panel_height / 2.0 + panel_padding.y + image_size.y / 2.0
	_image_display.position = Vector2(0.0, image_center_y)

	_set_control_rect(
		_close_button,
		Vector2(0.0, panel_height / 2.0 - panel_padding.y - close_size.y / 2.0),
		close_size
	)

## ----- Interactions ----- ##

func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close()

func _on_close_mouse_entered() -> void:
	GameFeedback.play_hover_button()

func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
