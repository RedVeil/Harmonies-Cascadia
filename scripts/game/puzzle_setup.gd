extends RefCounted
class_name PuzzleSetup

## Applies a puzzle definition onto the live Refactored_Main systems.


static func apply(
	puzzle: Dictionary,
	hex_manager: HexManager,
	score_engine: ScoreEngine,
	point_counter: PointCounter
) -> void:
	if puzzle.is_empty() or hex_manager == null or score_engine == null:
		return
	_apply_tiles(puzzle, hex_manager)
	_rebuild_groups_and_scores(hex_manager, score_engine)
	_sync_point_counter(score_engine, point_counter)


static func _apply_tiles(puzzle: Dictionary, hex_manager: HexManager) -> void:
	var raw_tiles = puzzle.get("tiles", [])
	if typeof(raw_tiles) != TYPE_ARRAY:
		return

	var filled: Array[Vector2i] = []
	for entry in raw_tiles:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var q := int(entry.get("q", 0))
		var r := int(entry.get("r", 0))
		var coord := Vector2i(q, r)
		if not hex_manager.tiles.has(coord):
			push_warning("PuzzleSetup: tile %s is outside the map; skipped." % coord)
			continue

		var data: HexTileData = hex_manager.tiles[coord]
		var element := int(entry.get("element", GameEnums.ELEMENT.NONE))
		var level := int(entry.get("level", GameEnums.LEVEL.SMALL))
		var animal_id := int(entry.get("animal_id", -1))

		data.element = element as GameEnums.ELEMENT
		data.level = level as GameEnums.LEVEL
		data.orientation_steps = HexCoord.pick_orientation_steps(coord)
		data.group_id = -1
		data.animal_id = -1
		data.animal_amount = 0

		if animal_id >= 0:
			var animal := _animal_by_id(animal_id)
			if animal != null:
				data.animal_id = animal.id
				data.animal_amount = maxi(1, animal.visual_amount)

		filled.append(coord)

	# Non-rivers first, then rivers twice so neighbor meshes resolve.
	for coord in filled:
		if hex_manager.tiles[coord].element != GameEnums.ELEMENT.RIVER:
			_commit_tile_visual(hex_manager, coord)
	for coord in filled:
		if hex_manager.tiles[coord].element == GameEnums.ELEMENT.RIVER:
			_commit_tile_visual(hex_manager, coord)
	for coord in filled:
		if hex_manager.tiles[coord].element == GameEnums.ELEMENT.RIVER:
			_commit_tile_visual(hex_manager, coord)


static func _commit_tile_visual(hex_manager: HexManager, coord: Vector2i) -> void:
	var container := hex_manager.hex_container
	if not container.tiles_by_coord.has(coord):
		return
	var tile: HexTile = container.tiles_by_coord[coord]
	var data: HexTileData = hex_manager.tiles[coord]
	var river_neighbors: Array[Vector2i] = []
	if data.element == GameEnums.ELEMENT.RIVER:
		river_neighbors = container.get_element_neighbors(coord, GameEnums.ELEMENT.RIVER)
	tile.commit_preview_from_tile_data(data, river_neighbors)


static func _animal_by_id(animal_id: int) -> CardData:
	for animal in CardCatalog.animals:
		if animal != null and animal.id == animal_id:
			return animal
	if animal_id >= 0 and animal_id < CardCatalog.animals.size():
		return CardCatalog.animals[animal_id]
	return null


static func _rebuild_groups_and_scores(hex_manager: HexManager, score_engine: ScoreEngine) -> void:
	hex_manager.groups.clear()
	hex_manager.next_group_id = 0
	score_engine.points_per_element_group.clear()
	score_engine.placed_animals.clear()
	score_engine.element_score = 0
	score_engine.animal_score = 0
	score_engine.quest_score = 0
	score_engine.total_score = 0

	var visited: Dictionary = {}
	var coords: Array = hex_manager.tiles.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	for coord in coords:
		var data: HexTileData = hex_manager.tiles[coord]
		if data.element == GameEnums.ELEMENT.NONE or visited.has(coord):
			continue
		var members := _flood_element_group(hex_manager, coord, data.element, visited)
		var group_id := hex_manager.next_group_id
		hex_manager.next_group_id += 1
		hex_manager.groups[group_id] = members
		for member in members:
			hex_manager.tiles[member].group_id = group_id

		var element_type := int(data.element)
		var score_coords: Array[Vector2i] = members.duplicate()
		if score_engine.active_rules.has(element_type):
			var rule: ScoringRule = score_engine.active_rules[element_type]
			if rule.special_rule == ScoringRule.SpecialRule.NEIGHBORS:
				score_coords = _neighbor_contributing_coords(hex_manager, members)
		var group_score := score_engine.calc_group_score(
			members[0],
			score_coords,
			element_type,
			hex_manager.tiles
		)
		score_engine.points_per_element_group[group_id] = group_score
		score_engine.element_score += group_score

	# Seed animal scores in stable order (base points only; multipliers apply on future placements).
	for coord in coords:
		var data: HexTileData = hex_manager.tiles[coord]
		if data.animal_id < 0 or data.animal_id >= CardCatalog.animals.size():
			continue
		var animal: CardData = CardCatalog.animals[data.animal_id]
		if score_engine.placed_animals.has(animal.id):
			score_engine.placed_animals[animal.id] += 1
		else:
			score_engine.placed_animals[animal.id] = 1
		score_engine.animal_score += animal.point_score

	score_engine.total_score = (
		score_engine.element_score + score_engine.animal_score + score_engine.quest_score
	)


static func _flood_element_group(
	hex_manager: HexManager,
	start: Vector2i,
	element: int,
	visited: Dictionary
) -> Array[Vector2i]:
	var members: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	visited[start] = true
	while not stack.is_empty():
		var coord: Vector2i = stack.pop_back()
		members.append(coord)
		for n in HexCoord.neighbors(coord):
			if visited.has(n) or not hex_manager.tiles.has(n):
				continue
			if hex_manager.tiles[n].element != element:
				continue
			visited[n] = true
			stack.append(n)
	return members


static func _neighbor_contributing_coords(
	hex_manager: HexManager,
	group_coords: Array[Vector2i]
) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	if group_coords.size() > 1:
		coords = group_coords.duplicate()
	for coord in group_coords:
		for n in HexCoord.neighbors(coord):
			if hex_manager.tiles.has(n) and not coords.has(n) and hex_manager.tiles[n].element > 0:
				coords.append(n)
	return coords


static func _sync_point_counter(score_engine: ScoreEngine, point_counter: PointCounter) -> void:
	if point_counter == null:
		return
	var score := score_engine.total_score
	point_counter.current = score
	point_counter.preview = score
	# Advance checkpoint targets past the seeded score without granting map points.
	while point_counter.current >= point_counter.target and point_counter.target > 0:
		point_counter.advance_target()
	point_counter.apply_current_style()
