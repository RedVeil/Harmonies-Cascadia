extends Node2D
class_name QuestManager

@export var quest_limit: int = 3

@onready var quest_container: QuestContainer = $QuestContainer

var active_quests: Array[int] = []
var completed_quests: Array[int] = []

var active_quests_backup: Array[int] = []
var completed_quests_backup: Array[int] = []
var completed_slot_indices: Array[int] = []

var _rng: RandomNumberGenerator

## ----- Initialisation ----- ##

func _ready() -> void:
	_rng = GameSession.make_rng("quest")
	active_quests.resize(quest_limit)
	active_quests.fill(-1)
	active_quests_backup = active_quests.duplicate(true)
	quest_container.init(quest_limit)

## ----- Pass data downstream ----- ##

func add_quest(id: int) -> void:
	var quest_index := active_quests.find(-1)
	if quest_index != -1 and not completed_quests.has(id):
		active_quests[quest_index] = id
		quest_container.add_quest(quest_index, QuestCatalog.quest_options[id])

func remove_quest(index: int) -> void:
	completed_quests.append(active_quests[index])
	active_quests[index] = -1
	quest_container.remove_quest(index)

func reset_preview() -> void:
	pass

func apply_preview() -> void:
	pass

func prepare_place_undo() -> void:
	active_quests_backup = active_quests.duplicate(true)
	completed_quests_backup = completed_quests.duplicate(true)
	completed_slot_indices.clear()

## ----- Evaluate Quests ----- ##

func evaluate_pattern_quests(
	coord: Vector2i,
	tiles: Dictionary[Vector2i, HexTileData],
	placement_logic: PlacementLogic
) -> int:
	if not tiles.has(coord):
		return 0

	var placed := tiles[coord]
	var points := 0

	for i in active_quests.size():
		var quest_id := active_quests[i]
		if quest_id == -1:
			continue

		var quest: Quest = QuestCatalog.quest_options[quest_id]
		if not quest.matches_tile_role(placed.element, placed.level):
			continue

		var candidates: Array[Vector2i] = [coord]
		for n in HexCoord.neighbors(coord):
			candidates.append(n)

		for c in candidates:
			if not tiles.has(c):
				continue
			if not placement_logic.is_valid_center(tiles[c], quest.placement):
				continue
			var result := placement_logic.check_bonus_pattern(c, quest.bonus, tiles)
			if result.is_valid:
				points += quest.points
				completed_slot_indices.append(i)
				remove_quest(i)
				break

	return points

func undo() -> void:
	if completed_slot_indices.is_empty():
		return

	for index in completed_slot_indices:
		var quest_id := active_quests_backup[index]
		if quest_id == -1:
			continue
		quest_container.add_quest(index, QuestCatalog.quest_options[quest_id])

	active_quests = active_quests_backup.duplicate(true)
	completed_quests = completed_quests_backup.duplicate(true)
	completed_slot_indices.clear()

## ----- Create new active Quests ----- ##

func pick_quest(_type: int, element: int) -> int:
	if active_quests.find(-1) == -1:
		return -1

	var options_filtered := QuestCatalog.quest_options.filter(
		func(option: Quest) -> bool:
			return not completed_quests.has(option.id) and not active_quests.has(option.id)
	)
	if options_filtered.is_empty():
		return -1

	var options_by_element := options_filtered.filter(
		func(option: Quest) -> bool:
			return option.center_element() == element
	)
	var pool: Array = options_by_element if not options_by_element.is_empty() else options_filtered
	return pool[_rng.randi_range(0, pool.size() - 1)].id
