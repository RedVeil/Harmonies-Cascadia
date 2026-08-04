extends Node3D
## Standalone board stress scene. Open scenes/debug/perf_board_demo.tscn and run (F6).
## WASD pan, scroll zoom. Element % must sum to 100; animal_percent is 0–100 fill rate.

@export var hex_manager: HexManager
@export var maps: int = 3
@export var radius: int = 3
@export var rng_seed: int = 42
@export_range(0.0, 100.0, 0.1) var animal_percent: float = 65.0

enum AnimalMotionMode {
	## Stop AnimationPlayer entirely (active=false). No GDScript process.
	FROZEN,
	## Idle/special clips only; no walk / path advance / process_frame.
	IDLE_SPECIAL,
	## Full roam: idle batches, walk laps, specials.
	FULL_ROAM,
}

@export var animal_motion: AnimalMotionMode = AnimalMotionMode.FROZEN:
	set(value):
		if animal_motion == value:
			return
		animal_motion = value
		if is_node_ready():
			_apply_animal_motion()

## Plant sway via global wind_amount (0 off, 1 full).
@export var enable_wind: bool = false:
	set(value):
		if enable_wind == value:
			return
		enable_wind = value
		if is_node_ready():
			_apply_wind()

## Grass cloud shadows via global cloud_shadow_amount (independent of wind).
@export var enable_clouds: bool = true:
	set(value):
		if enable_clouds == value:
			return
		enable_clouds = value
		if is_node_ready():
			_apply_clouds()

@export_group("Element % (must sum to 100)")
@export_range(0.0, 100.0, 0.1) var pct_forest: float = 20.0
@export_range(0.0, 100.0, 0.1) var pct_field: float = 20.0
@export_range(0.0, 100.0, 0.1) var pct_mountain: float = 20.0
@export_range(0.0, 100.0, 0.1) var pct_river: float = 20.0
@export_range(0.0, 100.0, 0.1) var pct_wetland: float = 20.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if hex_manager == null:
		hex_manager = get_node_or_null("HexManager") as HexManager
	if hex_manager == null:
		push_error("PerfBoardDemo: HexManager missing")
		return

	_rng.seed = rng_seed

	await get_tree().process_frame
	_rebuild_maps()
	_disable_tile_picking()
	_fill_board()
	_disable_tile_picking()
	_apply_animal_motion()
	_apply_wind()
	_apply_clouds()
	print(
		"PerfBoardDemo ready: %d tiles, %d maps, radius=%d, seed=%d, animal_motion=%s, enable_wind=%s, enable_clouds=%s"
		% [
			hex_manager.tiles.size(),
			hex_manager.hex_map_active.size(),
			radius,
			rng_seed,
			AnimalMotionMode.keys()[animal_motion],
			str(enable_wind),
			str(enable_clouds),
		]
	)


func _exit_tree() -> void:
	WindControl.set_wind_amount(WindControl.DEFAULT_AMOUNT)
	WindControl.set_cloud_amount(WindControl.DEFAULT_AMOUNT)


## ----- Board setup ----- ##

func _rebuild_maps() -> void:
	# HexManager._ready already created an origin map with its own ring count.
	_clear_board()
	hex_manager.map_ring_count = maxi(0, radius)
	hex_manager.create_map(Vector2i.ZERO)
	_ensure_maps()


func _clear_board() -> void:
	var container := hex_manager.hex_container
	for tile in container.tiles_by_coord.values():
		if is_instance_valid(tile):
			tile.free()
	container.tiles_by_coord.clear()
	hex_manager.tiles.clear()
	hex_manager.hex_map_active.clear()
	hex_manager.groups.clear()
	hex_manager.next_group_id = 0


func _ensure_maps() -> void:
	var origins: Array[Vector2i] = [Vector2i.ZERO]
	var ring := hex_manager.map_ring_count
	var i := 0
	while origins.size() < maps and i < 64:
		var base := origins[i % origins.size()]
		for neighbor in HexCoord.map_neighbors(base, ring):
			if origins.has(neighbor):
				continue
			hex_manager.create_map(neighbor)
			origins.append(neighbor)
			if origins.size() >= maps:
				break
		i += 1


