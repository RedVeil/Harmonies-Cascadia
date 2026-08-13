extends Node

## Run-scoped state shared across scene loads (menu -> game, roguelike levels, etc.).

const CONFIG_PATH := "res://data/session_config.json"
const TUTORIAL_CONFIG_PATH := "res://data/tutorial_config.json"
const PUZZLES_DIR := "res://data/puzzles"

enum GameMode { DAILY, NORMAL, ENDLESS, CHALLENGE, TUTORIAL, PUZZLE }
enum MapSize { SMALL, MEDIUM, LARGE }

var run_seed: int = 0
var game_mode: GameMode = GameMode.NORMAL
var map_size: MapSize = MapSize.MEDIUM

## Resolved from session_config.json when a run begins.
var ring_count: int = 4
var checkpoint: int = 10000
var checkpoint_multiplier: float = 2.0
var checkpoint_flat_increase: int = 0
## Explicit checkpoint sequence (e.g. puzzle bronze/silver/gold). Empty uses formula.
var checkpoint_targets: Array[int] = []
## When false, score checkpoints and map-point boosters cannot expand the map.
var map_growth_enabled: bool = true

## Set when joining a shared challenge code; -1 means none.
var reference_score: int = -1

## Cached tutorial_config.json (run options, scoring pins, steps).
var tutorial_config: Dictionary = {}

## Active puzzle definition (data/puzzles/*.json). Empty when not in puzzle mode.
var puzzle_id: String = ""
var puzzle_config: Dictionary = {}

var _config: Dictionary = {}


func _ready() -> void:
	_load_config()
	_load_tutorial_config()
	begin_run(0)
	_apply_mode_config(GameMode.NORMAL, MapSize.MEDIUM)
	clear_challenge()
	clear_puzzle()


func begin_run(desired_seed: int, force_seed: bool = false) -> void:
	if force_seed or desired_seed != 0:
		run_seed = desired_seed
	else:
		run_seed = randi()


func begin_daily_run() -> void:
	clear_challenge()
	clear_puzzle()
	game_mode = GameMode.DAILY
	map_size = MapSize.MEDIUM
	_apply_mode_config(game_mode, map_size)
	begin_run(_daily_seed())


func begin_normal_run(size: MapSize) -> void:
	clear_challenge()
	clear_puzzle()
	game_mode = GameMode.NORMAL
	map_size = size
	_apply_mode_config(game_mode, map_size)
	begin_run(0)


func begin_endless_run() -> void:
	clear_challenge()
	clear_puzzle()
	game_mode = GameMode.ENDLESS
	map_size = MapSize.MEDIUM
	_apply_mode_config(game_mode, map_size)
	begin_run(0)


func begin_challenge_run(seed: int, rings: int, ref_score: int) -> void:
	clear_puzzle()
	game_mode = GameMode.CHALLENGE
	map_size = MapSize.MEDIUM
	# Start from normal config, then override for shared-score challenge.
	_apply_mode_config(GameMode.NORMAL, MapSize.MEDIUM)
	ring_count = rings
	# Challenges keep a fixed footprint for fair score comparison.
	map_growth_enabled = false
	reference_score = ref_score
	# Shared final score becomes the first highscore checkpoint, then doubles.
	checkpoint = maxi(ref_score, 1)
	checkpoint_flat_increase = 0
	checkpoint_multiplier = 2.0
	checkpoint_targets.clear()
	begin_run(seed, true)


func begin_tutorial_run() -> void:
	clear_challenge()
	clear_puzzle()
	game_mode = GameMode.TUTORIAL
	_load_tutorial_config()
	var run_cfg: Dictionary = tutorial_config.get("run", {})
	map_size = _parse_map_size(str(run_cfg.get("map_size", "small")))
	# Tutorial uses normal small-map ring count / checkpoint tuning.
	_apply_mode_config(GameMode.NORMAL, map_size)
	map_growth_enabled = bool(run_cfg.get("map_growth", false))
	var seed_val := int(run_cfg.get("seed", 42))
	begin_run(seed_val, true)


