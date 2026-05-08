class_name AnimalSystem
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")
const HexCoord = preload("res://scripts/hex/HexCoord.gd")

var animals_by_id: Dictionary = {}
var animal_id_by_name: Dictionary = {}

func load_animals_csv(path: String) -> void:
	animals_by_id.clear()
	animal_id_by_name.clear()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Animal CSV not found: %s" % path)
		return

	var row_index := 0
	var next_auto_id := 1
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		row_index += 1
		if line.is_empty() or line.begins_with("#"):
			continue
		if row_index == 1 and (line.to_lower().begins_with("name,") or line.to_lower().begins_with("id,")):
			continue

		var cols: PackedStringArray = line.split(",", false)
		if cols.size() < 7:
			push_error("Invalid animal row: %s" % line)
			continue

		var animal_name: String = cols[0].strip_edges()
		var animal_id: int = next_auto_id
		var maybe_id := cols[0].strip_edges()
		if maybe_id.is_valid_int():
			animal_id = int(maybe_id)
			animal_name = cols[1].strip_edges()
		else:
			next_auto_id += 1

		var points_col := 1
		var symbol_col := 2
		var draw_col := 3
		var amount_col := 4
		var draw_elements_col := 5
		var pattern_col := 6
		if cols[0].strip_edges().is_valid_int():
			points_col = 2
			symbol_col = 3
			draw_col = 4
			amount_col = 5
			draw_elements_col = 6
			pattern_col = 7

		var required_cols := pattern_col + 1
		if cols.size() < required_cols:
			push_error("Invalid animal row (missing columns): %s" % line)
			continue

		var symbol_path := ""
		if cols.size() > symbol_col:
			symbol_path = cols[symbol_col].strip_edges()
		var draw_chance := 1.0
		if cols.size() > draw_col:
			draw_chance = maxf(float(cols[draw_col].strip_edges()), 0.0)
		var draw_amount := 1
		if cols.size() > amount_col:
			draw_amount = maxi(int(cols[amount_col].strip_edges()), 1)
		var draw_elements: Array[int] = []
		if cols.size() > draw_elements_col:
			draw_elements = _parse_draw_elements(cols[draw_elements_col].strip_edges())
		if draw_elements.is_empty():
			push_error("Animal row missing valid draw_elements: %s" % line)
			continue
		var pattern_raw := ""
		if cols.size() > pattern_col:
			pattern_raw = cols[pattern_col].strip_edges()
		var pattern := _parse_pattern(pattern_raw)
		if pattern.is_empty():
			push_error("Animal row missing valid pattern: %s" % line)
			continue
		var symbol_texture: Texture2D = null
		if not symbol_path.is_empty() and ResourceLoader.exists(symbol_path):
			var loaded := load(symbol_path)
			if loaded is Texture2D:
				symbol_texture = loaded as Texture2D

		animals_by_id[animal_id] = {
			"name": animal_name,
			"draw_elements": draw_elements,
			"point_score": int(cols[points_col].strip_edges()),
			"symbol_path": symbol_path,
			"symbol_texture": symbol_texture,
			"draw_chance": draw_chance,
			"draw_amount": draw_amount,
			"pattern": pattern
		}
		animal_id_by_name[animal_name.to_lower()] = animal_id

func can_place_animal(board: Dictionary, coord: Vector2i, animal: int) -> bool:
	if not board.has(coord):
		return false
	if not animals_by_id.has(animal):
		return false
	var def: Dictionary = animals_by_id[animal]
	var tile: TileState = board[coord]
	if tile.element == TileState.Element.NONE or tile.animal != 0:
		return false
	var pattern: Dictionary = def.get("pattern", {})
	var center_req: Dictionary = pattern.get("center", {})
	if center_req.is_empty():
		return false
	return _tile_matches_requirement(tile, center_req)

func score_animal(board: Dictionary, grid, coord: Vector2i, animal: int) -> int:
	if not can_place_animal(board, coord, animal):
		return 0
	var def: Dictionary = animals_by_id[animal]
	if _requirements_met(board, coord, def):
		return int(def["point_score"])
	return 0

