class_name Animal
extends Node3D

@export var walk_anims: Array[StringName] = []
@export var idle_anims: Array[StringName] = []
@export var special_anims: Array[StringName] = []
## World-space units per second along the path.
@export var walk_speed: float = 1.35
@export var anim_blend_sec: float = 0.15
## Inclusive min/max idle cycles before a walk or special.
@export var idle_count: Vector2i = Vector2i(3, 10)
## After idles: chance to play special instead of one walk cycle.
@export_range(0.0, 1.0) var special_chance: float = 0.25
## Extra local yaw after facing travel (+Z). Use PI if a model faces -Z instead.
@export var path_facing_yaw: float = 0.0

var animation_player_path: NodePath = NodePath("AnimationPlayer")

var _ap: AnimationPlayer
var _roaming := false
## Bumped on stop/restart so in-flight await chains exit instead of racing a new loop.
var _roam_token := 0
var _path_follow: PathFollow3D = null
var _home_parent: Node = null
## +1 / -1 along the closed path (clockwise vs counter-clockwise).
var _path_direction := 1.0
var _rng := RandomNumberGenerator.new()
var _resolved_walk: Array[StringName] = []
var _resolved_idle: Array[StringName] = []
var _resolved_special: Array[StringName] = []


func _ready() -> void:
	_cache_animation_player()
	# Stay frozen until TileVisuals activates life on commit.
	freeze()


func freeze() -> void:
	_roaming = false
	_roam_token += 1
	_cache_animation_player()
	if _ap != null:
		_ap.stop()
		_ap.speed_scale = 0.0


func _exit_tree() -> void:
	# Scene reload frees tiles while roam awaits are mid-timer/frame.
	# Invalidate the loop before get_tree() can be called on a detached node.
	_roaming = false
	_roam_token += 1


func start_roam(
	path: Path3D,
	rng_seed: int = 0,
	start_offset: float = -1.0
) -> void:
	_roam_token += 1

	_rng.seed = rng_seed if rng_seed != 0 else hash(get_instance_id())
	_cache_animation_player()
	_resolve_animations()

	_path_direction = 1.0 if _rng.randf() < 0.5 else -1.0

	if not _attach_to_path(path, start_offset):
		_roaming = false
		_play_idle_once()
		return

	if _ap != null:
		_ap.speed_scale = 1.0

	var token := _roam_token
	_roaming = true
	_run_roam_loop(token)


## Place on a PathFollow without starting movement (preview / frozen pose).
func place_on_path(path: Path3D, start_offset: float = -1.0) -> void:
	freeze()
	_path_direction = 1.0
	_attach_to_path(path, start_offset)


func stop_roam() -> void:
	_roaming = false
	_roam_token += 1
	_detach_from_path_follow()


## Reparent back under the original animals root without freeing the animal.
## Call before scene layers that own Path3Ds are rebuilt/freed.
func detach_from_path() -> void:
	_roaming = false
	_roam_token += 1
	_detach_from_path_follow()


func _is_roam_active(token: int) -> bool:
	return (
		_roaming
		and token == _roam_token
		and is_instance_valid(self)
		and is_inside_tree()
	)


## get_tree() errors when the node is already out of the tree — guard first.
func _scene_tree() -> SceneTree:
	if not is_inside_tree():
		return null
	return get_tree()


func _cache_animation_player() -> void:
	if _ap != null:
		return
	_ap = get_node_or_null(animation_player_path) as AnimationPlayer


func _resolve_animations() -> void:
	_resolved_walk.clear()
	_resolved_idle.clear()
	_resolved_special.clear()
	if _ap == null:
		return

	for anim in walk_anims:
		if not anim.is_empty() and _ap.has_animation(anim):
			_resolved_walk.append(anim)
	for anim in idle_anims:
		if not anim.is_empty() and _ap.has_animation(anim):
			_resolved_idle.append(anim)
	for anim in special_anims:
		if not anim.is_empty() and _ap.has_animation(anim):
			_resolved_special.append(anim)


func _pick_anim(list: Array[StringName]) -> StringName:
	if list.is_empty():
		return &""
	return list[_rng.randi_range(0, list.size() - 1)]


