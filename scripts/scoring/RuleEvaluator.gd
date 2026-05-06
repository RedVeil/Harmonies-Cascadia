class_name RuleEvaluator
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")

func evaluate_group_rule(rule: Dictionary, board: Dictionary, grid, group: Dictionary, analyzer, placed_coord: Vector2i) -> int:
	if not _conditions_met(rule.get("conditions", []), board, grid, group, analyzer, placed_coord):
		return 0
	return _score_value(rule.get("score", {}), board, grid, group, analyzer, placed_coord)

func evaluate_tile_rule(rule: Dictionary, board: Dictionary, grid, tile_coord: Vector2i, group: Dictionary, analyzer) -> int:
	if not _conditions_met(rule.get("conditions", []), board, grid, group, analyzer, tile_coord):
		return 0
	return _score_value(rule.get("score", {}), board, grid, group, analyzer, tile_coord)

func _conditions_met(conditions: Array, board: Dictionary, grid, group: Dictionary, analyzer, coord: Vector2i) -> bool:
	for cond in conditions:
		if not _condition_met(cond as Dictionary, board, grid, group, analyzer, coord):
			return false
	return true

func _condition_met(cond: Dictionary, board: Dictionary, grid, group: Dictionary, analyzer, coord: Vector2i) -> bool:
	var kind := String(cond.get("kind", ""))
	match kind:
		"group_size":
			var size := int(group.get("size", 0))
			var min_v := int(cond.get("min", -1))
			var max_v := int(cond.get("max", -1))
			if min_v >= 0 and size < min_v:
				return false
			if max_v >= 0 and size > max_v:
				var max_mode := String(cond.get("max_mode", "invalidate"))
				if max_mode == "invalidate":
					return false
			return true
		"placed_stack_equals":
			var t: TileState = board[coord]
			return int(t.stack_count) == int(cond.get("value", 0))
		"has_same_element_neighbor":
			var e := int(group.get("element", TileState.Element.NONE))
			for n in grid.neighbors(coord):
				if (board[n] as TileState).element == e:
					return true
			return false
		"stack_count_exact":
			var hist: Dictionary = group.get("stack_histogram", {})
			return int(hist.get(int(cond.get("stack", 0)), 0)) == int(cond.get("count", 0))
		"stack_mix_exact":
			var hist2: Dictionary = group.get("stack_histogram", {})
			var wanted: Dictionary = cond.get("counts", {})
			for key in wanted.keys():
				var k := int(key)
				if int(hist2.get(k, 0)) != int(wanted[key]):
					return false
			return true
		"distinct_neighbor_specs_min":
			var min_count := int(cond.get("min", 0))
			var exclude_none := bool(cond.get("exclude_none", true))
			var count_mode := String(cond.get("count_mode", "spec"))
			if count_mode == "element":
				return analyzer.distinct_neighbor_elements_count(board, grid, coord, exclude_none) >= min_count
			return analyzer.distinct_neighbor_specs_count(board, grid, coord, exclude_none) >= min_count
		"river_neighbors_min":
			var min_r := int(cond.get("min", 0))
			return analyzer.river_neighbor_count(board, grid, coord) >= min_r
		"big_lake_shape":
			return bool(group.get("is_big_lake_shape", false))
		_:
			return true

func _score_value(score: Dictionary, board: Dictionary, grid, group: Dictionary, analyzer, coord: Vector2i) -> int:
	var kind := String(score.get("kind", "flat"))
	match kind:
		"flat":
			return int(score.get("value", 0))
		"stack_tier":
			var t: TileState = board[coord]
			var tiers: Array = score.get("tiers", [])
			for tier in tiers:
				var min_stack := int((tier as Dictionary).get("min_stack", 0))
				var max_stack := int((tier as Dictionary).get("max_stack", 99))
				if t.stack_count >= min_stack and t.stack_count <= max_stack:
					return int((tier as Dictionary).get("points", 0))
			return int(score.get("default", 0))
		"group_size_per_unit_capped":
			var size := int(group.get("size", 0))
			var per := int(score.get("per", 0))
			var cap_size := int(score.get("cap_size", size))
			return mini(size, cap_size) * per
		"pair_from_stack_min":
			var min_stack2 := int(score.get("min_stack", 0))
			var points_per_pair := int(score.get("pair_points", 0))
			var hist: Dictionary = group.get("stack_histogram", {})
			var count := 0
			for k in hist.keys():
				if int(k) >= min_stack2:
					count += int(hist[k])
			return int(floor(float(count) / 2.0)) * points_per_pair
		"stack0_lookup":
			var hist0: Dictionary = group.get("stack_histogram", {})
			var stack0_count := int(hist0.get(0, 0))
			var table: Dictionary = score.get("table", {})
			return int(table.get(str(stack0_count), score.get("default", 0)))
		"river_length_curve":
			var length := int(group.get("route_length", 0))
			var cap_to_four := bool(score.get("cap_to_four", false))
			return _river_length_points(length, cap_to_four)
		"river_degree_two_triplets":
			var count_d2 := int(group.get("river_degree_two_count", 0))
			return int(floor(float(count_d2) / 3.0)) * int(score.get("triplet_points", 0))
		_:
			return int(score.get("value", 0))

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
