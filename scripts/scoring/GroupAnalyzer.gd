class_name GroupAnalyzer
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")

func collect_groups(board: Dictionary, grid, element: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for c in board.keys():
		var coord := c as Vector2i
		if seen.has(coord):
			continue
		var tile: TileState = board[coord]
		if tile.element != element:
			continue
		var coords := _collect_component(board, grid, coord, element)
		for gc in coords:
			seen[gc] = true
		var group := _build_group_context(board, grid, coords, element)
		out.append(group)
	return out

func group_for_coord(board: Dictionary, grid, coord: Vector2i, element: int) -> Dictionary:
	if not board.has(coord):
		return {}
	if (board[coord] as TileState).element != element:
		return {}
	var coords := _collect_component(board, grid, coord, element)
	return _build_group_context(board, grid, coords, element)

func connected_groups_touching_coord(board: Dictionary, grid, coord: Vector2i, element: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen_group_coords: Dictionary = {}
	for n in grid.neighbors(coord):
		if not board.has(n):
			continue
		if (board[n] as TileState).element != element:
			continue
		if seen_group_coords.has(n):
			continue
		var component := _collect_component(board, grid, n, element)
		for c in component:
			seen_group_coords[c] = true
		out.append(_build_group_context(board, grid, component, element))
	return out

func distinct_neighbor_specs_count(board: Dictionary, grid, coord: Vector2i, exclude_none: bool = true) -> int:
	var seen: Dictionary = {}
	for n in grid.neighbors(coord):
		var t: TileState = board[n]
		if exclude_none and t.element == TileState.Element.NONE:
			continue
		seen[t.spec_key()] = true
	return seen.size()

func distinct_neighbor_elements_count(board: Dictionary, grid, coord: Vector2i, exclude_none: bool = true) -> int:
	var seen: Dictionary = {}
	for n in grid.neighbors(coord):
		var t: TileState = board[n]
		if exclude_none and t.element == TileState.Element.NONE:
			continue
		seen[int(t.element)] = true
	return seen.size()

func river_neighbor_count(board: Dictionary, grid, coord: Vector2i) -> int:
	var count := 0
	for n in grid.neighbors(coord):
		if (board[n] as TileState).element == TileState.Element.RIVER:
			count += 1
	return count

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

func _build_group_context(board: Dictionary, grid, coords: Array[Vector2i], element: int) -> Dictionary:
	var stack_histogram: Dictionary = {}
	for c in coords:
		var stacks := int((board[c] as TileState).stack_count)
		stack_histogram[stacks] = int(stack_histogram.get(stacks, 0)) + 1

	var route_length := 0
	var degree_two_count := 0
	var has_big_lake_shape := false
	if element == TileState.Element.RIVER:
		route_length = _river_route_length_nodes(grid, coords)
		for c in coords:
			if river_neighbor_count(board, grid, c) == 2:
				degree_two_count += 1
		has_big_lake_shape = _is_big_lake_component(board, grid, coords)

	return {
		"element": element,
		"coords": coords,
		"size": coords.size(),
		"stack_histogram": stack_histogram,
		"route_length": route_length,
		"river_degree_two_count": degree_two_count,
		"is_big_lake_shape": has_big_lake_shape
	}

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

func _is_big_lake_component(board: Dictionary, grid, component: Array[Vector2i]) -> bool:
	if component.size() != 7:
		return false
	var center_count := 0
	var outer_count := 0
	for c in component:
		var degree := river_neighbor_count(board, grid, c)
		if degree == 6:
			center_count += 1
		elif degree == 3:
			outer_count += 1
		else:
			return false
	return center_count == 1 and outer_count == 6
