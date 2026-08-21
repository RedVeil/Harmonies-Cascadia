extends Node
## Autoload: detects keyboard/mouse, touch, or gamepad and exposes the active scheme.

signal scheme_changed(scheme: Scheme)

enum Scheme { KEYBOARD_MOUSE, TOUCH, GAMEPAD }

const MOUSE_MOVE_THRESHOLD := 8.0
const JOY_DEADZONE := 0.45
const ACTION_DEADZONE := 0.5
## Godot emits an emulated mouse click just after ScreenTouch. That click must
## not steal the touch scheme or two-tap confirm is wiped on every tap.
const TOUCH_MOUSE_GRACE_MSEC := 500

var current: Scheme = Scheme.KEYBOARD_MOUSE
var touch: TouchConfirm = TouchConfirm.new()
var last_device_id: int = -1
var last_device_label: String = "none"

var _last_mouse_pos := Vector2.ZERO
var _mouse_pos_inited: bool = false
var _suppress_click: bool = false
var _ignore_mouse_motion_frames: int = 0
var _last_touch_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_actions()
	_apply_scheme(_detect_boot_scheme(), true)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	call_deferred("_deferred_joypad_scan")


func scheme_name(scheme: int = -1) -> String:
	if scheme < 0:
		scheme = current
	match scheme:
		Scheme.KEYBOARD_MOUSE:
			return "keyboard_mouse"
		Scheme.TOUCH:
			return "touch"
		Scheme.GAMEPAD:
			return "gamepad"
	return "unknown"


func is_keyboard_mouse() -> bool:
	return current == Scheme.KEYBOARD_MOUSE


func is_touch() -> bool:
	return current == Scheme.TOUCH


## True for real touch, emulated mouse-from-touch, and phones (clicks are still fingers).
func uses_touch_confirm() -> bool:
	if current == Scheme.TOUCH or _is_emulated_touch_mouse():
		return true
	var os_name := OS.get_name()
	return os_name == "Android" or os_name == "iOS"


func is_gamepad() -> bool:
	return current == Scheme.GAMEPAD


func joy_device() -> int:
	if last_device_id >= 0 and Input.get_connected_joypads().has(last_device_id):
		return last_device_id
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return -1
	last_device_id = pads[0]
	last_device_label = _joy_label(pads[0])
	return last_device_id


func mark_pointer_dragged() -> void:
	_suppress_click = true


func take_suppressed_click() -> bool:
	if not _suppress_click:
		return false
	_suppress_click = false
	return true


