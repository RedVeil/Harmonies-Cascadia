extends Node

var path = "res://data/card_catalog.json"

var elements: Array[CardData]
var animals: Array[CardData]

# Called when the node enters the scene tree for the first time.
## ----- Initialisation ----- ##

func _ready() -> void:
	load_cards()

## ----- Loading Logic ----- ##

func load_cards():
	if not FileAccess.file_exists(path):
		push_error("Booster data not found: %s" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid booster data JSON: %s" % path)
		return false
	
	for element in parsed.elements:
		elements.append(parse_card(element))
	for animal in parsed.animals:
		var card = parse_card(animal)
		animals.append(card)

## ----- Parsing Logic ----- ##

func parse_card(card:Dictionary) -> CardData:
	var card_data := CardData.new()
	card_data.id = card.id
	card_data.type = card.type
	card_data.name = card.name
	card_data.amount = card.amount
	card_data.visual_amount = int(card.get("visual_amount", 1))
	card_data.draw_chance = card.draw_chance
	card_data.point_score = card.point_score
	card_data.bonus_points = card.bonus_points
	card_data.icon = card.icon
	card_data.models.assign(card.get("models", []))
	card_data.element = card.element
	card_data.secondary_element = card.secondary_element
	card_data.pattern = str(card.get("pattern", ""))
	
	var placement : Array[Placement] = []
	for p in card.placement:
		placement.append(parse_placement(p))
	card_data.placement = placement
		
	var bonus : Array[Placement] = []
	for b in card.bonus:
		bonus.append(parse_placement(b))
	card_data.bonus = bonus
	
	return card_data

func parse_placement(data:Dictionary) -> Placement:
	var placement = Placement.new()
	placement.element = data.element
	placement.level = data.level
	placement.coords = Vector2i(data.coords[0],data.coords[1])
	return placement
