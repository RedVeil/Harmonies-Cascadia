class_name Animal
extends Node3D

@export var walk_anims: Array[StringName] = []
@export var idle_anims: Array[StringName] = []
@export_range(0.0, 10.0) var max_start_delay_sec: float = 0.25
@export var walk_speed: float = 2.0
@export var turn_speed_deg: float = 45.0
@export var anim_blend_sec: float = 0.15
## Seconds of walking before a mid-path idle can trigger (per animal, randomized each segment).
@export var walk_before_idle_min: float = 1.2
@export var walk_before_idle_max: float = 4.0
## How long a mid-walk / break idle pause lasts.
@export var idle_pause_min: float = 0.7
@export var idle_pause_max: float = 2.0

var animation_player_path: NodePath = NodePath("AnimationPlayer")

var _ap: AnimationPlayer
var _roaming := false
## Bumped on stop/restart so in-flight await chains exit instead of racing a new loop.
var _roam_token := 0
var _roam_markers: Array[Marker3D] = []
var _current_marker: Marker3D = null
var _active_tween: Tween
var _rng := RandomNumberGenerator.new()
var _resolved_walk: Array[StringName] = []
var _resolved_idle: Array[StringName] = []


func _ready() -> void:
	_cache_animation_player()
	# Stay frozen until TileVisuals activates life on commit.
	freeze()


func freeze() -> void:
	stop_roam()
	_cache_animation_player()
	if _ap != null:
		_ap.stop()
		_ap.speed_scale = 0.0


func start_roam(
	markers: Array[Marker3D],
	rng_seed: int = 0,
	current_marker: Marker3D = null
) -> void:
	# Invalidate any in-flight roam awaits before swapping marker refs.
	_roam_token += 1
	_kill_active_tween()

	_roam_markers.clear()
	for marker in markers:
		if is_instance_valid(marker):
			_roam_markers.append(marker)

	_current_marker = current_marker if is_instance_valid(current_marker) else null
	_rng.seed = rng_seed if rng_seed != 0 else hash(get_instance_id())
	_cache_animation_player()
	_resolve_animations()

	if _ap != null:
		_ap.speed_scale = 1.0

	_play_idle(true)

	if _roam_markers.is_empty():
		_roaming = false
		return

	var token := _roam_token
	_roaming = true
	_run_roam_loop(token)


func stop_roam() -> void:
	_roaming = false
	_roam_token += 1
	_kill_active_tween()


func _is_roam_active(token: int) -> bool:
	return _roaming and token == _roam_token and is_instance_valid(self)


func _cache_animation_player() -> void:
	if _ap != null:
		return
	_ap = get_node_or_null(animation_player_path) as AnimationPlayer


func _resolve_animations() -> void:
	_resolved_walk.clear()
	_resolved_idle.clear()
	if _ap == null:
		return

	for anim in walk_anims:
		if not anim.is_empty() and _ap.has_animation(anim):
			_resolved_walk.append(anim)
	for anim in idle_anims:
		if not anim.is_empty() and _ap.has_animation(anim):
			_resolved_idle.append(anim)


func _pick_anim(list: Array[StringName]) -> StringName:
	if list.is_empty():
		return &""
	return list[_rng.randi_range(0, list.size() - 1)]


func _prune_invalid_markers() -> void:
	var alive: Array[Marker3D] = []
	for marker in _roam_markers:
		if is_instance_valid(marker):
			alive.append(marker)
	_roam_markers = alive
	if not is_instance_valid(_current_marker):
		_current_marker = null


func _run_roam_loop(token: int) -> void:
	while _is_roam_active(token):
		_prune_invalid_markers()
		if _roam_markers.size() <= 1:
			await _do_idle_break()
			continue

		var target := _pick_next_marker()
		if target == null:
			await _do_idle_break()
			continue

		await _walk_to(target, token)
		if not _is_roam_active(token):
			return

		if is_instance_valid(target):
			_current_marker = target
		# Short chance to linger at the destination; most idles happen mid-walk.
		if _rng.randf() < 0.4:
			await _do_idle_break()