func _idle_count_range() -> Vector2i:
	var lo := mini(idle_count.x, idle_count.y)
	var hi := maxi(idle_count.x, idle_count.y)
	return Vector2i(maxi(lo, 1), maxi(hi, 1))


func _attach_to_path(path: Path3D, start_offset: float) -> bool:
	if not is_instance_valid(path) or path.curve == null:
		return false
	var baked_length := path.curve.get_baked_length()
	if baked_length < 0.05:
		return false

	if _home_parent == null and get_parent() != null and not (get_parent() is PathFollow3D):
		_home_parent = get_parent()

	# Reuse follow node when rebinding to a new/replaced Path3D after layer rebuild.
	if not is_instance_valid(_path_follow):
		_path_follow = PathFollow3D.new()
		_path_follow.name = "AnimalPathFollow"
		_path_follow.loop = true
		# Position only — we aim +Z along travel ourselves (avoids oriented/sideways mismatch).
		_path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
	elif _path_follow.get_parent() != path:
		if _path_follow.get_parent() != null:
			_path_follow.get_parent().remove_child(_path_follow)

	if _path_follow.get_parent() != path:
		path.add_child(_path_follow)

	_path_follow.loop = true
	_path_follow.rotation_mode = PathFollow3D.ROTATION_NONE

	var offset := start_offset
	if offset < 0.0:
		if is_instance_valid(_path_follow) and _path_follow.get_parent() == path:
			offset = _path_follow.progress
		else:
			offset = _rng.randf_range(0.0, baked_length)
	else:
		offset = clampf(offset, 0.0, baked_length)
	_path_follow.progress = offset

	if get_parent() != _path_follow:
		reparent(_path_follow, false)
	# Sit at follow origin; cancel path scale (often 9.5) so scene scale is preserved.
	position = Vector3.ZERO
	rotation = Vector3.ZERO
	var parent_scale := _path_follow.global_transform.basis.get_scale()
	scale = Vector3(
		1.0 / maxf(absf(parent_scale.x), 0.001),
		1.0 / maxf(absf(parent_scale.y), 0.001),
		1.0 / maxf(absf(parent_scale.z), 0.001)
	)
	_face_travel_direction()
	return true


func _travel_direction_flat() -> Vector3:
	if not _path_follow_is_valid():
		return Vector3.ZERO

	var path := _path_follow.get_parent() as Path3D
	var curve := path.curve
	var baked_length := curve.get_baked_length()
	var look_dist := minf(0.35, baked_length * 0.08)
	var from_offset := _path_follow.progress
	var to_offset := fposmod(from_offset + _path_direction * look_dist, baked_length)

	var from_pos := path.to_global(curve.sample_baked(from_offset))
	var to_pos := path.to_global(curve.sample_baked(to_offset))
	var dir := Vector3(to_pos.x - from_pos.x, 0.0, to_pos.z - from_pos.z)
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return dir.normalized()


func _face_travel_direction() -> void:
	var dir := _travel_direction_flat()
	if dir == Vector3.ZERO:
		return
	# look_at aims -Z at the target; aim at -dir so model +Z faces travel.
	look_at(global_position - dir, Vector3.UP)
	if not is_zero_approx(path_facing_yaw):
		rotate_object_local(Vector3.UP, path_facing_yaw)


func _detach_from_path_follow() -> void:
	if not is_instance_valid(_path_follow):
		_path_follow = null
		return

	var follow := _path_follow
	_path_follow = null

	if is_inside_tree() and get_parent() == follow:
		var destination := _home_parent
		if destination != null and is_instance_valid(destination):
			reparent(destination, true)
		elif follow.get_parent() != null:
			reparent(follow.get_parent(), true)

	follow.queue_free()


func _path_follow_is_valid() -> bool:
	return (
		is_instance_valid(_path_follow)
		and is_instance_valid(_path_follow.get_parent())
		and _path_follow.get_parent() is Path3D
		and (_path_follow.get_parent() as Path3D).curve != null
		and (_path_follow.get_parent() as Path3D).curve.get_baked_length() >= 0.05
	)


