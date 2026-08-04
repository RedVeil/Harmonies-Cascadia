extends Camera3D

@export var move_speed: float = 12.0
@export var zoom_speed: float = 2.0
@export var zoom_min: float = 10.0
@export var zoom_max: float = 80.0
## Screen pixels of midpoint drag per world unit of pan (higher = slower pan).
@export var touch_pan_pixels_per_unit: float = 40.0
## Pinch distance change (px) scaled into orthographic size.
@export var touch_pinch_zoom_factor: float = 0.05

var _active_touches: Dictionary = {} # index -> Vector2 screen position
var _pinch_start_distance: float = 0.0
var _pinch_start_size: float = 0.0

## ----- Camera Input ----- ##

func _unhandled_input(event: InputEvent) -> void:
	if _handle_touch_gesture(event):
		get_viewport().set_input_as_handled()
		return

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


func _handle_touch_gesture(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_active_touches[touch.index] = touch.position
			if _active_touches.size() == 2:
				_begin_two_finger_gesture()
		else:
			_active_touches.erase(touch.index)
			if _active_touches.size() < 2:
				_pinch_start_distance = 0.0
		return _active_touches.size() >= 2 or touch.index > 0

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _active_touches.has(drag.index):
			return false
		var previous_touches := _active_touches.duplicate()
		_active_touches[drag.index] = drag.position
		if _active_touches.size() == 2:
			_apply_two_finger_gesture(previous_touches)
			return true
		return false

	return false


func _begin_two_finger_gesture() -> void:
	var positions := _touch_positions()
	if positions.size() < 2:
		return
	_pinch_start_distance = positions[0].distance_to(positions[1])
	_pinch_start_size = size


func _apply_two_finger_gesture(previous_touches: Dictionary) -> void:
	var prev_positions := _dict_positions(previous_touches)
	var positions := _touch_positions()
	if prev_positions.size() < 2 or positions.size() < 2:
		return

	var prev_mid := (prev_positions[0] + prev_positions[1]) * 0.5
	var new_mid := (positions[0] + positions[1]) * 0.5
	_pan_by_screen_delta(new_mid - prev_mid)

	var current_distance := positions[0].distance_to(positions[1])
	if _pinch_start_distance > 0.0:
		var distance_delta := current_distance - _pinch_start_distance
		size = clampf(
			_pinch_start_size - distance_delta * touch_pinch_zoom_factor,
			zoom_min,
			zoom_max
		)


func _touch_positions() -> Array[Vector2]:
	return _dict_positions(_active_touches)


func _dict_positions(touches: Dictionary) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for pos in touches.values():
		positions.append(pos)
	return positions


func _pan_by_screen_delta(screen_delta: Vector2) -> void:
	if screen_delta == Vector2.ZERO:
		return
	# Drag direction inverted so the board follows the fingers.
	var input_vector := Vector2(-screen_delta.x, screen_delta.y) / touch_pan_pixels_per_unit
	_move_on_ground_plane(input_vector)


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

## ----- Camera Movement ----- ##

func _process(delta: float) -> void:
	var input_vector := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1.0

	if input_vector == Vector2.ZERO:
		return

	input_vector = input_vector.normalized()
	_move_on_ground_plane(input_vector * move_speed * delta)
