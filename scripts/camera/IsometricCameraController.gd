extends Camera3D

@export var move_speed: float = 12.0
@export var zoom_speed: float = 2.0
@export var zoom_min: float = 10.0
@export var zoom_max: float = 80.0

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

	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_vector.y += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_vector.y -= 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1.0

	if input_vector == Vector2.ZERO:
		return

	input_vector = input_vector.normalized()
	_move_on_ground_plane(input_vector * move_speed * delta)
