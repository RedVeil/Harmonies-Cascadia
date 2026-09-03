extends Area2D
class_name PlayCounter

@export var tooltip_text: String = "How many tiles you can still place."

var COLOR_BROWN := Color.html("#918478")

@onready var _label: Label = $Label
@onready var _tooltip: Panel = $Tooltip
@onready var _tooltip_label: Label = $Tooltip/Label

var _hovered := false
var _pinned := false
var _timer := 0.5


func _ready() -> void:
	input_pickable = true
	if _label:
		_label.add_theme_color_override("font_color", COLOR_BROWN)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tooltip_label:
		_tooltip_label.text = tooltip_text
	if _tooltip:
		_tooltip.hide()


func set_remaining(remaining: int) -> void:
	if remaining < 0:
		_clear_tooltip_state()
		hide()
		return
	var label := _label
	if label == null:
		label = get_node_or_null("Label") as Label
	if label:
		label.text = str(remaining)
	show()


func set_focus_hover(on: bool) -> void:
	if on:
		_on_mouse_entered()
	else:
		_on_mouse_exited()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not InputScheme.is_left_click(event):
		return
	if InputScheme.uses_touch_confirm():
		_toggle_tooltip_pin()


func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	GameFeedback.play_hover_button()
	_hovered = true
	_timer = 0.5
	if InputScheme.uses_touch_confirm():
		_show_tooltip()


func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	_hovered = false
	_timer = 0.5
	if not _pinned:
		_hide_tooltip()


func _toggle_tooltip_pin() -> void:
	_pinned = not _pinned
	if _pinned:
		_show_tooltip()
	elif not _hovered:
		_hide_tooltip()


func _process(delta: float) -> void:
	if not _hovered or _pinned:
		return
	if InputScheme.uses_touch_confirm():
		return
	_timer -= delta
	if _timer <= 0.0:
		_show_tooltip()


func _show_tooltip() -> void:
	if _tooltip:
		_tooltip.show()


func _hide_tooltip() -> void:
	if _tooltip:
		_tooltip.hide()


func _clear_tooltip_state() -> void:
	_hovered = false
	_pinned = false
	_timer = 0.5
	_hide_tooltip()
	UiPointerBlock.exit(self)
