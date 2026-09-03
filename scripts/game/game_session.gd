extends Node

## Run-scoped state shared across scene loads (menu -> game, roguelike levels, etc.).

const CONFIG_PATH := "res://data/session_config.json"
const TUTORIAL_CONFIG_PATH := "res://data/tutorial_config.json"
const PUZZLES_PATH := "res://data/puzzles.json"

enum GameMode { DAILY, NORMAL, ENDLESS, CHALLENGE, TUTORIAL, PUZZLE, PUZZLE_MAKER }
enum MapSize { SMALL, MEDIUM, LARGE }

var run_seed: int = 0
var game_mode: GameMode = GameMode.NORMAL
var map_size: MapSize = MapSize.MEDIUM

## Resolved from session_config.json when a run begins.
var ring_count: int = 3
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
## Empty starts at the first part. Set by begin_tutorial_run(part_id).
var tutorial_start_part: String = ""

## Active puzzle definition (data/puzzles.json). Empty when not in puzzle mode.
var puzzle_id: String = ""
var puzzle_config: Dictionary = {}

var _config: Dictionary = {}
var _puzzles: Array = []


func _ready() -> void:
	_load_config()
	_load_tutorial_config()
	_load_puzzles()
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
	map_size = MapSize.SMALL
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


func begin_tutorial_run(part_id: String = "") -> void:
	clear_challenge()
	clear_puzzle()
	game_mode = GameMode.TUTORIAL
	_load_tutorial_config()
	tutorial_start_part = part_id
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


func begin_puzzle_maker(edit_id: String = "") -> void:
	clear_challenge()
	clear_puzzle()
	game_mode = GameMode.PUZZLE_MAKER
	map_size = MapSize.MEDIUM
	_apply_mode_config(GameMode.NORMAL, MapSize.MEDIUM)
	ring_count = 3
	map_growth_enabled = false
	checkpoint = 100
	checkpoint_flat_increase = 0
	checkpoint_multiplier = 2.0
	checkpoint_targets.clear()
	if not edit_id.is_empty():
		var loaded := load_puzzle(edit_id)
		if not loaded.is_empty():
			puzzle_id = edit_id
			puzzle_config = loaded
			ring_count = int(loaded.get("ring_count", ring_count))
	begin_run(hash("puzzle_maker"), true)


func is_tutorial() -> bool:
	return game_mode == GameMode.TUTORIAL


func is_puzzle() -> bool:
	return game_mode == GameMode.PUZZLE


func is_puzzle_maker() -> bool:
	return game_mode == GameMode.PUZZLE_MAKER


func reload_puzzles() -> void:
	_load_puzzles()


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


func get_tutorial_parts() -> Array:
	if tutorial_config.is_empty():
		_load_tutorial_config()
	var raw = tutorial_config.get("parts", [])
	return raw if typeof(raw) == TYPE_ARRAY else []


func get_tutorial_part(part_id: String) -> Dictionary:
	if part_id.is_empty():
		return {}
	for part in get_tutorial_parts():
		if typeof(part) == TYPE_DICTIONARY and str(part.get("id", "")) == part_id:
			return part
	return {}


func get_tutorial_start_step_index() -> int:
	var steps := get_tutorial_steps()
	if steps.is_empty():
		return 0
	var part := get_tutorial_part(tutorial_start_part)
	if part.is_empty():
		return 0
	var start_id := str(part.get("start", ""))
	if start_id.is_empty():
		return 0
	for i in steps.size():
		if typeof(steps[i]) == TYPE_DICTIONARY and str(steps[i].get("id", "")) == start_id:
			return i
	return 0


func get_puzzle_scoring_rules() -> Dictionary:
	var raw = puzzle_config.get("scoring_rules", {})
	return raw if typeof(raw) == TYPE_DICTIONARY else {}


func get_puzzle_ratings() -> Dictionary:
	return _ratings_from_puzzle(puzzle_config)


