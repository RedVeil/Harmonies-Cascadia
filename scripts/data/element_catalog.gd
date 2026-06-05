extends Node

var path = "res://data/element_catalog.json"

var elements: Array[Element]

# Called when the node enters the scene tree for the first time.
## ----- Initialisation ----- ##

func _ready() -> void:
	load_elements()

## ----- Loading Logic ----- ##

func load_elements():
	if not FileAccess.file_exists(path):
		push_error("Element data not found: %s" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid element data JSON: %s" % path)
		return false
	for element in parsed:
		elements.append(parse_element(element))

## ----- Parsing Logic ----- ##

func parse_element(element:Dictionary) -> Element:
	var element_data := Element.new()
	element_data.type = element.id
	element_data.name = element.name
	element_data.scoring_rules.assign(element.scoring_rules)
	if element_data.scoring_rules.size() > 0:
		element_data.active_scoring_rule = element.scoring_rules[0]
	
	var levels : Array[ElementLevel] = []
	for l in element.levels:
		levels.append(parse_level(l))
	element_data.levels = levels
	
	return element_data

func parse_level(data:Dictionary) -> ElementLevel:
	var level = ElementLevel.new()
	level.name = data.name
	level.level = data.level
	level.icon = data.icon
	level.color = data.color
	
	return level
