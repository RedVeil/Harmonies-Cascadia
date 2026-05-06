class_name QuestSystem
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")
const GroupAnalyzer = preload("res://scripts/scoring/GroupAnalyzer.gd")

var rng := RandomNumberGenerator.new()
var analyzer := GroupAnalyzer.new()

var active_quest: Dictionary = {}
var placed_tile_count: int = 0
var guaranteed_first_quest_spawned: bool = false
var current_spawn_chance: float = 0.0
var spawn_base_chance: float = 0.06
var spawn_chance_step: float = 0.03
var default_completion_points: int = 25

var quest_pool: Array[Dictionary] = [
	{"id": "forest_groups_5_any", "element": TileState.Element.FOREST, "required_groups": 5, "min_group_size": 1, "max_group_size": -1, "icon": "F0", "icon_texture": null, "points": 25},
	{"id": "field_groups_3_exact3", "element": TileState.Element.FIELD, "required_groups": 3, "min_group_size": 3, "max_group_size": 3, "icon": "A0", "icon_texture": null, "points": 25},
	{"id": "mountain_group_1_size10", "element": TileState.Element.MOUNTAIN, "required_groups": 1, "min_group_size": 10, "max_group_size": -1, "icon": "M0", "icon_texture": null, "points": 25}
]

func _init() -> void:
	rng.randomize()
	current_spawn_chance = spawn_base_chance

func configure_spawn(base_chance: float, chance_step: float) -> void:
	spawn_base_chance = clampf(base_chance, 0.0, 1.0)
	spawn_chance_step = clampf(chance_step, 0.0, 1.0)
	current_spawn_chance = spawn_base_chance

func load_quests_csv(path: String) -> void:
	var loaded: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Quest CSV not found: %s" % path)
		return
	var row_index := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		row_index += 1
		if line.is_empty() or line.begins_with("#"):
			continue
		if row_index == 1 and line.to_lower().begins_with("id,"):
			continue
		var cols: PackedStringArray = line.split(",", false)
		if cols.size() < 6:
			continue
		var qid := cols[0].strip_edges()
		var element := _parse_element_token(cols[1].strip_edges().to_lower())
		if qid.is_empty() or element == TileState.Element.NONE:
			continue
		var required := maxi(int(cols[2].strip_edges()), 1)
		var min_size := maxi(int(cols[3].strip_edges()), 1)
		var max_raw := cols[4].strip_edges().to_lower()
		var max_size := -1
		if max_raw != "*" and max_raw != "inf" and max_raw != "infinity" and max_raw != "-1":
			max_size = maxi(int(cols[4].strip_edges()), min_size)
		var icon := cols[5].strip_edges()
		var points := default_completion_points
		if cols.size() > 6:
			points = int(cols[6].strip_edges())
		loaded.append({
			"id": qid,
			"element": element,
			"required_groups": required,
			"min_group_size": min_size,
			"max_group_size": max_size,
			"icon": icon,
			"icon_texture": _load_icon_texture(icon),
			"points": points
		})
	if not loaded.is_empty():
		quest_pool = loaded

func on_tile_placed(board: Dictionary, grid) -> Dictionary:
	placed_tile_count += 1
	var message := ""
	var spawned := false
	var completed := false
	var delta_points := 0

	if not active_quest.is_empty() and _is_quest_completed(board, grid, active_quest):
		completed = true
		delta_points = int(active_quest.get("points", default_completion_points))
		message = "Quest complete: %s (+%d)" % [_quest_text(active_quest), delta_points]
		active_quest.clear()

	if active_quest.is_empty():
		if not guaranteed_first_quest_spawned and placed_tile_count >= 10:
			active_quest = _roll_quest()
			guaranteed_first_quest_spawned = true
			current_spawn_chance = spawn_base_chance
			spawned = true
			message = "New quest: %s" % _quest_text(active_quest)
		elif guaranteed_first_quest_spawned:
			if rng.randf() <= current_spawn_chance:
				active_quest = _roll_quest()
				current_spawn_chance = spawn_base_chance
				spawned = true
				message = "New quest: %s" % _quest_text(active_quest)
			else:
				current_spawn_chance = minf(1.0, current_spawn_chance + spawn_chance_step)

	return {"spawned": spawned, "completed": completed, "message": message, "delta_points": delta_points}

