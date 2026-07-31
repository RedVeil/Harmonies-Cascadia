extends Node
class_name ScoreEngine

var active_rules : Dictionary[int, ScoringRule] = {}

var points_per_element_group: Dictionary[int, int] = {}
var placed_animals: Dictionary[int, int] = {}
var element_score: int = 0
var animal_score:int = 0
var quest_score: int = 0
var total_score : int = 0

var new_element_score : int = 0
var new_quest_score : int = 0

var element_score_backup: int = 0
var animal_score_backup:int = 0
var quest_score_backup: int = 0
var points_per_element_group_backup: Dictionary[int, int] = {}

## ----- Initialisation ----- ##

func _ready() -> void:
	var rng := GameSession.make_rng("scoring")
	for i in range(5):
		var element = ElementCatalog.elements[i + 1]
		var rule_id: int = element.scoring_rules[rng.randi() % element.scoring_rules.size()]
		active_rules[element.type] = RuleCatalog.rules[rule_id]
		element.active_scoring_rule = rule_id

## ----- Scoring Logic ----- ##

func calc_total_group_score(excluded_groups:Array[int]) -> int:
	var result : int = 0
	for key in points_per_element_group.keys():
		if !excluded_groups.has(key):
			result += points_per_element_group[key]
	return result

func calc_group_score(
	coord:Vector2i, 
	coords: Array[Vector2i],
	element:int, 
	tiles:Dictionary[Vector2i, HexTileData]
	) -> int:
	var result : int = 0
	var rule = active_rules[element]
	if rule.special_rule == 1:
		var coords_ := coords.duplicate(true)
		coords_.append(coord)
		result = calculate_element_special_shortest_route(coords_, rule)
	elif rule.special_rule == 2:
		result = calculate_element_special_neighbors(coords, rule, tiles)
	elif rule.special_rule == 3:
		var coords_ := coords.duplicate(true)
		if not coords_.has(coord):
			coords_.append(coord)
		result = calculate_element_special_group_size(coords_, rule)
	else:
		if coords.has(coord):
			result = calculate_normal_element_group(coords,rule, tiles)
		else:
			var coords_ := coords.duplicate(true)
			coords_.append(coord)
			result = calculate_normal_element_group(coords_,rule, tiles)
	return result

func calculate_normal_element_group(
	coords: Array[Vector2i], 
	rule:ScoringRule,
	tiles:Dictionary[Vector2i, HexTileData]
	) -> int:
	var levels : Array[int] = []
	for c in coords:
		levels.append(tiles[c].level)
	levels.sort()
	levels.reverse()

	if rule.max_group_size < levels.size():
		levels = levels.slice(0, rule.max_group_size)

	var score = 0
	for l in levels:
		score += rule.points_per_tile_level[l-1][1]
	if coords.size() >= rule.min_group_size:
		score += rule.flat_points
	return score


func calculate_element_special_neighbors(
	coords: Array[Vector2i], 
	rule:ScoringRule, 
	tiles:Dictionary[Vector2i, HexTileData]
	) -> int:
	var neighbor_elements : Array[int] = []
	var eligble_neighbors : Array[Vector2i] = []
	for c in coords:
		var neighbor_element = tiles[c].element
		if !neighbor_elements.has(neighbor_element) and neighbor_element > 0:
			neighbor_elements.append(neighbor_element)
			eligble_neighbors.append(c)
	
	if neighbor_elements.size() >= rule.special_rule_specs.neighbors_min:
		if rule.special_rule_specs.points_per > 0:
			return neighbor_elements.size() * rule.special_rule_specs.points_per
		elif rule.special_rule_specs.points_flat > 0:
			return rule.special_rule_specs.points_flat
		else:
			## error case - this shouldnt happen
			return 0
	else:
		return 0

func calculate_element_special_shortest_route(coords: Array[Vector2i], rule:ScoringRule) -> int:
	var rule_specs = rule.special_rule_specs
	var path = find_longest_path(coords)
	return _points_from_size_curve(path.size(), rule_specs)

func calculate_element_special_group_size(coords: Array[Vector2i], rule:ScoringRule) -> int:
	if coords.size() < rule.min_group_size:
		return 0
	return _points_from_size_curve(coords.size(), rule.special_rule_specs)

func _points_from_size_curve(size: int, rule_specs: Dictionary) -> int:
	if size <= 0:
		return 0
	var points: Array = rule_specs.points
	if size >= points.size():
		var diff = size - points.size()
		return points[points.size() - 1] + (diff * int(rule_specs.extra_points))
	return points[size - 1]

## ----- Path Finding Logic ----- ##

func find_longest_path(coords: Array[Vector2i]) -> Array[Vector2i]:
	if coords.is_empty():
		return []
		
	var coord_set := {}
	for coord in coords:
		coord_set[coord] = true
	var best_start := coords[0]
	var best_end := coords[0]
	var best_distance := -1
	# Try BFS from every coord.
	for start in coords:
		var result := bfs_furthest_from(start, coord_set)
		var end: Vector2i = result["coord"]
		var distance: int = result["distance"]
		if distance > best_distance:
			best_distance = distance
			best_start = start
			best_end = end

	return bfs_path(best_start, best_end, coord_set)

func bfs_furthest_from(start: Vector2i, river_set: Dictionary) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var distance := {}
	distance[start] = 0
	var furthest_coord := start
	var furthest_distance := 0
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var current_distance: int = distance[current]
		if current_distance > furthest_distance:
			furthest_distance = current_distance
			furthest_coord = current
		for dir in HexCoord.DIRECTIONS:
			var neighbor : Vector2i = current + dir
			if not river_set.has(neighbor):
				continue
			if distance.has(neighbor):
				continue
			distance[neighbor] = current_distance + 1
			queue.append(neighbor)

	return {
		"coord": furthest_coord,
		"distance": furthest_distance,
	}

func bfs_path(start: Vector2i, goal: Vector2i, coord_set: Dictionary) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var came_from := {}
	came_from[start] = null

	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()

		if current == goal:
			return reconstruct_path(goal, came_from)

		for dir in HexCoord.DIRECTIONS:
			var neighbor: Vector2i = current + dir

			if not coord_set.has(neighbor):
				continue

			if came_from.has(neighbor):
				continue

			came_from[neighbor] = current
			queue.append(neighbor)

	return []

func reconstruct_path(end_coord: Vector2i, came_from: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current: Variant = end_coord
	
	while current != null:
		path.append(current)
		current = came_from[current]
	
	path.reverse()
	return path
