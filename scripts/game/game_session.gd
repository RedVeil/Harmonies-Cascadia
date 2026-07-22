extends Node

## Run-scoped state shared across scene loads (menu -> game, roguelike levels, etc.).
var run_seed: int = 0


func _ready() -> void:
	begin_run(0)


func begin_run(desired_seed: int) -> void:
	run_seed = desired_seed if desired_seed != 0 else randi()


func make_rng(tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [run_seed, tag])
	return rng
