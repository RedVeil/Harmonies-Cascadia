extends Camera3D

@export var move_speed: float = 12.0


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

	# Move only along the horizontal plane while keeping fixed isometric rotation.
	var right := global_basis.x
	var forward := -global_basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()

	var move_direction := (right * input_vector.x) + (forward * input_vector.y)
	global_position += move_direction * move_speed * delta
