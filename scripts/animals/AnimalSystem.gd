class_name AnimalSystem
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")
const HexCoord = preload("res://scripts/hex/HexCoord.gd")

var penalties_enabled: bool = true
var animals_by_id: Dictionary = {}
var animal_id_by_name: Dictionary = {}
var pending_goals: Array[Dictionary] = []

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
		if cols.size() < 10:
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

		var range_col := 1
		var timer_col := 2
		var points_col := 3
		var penalty_col := 4
		var enabled_col := 5
		var symbol_col := 6
		var draw_col := 7
		var amount_col := 8
		var place_types_col := 9
		var required_types_col := 10
		var draw_elements_col := 11
		if cols[0].strip_edges().is_valid_int():
			range_col = 2
			timer_col = 3
			points_col = 4
			penalty_col = 5
			enabled_col = 6
			symbol_col = 7
			draw_col = 8
			amount_col = 9
			place_types_col = 10
			required_types_col = 11
			draw_elements_col = 12

		var required_cols := enabled_col + 1
		if cols.size() < required_cols:
			push_error("Invalid animal row (missing columns): %s" % line)
			continue

		var check_range: int = int(cols[range_col].strip_edges())

		var symbol_path := ""
		if cols.size() > symbol_col:
			symbol_path = cols[symbol_col].strip_edges()
		var draw_chance := 1.0
		if cols.size() > draw_col:
			draw_chance = maxf(float(cols[draw_col].strip_edges()), 0.0)
		var draw_amount := 1
		if cols.size() > amount_col:
			draw_amount = maxi(int(cols[amount_col].strip_edges()), 1)
		var place_specs: Array[String] = []
		var required_specs: Array[String] = []
		if cols.size() > place_types_col:
			place_specs = _parse_spec_list(cols[place_types_col].strip_edges())
		if cols.size() > required_types_col:
			required_specs = _parse_spec_list(cols[required_types_col].strip_edges())
		if place_specs.is_empty():
			push_error("Animal row missing place_specs: %s" % line)
			continue
		if required_specs.is_empty():
			push_error("Animal row missing required_specs: %s" % line)
			continue
		var draw_elements: Array[int] = []
		if cols.size() > draw_elements_col:
			draw_elements = _parse_draw_elements(cols[draw_elements_col].strip_edges())
		if draw_elements.is_empty():
			draw_elements = _infer_draw_elements_from_specs(place_specs)
		if draw_elements.is_empty():
			push_error("Animal row missing valid draw_elements: %s" % line)
			continue
		var symbol_texture: Texture2D = null
		if not symbol_path.is_empty() and ResourceLoader.exists(symbol_path):
			var loaded := load(symbol_path)
			if loaded is Texture2D:
				symbol_texture = loaded as Texture2D

		animals_by_id[animal_id] = {
			"name": animal_name,
			"range": max(check_range, 0),
			"place_specs": place_specs,
			"required_specs": required_specs,
			"draw_elements": draw_elements,
			"turn_timer": int(cols[timer_col].strip_edges()),
			"point_score": int(cols[points_col].strip_edges()),
			"penalty_score": int(cols[penalty_col].strip_edges()),
			"enabled": cols[enabled_col].strip_edges().to_lower() != "false",
			"symbol_path": symbol_path,
			"symbol_texture": symbol_texture,
			"draw_chance": draw_chance,
			"draw_amount": draw_amount
		}
		animal_id_by_name[animal_name.to_lower()] = animal_id

func can_place_animal(board: Dictionary, coord: Vector2i, animal: int) -> bool:
	if not board.has(coord):
		return false
	if not animals_by_id.has(animal):
		return false
	var def: Dictionary = animals_by_id[animal]
	if not bool(def["enabled"]):
		return false
	var tile: TileState = board[coord]
	if tile.element == TileState.Element.NONE or tile.animal != 0:
		return false
	return (def["place_specs"] as Array).has(tile.spec_key())

