extends Camera3D

@export var move_speed: float = 12.0
@export var zoom_speed: float = 2.0
@export var zoom_min: float = 10.0
@export var zoom_max: float = 80.0
@export var touch_drag_threshold: float = 12.0
@export var trigger_zoom_speed: float = 36.0
@export var focus_follow_speed: float = 10.0
@export var stick_deadzone: float = 0.28

var _touches: Dictionary = {} # index -> Vector2
var _pan_index: int = -1
var _pan_last := Vector2.ZERO
var _panning: bool = false
var _touch_on_hud: bool = false
var _pinch_distance: float = 0.0
var _focus_target := Vector3.ZERO
var _has_focus_target: bool = false
var _stick_ready: bool = false
var _stick_device: int = -1


## ----- Camera Input ----- ##

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var zoom_delta := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_delta = -zoom_speed * event.factor
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_delta = zoom_speed * event.factor
	else:
		return
	size = clampf(size + zoom_delta, zoom_min, zoom_max)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch_camera(event)


func _handle_touch_camera(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				_pan_index = event.index
				_pan_last = event.position
				_panning = false
				_touch_on_hud = UiPointerBlock.is_blocked()
			elif _touches.size() >= 2:
				_pinch_distance = _current_pinch_distance()
				_panning = false
				InputScheme.mark_pointer_dragged()
		else:
			_touches.erase(event.index)
			if event.index == _pan_index:
				_pan_index = -1
				_panning = false
			if _touches.size() < 2:
				_pinch_distance = 0.0
		return

	if event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var dist := _current_pinch_distance()
			if _pinch_distance > 0.0 and dist > 0.0:
				var ratio := _pinch_distance / dist
				size = clampf(size * ratio, zoom_min, zoom_max)
				InputScheme.mark_pointer_dragged()
			_pinch_distance = dist
			get_viewport().set_input_as_handled()
			return
		if _touch_on_hud or _pan_index != event.index:
			return
		var delta: Vector2 = event.position - _pan_last
		if not _panning:
			if delta.length() < touch_drag_threshold:
				return
			_panning = true
			InputScheme.mark_pointer_dragged()
		_pan_from_screen(_pan_last, event.position)
		_pan_last = event.position
		get_viewport().set_input_as_handled()


func _current_pinch_distance() -> float:
	if _touches.size() < 2:
		return 0.0
	var pts: Array = _touches.values()
	return pts[0].distance_to(pts[1])


func _pan_from_screen(from_screen: Vector2, to_screen: Vector2) -> void:
	var ground := Plane(Vector3.UP, 0.0)
	var hit0 = ground.intersects_ray(project_ray_origin(from_screen), project_ray_normal(from_screen))
	var hit1 = ground.intersects_ray(project_ray_origin(to_screen), project_ray_normal(to_screen))
	if hit0 == null or hit1 == null:
		return
	global_position += hit0 - hit1


func _move_on_ground_plane(input_vector: Vector2) -> void:
	if input_vector == Vector2.ZERO:
		return
	var right := global_basis.x
	var forward := -global_basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	var move_direction := (right * input_vector.x) + (forward * input_vector.y)
	global_position += move_direction


func _gamepad_move_vector() -> Vector2:
	var device := InputScheme.joy_device()
	if device < 0:
		_stick_ready = false
		_stick_device = -1
		return Vector2.ZERO
	if device != _stick_device:
		_stick_device = device
		_stick_ready = false
	var raw := Vector2(
		Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
		-Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
	)
	if raw.length() <= stick_deadzone:
		_stick_ready = true
		return Vector2.ZERO
	if not _stick_ready:
		return Vector2.ZERO
	return _apply_circular_deadzone(raw, stick_deadzone)


func _gamepad_zoom_axis() -> float:
	var device := InputScheme.joy_device()
	if device < 0:
		return 0.0
	var zoom_out := maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT))
	var zoom_in := maxf(0.0, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))
	return zoom_out - zoom_in


func _apply_circular_deadzone(raw: Vector2, deadzone: float) -> Vector2:
	var length := raw.length()
	if length <= deadzone:
		return Vector2.ZERO
	var scaled := minf(1.0, (length - deadzone) / (1.0 - deadzone))
	return raw * (scaled / length)


func ensure_world_visible(world: Vector3, margin: float = 96.0) -> void:
	var screen := unproject_position(world)
	var rect := get_viewport().get_visible_rect().grow(-margin)
	if rect.has_point(screen):
		_has_focus_target = false
		return
	_focus_target = world
	_has_focus_target = true


## ----- Camera Movement ----- ##

func _process(delta: float) -> void:
	if _has_focus_target:
		_follow_focus_target(delta)

	var input_vector := Vector2.ZERO
	if InputScheme.is_keyboard_mouse():
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_vector.y += 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_vector.y -= 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_vector.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_vector.x += 1.0
	elif InputScheme.is_gamepad():
		input_vector = _gamepad_move_vector()
		var zoom := _gamepad_zoom_axis()
		if absf(zoom) > 0.05:
			size = clampf(size + zoom * trigger_zoom_speed * delta, zoom_min, zoom_max)

	if input_vector == Vector2.ZERO:
		return
	_move_on_ground_plane(input_vector * move_speed * delta)


func _follow_focus_target(delta: float) -> void:
	var screen := unproject_position(_focus_target)
	var rect := get_viewport().get_visible_rect()
	var margin := 96.0
	var inner := rect.grow(-margin)
	if inner.has_point(screen):
		_has_focus_target = false
		return
	var clamped := Vector2(
		clampf(screen.x, inner.position.x, inner.end.x),
		clampf(screen.y, inner.position.y, inner.end.y)
	)
	_pan_from_screen(clamped, clamped.lerp(screen, clampf(focus_follow_speed * delta, 0.0, 1.0)))