func _run_roam_loop(token: int) -> void:
	# First beat: equal chance idle batch, walk lap, or special.
	await _play_opening_action(token)
	if not _is_roam_active(token):
		return

	while _is_roam_active(token):
		await _play_idle_batch(token)
		if not _is_roam_active(token):
			return

		if not _resolved_special.is_empty() and _rng.randf() < special_chance:
			await _play_anim_clip(_resolved_special, token)
		else:
			await _play_walk_lap(token)


func _play_opening_action(token: int) -> void:
	var roll := _rng.randf()
	if roll < 1.0 / 3.0:
		await _play_idle_batch(token)
	elif roll < 2.0 / 3.0:
		await _play_walk_lap(token)
	elif not _resolved_special.is_empty():
		await _play_anim_clip(_resolved_special, token)
	else:
		# No special clips authored — fall back to idle.
		await _play_idle_batch(token)


func _play_idle_batch(token: int) -> void:
	var counts := _idle_count_range()
	var n := _rng.randi_range(counts.x, counts.y)
	for _i in n:
		if not _is_roam_active(token):
			return
		await _play_anim_clip(_resolved_idle, token)


## Walk one full closed-path lap from the current progress back to the same point.
## Walk anim loops for the whole lap.
func _play_walk_lap(token: int) -> void:
	if not _is_roam_active(token):
		return
	if _resolved_walk.is_empty() or not _path_follow_is_valid():
		await _play_anim_clip(_resolved_idle, token)
		return

	_cache_animation_player()
	if _ap == null:
		return

	var pick := _pick_anim(_resolved_walk)
	if pick.is_empty():
		return

	var path := _path_follow.get_parent() as Path3D
	var baked_length := path.curve.get_baked_length()
	if baked_length < 0.05:
		return

	_ap.speed_scale = 1.0
	_ap.play(pick, anim_blend_sec)

	var traveled := 0.0
	# Slight epsilon so float wrap doesn't leave us one frame short of a full lap.
	var lap_target := baked_length - 0.001
	while _is_roam_active(token) and traveled < lap_target:
		if not _path_follow_is_valid():
			break
		var tree := _scene_tree()
		if tree == null:
			return
		await tree.process_frame
		if not _is_roam_active(token):
			return
		var delta := get_process_delta_time()
		traveled += _advance_path_follow(delta)

	if _ap != null and _ap.current_animation == StringName(pick):
		_ap.pause()


## Advances along the path. Returns path-local distance traveled this frame.
func _advance_path_follow(delta: float) -> float:
	if not _path_follow_is_valid():
		return 0.0

	var path := _path_follow.get_parent() as Path3D
	var baked_length := path.curve.get_baked_length()
	if baked_length < 0.05:
		return 0.0
	# progress is in path-local units; walk_speed is world units/sec.
	var scale_len := path.global_transform.basis.x.length()
	var progress_delta := (walk_speed / maxf(scale_len, 0.001)) * delta * _path_direction
	_path_follow.progress = fposmod(_path_follow.progress + progress_delta, baked_length)
	_face_travel_direction()
	return absf(progress_delta)


func _play_anim_clip(list: Array[StringName], token: int) -> void:
	if not _is_roam_active(token) or not is_instance_valid(self):
		return
	_cache_animation_player()
	if _ap == null:
		return
	var pick := _pick_anim(list)
	if pick.is_empty():
		return
	_ap.speed_scale = 1.0
	_ap.play(pick, anim_blend_sec)
	var anim := _ap.get_animation(pick)
	var duration := anim.length if anim != null else _ap.current_animation_length
	if duration <= 0.0:
		duration = 1.0
	var tree := _scene_tree()
	if tree == null:
		return
	await tree.create_timer(duration).timeout
	if not _is_roam_active(token):
		return


func _play_idle_once() -> void:
	_cache_animation_player()
	if _ap == null:
		return
	var pick := _pick_anim(_resolved_idle)
	if pick.is_empty():
		return
	_ap.speed_scale = 1.0
	_ap.play(pick, anim_blend_sec)