func preview_completion(board: Dictionary, grid) -> Dictionary:
	if active_quest.is_empty():
		return {"completed": false, "delta_points": 0, "highlight_tiles": []}
	var matched := _matching_groups(board, grid, active_quest)
	var required := int(active_quest.get("required_groups", 0))
	if matched.size() < required:
		return {"completed": false, "delta_points": 0, "highlight_tiles": []}
	var out: Array[Vector2i] = []
	for i in range(mini(required, matched.size())):
		for c in (matched[i] as Dictionary).get("coords", []):
			var vc := c as Vector2i
			if not out.has(vc):
				out.append(vc)
	return {"completed": true, "delta_points": int(active_quest.get("points", default_completion_points)), "highlight_tiles": out}

func active_quest_text() -> String:
	if active_quest.is_empty():
		return "No active quest"
	return _quest_text(active_quest)

func active_quest_rule_text() -> String:
	if active_quest.is_empty():
		return ""
	return _quest_text(active_quest)

func active_quest_progress_text(board: Dictionary, grid) -> String:
	if active_quest.is_empty():
		return ""
	var have := _matching_group_count(board, grid, active_quest)
	var need := int(active_quest.get("required_groups", 0))
	return "Progress %d/%d" % [min(have, need), need]

func active_quest_progress_ratio(board: Dictionary, grid) -> float:
	if active_quest.is_empty():
		return 0.0
	var have := _matching_group_count(board, grid, active_quest)
	var need := maxi(int(active_quest.get("required_groups", 1)), 1)
	return clampf(float(have) / float(need), 0.0, 1.0)

func active_quest_icon_texture() -> Texture2D:
	if active_quest.is_empty():
		return null
	return active_quest.get("icon_texture", null) as Texture2D

func _roll_quest() -> Dictionary:
	if quest_pool.is_empty():
		return {}
	var idx := rng.randi_range(0, quest_pool.size() - 1)
	return (quest_pool[idx] as Dictionary).duplicate(true)

func _is_quest_completed(board: Dictionary, grid, quest: Dictionary) -> bool:
	return _matching_group_count(board, grid, quest) >= int(quest.get("required_groups", 0))

func _matching_group_count(board: Dictionary, grid, quest: Dictionary) -> int:
	return _matching_groups(board, grid, quest).size()

func _matching_groups(board: Dictionary, grid, quest: Dictionary) -> Array[Dictionary]:
	var element := int(quest.get("element", TileState.Element.NONE))
	var min_size := int(quest.get("min_group_size", 1))
	var max_size := int(quest.get("max_group_size", -1))
	var groups := analyzer.collect_groups(board, grid, element)
	var matched: Array[Dictionary] = []
	for g in groups:
		var size := int((g as Dictionary).get("size", 0))
		if size < min_size:
			continue
		if max_size >= 0 and size > max_size:
			continue
		matched.append(g as Dictionary)
	matched.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("size", 0)) > int(b.get("size", 0))
	)
	return matched

func _quest_text(quest: Dictionary) -> String:
	var required := int(quest.get("required_groups", 0))
	var min_size := int(quest.get("min_group_size", 1))
	var max_size := int(quest.get("max_group_size", -1))
	var e := int(quest.get("element", TileState.Element.NONE))
	var size_text := "size >= %d" % min_size if max_size < 0 else "size %d-%d" % [min_size, max_size]
	return "%d %s groups (%s)" % [required, _element_name(e), size_text]

func _element_name(element: int) -> String:
	match element:
		TileState.Element.FOREST:
			return "Forest"
		TileState.Element.FIELD:
			return "Field"
		TileState.Element.MOUNTAIN:
			return "Mountain"
		TileState.Element.RIVER:
			return "River"
		TileState.Element.WETLANDS:
			return "Wetlands"
		_:
			return "None"

func _parse_element_token(raw: String) -> int:
	if raw.is_valid_int():
		var id := int(raw)
		if id >= TileState.Element.FOREST and id <= TileState.Element.WETLANDS:
			return id
		return TileState.Element.NONE
	match raw:
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
