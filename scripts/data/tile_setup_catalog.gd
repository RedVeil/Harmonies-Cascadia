extends Node

const CATALOG_PATH := "res://data/tile_setup_catalog.json"

var _setups: Dictionary = {}
var _default_setup: TileSetup


func _ready() -> void:
	load_catalog()


func load_catalog() -> void:
	_setups.clear()
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
		var setup_path: String = entry.get("setup", "")
		if element < 0 or level < 0 or setup_path.is_empty():
			continue

		var setup := load(setup_path) as TileSetup
		if setup == null:
			push_error("Failed to load tile setup: %s" % setup_path)
			continue

		_setups[_make_key(element, level)] = setup
		if element == GameEnums.ELEMENT.NONE and level == GameEnums.LEVEL.ANY:
			_default_setup = setup


func get_setup(element: int, level: int) -> TileSetup:
	var setup: TileSetup = _lookup_setup(element, level)
	if setup != null:
		return setup
	return _default_setup


func _lookup_setup(element: int, level: int) -> TileSetup:
	var key := _make_key(element, level)
	if _setups.has(key):
		return _setups[key]

	if level > GameEnums.LEVEL.ANY:
		return _lookup_setup(element, level - 1)

	if element != GameEnums.ELEMENT.NONE:
		return _lookup_setup(GameEnums.ELEMENT.NONE, GameEnums.LEVEL.ANY)

	return null


func _make_key(element: int, level: int) -> String:
	return "%d_%d" % [element, level]
