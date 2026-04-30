class_name ScoreEngine
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")

var placement_bonus: int = 1
var selected_rule_set: Dictionary = {}
var available_rule_sets: Dictionary = {}
var element_defs: Dictionary = {}

func init_rule_sets() -> void:
	if element_defs.is_empty():
		_init_default_element_defs()
	available_rule_sets.clear()
	selected_rule_set.clear()
	var key_to_element := {
		"forest": TileState.Element.FOREST,
		"field": TileState.Element.FIELD,
		"mountain": TileState.Element.MOUNTAIN,
		"river": TileState.Element.RIVER,
		"wetlands": TileState.Element.WETLANDS
	}
	for element_key in key_to_element.keys():
		var eid := int(key_to_element[element_key])
		var lib: Dictionary = _rule_library_for_element_key(String(element_key))
		var ids: Array[String] = (_def_for(eid).get("available_rules", []) as Array[String]).duplicate()
		var options := {}
		for rid in ids:
			if lib.has(rid):
				options[rid] = lib[rid]
		if options.is_empty():
			for rid in lib.keys():
				options[rid] = lib[rid]
		available_rule_sets[element_key] = options
		var default_rule := String(_def_for(eid).get("default_rule", ""))
		if default_rule.is_empty() or not options.has(default_rule):
			default_rule = String(options.keys()[0]) if not options.is_empty() else ""
		selected_rule_set[element_key] = default_rule

func load_elements_csv(path: String) -> void:
	element_defs.clear()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Elements CSV not found: %s" % path)
		_init_default_element_defs()
		return
	var row_index := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		row_index += 1
		if line.is_empty() or line.begins_with("#"):
			continue
		if row_index == 1 and line.to_lower().begins_with("element_id,"):
			continue
		var cols: PackedStringArray = line.split(",", false)
		if cols.size() < 9:
			continue
		var element_id := int(cols[0].strip_edges())
		if element_id < TileState.Element.FOREST or element_id > TileState.Element.WETLANDS:
			continue
		element_defs[element_id] = {
			"name": cols[1].strip_edges(),
			"base_draw_weight": maxf(float(cols[2].strip_edges()), 0.0),
			"draw_self_delta": float(cols[3].strip_edges()),
			"draw_other_delta": float(cols[4].strip_edges()),
			"min_draw_weight": maxf(float(cols[5].strip_edges()), 0.0),
			"max_stacks": maxi(int(cols[6].strip_edges()), 0),
			"allowed_place_specs": _parse_specs(cols[7].strip_edges()),
			"icons": _parse_icons(cols[8].strip_edges()),
			"available_rules": _parse_rule_ids(cols[9].strip_edges()) if cols.size() > 9 else [],
			"default_rule": cols[10].strip_edges() if cols.size() > 10 else ""
		}
	if element_defs.is_empty():
		_init_default_element_defs()

func element_order() -> Array[int]:
	var out: Array[int] = []
	for e in [TileState.Element.FOREST, TileState.Element.FIELD, TileState.Element.MOUNTAIN, TileState.Element.RIVER, TileState.Element.WETLANDS]:
		if element_defs.has(e):
			out.append(e)
	return out

func base_draw_weight_for(element: int) -> float:
	return float(_def_for(element).get("base_draw_weight", 0.0))

func draw_self_delta_for(element: int) -> float:
	return float(_def_for(element).get("draw_self_delta", -5.0))

func draw_other_delta_for(element: int) -> float:
	return float(_def_for(element).get("draw_other_delta", 1.0))

func min_draw_weight_for(element: int) -> float:
	return float(_def_for(element).get("min_draw_weight", 0.0))

func icon_for(element: int, stacks: int) -> String:
	var icons: Array = _def_for(element).get("icons", [])
	if icons.is_empty():
		return ""
	var idx := clampi(stacks, 0, icons.size() - 1)
	return String(icons[idx])

