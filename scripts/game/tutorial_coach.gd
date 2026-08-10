extends CanvasLayer
class_name TutorialCoach
## Presentation-only coach: hole-punch dimmer, spotlight frame, text bubble.

signal continue_pressed
signal skip_pressed
signal tip_pressed

var COLOR_CREAM := Color.html("#F4DFCA")
var COLOR_BROWN := Color.html("#918478")
const DIM_COLOR := Color(0, 0, 0, 0.45)

@onready var _dim_top: ColorRect = $DimmerRoot/DimTop
@onready var _dim_bottom: ColorRect = $DimmerRoot/DimBottom
@onready var _dim_left: ColorRect = $DimmerRoot/DimLeft
@onready var _dim_right: ColorRect = $DimmerRoot/DimRight
@onready var _spotlight: Panel = $Spotlight
@onready var _bubble: Panel = $Bubble
@onready var _title: Label = $Bubble/Margin/VBox/Title
@onready var _body: Label = $Bubble/Margin/VBox/Body
@onready var _continue_button: Button = $Bubble/Margin/VBox/ButtonRow/ContinueButton
@onready var _tip_button: Button = $Bubble/Margin/VBox/ButtonRow/TipButton
@onready var _skip_button: Button = $Bubble/Margin/VBox/ButtonRow/SkipButton

var _highlight_rect: Rect2 = Rect2()


func _ready() -> void:
	layer = 12
	hide()
	for dim in [_dim_top, _dim_bottom, _dim_left, _dim_right]:
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.color = DIM_COLOR
	_spotlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_button.pressed.connect(_on_continue)
	_tip_button.pressed.connect(_on_tip)
	_skip_button.pressed.connect(_on_skip)
	for button in [_continue_button, _tip_button, _skip_button]:
		button.mouse_entered.connect(_on_button_mouse_entered)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_button_mouse_entered() -> void:
	GameFeedback.play_hover_button()


func show_step(step: Dictionary, highlight_rect: Rect2, show_continue: bool, tip_available: bool) -> void:
	_title.text = str(step.get("title", ""))
	_body.text = str(step.get("body", ""))
	_continue_button.visible = show_continue
	_tip_button.visible = tip_available
	_highlight_rect = highlight_rect
	_apply_spotlight(highlight_rect)
	_place_bubble(highlight_rect)
	show()


func hide_coach() -> void:
	hide()


func _apply_spotlight(rect: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		_spotlight.hide()
		# Full-screen dim when there is no hole.
		_set_dim_rects(Rect2(0, 0, vp.x, 0))
		return

	var hole := Rect2(rect.position - Vector2(8, 8), rect.size + Vector2(16, 16))
	hole.position.x = clampf(hole.position.x, 0.0, vp.x)
	hole.position.y = clampf(hole.position.y, 0.0, vp.y)
	hole.size.x = clampf(hole.size.x, 0.0, vp.x - hole.position.x)
	hole.size.y = clampf(hole.size.y, 0.0, vp.y - hole.position.y)

	_spotlight.show()
	_spotlight.position = hole.position
	_spotlight.size = hole.size
	_set_dim_rects(hole)


## Lay out four dim strips around the hole so the highlight stays undimmed
## and has no Control covering it (input reaches the game underneath).
func _set_dim_rects(hole: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size
	# Top
	_dim_top.position = Vector2.ZERO
	_dim_top.size = Vector2(vp.x, maxf(hole.position.y, 0.0))
	# Bottom
	var bottom_y := hole.position.y + hole.size.y
	_dim_bottom.position = Vector2(0.0, bottom_y)
	_dim_bottom.size = Vector2(vp.x, maxf(vp.y - bottom_y, 0.0))
	# Left (middle band only)
	_dim_left.position = Vector2(0.0, hole.position.y)
	_dim_left.size = Vector2(maxf(hole.position.x, 0.0), hole.size.y)
	# Right (middle band only)
	var right_x := hole.position.x + hole.size.x
	_dim_right.position = Vector2(right_x, hole.position.y)
	_dim_right.size = Vector2(maxf(vp.x - right_x, 0.0), hole.size.y)


func _place_bubble(highlight_rect: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var bubble_size := Vector2(360, 200)
	_bubble.custom_minimum_size = bubble_size
	var pos := Vector2((vp.x - bubble_size.x) * 0.5, vp.y - bubble_size.y - 24.0)
	if highlight_rect.size.x > 1.0:
		var above := highlight_rect.position.y - bubble_size.y - 16.0
		if above > 16.0:
			pos = Vector2(
				clampf(highlight_rect.get_center().x - bubble_size.x * 0.5, 16.0, vp.x - bubble_size.x - 16.0),
				above
			)
		else:
			var below := highlight_rect.end.y + 16.0
			if below + bubble_size.y < vp.y - 16.0:
				pos = Vector2(
					clampf(highlight_rect.get_center().x - bubble_size.x * 0.5, 16.0, vp.x - bubble_size.x - 16.0),
					below
				)
	_bubble.position = pos
	_bubble.size = bubble_size


func _on_viewport_resized() -> void:
	if not visible:
		return
	_apply_spotlight(_highlight_rect)
	_place_bubble(_highlight_rect)


func _on_continue() -> void:
	GameFeedback.play_click_button()
	continue_pressed.emit()


func _on_tip() -> void:
	GameFeedback.play_click_button()
	tip_pressed.emit()


func _on_skip() -> void:
	GameFeedback.play_click_button()
	skip_pressed.emit()
