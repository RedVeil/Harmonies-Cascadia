class_name FeedbackAnimHelper

## Shared tween lifecycle for scene-local feedback animations.

## ----- Tween Lifecycle ----- ##

static func set_tween(tweens: Dictionary, key: StringName, tween: Tween) -> void:
	if tweens.has(key):
		var existing: Tween = tweens[key]
		if existing.is_valid():
			existing.kill()
	tweens[key] = tween

static func kill_all(tweens: Dictionary) -> void:
	for key in tweens.keys():
		var tween: Tween = tweens[key]
		if tween.is_valid():
			tween.kill()
	tweens.clear()

static func create_tween(
	host: Node,
	tweens: Dictionary,
	key: StringName,
	parallel: bool = false
) -> Tween:
	var tween := host.create_tween()
	if parallel:
		tween.set_parallel(true)
	set_tween(tweens, key, tween)
	return tween

static func play_sounds(sounds: Array[AudioStream], volume_db: float = 0.0) -> void:
	if sounds.is_empty():
		return
	GameFeedback.play_sounds(sounds, volume_db)


## Scale punch: snap from `start_scale` through `peak_scale`, then settle on `rest_scale`.
## `t` runs 0 to 1 across `up_duration` + `settle_duration`.
static func pop_scale(
	t: float,
	start_scale: float,
	peak_scale: float,
	rest_scale: float,
	up_duration: float,
	settle_duration: float
) -> float:
	var total := up_duration + settle_duration
	if total <= 0.0:
		return rest_scale
	var elapsed := clampf(t, 0.0, 1.0) * total
	if elapsed <= up_duration:
		return Tween.interpolate_value(
			start_scale,
			peak_scale - start_scale,
			elapsed,
			up_duration,
			Tween.TRANS_BACK,
			Tween.EASE_OUT
		)
	return Tween.interpolate_value(
		peak_scale,
		rest_scale - peak_scale,
		elapsed - up_duration,
		settle_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)


## Place / contributor bounce. `t` runs 0 to 1 across rise + land + spring.
## Yaw on `node` is kept; rumble is applied around it.
static func apply_celebrate_pose(
	node: Node3D,
	t: float,
	lift: float,
	stretch: Vector3,
	squash: Vector3,
	rise_duration: float,
	land_duration: float,
	spring_duration: float,
	rumble_distance: float,
	rumble_degrees: float,
	rumble_cycles: float
) -> void:
	if node == null or not is_instance_valid(node):
		return
	var total := rise_duration + land_duration + spring_duration
	if total <= 0.0:
		return
	var elapsed := t * total
	var y := 0.0
	var visual_scale := Vector3.ONE
	if elapsed <= rise_duration:
		y = Tween.interpolate_value(0.0, lift, elapsed, rise_duration, Tween.TRANS_QUAD, Tween.EASE_OUT)
		visual_scale = Tween.interpolate_value(Vector3.ONE, stretch - Vector3.ONE, elapsed, rise_duration, Tween.TRANS_BACK, Tween.EASE_OUT)
	elif elapsed <= rise_duration + land_duration:
		var land_elapsed := elapsed - rise_duration
		y = Tween.interpolate_value(lift, -lift, land_elapsed, land_duration, Tween.TRANS_QUAD, Tween.EASE_IN)
		visual_scale = Tween.interpolate_value(stretch, squash - stretch, land_elapsed, land_duration, Tween.TRANS_QUAD, Tween.EASE_IN)
	else:
		var spring_elapsed := elapsed - rise_duration - land_duration
		visual_scale = Tween.interpolate_value(squash, Vector3.ONE - squash, spring_elapsed, spring_duration, Tween.TRANS_BACK, Tween.EASE_OUT)

	var rumble_start := rise_duration
	var shove := Vector2.ZERO
	var rock := Vector2.ZERO
	if elapsed > rumble_start and total > rumble_start:
		var rumble_u := clampf((elapsed - rumble_start) / (total - rumble_start), 0.0, 1.0)
		var decay := pow(1.0 - rumble_u, 1.35)
		var wave := sin(rumble_u * TAU * rumble_cycles)
		shove = Vector2(wave, wave * 0.35) * rumble_distance * decay
		rock = Vector2(wave * 0.85, wave * 0.25) * rumble_degrees * decay

	var yaw := node.rotation_degrees.y
	node.position = Vector3(shove.x, y, shove.y)
	node.scale = visual_scale
	node.rotation_degrees = Vector3(rock.x, yaw, rock.y)