func set_rule_id(element_key: String, rule_id: String) -> bool:
	if not available_rule_sets.has(element_key):
		return false
	var options: Dictionary = available_rule_sets[element_key]
	if not options.has(rule_id):
		return false
	selected_rule_set[element_key] = rule_id
	return true

func rule_id_for(element_key: String) -> String:
	return String(selected_rule_set.get(element_key, ""))

func available_rule_ids_for(element_key: String) -> Array[String]:
	var out: Array[String] = []
	if not available_rule_sets.has(element_key):
		return out
	for key in (available_rule_sets[element_key] as Dictionary).keys():
		out.append(String(key))
	out.sort()
	return out

func preview_element_points(board: Dictionary, grid, coord: Vector2i, element: int) -> Dictionary:
	if not board.has(coord):
		return {"valid": false, "points": 0, "reason": "Outside map"}
	var tile: TileState = board[coord]
	if not can_place_element(tile, element):
		return {"valid": false, "points": 0, "reason": "Invalid base tile"}

	var sim_board: Dictionary = _clone_board(board)
	var sim_tile: TileState = sim_board[coord]
	apply_element_placement(sim_tile, element)
	var points := compute_element_delta(sim_board, grid, coord, element)
	return {"valid": true, "points": points, "reason": "Valid placement"}

func can_place_element(tile: TileState, element: int) -> bool:
	if tile.animal != 0:
		return false
	return (allowed_place_specs_for_element(element) as Array).has(tile.spec_key())

func apply_element_placement(tile: TileState, element: int) -> void:
	match element:
		TileState.Element.MOUNTAIN, TileState.Element.FOREST, TileState.Element.FIELD:
			if tile.element == element:
				var max_stacks := max_stacks_for_element(element)
				tile.stack_count = mini(tile.stack_count + 1, max_stacks)
			else:
				tile.element = element
				tile.stack_count = 0
		TileState.Element.RIVER:
			tile.element = TileState.Element.RIVER
			tile.stack_count = 0
		TileState.Element.WETLANDS:
			var was_empty := tile.element == TileState.Element.NONE
			tile.element = TileState.Element.WETLANDS
			tile.stack_count = 0 if was_empty else 1

func allowed_place_specs_for_element(element: int) -> Array[String]:
	return (_def_for(element).get("allowed_place_specs", []) as Array[String]).duplicate()

func max_stacks_for_element(element: int) -> int:
	return int(_def_for(element).get("max_stacks", 0))

func compute_element_delta(board: Dictionary, grid, coord: Vector2i, element: int) -> int:
	var score := placement_bonus
	match element:
		TileState.Element.FOREST:
			score += _run_tile_rule("forest", board, grid, coord)
		TileState.Element.FIELD:
			score += _run_tile_rule("field", board, grid, coord)
		TileState.Element.MOUNTAIN:
			score += _run_tile_rule("mountain", board, grid, coord)
		TileState.Element.RIVER:
			score += _run_tile_rule("river", board, grid, coord)
		TileState.Element.WETLANDS:
			score += _run_tile_rule("wetlands", board, grid, coord)
	return score

func _rule_field_group_three_mix(board: Dictionary, grid, coord: Vector2i) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.FIELD)
	if component.size() != 3:
		return 0
	var counts := _field_stack_counts(board, component)
	var stack0_count := int(counts.get(0, 0))
	match stack0_count:
		3:
			return 10
		2:
			return 15
		1:
			return 20
		_:
			return 0

func _rule_field_three_fields_only(board: Dictionary, grid, coord: Vector2i) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.FIELD)
	if component.size() != 3:
		return 0
	var counts := _field_stack_counts(board, component)
	return 15 if int(counts.get(1, 0)) == 3 else 0

func _rule_field_pair_field_grassland(board: Dictionary, grid, coord: Vector2i) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.FIELD)
	if component.size() != 2:
		return 0
	var counts := _field_stack_counts(board, component)
	return 10 if int(counts.get(1, 0)) == 1 and int(counts.get(0, 0)) == 1 else 0