func is_left_click(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	if take_suppressed_click():
		return false
	return true


func _detect_boot_scheme() -> Scheme:
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		last_device_id = pads[0]
		last_device_label = _joy_label(pads[0])
		return Scheme.GAMEPAD
	var os_name := OS.get_name()
	if DisplayServer.is_touchscreen_available() and (os_name == "Android" or os_name == "iOS"):
		last_device_label = "touchscreen"
		return Scheme.TOUCH
	last_device_label = "keyboard_mouse"
	return Scheme.KEYBOARD_MOUSE


func _deferred_joypad_scan() -> void:
	if current != Scheme.GAMEPAD and not Input.get_connected_joypads().is_empty():
		_apply_scheme(Scheme.GAMEPAD, false)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if last_device_id < 0:
			last_device_id = device
			last_device_label = _joy_label(device)
		if current != Scheme.GAMEPAD:
			_apply_scheme(Scheme.GAMEPAD, false)
		return
	if last_device_id == device:
		var pads := Input.get_connected_joypads()
		if pads.is_empty():
			last_device_id = -1
			last_device_label = "none"
		else:
			last_device_id = pads[0]
			last_device_label = _joy_label(pads[0])
	if current == Scheme.GAMEPAD and Input.get_connected_joypads().is_empty():
		_apply_scheme(_detect_boot_scheme(), false)


func _input(event: InputEvent) -> void:
	var detected := _scheme_from_event(event)
	if detected >= 0:
		_event_reason(event)
		_apply_scheme(detected as Scheme, false)
	_notify_touch_press_release(event)
	if OverlayFocus.try_activate_event(get_viewport(), event):
		get_viewport().set_input_as_handled()


func _notify_touch_press_release(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touch.notify_press()
		else:
			touch.notify_release()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch.notify_press()
		else:
			touch.notify_mouse_up()


func _process(_delta: float) -> void:
	if _ignore_mouse_motion_frames > 0:
		_ignore_mouse_motion_frames -= 1


func _scheme_from_event(event: InputEvent) -> int:
	if event is InputEventJoypadButton and event.pressed:
		return Scheme.GAMEPAD
	if event is InputEventJoypadMotion and absf(event.axis_value) >= JOY_DEADZONE:
		return Scheme.GAMEPAD
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_last_touch_msec = Time.get_ticks_msec()
		return Scheme.TOUCH
	if event is InputEventKey and event.pressed and not event.echo:
		return Scheme.KEYBOARD_MOUSE
	if event is InputEventMouseButton:
		# Finger taps synthesize a left click; keep the touch scheme so sticky
		# two-tap confirm (preview, then take) survives the emulated mouse.
		if current == Scheme.TOUCH or _is_emulated_touch_mouse():
			return -1
		var os_name := OS.get_name()
		if os_name == "Android" or os_name == "iOS":
			return -1
		return Scheme.KEYBOARD_MOUSE
	if event is InputEventMouseMotion:
		if _ignore_mouse_motion_frames > 0:
			_last_mouse_pos = event.position
			_mouse_pos_inited = true
			return -1
		# Hidden-cursor warp and a sitting mouse must not steal gamepad/touch.
		if current != Scheme.KEYBOARD_MOUSE:
			_last_mouse_pos = event.position
			_mouse_pos_inited = true
			return -1
		if not _mouse_pos_inited:
			_last_mouse_pos = event.position
			_mouse_pos_inited = true
			return -1
		if event.position.distance_to(_last_mouse_pos) < MOUSE_MOVE_THRESHOLD:
			return -1
		_last_mouse_pos = event.position
		return Scheme.KEYBOARD_MOUSE
	return -1


func _is_emulated_touch_mouse() -> bool:
	return _last_touch_msec > 0 \
		and Time.get_ticks_msec() - _last_touch_msec < TOUCH_MOUSE_GRACE_MSEC


func _apply_scheme(scheme: Scheme, force: bool = false) -> void:
	if not force and scheme == current:
		return
	current = scheme
	touch.clear()
	_suppress_click = false
	_ignore_mouse_motion_frames = 12
	_apply_cursor()
	scheme_changed.emit(scheme)


func _apply_cursor() -> void:
	if current == Scheme.KEYBOARD_MOUSE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		Input.warp_mouse(Vector2(-64, -64))


func _register_actions() -> void:
	_ensure_action("focus_left", [
		_joy_button(JOY_BUTTON_DPAD_LEFT),
		_joy_axis(JOY_AXIS_LEFT_X, -1.0),
	])
	_ensure_action("focus_right", [
		_joy_button(JOY_BUTTON_DPAD_RIGHT),
		_joy_axis(JOY_AXIS_LEFT_X, 1.0),
	])
	_ensure_action("focus_up", [
		_joy_button(JOY_BUTTON_DPAD_UP),
		_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
	])
	_ensure_action("focus_down", [
		_joy_button(JOY_BUTTON_DPAD_DOWN),
		_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
	])
	_ensure_action("focus_region_next", [_joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	_ensure_action("focus_region_prev", [_joy_button(JOY_BUTTON_LEFT_SHOULDER)])
	_ensure_action("confirm", [_joy_button(JOY_BUTTON_A)])
	_ensure_action("cancel", [_joy_button(JOY_BUTTON_B)])
	_ensure_action("ui_accept", [_joy_button(JOY_BUTTON_A)])
	_ensure_action("ui_cancel", [_joy_button(JOY_BUTTON_B)])
	_ensure_action("ui_left", [
		_joy_button(JOY_BUTTON_DPAD_LEFT),
		_joy_axis(JOY_AXIS_LEFT_X, -1.0),
	])
	_ensure_action("ui_right", [
		_joy_button(JOY_BUTTON_DPAD_RIGHT),
		_joy_axis(JOY_AXIS_LEFT_X, 1.0),
	])
	_ensure_action("ui_up", [
		_joy_button(JOY_BUTTON_DPAD_UP),
		_joy_axis(JOY_AXIS_LEFT_Y, -1.0),
	])
	_ensure_action("ui_down", [
		_joy_button(JOY_BUTTON_DPAD_DOWN),
		_joy_axis(JOY_AXIS_LEFT_Y, 1.0),
	])
	_ensure_action("alt_action", [_joy_button(JOY_BUTTON_X)])
	_ensure_action("undo_action", [_joy_button(JOY_BUTTON_Y)])
	_ensure_action("open_menu", [_joy_button(JOY_BUTTON_START)])
	_ensure_action("camera_left", [_joy_axis(JOY_AXIS_RIGHT_X, -1.0)])
	_ensure_action("camera_right", [_joy_axis(JOY_AXIS_RIGHT_X, 1.0)])
	_ensure_action("camera_up", [_joy_axis(JOY_AXIS_RIGHT_Y, -1.0)])
	_ensure_action("camera_down", [_joy_axis(JOY_AXIS_RIGHT_Y, 1.0)])
	_ensure_action("zoom_in", [_joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	_ensure_action("zoom_out", [_joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])


func _ensure_action(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, ACTION_DEADZONE)
	for event in events:
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _joy_button(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button_index
	return event


func _joy_axis(axis: int, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = axis_value
	return event


func _event_reason(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		last_device_id = event.device
		last_device_label = _joy_label(event.device)
	elif event is InputEventJoypadMotion:
		last_device_id = event.device
		last_device_label = _joy_label(event.device)
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_device_label = "touchscreen"
	elif event is InputEventKey:
		last_device_label = "keyboard"
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		last_device_label = "mouse"


func _joy_label(device: int) -> String:
	var joy_name := Input.get_joy_name(device)
	if joy_name.is_empty():
		joy_name = "unknown"
	var guid := Input.get_joy_guid(device)
	if guid.is_empty():
		return "%s#%s" % [joy_name, device]
	return "%s#%s guid=%s" % [joy_name, device, guid]