func _pick_next_marker() -> Marker3D:
	var candidates: Array[Marker3D] = []
	for marker in _roam_markers:
		if not is_instance_valid(marker):
			continue
		if marker == _current_marker:
			continue
		candidates.append(marker)
	if candidates.is_empty():
		for marker in _roam_markers:
			if is_instance_valid(marker):
				return marker
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _walk_to(target: Marker3D, token: int) -> void:
	if not _is_roam_active(token) or not is_instance_valid(target):
		return

	var end := target.global_position
	if global_position.distance_to(end) < 0.05:
		return

	await _turn_toward_horizontal(end)
	if not _is_roam_active(token) or not is_instance_valid(target):
		return

	while _is_roam_active(token) and is_instance_valid(target):
		end = target.global_position
		var remaining := global_position.distance_to(end)
		if remaining < 0.08:
			return

		_play_walk()

		var interrupt_after := _rng.randf_range(walk_before_idle_min, walk_before_idle_max)
		var full_duration := remaining / maxf(walk_speed, 0.01)
		var segment_duration := minf(interrupt_after, full_duration)
		var move_dist := minf(walk_speed * segment_duration, remaining)
		var dir := (end - global_position).normalized()
		var segment_end := global_position + dir * move_dist

		_kill_active_tween()
		_active_tween = create_tween()
		_active_tween.tween_property(self, "global_position", segment_end, segment_duration)\
			.set_trans(Tween.TRANS_LINEAR)\
			.set_ease(Tween.EASE_IN_OUT)
		await _active_tween.finished

		if not _is_roam_active(token) or not is_instance_valid(target):
			return

		# Reached (or almost reached) the marker — no mid-walk idle needed.
		if global_position.distance_to(target.global_position) < 0.08:
			return

		# Random mid-path idle, then continue toward the same target.
		await _do_idle_break()
		if not _is_roam_active(token) or not is_instance_valid(target):
			return

		# Re-face in case the animal drifted visually; target may still be ahead.
		await _turn_toward_horizontal(target.global_position)


func _play_walk() -> void:
	if _ap == null:
		return
	var pick := _pick_anim(_resolved_walk)
	if pick.is_empty():
		return
	_ap.speed_scale = 1.0
	_ap.play(pick, anim_blend_sec)


func _do_idle_break() -> void:
	if not is_instance_valid(self):
		return
	_play_idle(false)
	var pause := _rng.randf_range(idle_pause_min, idle_pause_max)
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(pause).timeout


func _turn_toward_horizontal(target: Vector3) -> void:
	if not is_instance_valid(self):
		return
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var dir := Vector3(flat_target.x - global_position.x, 0.0, flat_target.z - global_position.z)
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()

	# Models face +Z. Basis.looking_at aligns -Z with the given forward, so pass -dir
	# so that +Z points along movement. Compose the world yaw delta onto local Y so
	# parent tile orientation (VisualsRoot) is handled correctly.
	var target_yaw := Basis.looking_at(-dir, Vector3.UP).get_euler().y
	var delta := wrapf(target_yaw - global_rotation.y, -PI, PI)
	if absf(delta) < 0.01:
		return

	var turn_duration: float = absf(delta) / deg_to_rad(maxf(turn_speed_deg, 1.0))
	var start_local_y := rotation.y
	_kill_active_tween()
	_active_tween = create_tween()
	_active_tween.tween_property(self, "rotation:y", start_local_y + delta, turn_duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	await _active_tween.finished


func _play_idle(randomize_offset: bool) -> void:
	_cache_animation_player()
	if _ap == null:
		return
	var pick := _pick_anim(_resolved_idle)
	if pick.is_empty():
		return
	_ap.speed_scale = 1.0
	_ap.play(pick, anim_blend_sec)
	if randomize_offset:
		var delay := _rng.randf_range(0.0, max_start_delay_sec)
		_ap.seek(delay, true)


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
