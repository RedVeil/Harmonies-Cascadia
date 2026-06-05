extends Node


const path = "res://data/booster_catalog.json"


var booster_options: Array[BoosterOption] = []

## ----- Initialisation ----- ##

func _ready() -> void:
	build_booster_options()

## ----- Loading Logic ----- ##

func build_booster_options() -> bool:
	if not FileAccess.file_exists(path):
		push_error("Booster data not found: %s" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid booster data JSON: %s" % path)
		return false
	 
	for option in parsed:
		booster_options.append(parse_booster_option(option))
		
	return true

## ----- Parsing Logic ----- ##

func parse_booster_option(option:Dictionary) -> BoosterOption:
	var booster_option := BoosterOption.new()
	booster_option.type = option.type
	booster_option.draw_chance = option.draw_chance
	booster_option.extra_card_chance = option.extra_card_chance
	booster_option.extra_chance = option.extra_chance
	booster_option.base_content_options = parse_content_options(option.base_content_options)
	booster_option.extra_card_options = parse_content_options(option.extra_card_options)
	booster_option.extra_content_options = parse_content_options(option.extra_content_options)
	return booster_option

func parse_content_options(data:Array) -> Array[BoosterContentOption]:
	var result : Array[BoosterContentOption] = []
	for entry in data:
		var content_option = BoosterContentOption.new()
		
		match String(entry.get("type", "")):
			"element":
				content_option.type = BoosterContentOption.RewardType.ELEMENT
			"animal":
				content_option.type = BoosterContentOption.RewardType.ANIMAL
			"quest":
				content_option.type = BoosterContentOption.RewardType.QUEST
			"booster_point":
				content_option.type = BoosterContentOption.RewardType.BOOSTER_POINT
			"map_point":
				content_option.type = BoosterContentOption.RewardType.MAP_POINT
		content_option.id = entry.id
		content_option.amount = entry.amount
		content_option.draw_chance = entry.draw_chance
		result.append(content_option)
	
	return result