func _rule_field_isolated_field_five(board: Dictionary, grid, coord: Vector2i) -> int:
	var tile: TileState = board[coord]
	if tile.element != TileState.Element.FIELD or tile.stack_count < 1:
		return 0
	for n in grid.neighbors(coord):
		if (board[n] as TileState).element == TileState.Element.FIELD:
			return 0
	return 5

func _rule_forest_connected_tiered_1_3_7(board: Dictionary, grid, coord: Vector2i) -> int:
	if not _has_forest_neighbor(board, grid, coord):
		return 0
	var stacks := int((board[coord] as TileState).stack_count)
	match stacks:
		0:
			return 1
		1:
			return 3
		_:
			return 7

func _rule_forest_connected_mid_high_flat_4(board: Dictionary, grid, coord: Vector2i) -> int:
	if not _has_forest_neighbor(board, grid, coord):
		return 0
	return 4 if int((board[coord] as TileState).stack_count) >= 1 else 0

func _rule_forest_component_two_each_cap_ten(board: Dictionary, grid, coord: Vector2i) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.FOREST)
	var count := component.size()
	if count <= 0:
		return 0
	if count >= 3:
		return 10
	return count * 2

func _rule_forest_jungle_pairs_fifteen(board: Dictionary, grid, coord: Vector2i) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.FOREST)
	if component.is_empty():
		return 0
	var stack2_or_more_count := 0
	for c in component:
		if int((board[c] as TileState).stack_count) >= 2:
			stack2_or_more_count += 1
	return int(floor(float(stack2_or_more_count) / 2.0)) * 15

func _rule_wetlands_diverse_neighbors_three_plus(board: Dictionary, grid, coord: Vector2i) -> int:
	if int((board[coord] as TileState).stack_count) != 1:
		return 0
	var seen_types: Dictionary = {}
	for n in grid.neighbors(coord):
		var t: TileState = board[n]
		if t.element != TileState.Element.NONE:
			seen_types[t.spec_key()] = true
	return 5 if seen_types.size() >= 3 else 0

func _rule_wetlands_group_flat_four(board: Dictionary, grid, coord: Vector2i) -> int:
	if int((board[coord] as TileState).stack_count) != 1:
		return 0
	var component := _collect_component(board, grid, coord, TileState.Element.WETLANDS)
	return 4 if not component.is_empty() else 0

func _rule_wetlands_group_three_ten(board: Dictionary, grid, coord: Vector2i) -> int:
	if int((board[coord] as TileState).stack_count) != 1:
		return 0
	var component := _collect_component(board, grid, coord, TileState.Element.WETLANDS)
	return 10 if component.size() == 3 else 0

func _rule_wetlands_two_river_neighbors_four(board: Dictionary, grid, coord: Vector2i) -> int:
	if int((board[coord] as TileState).stack_count) != 1:
		return 0
	var river_neighbors := 0
	for n in grid.neighbors(coord):
		if (board[n] as TileState).element == TileState.Element.RIVER:
			river_neighbors += 1
	return 4 if river_neighbors >= 2 else 0

func _rule_mountain_connected_tiered_1_3_7(board: Dictionary, grid, coord: Vector2i) -> int:
	if not _has_mountain_neighbor(board, grid, coord):
		return 0
	var stacks := int((board[coord] as TileState).stack_count)
	match stacks:
		0:
			return 1
		1:
			return 3
		_:
			return 7

func _rule_mountain_connected_mid_high_5_10(board: Dictionary, grid, coord: Vector2i) -> int:
	if not _has_mountain_neighbor(board, grid, coord):
		return 0
	var stacks := int((board[coord] as TileState).stack_count)
	match stacks:
		1:
			return 5
		2:
			return 10
		_:
			return 0

func _rule_mountain_tiered_3_3_1(board: Dictionary, grid, coord: Vector2i) -> int:
	if not _has_mountain_neighbor(board, grid, coord):
		return 0
	var stacks := int((board[coord] as TileState).stack_count)
	match stacks:
		0:
			return 3
		1:
			return 3
		_:
			return 1

