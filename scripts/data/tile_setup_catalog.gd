extends Node

const CATALOG_PATH := "res://data/tile_setup_catalog.json"

var _entries: Dictionary = {}
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
		_entries[key] = {
			"scene_layers": _load_scene_layers_from_json(entry.get("scene_layers", [])),
			"multi_mesh_layers": _load_multimesh_layers_from_json(entry.get("multi_mesh_layers", [])),
		}


func resolve_layers(
	element: int,
	level: int,
	coord: Vector2i = Vector2i.ZERO,
	river_index: int = -1
) -> Dictionary:
	var key := _make_key(element, level)
	if not _entries.has(key):
		push_error("No tile setup catalog entry for element=%d level=%d" % [element, level])
		return {
			"scene_layers": [],
			"multi_mesh_layers": [],
			"signature": _make_signature(element, level, river_index),
		}

	var entry: Dictionary = _entries[key]
	var scene_option_layers := _duplicate_layers(entry.get("scene_layers", []))
	var multimesh_option_layers := _duplicate_layers(entry.get("multi_mesh_layers", []))
	var pick_rng := _make_pick_rng(coord, element, level)
	
	if element == 4 and river_index == -1:
		river_index = 12
	
	return {
		"scene_layers": _resolve_scene_layers(scene_option_layers, pick_rng, river_index),
		"multi_mesh_layers": _resolve_multimesh_layers(multimesh_option_layers, pick_rng),
		"signature": _make_signature(element, level, river_index),
	}


func get_layers_state(
	element: int,
	level: int,
	coord: Vector2i = Vector2i.ZERO
) -> TileLayersState:
	var resolved := resolve_layers(element, level, coord)
	return TileLayersState.create(
		resolved.get("scene_layers", []),
		resolved.get("multi_mesh_layers", []),
		[],
		resolved.get("signature", _make_signature(element, level, -1))
	)


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
			_make_signature(element, level, -1),
			coord.x,
			coord.y,
		]
	)
	return rng


func _pick_option_index(rng: RandomNumberGenerator, option_count: int) -> int:
	if option_count <= 0:
		return 0
	return mini(rng.randi_range(0, 4), option_count - 1)


func _resolve_scene_layers(option_layers: Array, rng: RandomNumberGenerator, river_index: int = -1) -> Array:
	var resolved: Array = []
	for layer_options in option_layers:
		if typeof(layer_options) != TYPE_ARRAY:
			resolved.append(layer_options if layer_options is PackedScene else null)
			continue

		var options: Array = layer_options
		var picked: PackedScene = null
		if not options.is_empty():
			var index := _pick_option_index(rng, options.size()) if river_index == -1 else river_index
			index = clampi(index, 0, options.size() - 1)
			var choice = options[index]
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


func _make_signature(element: int, level: int, river_index:int) -> String:
	if element == GameEnums.ELEMENT.RIVER and river_index >= 0:
		return "%d_%d_r%d" % [element, level, river_index]
	return "%d_%d" % [element, level]


func _make_key(element: int, level: int) -> String:
	return "%d_%d" % [element, level]