func pattern_contributor_tiles(board: Dictionary, coord: Vector2i, animal: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not animals_by_id.has(animal):
		return out
	var def: Dictionary = animals_by_id[animal]
	var pattern: Dictionary = def.get("pattern", {})
	if pattern.is_empty():
		return out
	var match_result := _match_pattern(board, coord, pattern)
	if not bool(match_result.get("matched", false)):
		return out
	for c in match_result.get("tiles", []):
		var tile_coord := c as Vector2i
		if tile_coord != coord and not out.has(tile_coord):
			out.append(tile_coord)
	return out

func animal_name(animal: int) -> String:
	if animals_by_id.has(animal):
		return String(animals_by_id[animal]["name"])
	return "Unknown"

func animal_symbol_texture(animal: int) -> Texture2D:
	if not animals_by_id.has(animal):
		return null
	return animals_by_id[animal]["symbol_texture"] as Texture2D

func animal_ids_for_element(element: int) -> Array[int]:
	var out: Array[int] = []
	for k in animals_by_id.keys():
		var id := int(k)
		var def: Dictionary = animals_by_id[id]
		if (def["draw_elements"] as Array).has(element):
			out.append(id)
	return out

func animal_draw_chance(animal: int) -> float:
	if not animals_by_id.has(animal):
		return 0.0
	return float(animals_by_id[animal]["draw_chance"])

func animal_draw_amount(animal: int) -> int:
	if not animals_by_id.has(animal):
		return 1
	return maxi(int(animals_by_id[animal].get("draw_amount", 1)), 1)

func _requirements_met(board: Dictionary, center: Vector2i, def: Dictionary) -> bool:
	var pattern: Dictionary = def.get("pattern", {})
	if pattern.is_empty():
		return false
	return _pattern_requirements_met(board, center, pattern)

func _pattern_requirements_met(board: Dictionary, center: Vector2i, pattern: Dictionary) -> bool:
	return bool(_match_pattern(board, center, pattern).get("matched", false))

func _match_pattern(board: Dictionary, center: Vector2i, pattern: Dictionary) -> Dictionary:
	if not board.has(center):
		return {"matched": false, "tiles": []}
	var center_req: Dictionary = pattern.get("center", {})
	if center_req.is_empty():
		return {"matched": false, "tiles": []}
	if not _tile_matches_requirement(board[center] as TileState, center_req):
		return {"matched": false, "tiles": []}

	var fixed_requirements: Array = pattern.get("requirements", [])
	var adjacent_requirements: Array = pattern.get("adjacent", [])
	for mirrored in [false, true]:
		for rot in range(6):
			var fixed := _fixed_requirements_match(board, center, fixed_requirements, rot, mirrored)
			if not bool(fixed.get("matched", false)):
				continue
			var adjacent := _adjacent_requirements_match(board, center, adjacent_requirements)
			if not bool(adjacent.get("matched", false)):
				continue
			var matched_tiles: Array[Vector2i] = [center]
			for c in fixed.get("tiles", []):
				var fc := c as Vector2i
				if not matched_tiles.has(fc):
					matched_tiles.append(fc)
			for c in adjacent.get("tiles", []):
				var ac := c as Vector2i
				if not matched_tiles.has(ac):
					matched_tiles.append(ac)
			return {"matched": true, "tiles": matched_tiles}
	return {"matched": false, "tiles": []}

func _fixed_requirements_match(board: Dictionary, center: Vector2i, requirements: Array, rotation_steps: int, mirrored: bool) -> Dictionary:
	var tiles: Array[Vector2i] = []
	for item in requirements:
		var req := item as Dictionary
		var offset := _transform_offset(req.get("offset", Vector2i.ZERO) as Vector2i, rotation_steps, mirrored)
		var target := center + offset
		if not board.has(target):
			return {"matched": false, "tiles": []}
		var target_tile: TileState = board[target] as TileState
		if not _tile_matches_requirement(target_tile, req):
			return {"matched": false, "tiles": []}
		if not tiles.has(target):
			tiles.append(target)
	return {"matched": true, "tiles": tiles}

func _adjacent_requirements_match(board: Dictionary, center: Vector2i, requirements: Array) -> Dictionary:
	var all_tiles: Array[Vector2i] = []
	for item in requirements:
		var req := item as Dictionary
		var needed := int(req.get("count", 0))
		if needed <= 0:
			continue
		var matched_neighbors: Array[Vector2i] = []
		for dir in HexCoord.DIRECTIONS:
			var n := center + (dir as Vector2i)
			if not board.has(n):
				continue
			var n_tile: TileState = board[n] as TileState
			if _tile_matches_requirement(n_tile, req) and not matched_neighbors.has(n):
				matched_neighbors.append(n)
		if matched_neighbors.size() < needed:
			return {"matched": false, "tiles": []}
		for i in range(needed):
			var picked: Vector2i = matched_neighbors[i]
			if not all_tiles.has(picked):
				all_tiles.append(picked)
	return {"matched": true, "tiles": all_tiles}

func _tile_matches_requirement(tile: TileState, req: Dictionary) -> bool:
	var element := int(req.get("element", TileState.Element.NONE))
	if int(tile.element) != element:
		return false
	var stack = req.get("stack", "*")
	if stack is String and String(stack) == "*":
		return true
	return int(tile.stack_count) == int(stack)

func _rotate_axial(offset: Vector2i, steps: int) -> Vector2i:
	var out := offset
	for _i in range(posmod(steps, 6)):
		# 60 degree clockwise rotation in axial coordinates.
		out = Vector2i(-out.y, out.x + out.y)
	return out

func _mirror_axial(offset: Vector2i) -> Vector2i:
	# Mirror around one hex-axis; combined with rotations this covers all reflections.
	return Vector2i(-offset.x - offset.y, offset.y)

func _transform_offset(offset: Vector2i, rotation_steps: int, mirrored: bool) -> Vector2i:
	var out := offset
	if mirrored:
		out = _mirror_axial(out)
	return _rotate_axial(out, rotation_steps)

func resolve_animal_ref(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		var id := int(value)
		return id if animals_by_id.has(id) else 0
	var s := str(value).strip_edges()
	if s.is_valid_int():
		var id2 := int(s)
		return id2 if animals_by_id.has(id2) else 0
	var key := s.to_lower()
	if animal_id_by_name.has(key):
		return int(animal_id_by_name[key])
	return 0

func tile_spec_key(tile: TileState) -> String:
	return tile.spec_key()

func parse_spec_key(spec: String) -> Dictionary:
	var parts := spec.split(":", false)
	if parts.size() != 2:
		return {}
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return {}
	return {"element": int(parts[0]), "stacks": int(parts[1])}

func _parse_draw_elements(raw: String) -> Array[int]:
	if raw.is_empty():
		return []
	var out: Array[int] = []
	for part in raw.split("|", false):
		var p := part.strip_edges()
		if not p.is_valid_int():
			return []
		var id := int(p)
		if id < TileState.Element.FOREST or id > TileState.Element.WETLANDS:
			return []
		out.append(id)
	return out

func _parse_pattern(raw: String) -> Dictionary:
	if raw.is_empty():
		return {}
	var out := {
		"center": {},
		"requirements": [],
		"adjacent": []
	}
	for part in raw.split("|", false):
		var token := part.strip_edges()
		if token.is_empty():
			continue
		if token.contains("=") and not token.begins_with("center=") and not token.begins_with("req=") and not token.begins_with("any_adjacent="):
			var compact_entry := _parse_compact_pattern_entry(token)
			if compact_entry.is_empty():
				return {}
			var offset := compact_entry.get("offset", Vector2i.ZERO) as Vector2i
			if offset == Vector2i.ZERO:
				out["center"] = compact_entry.get("requirement", {})
			else:
				var req = compact_entry.get("requirement", {}).duplicate(true)
				req["offset"] = offset
				(out["requirements"] as Array).append(req)
			continue
		if token.begins_with("center="):
			var center_req := _parse_element_stack_token(token.trim_prefix("center=").strip_edges())
			if center_req.is_empty():
				return {}
			out["center"] = center_req
			continue
		if token.begins_with("req="):
			var req_body := token.trim_prefix("req=").strip_edges()
			var pieces := req_body.split(":", false)
			if pieces.size() != 4:
				return {}
			if not pieces[0].is_valid_int() or not pieces[1].is_valid_int():
				return {}
			var target_req := _parse_element_stack_token("%s:%s" % [pieces[2].strip_edges(), pieces[3].strip_edges()])
			if target_req.is_empty():
				return {}
			target_req["offset"] = Vector2i(int(pieces[0]), int(pieces[1]))
			(out["requirements"] as Array).append(target_req)
			continue
		if token.begins_with("any_adjacent="):
			var adj_body := token.trim_prefix("any_adjacent=").strip_edges()
			var adj_parts := adj_body.split(":", false)
			if adj_parts.size() != 3:
				return {}
			var adj_req := _parse_element_stack_token("%s:%s" % [adj_parts[0].strip_edges(), adj_parts[1].strip_edges()])
			if adj_req.is_empty():
				return {}
			if not adj_parts[2].strip_edges().is_valid_int():
				return {}
			adj_req["count"] = max(0, int(adj_parts[2].strip_edges()))
			(out["adjacent"] as Array).append(adj_req)
			continue
		return {}
	if (out["center"] as Dictionary).is_empty():
		return {}
	return out

func _parse_compact_pattern_entry(token: String) -> Dictionary:
	var pieces := token.split("=", false)
	if pieces.size() != 2:
		return {}
	var coord_token := pieces[0].strip_edges()
	var req_token := pieces[1].strip_edges()

	var coord_parts := coord_token.split(":", false)
	if coord_parts.size() != 2:
		return {}
	if not coord_parts[0].strip_edges().is_valid_int() or not coord_parts[1].strip_edges().is_valid_int():
		return {}
	var offset := Vector2i(int(coord_parts[0].strip_edges()), int(coord_parts[1].strip_edges()))

	var bracket_open := req_token.find("[")
	var bracket_close := req_token.find("]")
	if bracket_open <= 0 or bracket_close <= bracket_open + 1:
		return {}
	if bracket_close != req_token.length() - 1:
		return {}
	var element_token := req_token.substr(0, bracket_open).strip_edges()
	var stack_token := req_token.substr(bracket_open + 1, bracket_close - bracket_open - 1).strip_edges()
	var requirement := _parse_element_stack_token("%s:%s" % [element_token, stack_token])
	if requirement.is_empty():
		return {}
	return {
		"offset": offset,
		"requirement": requirement
	}

func _parse_element_stack_token(raw: String) -> Dictionary:
	var parts := raw.split(":", false)
	if parts.size() != 2:
		return {}
	var element := _parse_element_token(parts[0].strip_edges().to_lower())
	var original_element := parts[0].strip_edges().to_lower()
	if element == TileState.Element.NONE and original_element != "none" and original_element != "dead_earth" and original_element != "0":
		return {}
	var stack_token := parts[1].strip_edges()
	if stack_token != "*" and not stack_token.is_valid_int():
		return {}
	if stack_token != "*" and int(stack_token) < 0:
		return {}
	return {
		"element": element,
		"stack": stack_token if stack_token == "*" else int(stack_token)
	}

func _parse_element_token(raw: String) -> int:
	if raw.is_valid_int():
		var id := int(raw)
		if id < TileState.Element.NONE or id > TileState.Element.WETLANDS:
			return TileState.Element.NONE
		return id
	match raw:
		"none", "dead_earth":
			return TileState.Element.NONE
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