func begin_puzzle_run(id: String) -> bool:
	clear_challenge()
	var loaded := load_puzzle(id)
	if loaded.is_empty():
		push_error("GameSession: failed to load puzzle '%s'" % id)
		return false
	game_mode = GameMode.PUZZLE
	puzzle_id = id
	puzzle_config = loaded
	map_size = MapSize.MEDIUM
	# Ring / growth defaults from normal, then puzzle overrides.
	_apply_mode_config(GameMode.NORMAL, MapSize.MEDIUM)
	ring_count = int(puzzle_config.get("ring_count", ring_count))
	# Puzzles keep a fixed map unless a puzzle explicitly opts in.
	map_growth_enabled = bool(puzzle_config.get("map_growth", false))
	# Bronze / silver / gold ratings drive the checkpoint sequence.
	checkpoint_targets = _build_rating_checkpoint_targets()
	if checkpoint_targets.is_empty():
		checkpoint = 100
	else:
		checkpoint = checkpoint_targets[0]
	# After the last medal, keep doubling.
	checkpoint_flat_increase = 0
	checkpoint_multiplier = 2.0
	var seed_val := int(puzzle_config.get("seed", 0))
	begin_run(seed_val if seed_val != 0 else hash(id), true)
	return true


func is_tutorial() -> bool:
	return game_mode == GameMode.TUTORIAL


func is_puzzle() -> bool:
	return game_mode == GameMode.PUZZLE


## Puzzle mode always; tutorial when boosters/animal_market queues are authored.
func uses_scripted_shop() -> bool:
	if is_puzzle():
		return true
	if not is_tutorial():
		return false
	if tutorial_config.is_empty():
		_load_tutorial_config()
	var boosters = tutorial_config.get("boosters", [])
	var animals = tutorial_config.get("animal_market", [])
	return (typeof(boosters) == TYPE_ARRAY and not boosters.is_empty()) \
		or (typeof(animals) == TYPE_ARRAY and not animals.is_empty())


func get_scripted_shop_config() -> Dictionary:
	if is_puzzle():
		return puzzle_config
	if is_tutorial():
		if tutorial_config.is_empty():
			_load_tutorial_config()
		return tutorial_config
	return {}


func allows_map_growth() -> bool:
	return map_growth_enabled