func _rule_mountain_mid_high_flat_4(board: Dictionary, grid, coord: Vector2i) -> int:
	if not _has_mountain_neighbor(board, grid, coord):
		return 0
	return 4 if int((board[coord] as TileState).stack_count) >= 1 else 0

func _run_tile_rule(element_key: String, board: Dictionary, grid, coord: Vector2i) -> int:
	if not available_rule_sets.has(element_key):
		return 0
	var rule_id: String = String(selected_rule_set.get(element_key, ""))
	var options: Dictionary = available_rule_sets[element_key]
	if not options.has(rule_id):
		return 0
	var rule_fn: Callable = options[rule_id]
	return int(rule_fn.call(board, grid, coord))

func _score_river_component(board: Dictionary, grid, coord: Vector2i) -> int:
	return _river_expansion_points(board, grid, coord, false)

func _rule_river_shortest_route(board: Dictionary, grid, coord: Vector2i) -> int:
	return _score_river_component(board, grid, coord)

func _rule_river_short_river(board: Dictionary, grid, coord: Vector2i) -> int:
	return _river_expansion_points(board, grid, coord, true)

func _rule_river_small_lakes(board: Dictionary, grid, coord: Vector2i) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.RIVER)
	if component.is_empty():
		return 0
	var degree_two_count := 0
	for c in component:
		if _river_degree_in_component(board, grid, c) == 2:
			degree_two_count += 1
	return int(floor(float(degree_two_count) / 3.0)) * 10

func _rule_river_big_lakes(board: Dictionary, grid, coord: Vector2i) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.RIVER)
	if not _is_big_lake_component(board, grid, component):
		return 0
	return 10

