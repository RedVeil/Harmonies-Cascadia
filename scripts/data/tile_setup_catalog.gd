extends Node

const CATALOG_PATH := "res://data/tile_setup_catalog.json"

var _entries: Dictionary = {}
var _entry_layers_cache: Dictionary = {}
var _default_scene_layers: Array = []
var _default_multi_mesh_layers: Array = []
var _game_seed: int = 0


func _ready() -> void:
	_game_seed = randi()
	load_catalog()


func load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("Tile setup catalog not found: %s" % CATALOG_PATH)
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid tile setup catalog JSON: %s" % CATALOG_PATH)
		return

	for entry in parsed:
		var element: int = entry.get("element", -1)
		var level: int = entry.get("level", -1)
		if element < 0 or level < 0:
			continue

		var key := _make_key(element, level)
		_entries[key] = entry
		_entry_layers_cache[key] = {
			"scene_layers": _load_scene_layers_from_json(entry.get("scene_layers", [])),
			"multi_mesh_layers": _load_multimesh_layers_from_json(entry.get("multi_mesh_layers", [])),
		}
		if element == GameEnums.ELEMENT.NONE and level == GameEnums.LEVEL.ANY:
			_default_scene_layers = _duplicate_layers(
				_entry_layers_cache[key].get("scene_layers", [])
			)
			_default_multi_mesh_layers = _duplicate_layers(
				_entry_layers_cache[key].get("multi_mesh_layers", [])
			)


func get_layers_state(
	element: int,
	level: int,
	coord: Vector2i = Vector2i.ZERO
) -> TileLayersState:
	var entry: Dictionary = _lookup_entry(element, level)
	var scene_option_layers: Array = []
	var multimesh_option_layers: Array = []

	if entry.is_empty():
		scene_option_layers = _duplicate_layers(_default_scene_layers)
		multimesh_option_layers = _duplicate_layers(_default_multi_mesh_layers)
	else:
		var key := _make_key(entry.get("element", -1), entry.get("level", -1))
		var cached_layers: Dictionary = _entry_layers_cache.get(key, {})
		scene_option_layers = _duplicate_layers(cached_layers.get("scene_layers", []))
		multimesh_option_layers = _duplicate_layers(cached_layers.get("multi_mesh_layers", []))

	var pick_rng := _make_pick_rng(coord, element, level)
	var resolved_scene_layers := _resolve_scene_layers(scene_option_layers, pick_rng)
	var resolved_multimesh_layers := _resolve_multimesh_layers(multimesh_option_layers, pick_rng)
	var signature := _make_signature(element, level)
	return TileLayersState.create(
		resolved_scene_layers,
		resolved_multimesh_layers,
		[],
		signature
	)


func _lookup_entry(element: int, level: int) -> Dictionary:
	var key := _make_key(element, level)
	if _entries.has(key):
		return _entries[key]

	if level > GameEnums.LEVEL.ANY:
		return _lookup_entry(element, level - 1)

	if element != GameEnums.ELEMENT.NONE:
		return _lookup_entry(GameEnums.ELEMENT.NONE, GameEnums.LEVEL.ANY)

	return {}


func _load_scene_layers_from_json(raw_layers: Array) -> Array:
	var layers: Array = []
	for raw_layer in raw_layers:
		var options: Array[PackedScene] = []
		if typeof(raw_layer) != TYPE_ARRAY:
			continue
		for path in raw_layer:
			if typeof(path) != TYPE_STRING or path.is_empty():
				continue
			var scene := load(path) as PackedScene
			if scene != null:
				options.append(scene)
		layers.append(options)
	return layers


func _load_multimesh_layers_from_json(raw_layers: Array) -> Array:
	var layers: Array = []
	for raw_layer in raw_layers:
		var options: Array[String] = []
		if typeof(raw_layer) != TYPE_ARRAY:
			continue
		for path in raw_layer:
			if typeof(path) == TYPE_STRING and not path.is_empty():
				options.append(path)
		layers.append(options)
	return layers


func _duplicate_layers(source_layers: Array) -> Array:
	var duplicated: Array = []
	for raw_layer in source_layers:
		if typeof(raw_layer) == TYPE_ARRAY:
			duplicated.append((raw_layer as Array).duplicate())
	return duplicated


func _make_pick_rng(
	coord: Vector2i,
	element: int,
	level: int
) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(
		"%d|%s|%d,%d" % [
			_game_seed,
			_make_signature(element, level),
			coord.x,
			coord.y,
		]
	)
	return rng


func _pick_option_index(rng: RandomNumberGenerator, option_count: int) -> int:
	if option_count <= 0:
		return 0
	return mini(rng.randi_range(0, 4), option_count - 1)


func _resolve_scene_layers(option_layers: Array, rng: RandomNumberGenerator) -> Array:
	var resolved: Array = []
	for layer_options in option_layers:
		if typeof(layer_options) != TYPE_ARRAY:
			resolved.append(layer_options if layer_options is PackedScene else null)
			continue

		var options: Array = layer_options
		var picked: PackedScene = null
		if not options.is_empty():
			var choice = options[_pick_option_index(rng, options.size())]
			if choice is PackedScene:
				picked = choice
		resolved.append(picked)
	return resolved


func _resolve_multimesh_layers(option_layers: Array, rng: RandomNumberGenerator) -> Array:
	var resolved: Array = []
	for layer_options in option_layers:
		if typeof(layer_options) != TYPE_ARRAY:
			resolved.append(layer_options if typeof(layer_options) == TYPE_STRING else "")
			continue

		var options: Array = layer_options
		var picked := ""
		if not options.is_empty():
			var choice = options[_pick_option_index(rng, options.size())]
			if typeof(choice) == TYPE_STRING and not choice.is_empty():
				picked = choice
		resolved.append(picked)
	return resolved


func _make_signature(element: int, level: int) -> String:
	return "%d_%d" % [element, level]


func _make_key(element: int, level: int) -> String:
	return "%d_%d" % [element, level]
