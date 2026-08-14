extends Node
## Autoload: touch vs mouse control mode.
## Do not treat every touchscreen-capable desktop as touch-primary —
## Windows often reports a touchscreen even when using a mouse.

const EMULATED_MOUSE_MS := 80

var _touch_controls: bool = false
var _last_screen_touch_msec: int = -99999


func _ready() -> void:
	# Phones/tablets start in touch mode; desktop starts in mouse mode
	# even if a touchscreen is present.
	_touch_controls = OS.has_feature("mobile")


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_touch_controls = true
		_last_screen_touch_msec = Time.get_ticks_msec()
		return
	if event is InputEventMouseButton and event.pressed:
		# Ignore emulated mouse clicks that immediately follow a screen touch.
		if Time.get_ticks_msec() - _last_screen_touch_msec > EMULATED_MOUSE_MS:
			_touch_controls = false


func is_touch() -> bool:
	return _touch_controls


func is_emulated_mouse_event(event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	return Time.get_ticks_msec() - _last_screen_touch_msec <= EMULATED_MOUSE_MS


func clear_stuck_gui_hover() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.gui_release_focus()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(-10000, -10000)
	motion.global_position = Vector2(-10000, -10000)
	vp.push_input(motion)