func _ratings_from_puzzle(puzzle: Dictionary) -> Dictionary:
	var raw = puzzle.get("ratings", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	return {
		"bronze": int(raw.get("bronze", 0)),
		"silver": int(raw.get("silver", 0)),
		"gold": int(raw.get("gold", 0)),
	}


## -1 means unlimited pack takes (open puzzles / non-puzzle modes).
func get_max_pack_takes() -> int:
	if not is_puzzle():
		return -1
	if not puzzle_config.has("max_pack_takes"):
		return -1
	return int(puzzle_config.get("max_pack_takes", -1))


func format_puzzle_description(puzzle: Dictionary) -> String:
	return str(puzzle.get("description", "")).strip_edges()


## -1 means unlimited placements (open puzzles / non-puzzle modes).
func get_max_plays() -> int:
	if not is_puzzle():
		return -1
	if not puzzle_config.has("max_plays"):
		return -1
	return int(puzzle_config.get("max_plays", -1))


func get_puzzle_rating_line() -> String:
	var ratings := get_puzzle_ratings()
	if ratings.is_empty():
		return ""
	return "Bronze %d  ·  Silver %d  ·  Gold %d" % [
		int(ratings.get("bronze", 0)),
		int(ratings.get("silver", 0)),
		int(ratings.get("gold", 0)),
	]


## Returns "gold" / "silver" / "bronze" / "" for the highest tier reached.
func rating_for_score(score: int, ratings: Dictionary = {}) -> String:
	var resolved: Dictionary = ratings
	if resolved.is_empty():
		resolved = get_puzzle_ratings()
	if resolved.is_empty():
		return ""
	var gold := int(resolved.get("gold", 0))
	var silver := int(resolved.get("silver", 0))
	var bronze := int(resolved.get("bronze", 0))
	if gold > 0 and score >= gold:
		return "gold"
	if silver > 0 and score >= silver:
		return "silver"
	if bronze > 0 and score >= bronze:
		return "bronze"
	return ""


func record_puzzle_result(score: int) -> void:
	if not is_puzzle() or puzzle_id.is_empty():
		return
	GameSettings.record_puzzle_score(puzzle_id, score)


## First catalog puzzle id, or empty if the catalog has none.
func get_first_puzzle_id() -> String:
	var puzzles := list_puzzles()
	if puzzles.is_empty():
		return ""
	return str(puzzles[0].get("id", ""))


## Catalog entry after the current puzzle, or empty if this is the last.
func get_next_puzzle_id() -> String:
	if puzzle_id.is_empty():
		return ""
	var puzzles := list_puzzles()
	for i in puzzles.size():
		if str(puzzles[i].get("id", "")) != puzzle_id:
			continue
		if i + 1 >= puzzles.size():
			return ""
		return str(puzzles[i + 1].get("id", ""))
	return ""


func list_puzzles() -> Array[Dictionary]:
	if _puzzles.is_empty():
		_load_puzzles()
	var out: Array[Dictionary] = []
	for puzzle in _puzzles:
		if typeof(puzzle) != TYPE_DICTIONARY:
			continue
		var id := str(puzzle.get("id", ""))
		if id.is_empty():
			continue
		out.append({
			"id": id,
			"title": str(puzzle.get("title", id)),
			"description": format_puzzle_description(puzzle),
			"order": int(puzzle.get("order", 1000)),
			"ratings": _ratings_from_puzzle(puzzle),
		})
	return out


func load_puzzle(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	if _puzzles.is_empty():
		_load_puzzles()
	for puzzle in _puzzles:
		if typeof(puzzle) == TYPE_DICTIONARY and str(puzzle.get("id", "")) == id:
			return puzzle
	push_warning("Puzzle not found: %s" % id)
	return {}


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


func _load_puzzles() -> void:
	_puzzles = []
	if not FileAccess.file_exists(PUZZLES_PATH):
		push_warning("Puzzle catalog not found: %s" % PUZZLES_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(PUZZLES_PATH))
	var raw: Array = []
	if typeof(parsed) == TYPE_DICTIONARY:
		var listed = parsed.get("puzzles", [])
		if typeof(listed) == TYPE_ARRAY:
			raw = listed
	elif typeof(parsed) == TYPE_ARRAY:
		raw = parsed
	else:
		push_error("Invalid puzzle catalog JSON: %s" % PUZZLES_PATH)
		return
	_puzzles = raw


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


func get_utc_date_iso() -> String:
	var d := Time.get_date_dict_from_system(true)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func _daily_seed() -> int:
	var d := Time.get_date_dict_from_system(true)
	var key := "%04d%02d%02d" % [d.year, d.month, d.day]
	var h := hash(key)
	return h if h != 0 else 1