func score_animal(board: Dictionary, grid, coord: Vector2i, animal: int) -> int:
	if not can_place_animal(board, coord, animal):
		return 0
	var def: Dictionary = animals_by_id[animal]
	if _requirements_met(board, coord, def):
		return int(def["point_score"])
	return 0

func register_animal_goal(board: Dictionary, coord: Vector2i, animal: int, created_turn: int) -> void:
	if not animals_by_id.has(animal):
		return
	var def: Dictionary = animals_by_id[animal]
	var timer := int(def["turn_timer"])
	var penalty := int(def["penalty_score"])
	if timer <= 0 or penalty <= 0:
		return
	if _requirements_met(board, coord, def):
		return
	pending_goals.append({
		"animal": animal,
		"coord": coord,
		"created_turn": created_turn,
		"turn_limit": timer,
		"penalty_points": penalty,
		"resolved": false
	})

func process_turn_penalties(board: Dictionary, current_turn: int) -> int:
	if not penalties_enabled:
		return 0
	var delta: int = 0
	for goal in pending_goals:
		if goal["resolved"]:
			continue
		if not board.has(goal["coord"]):
			goal["resolved"] = true
			continue
		if not animals_by_id.has(goal["animal"]):
			goal["resolved"] = true
			continue
		var def: Dictionary = animals_by_id[goal["animal"]]
		if _requirements_met(board, goal["coord"], def):
			goal["resolved"] = true
			continue
		if current_turn - int(goal["created_turn"]) >= int(goal["turn_limit"]):
			delta -= int(goal["penalty_points"])
			goal["resolved"] = true
	return delta

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
		if bool(def["enabled"]) and (def["draw_elements"] as Array).has(element):
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
	var check_range := int(def["range"])
	var found_counts: Dictionary = {}
	for c in board.keys():
		var coord := c as Vector2i
		var dist := HexCoord.distance(center, coord)
		if dist == 0 or dist > check_range:
			continue
		var t : String = (board[coord] as TileState).spec_key()
		found_counts[t] = int(found_counts.get(t, 0)) + 1

	var wanted_counts: Dictionary = {}
	for t in def["required_specs"] as Array:
		var key := str(t)
		wanted_counts[key] = int(wanted_counts.get(key, 0)) + 1

	for key in wanted_counts.keys():
		if int(found_counts.get(key, 0)) < int(wanted_counts[key]):
			return false
	return true

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

func _parse_spec_list(raw: String) -> Array[String]:
	if raw.is_empty():
		return []
	var parts := raw.split("|", false)
	var out: Array[String] = []
	for p in parts:
		var spec := _normalize_spec_token(p.strip_edges())
		if not spec.is_empty():
			out.append(spec)
	return out

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

func _infer_draw_elements_from_specs(specs: Array[String]) -> Array[int]:
	var set := {}
	for s in specs:
		var info := parse_spec_key(s)
		var e := int(info.get("element", TileState.Element.NONE))
		if e != TileState.Element.NONE:
			set[e] = true
	var out: Array[int] = []
	for k in set.keys():
		out.append(int(k))
	return out

func _normalize_spec_token(raw: String) -> String:
	if raw.is_empty():
		return ""
	var token := raw.strip_edges().to_lower()
	token = token.replace("(", "").replace(")", "")
	token = token.replace(",", ":")
	var parts := token.split(":", false)
	if parts.size() != 2:
		return ""
	var element_part := parts[0].strip_edges()
	var stacks_part := parts[1].strip_edges()
	var element := _parse_element_token(element_part)
	if element == TileState.Element.NONE and element_part != "none" and element_part != "dead_earth" and element_part != "0":
		return ""
	if not stacks_part.is_valid_int():
		return ""
	var stacks := int(stacks_part)
	if stacks < 0:
		return ""
	if stacks > 8:
		return ""
	return "%d:%d" % [element, stacks]

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
