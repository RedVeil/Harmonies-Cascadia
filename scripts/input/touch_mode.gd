extends Node
## Autoload: touch vs mouse control mode.
## Do not treat every touchscreen-capable desktop as touch-primary —
## Windows often reports a touchscreen even when using a mouse.

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
		if Time.get_ticks_msec() - _last_screen_touch_msec > 80:
			_touch_controls = false


func is_touch() -> bool:
	return _touch_controls
