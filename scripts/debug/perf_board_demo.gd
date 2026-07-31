extends Node3D
## Standalone board stress scene: ~3 maps (~100 hexes) filled with mixed terrain + animals.
## Open scenes/debug/perf_board_demo.tscn and run (F6). WASD pan, scroll zoom.
## Element weights are relative (0 = never). They do not need to sum to 1.

@export var hex_manager: HexManager
@export var map_count: int = 3
@export var rng_seed: int = 42
@export var animal_chance: float = 0.65

@export_group("Element Split (relative weights)")
@export_range(0.0, 100.0, 0.1) var weight_forest: float = 0.0
@export_range(0.0, 100.0, 0.1) var weight_field: float = 1.0
@export_range(0.0, 100.0, 0.1) var weight_mountain: float = 1.0
@export_range(0.0, 100.0, 0.1) var weight_river: float = 0.0
@export_range(0.0, 100.0, 0.1) var weight_wetland: float = 1.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if hex_manager == null:
		hex_manager = get_node_or_null("HexManager") as HexManager
	if hex_manager == null:
		push_error("PerfBoardDemo: HexManager missing")
		return

	_rng.seed = rng_seed

	await get_tree().process_frame
	_ensure_maps()
	# Block picking before fill — hover during apply would hit a null Orchestrator.
	_disable_tile_picking()
	_fill_board()
	_disable_tile_picking()
	print(
		"PerfBoardDemo ready: %d tiles, %d maps, seed=%d"
		% [hex_manager.tiles.size(), hex_manager.hex_map_active.size(), rng_seed]
	)


## ----- Board setup ----- ##

func _ensure_maps() -> void:
	# HexManager._ready already created the origin map.
	var origins: Array[Vector2i] = [Vector2i.ZERO]
	var ring := hex_manager.map_ring_count
	var i := 0
	while origins.size() < map_count and i < 32:
		var base := origins[i % origins.size()]
		for neighbor in HexCoord.map_neighbors(base, ring):
			if origins.has(neighbor):
				continue
			hex_manager.create_map(neighbor)
			origins.append(neighbor)
			if origins.size() >= map_count:
				break
		i += 1


func _fill_board() -> void:
	var coords: Array[Vector2i] = []
	coords.assign(hex_manager.tiles.keys())
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	for coord in coords:
		_assign_terrain_and_animal(hex_manager.tiles[coord], coord)

	# Rivers need neighbor data present before apply; do a second pass for them.
	for coord in coords:
		if hex_manager.tiles[coord].element != GameEnums.ELEMENT.RIVER:
			_apply_tile(coord)
	for coord in coords:
		if hex_manager.tiles[coord].element == GameEnums.ELEMENT.RIVER:
			_apply_tile(coord)
	for coord in coords:
		if hex_manager.tiles[coord].element == GameEnums.ELEMENT.RIVER:
			_apply_tile(coord)


func _assign_terrain_and_animal(data: HexTileData, coord: Vector2i) -> void:
	data.element = _pick_element()
	data.level = _pick_level(data.element)
	data.orientation_steps = HexCoord.pick_orientation_steps(coord)

	if (
		data.element == GameEnums.ELEMENT.RIVER
		or _rng.randf() > animal_chance
		or CardCatalog.animals.is_empty()
	):
		data.animal_id = -1
		data.animal_amount = 0
		return

	var animal: CardData = CardCatalog.animals[_rng.randi_range(0, CardCatalog.animals.size() - 1)]
	data.animal_id = animal.id
	data.animal_amount = maxi(1, animal.visual_amount)


func _pick_element() -> GameEnums.ELEMENT:
	var entries: Array[Dictionary] = [
		{"element": GameEnums.ELEMENT.FOREST, "weight": weight_forest},
		{"element": GameEnums.ELEMENT.FIELD, "weight": weight_field},
		{"element": GameEnums.ELEMENT.MOUNTAIN, "weight": weight_mountain},
		{"element": GameEnums.ELEMENT.RIVER, "weight": weight_river},
		{"element": GameEnums.ELEMENT.WETLAND, "weight": weight_wetland},
	]
	var total := 0.0
	for entry in entries:
		total += maxf(0.0, float(entry.weight))
	if total <= 0.0:
		push_warning("PerfBoardDemo: all element weights are 0; defaulting to FIELD")
		return GameEnums.ELEMENT.FIELD

	var roll := _rng.randf() * total
	var cumulative := 0.0
	for entry in entries:
		var w := maxf(0.0, float(entry.weight))
		if w <= 0.0:
			continue
		cumulative += w
		if roll <= cumulative:
			return entry.element as GameEnums.ELEMENT
	return entries.back().element as GameEnums.ELEMENT


func _pick_level(element: GameEnums.ELEMENT) -> GameEnums.LEVEL:
	match element:
		GameEnums.ELEMENT.FOREST, GameEnums.ELEMENT.MOUNTAIN:
			return _rng.randi_range(GameEnums.LEVEL.SMALL, GameEnums.LEVEL.LARGE) as GameEnums.LEVEL
		_:
			return GameEnums.LEVEL.SMALL


func _apply_tile(coord: Vector2i) -> void:
	var container := hex_manager.hex_container
	if not container.tiles_by_coord.has(coord):
		return
	var tile: HexTile = container.tiles_by_coord[coord]
	var data: HexTileData = hex_manager.tiles[coord]
	var river_neighbors: Array[Vector2i] = []
	if data.element == GameEnums.ELEMENT.RIVER:
		river_neighbors = container.get_element_neighbors(coord, GameEnums.ELEMENT.RIVER)
	tile.commit_preview_from_tile_data(data, river_neighbors)


func _disable_tile_picking() -> void:
	# No Orchestrator in this scene — block hover/click so HexManager never calls one.
	for tile in hex_manager.hex_container.tiles_by_coord.values():
		if tile is CollisionObject3D:
			(tile as CollisionObject3D).input_ray_pickable = false