func _fill_board() -> void:
	var pcts: Array[float] = [
		pct_forest, pct_field, pct_mountain, pct_river, pct_wetland
	]
	var pct_sum := 0.0
	for p in pcts:
		pct_sum += p
	if absf(pct_sum - 100.0) > 0.05:
		push_warning(
			"PerfBoardDemo: element %% sum to %.2f (expected 100). Allocating proportionally."
			% pct_sum
		)

	var coords: Array[Vector2i] = []
	coords.assign(hex_manager.tiles.keys())
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	var elements := [
		GameEnums.ELEMENT.FOREST,
		GameEnums.ELEMENT.FIELD,
		GameEnums.ELEMENT.MOUNTAIN,
		GameEnums.ELEMENT.RIVER,
		GameEnums.ELEMENT.WETLAND,
	]
	var counts := _allocate_counts(coords.size(), pcts)
	var element_list: Array[int] = []
	for i in counts.size():
		for _j in counts[i]:
			element_list.append(elements[i])
	_shuffle(element_list)

	for i in coords.size():
		var coord := coords[i]
		var data: HexTileData = hex_manager.tiles[coord]
		data.element = element_list[i] as GameEnums.ELEMENT
		data.level = _pick_level(data.element)
		data.orientation_steps = HexCoord.pick_orientation_steps(coord)
		data.animal_id = -1
		data.animal_amount = 0

	_assign_animals(coords)

	# Rivers need neighbor data present before apply; non-rivers first, then rivers twice.
	for coord in coords:
		if hex_manager.tiles[coord].element != GameEnums.ELEMENT.RIVER:
			_apply_tile(coord)
	for coord in coords:
		if hex_manager.tiles[coord].element == GameEnums.ELEMENT.RIVER:
			_apply_tile(coord)
	for coord in coords:
		if hex_manager.tiles[coord].element == GameEnums.ELEMENT.RIVER:
			_apply_tile(coord)


func _assign_animals(coords: Array[Vector2i]) -> void:
	if CardCatalog.animals.is_empty():
		return

	var eligible: Array[Vector2i] = []
	for coord in coords:
		if hex_manager.tiles[coord].element != GameEnums.ELEMENT.RIVER:
			eligible.append(coord)

	var animal_count := clampi(
		roundi(float(eligible.size()) * clampf(animal_percent, 0.0, 100.0) / 100.0),
		0,
		eligible.size()
	)
	_shuffle(eligible)
	for i in animal_count:
		var data: HexTileData = hex_manager.tiles[eligible[i]]
		var animal: CardData = CardCatalog.animals[_rng.randi_range(0, CardCatalog.animals.size() - 1)]
		data.animal_id = animal.id
		data.animal_amount = maxi(1, animal.visual_amount)


func _allocate_counts(total: int, weights: Array[float]) -> Array[int]:
	var counts: Array[int] = []
	counts.resize(weights.size())
	var weight_sum := 0.0
	for w in weights:
		weight_sum += maxf(0.0, w)

	if total <= 0 or weight_sum <= 0.0:
		for i in counts.size():
			counts[i] = 0
		if total > 0 and counts.size() > 0:
			counts[0] = total
		return counts

	var remainders: Array[Dictionary] = []
	var assigned := 0
	for i in weights.size():
		var share := total * maxf(0.0, weights[i]) / weight_sum
		var base := int(floor(share))
		counts[i] = base
		assigned += base
		remainders.append({"index": i, "frac": share - float(base)})

	remainders.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.frac) > float(b.frac)
	)
	var leftover := total - assigned
	for i in leftover:
		counts[int(remainders[i].index)] += 1
	return counts


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


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
	for tile in hex_manager.hex_container.tiles_by_coord.values():
		if tile is CollisionObject3D:
			(tile as CollisionObject3D).input_ray_pickable = false


## ----- Animal motion + wind ----- ##

func _apply_animal_motion() -> void:
	if hex_manager == null:
		return
	match animal_motion:
		AnimalMotionMode.FROZEN:
			_foreach_tile_visuals(func(visuals: TileVisuals) -> void:
				visuals.freeze_animals()
			)
		AnimalMotionMode.IDLE_SPECIAL:
			_foreach_tile_visuals(func(visuals: TileVisuals) -> void:
				visuals.start_animal_idle_loop()
			)
		AnimalMotionMode.FULL_ROAM:
			_foreach_tile_visuals(func(visuals: TileVisuals) -> void:
				visuals.start_animal_roam()
			)


func _apply_wind() -> void:
	WindControl.set_wind_enabled(enable_wind)


func _apply_clouds() -> void:
	WindControl.set_cloud_enabled(enable_clouds)


func _foreach_tile_visuals(action: Callable) -> void:
	for tile in hex_manager.hex_container.tiles_by_coord.values():
		if not is_instance_valid(tile):
			continue
		for path in [&"VisualsRoot/current", &"VisualsRoot/previous"]:
			var visuals := tile.get_node_or_null(NodePath(path)) as TileVisuals
			if visuals != null:
				action.call(visuals)
