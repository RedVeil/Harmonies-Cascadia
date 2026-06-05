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
		quest_options.append(parse_quest_option(option))
		
	return true

## ----- Parsing Logic ----- ##

func parse_quest_option(option:Dictionary) -> Quest:
	var quest_option := Quest.new()
	quest_option.id = option.id
	quest_option.name = option.name
	quest_option.description = option.description
	quest_option.type = option.type
	quest_option.target_id = option.target_id
	quest_option.levels.assign(option.levels)
	quest_option.min_group_size = option.min_group_size
	quest_option.max_group_size = option.max_group_size
	quest_option.group_amount = option.group_amount
	quest_option.points = option.points
	return quest_option
