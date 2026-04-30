class_name ScoreEngine
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")
const GroupAnalyzer = preload("res://scripts/scoring/GroupAnalyzer.gd")
const RuleEvaluator = preload("res://scripts/scoring/RuleEvaluator.gd")

var placement_bonus: int = 1
var selected_rule_set: Dictionary = {}
var available_rule_sets: Dictionary = {}
var element_defs: Dictionary = {}
var rules_config: Dictionary = {}
var group_analyzer := GroupAnalyzer.new()
var rule_evaluator := RuleEvaluator.new()

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
		var ids: Array[String] = (_def_for(eid).get("available_rules", []) as Array[String]).duplicate()
		var options := {}
		for rid in ids:
			if not _rule_def(String(element_key), rid).is_empty():
				options[rid] = true
		if options.is_empty():
			var all_defs: Dictionary = (rules_config.get("elements", {}) as Dictionary).get(String(element_key), {})
			for rid in all_defs.keys():
				options[String(rid)] = true
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
		if element_id < TileState.Element.NONE or element_id > TileState.Element.WETLANDS:
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
			"icon_textures": _parse_icon_textures(cols[8].strip_edges()),
			"available_rules": _parse_rule_ids(cols[9].strip_edges()) if cols.size() > 9 else [],
			"default_rule": cols[10].strip_edges() if cols.size() > 10 else ""
		}
	if element_defs.is_empty():
		_init_default_element_defs()
	_ensure_dead_earth_def()

func load_rules_json(path: String) -> void:
	rules_config.clear()
	if not FileAccess.file_exists(path):
		push_error("Rules JSON not found: %s" % path)
		return
	var raw := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		rules_config = parsed

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

func icon_texture_for(element: int, stacks: int) -> Texture2D:
	var textures: Array = _def_for(element).get("icon_textures", [])
	if textures.is_empty():
		return null
	var idx := clampi(stacks, 0, textures.size() - 1)
	return textures[idx] as Texture2D

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

func score_board_state(board: Dictionary, grid) -> Dictionary:
	var per_element_totals := {}
	var group_breakdown := {}
	var total_element_score := 0
	for element_key in ["forest", "field", "mountain", "river", "wetlands"]:
		var eid := _element_for_key(element_key)
		if eid == TileState.Element.NONE:
			continue
		var rule_id := rule_id_for(element_key)
		var rule_def := _rule_def(element_key, rule_id)
		if rule_def.is_empty():
			per_element_totals[element_key] = 0
			group_breakdown[element_key] = []
			continue
		var groups := group_analyzer.collect_groups(board, grid, eid)
		var element_total := 0
		var entries: Array[Dictionary] = []
		for g in groups:
			var group_score := _evaluate_group_rule(rule_def, board, grid, g as Dictionary)
			element_total += group_score
			entries.append({"coords": (g as Dictionary).get("coords", []), "score": group_score})
		per_element_totals[element_key] = element_total
		group_breakdown[element_key] = entries
		total_element_score += element_total
	return {
		"total_element_score": total_element_score,
		"per_element_totals": per_element_totals,
		"group_breakdown": group_breakdown
	}

func simulate_action_delta(board: Dictionary, grid, action: Dictionary) -> Dictionary:
	var kind := String(action.get("kind", ""))
	if kind != "element":
		return {"valid": false, "reason": "Unsupported action kind", "delta": 0}
	var coord: Vector2i = action.get("coord", Vector2i.ZERO)
	var element := int(action.get("element", TileState.Element.NONE))
	if not board.has(coord):
		return {"valid": false, "reason": "Outside map", "delta": 0}
	var tile: TileState = board[coord]
	if not can_place_element(tile, element):
		return {"valid": false, "reason": "Invalid base tile", "delta": 0}

	var before_snapshot := score_board_state(board, grid)
	var after_board := _clone_board(board)
	apply_element_placement(after_board[coord] as TileState, element)
	var after_snapshot := score_board_state(after_board, grid)
	var delta := int(after_snapshot["total_element_score"]) - int(before_snapshot["total_element_score"])
	var element_key := _key_for_element(element)
	var affected_group_tiles: Array[Vector2i] = []
	if not element_key.is_empty():
		var affected_groups := group_analyzer.connected_groups_touching_coord(after_board, grid, coord, element)
		for g in affected_groups:
			for gc in (g as Dictionary).get("coords", []):
				var c := gc as Vector2i
				if not affected_group_tiles.has(c):
					affected_group_tiles.append(c)
		if affected_group_tiles.is_empty():
			affected_group_tiles.append(coord)
	return {
		"valid": true,
		"reason": "Valid placement",
		"delta": delta,
		"before_snapshot": before_snapshot,
		"after_snapshot": after_snapshot,
		"after_board": after_board,
		"affected_group_tiles": affected_group_tiles,
		"element_key": element_key
	}

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