func _collect_component(board: Dictionary, grid, start: Vector2i, element: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if (board[start] as TileState).element != element:
		return out
	var queue: Array[Vector2i] = [start]
	var seen: Dictionary = {start: true}
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		out.append(c)
		for n in grid.neighbors(c):
			if not seen.has(n) and (board[n] as TileState).element == element:
				seen[n] = true
				queue.append(n)
	return out

func _river_route_length_nodes(grid, component: Array[Vector2i]) -> int:
	if component.is_empty():
		return 0
	if component.size() == 1:
		return 1

	var idx: Dictionary = {}
	for i in range(component.size()):
		idx[component[i]] = i

	var max_distance_edges := 0
	for source in component:
		var dist: Dictionary = {}
		var queue: Array[Vector2i] = [source]
		dist[source] = 0
		while not queue.is_empty():
			var c: Vector2i = queue.pop_front()
			for n in grid.neighbors(c):
				if not idx.has(n) or dist.has(n):
					continue
				dist[n] = int(dist[c]) + 1
				queue.append(n)
				max_distance_edges = maxi(max_distance_edges, int(dist[n]))

	return max_distance_edges + 1

func _river_expansion_points(board: Dictionary, grid, coord: Vector2i, cap_to_four: bool) -> int:
	var component := _collect_component(board, grid, coord, TileState.Element.RIVER)
	if component.is_empty():
		return 0
	var new_len := _river_route_length_nodes(grid, component)

	# Compare against the best reachable route length before placing this river tile.
	var old_board := _clone_board(board)
	var reverted: TileState = old_board[coord]
	reverted.element = TileState.Element.NONE
	reverted.stack_count = 0

	var old_best_len := 0
	var seen: Dictionary = {}
	for n in grid.neighbors(coord):
		var t: TileState = old_board[n]
		if t.element != TileState.Element.RIVER or seen.has(n):
			continue
		var old_component := _collect_component(old_board, grid, n, TileState.Element.RIVER)
		for c in old_component:
			seen[c] = true
		old_best_len = maxi(old_best_len, _river_route_length_nodes(grid, old_component))

	if new_len <= old_best_len:
		return 0
	return _river_length_points(new_len, cap_to_four)

func _river_length_points(length: int, cap_to_four: bool) -> int:
	var l := maxi(length, 1)
	if cap_to_four:
		l = mini(l, 4)
	if l <= 1:
		return 0
	if l == 2:
		return 2
	if l == 3:
		return 5
	if l == 4:
		return 8
	if l == 5:
		return 11
	if l == 6:
		return 15
	return 15 + ((l - 6) * 4)

func _river_degree_in_component(board: Dictionary, grid, coord: Vector2i) -> int:
	var degree := 0
	for n in grid.neighbors(coord):
		if (board[n] as TileState).element == TileState.Element.RIVER:
			degree += 1
	return degree

func _is_big_lake_component(board: Dictionary, grid, component: Array[Vector2i]) -> bool:
	if component.size() != 7:
		return false
	var center_count := 0
	var outer_count := 0
	for c in component:
		var degree := _river_degree_in_component(board, grid, c)
		if degree == 6:
			center_count += 1
		elif degree == 3:
			outer_count += 1
		else:
			return false
	return center_count == 1 and outer_count == 6

func _has_mountain_neighbor(board: Dictionary, grid, coord: Vector2i) -> bool:
	for n in grid.neighbors(coord):
		if (board[n] as TileState).element == TileState.Element.MOUNTAIN:
			return true
	return false

func _has_forest_neighbor(board: Dictionary, grid, coord: Vector2i) -> bool:
	for n in grid.neighbors(coord):
		if (board[n] as TileState).element == TileState.Element.FOREST:
			return true
	return false

func _field_stack_counts(board: Dictionary, component: Array[Vector2i]) -> Dictionary:
	var counts := {}
	for c in component:
		var stacks := int((board[c] as TileState).stack_count)
		counts[stacks] = int(counts.get(stacks, 0)) + 1
	return counts

func _spec_key(element: int, stacks: int) -> String:
	return "%d:%d" % [element, stacks]

func _def_for(element: int) -> Dictionary:
	return element_defs.get(element, {})

func _parse_specs(raw: String) -> Array[String]:
	var out: Array[String] = []
	if raw.is_empty():
		return out
	for part in raw.split("|", false):
		var p := part.strip_edges()
		if _is_valid_spec(p):
			out.append(p)
	return out

func _parse_icons(raw: String) -> Array[String]:
	var out: Array[String] = []
	if raw.is_empty():
		return out
	for part in raw.split("|", false):
		out.append(part.strip_edges())
	return out

func _is_valid_spec(spec: String) -> bool:
	var parts := spec.split(":", false)
	return parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int()

func _init_default_element_defs() -> void:
	element_defs = {
		TileState.Element.FOREST: {
			"name": "Forest",
			"base_draw_weight": 20.0,
			"draw_self_delta": -5.0,
			"draw_other_delta": 1.0,
			"min_draw_weight": 1.0,
			"max_stacks": 2,
			"allowed_place_specs": ["0:0", "1:0", "1:1"],
			"icons": ["F0", "F1", "F2"],
			"available_rules": ["connected_tiered_1_3_7", "connected_mid_high_flat_4", "component_two_each_cap_ten", "jungle_pairs_fifteen"],
			"default_rule": "connected_tiered_1_3_7"
		},
		TileState.Element.FIELD: {
			"name": "Field",
			"base_draw_weight": 20.0,
			"draw_self_delta": -5.0,
			"draw_other_delta": 1.0,
			"min_draw_weight": 1.0,
			"max_stacks": 1,
			"allowed_place_specs": ["0:0", "2:0"],
			"icons": ["A0", "A1"],
			"available_rules": ["group_three_mix", "three_fields_only", "pair_field_grassland", "isolated_field_five"],
			"default_rule": "group_three_mix"
		},
		TileState.Element.MOUNTAIN: {
			"name": "Mountain",
			"base_draw_weight": 20.0,
			"draw_self_delta": -5.0,
			"draw_other_delta": 1.0,
			"min_draw_weight": 1.0,
			"max_stacks": 2,
			"allowed_place_specs": ["0:0", "3:0", "3:1"],
			"icons": ["M0", "M1", "M2"],
			"available_rules": ["connected_tiered_1_3_7", "connected_mid_high_5_10", "tiered_3_3_1", "mid_high_flat_4"],
			"default_rule": "connected_tiered_1_3_7"
		},
		TileState.Element.RIVER: {
			"name": "River",
			"base_draw_weight": 20.0,
			"draw_self_delta": -5.0,
			"draw_other_delta": 1.0,
			"min_draw_weight": 1.0,
			"max_stacks": 0,
			"allowed_place_specs": ["0:0"],
			"icons": ["R0"],
			"available_rules": ["shortest_route", "short_river", "small_lakes", "big_lakes"],
			"default_rule": "shortest_route"
		},
		TileState.Element.WETLANDS: {
			"name": "Wetlands",
			"base_draw_weight": 20.0,
			"draw_self_delta": -5.0,
			"draw_other_delta": 1.0,
			"min_draw_weight": 1.0,
			"max_stacks": 0,
			"allowed_place_specs": ["1:0", "2:0", "4:0"],
			"icons": ["W0"],
			"available_rules": ["diverse_neighbors_three_plus", "group_flat_four", "group_three_ten", "two_river_neighbors_four"],
			"default_rule": "diverse_neighbors_three_plus"
		}
	}

func _parse_rule_ids(raw: String) -> Array[String]:
	var out: Array[String] = []
	if raw.is_empty():
		return out
	for part in raw.split("|", false):
		var rid := part.strip_edges()
		if not rid.is_empty():
			out.append(rid)
	return out

func _rule_library_for_element_key(element_key: String) -> Dictionary:
	match element_key:
		"forest":
			return {
				"connected_tiered_1_3_7": Callable(self, "_rule_forest_connected_tiered_1_3_7"),
				"connected_mid_high_flat_4": Callable(self, "_rule_forest_connected_mid_high_flat_4"),
				"component_two_each_cap_ten": Callable(self, "_rule_forest_component_two_each_cap_ten"),
				"jungle_pairs_fifteen": Callable(self, "_rule_forest_jungle_pairs_fifteen")
			}
		"field":
			return {
				"group_three_mix": Callable(self, "_rule_field_group_three_mix"),
				"three_fields_only": Callable(self, "_rule_field_three_fields_only"),
				"pair_field_grassland": Callable(self, "_rule_field_pair_field_grassland"),
				"isolated_field_five": Callable(self, "_rule_field_isolated_field_five")
			}
		"mountain":
			return {
				"connected_tiered_1_3_7": Callable(self, "_rule_mountain_connected_tiered_1_3_7"),
				"connected_mid_high_5_10": Callable(self, "_rule_mountain_connected_mid_high_5_10"),
				"tiered_3_3_1": Callable(self, "_rule_mountain_tiered_3_3_1"),
				"mid_high_flat_4": Callable(self, "_rule_mountain_mid_high_flat_4")
			}
		"river":
			return {
				"shortest_route": Callable(self, "_rule_river_shortest_route"),
				"short_river": Callable(self, "_rule_river_short_river"),
				"small_lakes": Callable(self, "_rule_river_small_lakes"),
				"big_lakes": Callable(self, "_rule_river_big_lakes")
			}
		"wetlands":
			return {
				"diverse_neighbors_three_plus": Callable(self, "_rule_wetlands_diverse_neighbors_three_plus"),
				"group_flat_four": Callable(self, "_rule_wetlands_group_flat_four"),
				"group_three_ten": Callable(self, "_rule_wetlands_group_three_ten"),
				"two_river_neighbors_four": Callable(self, "_rule_wetlands_two_river_neighbors_four")
			}
		_:
			return {}

func _clone_board(board: Dictionary) -> Dictionary:
	var clone: Dictionary = {}
	for c in board.keys():
		clone[c] = (board[c] as TileState).clone()
	return clone
