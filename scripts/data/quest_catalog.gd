extends Node

const path = "res://data/quest_catalog.json"

var quest_options: Array[Quest] = []

## ----- Initialisation ----- ##

func _ready() -> void:
	build_quest_options()

## ----- Loading Logic ----- ##

func build_quest_options() -> bool:
	if not FileAccess.file_exists(path):
		push_error("Quest data not found: %s" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid quest data JSON: %s" % path)
		return false

	for option in parsed:
		var quest := parse_quest_option(option)
		_validate_ring_pattern(quest)
		quest_options.append(quest)

	return true

## ----- Parsing Logic ----- ##

func parse_quest_option(option: Dictionary) -> Quest:
	var quest_option := Quest.new()
	quest_option.id = option.id
	quest_option.name = option.name
	quest_option.description = option.description
	quest_option.type = option.type
	quest_option.points = option.points

	var placement: Array[Placement] = []
	for p in option.placement:
		placement.append(parse_placement(p))
	quest_option.placement = placement

	var bonus: Array[Placement] = []
	for b in option.bonus:
		bonus.append(parse_placement(b))
	quest_option.bonus = bonus

	return quest_option

func parse_placement(data: Dictionary) -> Placement:
	var placement := Placement.new()
	placement.element = data.element
	placement.level = data.level
	placement.coords = Vector2i(data.coords[0], data.coords[1])
	return placement

func _validate_ring_pattern(quest: Quest) -> void:
	for b in quest.bonus:
		if HexCoord.distance(Vector2i.ZERO, b.coords) != 1:
			push_error(
				"Quest '%s' bonus offset %s must be in the first ring (distance 1)"
				% [quest.name, str(b.coords)]
			)
	for p in quest.placement + quest.bonus:
		var levels: Array = ElementCatalog.elements[p.element].levels
		if p.level < 1 or p.level > levels.size():
			push_error(
				"Quest '%s' uses %s level %d, but that element only has %d level(s)"
				% [quest.name, GameEnums.ELEMENT_NAMES[p.element], p.level, levels.size()]
			)