func _parse_icon_textures(raw: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if raw.is_empty():
		return out
	for part in raw.split("|", false):
		out.append(_load_icon_texture(part.strip_edges()))
	return out

func _load_icon_texture(token: String) -> Texture2D:
	if token.is_empty():
		return null
	var candidates: Array[String] = []
	if token.begins_with("res://"):
		candidates.append(token)
	else:
		candidates.append("res://assets/elements/%s.png" % token.to_lower())
		candidates.append("res://assets/elements/%s.webp" % token.to_lower())
		candidates.append("res://assets/elements/%s.jpg" % token.to_lower())
	for path in candidates:
		if ResourceLoader.exists(path):
			var loaded := load(path)
			if loaded is Texture2D:
				return loaded as Texture2D
	return null

func _is_valid_spec(spec: String) -> bool:
	var parts := spec.split(":", false)
	return parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int()

func _init_default_element_defs() -> void:
	element_defs = {
		TileState.Element.NONE: {
			"name": "DeadEarth",
			"base_draw_weight": 0.0,
			"draw_self_delta": 0.0,
			"draw_other_delta": 0.0,
			"min_draw_weight": 0.0,
			"max_stacks": 0,
			"allowed_place_specs": [],
			"icons": ["N0"],
			"icon_textures": _parse_icon_textures("N0"),
			"available_rules": [],
			"default_rule": ""
		},
		TileState.Element.FOREST: {
			"name": "Forest",
			"base_draw_weight": 20.0,
			"draw_self_delta": -5.0,
			"draw_other_delta": 1.0,
			"min_draw_weight": 1.0,
			"max_stacks": 2,
			"allowed_place_specs": ["0:0", "1:0", "1:1"],
			"icons": ["F0", "F1", "F2"],
			"icon_textures": _parse_icon_textures("F0|F1|F2"),
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
			"icon_textures": _parse_icon_textures("A0|A1"),
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
			"icon_textures": _parse_icon_textures("M0|M1|M2"),
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
			"icon_textures": _parse_icon_textures("R0"),
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
			"icon_textures": _parse_icon_textures("W0"),
			"available_rules": ["diverse_neighbors_three_plus", "group_flat_four", "group_three_ten", "two_river_neighbors_four"],
			"default_rule": "diverse_neighbors_three_plus"
		}
	}

func _ensure_dead_earth_def() -> void:
	if element_defs.has(TileState.Element.NONE):
		return
	element_defs[TileState.Element.NONE] = {
		"name": "DeadEarth",
		"base_draw_weight": 0.0,
		"draw_self_delta": 0.0,
		"draw_other_delta": 0.0,
		"min_draw_weight": 0.0,
		"max_stacks": 0,
		"allowed_place_specs": [],
		"icons": ["N0"],
		"icon_textures": _parse_icon_textures("N0"),
		"available_rules": [],
		"default_rule": ""
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

func _rule_def(element_key: String, rule_id: String) -> Dictionary:
	var elements: Dictionary = rules_config.get("elements", {})
	if not elements.has(element_key):
		return {}
	var defs: Dictionary = elements[element_key]
	return defs.get(rule_id, {})

func _evaluate_group_rule(rule_def: Dictionary, board: Dictionary, grid, group: Dictionary) -> int:
	var scope := String(rule_def.get("scope", "group"))
	match scope:
		"group":
			return rule_evaluator.evaluate_group_rule(rule_def, board, grid, group, group_analyzer, Vector2i.ZERO)
		"group_per_tile":
			var total := 0
			for c in group.get("coords", []):
				total += rule_evaluator.evaluate_tile_rule(rule_def, board, grid, c as Vector2i, group, group_analyzer)
			return total
		_:
			return rule_evaluator.evaluate_group_rule(rule_def, board, grid, group, group_analyzer, Vector2i.ZERO)

func _element_for_key(element_key: String) -> int:
	match element_key:
		"forest":
			return TileState.Element.FOREST
		"field":
			return TileState.Element.FIELD
		"mountain":
			return TileState.Element.MOUNTAIN
		"river":
			return TileState.Element.RIVER
		"wetlands":
			return TileState.Element.WETLANDS
		_:
			return TileState.Element.NONE

func _key_for_element(element: int) -> String:
	match element:
		TileState.Element.FOREST:
			return "forest"
		TileState.Element.FIELD:
			return "field"
		TileState.Element.MOUNTAIN:
			return "mountain"
		TileState.Element.RIVER:
			return "river"
		TileState.Element.WETLANDS:
			return "wetlands"
		_:
			return ""

func _clone_board(board: Dictionary) -> Dictionary:
	var clone: Dictionary = {}
	for c in board.keys():
		clone[c] = (board[c] as TileState).clone()
	return clone
