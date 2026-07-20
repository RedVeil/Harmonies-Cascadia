class_name Animal
extends Node3D

@export var anim_name: StringName = &"Tiger_001_idle_rare"
var animation_player_path: NodePath = NodePath("AnimationPlayer")

# This is the "slightly delayed" amount (in seconds).
@export_range(0.0, 10.0) var max_start_delay_sec: float = 0.25

func _ready() -> void:
	var ap := get_node_or_null(animation_player_path) as AnimationPlayer
	if ap == null:
		return
	if anim_name.is_empty():
		return
	if not ap.has_animation(anim_name):
		return

	# Start then instantly jump to a randomized time offset.
	# (This will override whatever autoplay already did.)
	ap.play(anim_name)

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [str(anim_name), get_instance_id()])

	var delay := rng.randf_range(0.0, max_start_delay_sec)
	ap.seek(delay, true) # update immediately