func get_tutorial_scoring_rules() -> Dictionary:
	if tutorial_config.is_empty():
		_load_tutorial_config()
	var raw = tutorial_config.get("scoring_rules", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func get_tutorial_steps() -> Array:
	if tutorial_config.is_empty():
		_load_tutorial_config()
	var raw = tutorial_config.get("steps", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


func get_puzzle_scoring_rules() -> Dictionary:
	var raw = puzzle_config.get("scoring_rules", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func get_puzzle_ratings() -> Dictionary:
	var raw = puzzle_config.get("ratings", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return {
		"bronze": int(raw.get("bronze", 0)),
		"silver": int(raw.get("silver", 0)),
		"gold": int(raw.get("gold", 0)),
	}


## Returns "gold" / "silver" / "bronze" / "" for the highest tier reached.
func rating_for_score(score: int) -> String:
	var ratings := get_puzzle_ratings()
	if ratings.is_empty():
		return ""
	var gold := int(ratings.get("gold", 0))
	var silver := int(ratings.get("silver", 0))
	var bronze := int(ratings.get("bronze", 0))
	if score >= gold:
		return "gold"
	if score >= silver:
		return "silver"
	if score >= bronze:
		return "bronze"
	return ""


func list_puzzles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(PUZZLES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var id := file_name.get_basename()
			var puzzle := load_puzzle(id)
			if not puzzle.is_empty():
				out.append({
					"id": str(puzzle.get("id", id)),
					"title": str(puzzle.get("title", id)),
					"description": str(puzzle.get("description", "")),
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("title", "")) < str(b.get("title", ""))
	)
	return out


func load_puzzle(id: String) -> Dictionary:
	var path := "%s/%s.json" % [PUZZLES_DIR, id]
	if not FileAccess.file_exists(path):
		push_warning("Puzzle not found: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid puzzle JSON: %s" % path)
		return {}
	if not parsed.has("id"):
		parsed["id"] = id
	return parsed


func clear_puzzle() -> void:
	puzzle_id = ""
	puzzle_config = {}
	checkpoint_targets.clear()


func clear_challenge() -> void:
	reference_score = -1


func has_reference_score() -> bool:
	return reference_score >= 0


## Next checkpoint after `current_target`. Uses explicit list first, then formula.
func next_checkpoint(current_target: int) -> int:
	for t in checkpoint_targets:
		if t > current_target:
			return t
	var advanced := ceili((float(current_target) + float(checkpoint_flat_increase)) * checkpoint_multiplier)
	if advanced <= current_target:
		# Guard against stuck targets when mult/flat would not increase.
		return current_target + maxi(checkpoint_flat_increase, 1)
	return advanced


func get_map_ring_count() -> int:
	return ring_count


func make_rng(tag: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d|%s" % [run_seed, tag])
	return rng


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("Session config not found: %s" % CONFIG_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid session config JSON: %s" % CONFIG_PATH)
		return
	_config = parsed


func _load_tutorial_config() -> void:
	if not FileAccess.file_exists(TUTORIAL_CONFIG_PATH):
		push_warning("Tutorial config not found: %s" % TUTORIAL_CONFIG_PATH)
		tutorial_config = {}
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TUTORIAL_CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid tutorial config JSON: %s" % TUTORIAL_CONFIG_PATH)
		tutorial_config = {}
		return
	tutorial_config = parsed


func _apply_mode_config(mode: GameMode, size: MapSize) -> void:
	var mode_key := _mode_key(mode)
	var mode_cfg: Dictionary = _config.get(mode_key, {})
	checkpoint = int(mode_cfg.get("checkpoint", checkpoint))
	checkpoint_multiplier = float(mode_cfg.get("checkpoint_multiplier", checkpoint_multiplier))
	checkpoint_flat_increase = int(mode_cfg.get("checkpoint_flat_increase", checkpoint_flat_increase))
	map_growth_enabled = bool(mode_cfg.get("map_growth", true))
	checkpoint_targets.clear()

	if mode == GameMode.NORMAL:
		var size_key := _map_size_key(size)
		var sizes: Dictionary = mode_cfg.get("map_sizes", {})
		var size_cfg: Dictionary = sizes.get(size_key, {})
		ring_count = int(size_cfg.get("ring_count", ring_count))
	else:
		ring_count = int(mode_cfg.get("ring_count", ring_count))


func _build_rating_checkpoint_targets() -> Array[int]:
	var ratings := get_puzzle_ratings()
	var out: Array[int] = []
	for key in ["bronze", "silver", "gold"]:
		var value := int(ratings.get(key, 0))
		if value > 0 and not out.has(value):
			out.append(value)
	out.sort()
	return out


func _mode_key(mode: GameMode) -> String:
	match mode:
		GameMode.DAILY:
			return "daily"
		GameMode.ENDLESS:
			return "endless"
		_:
			return "normal"


func _map_size_key(size: MapSize) -> String:
	match size:
		MapSize.SMALL:
			return "small"
		MapSize.LARGE:
			return "large"
		_:
			return "medium"


func _parse_map_size(key: String) -> MapSize:
	match key.to_lower():
		"small":
			return MapSize.SMALL
		"large":
			return MapSize.LARGE
		_:
			return MapSize.MEDIUM


func get_daily_seed() -> int:
	return _daily_seed()


func _daily_seed() -> int:
	var d := Time.get_date_dict_from_system(true)
	var key := "%04d%02d%02d" % [d.year, d.month, d.day]
	var h := hash(key)
	return h if h != 0 else 1
