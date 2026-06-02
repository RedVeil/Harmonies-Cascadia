extends Node2D
class_name CardManager

@onready var card_container : CardContainer = $CardContainer

@export var orchestrator : Orchestrator
@export var card_limit : int = 12
@export var card_limit_buffer : int = 5
@export var recycling_value : int = 2

var cards: Array[CardData] = []
var card_amount: int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	cards.resize(card_limit + card_limit_buffer)
	card_container.init(self, card_limit + card_limit_buffer)

## ----- Pass Data Upstream ----- ##

func select_card(id:int) -> void:
	orchestrator.select_hand_card(id)

## ----- Pass Data downtream ----- ##

func deselect_card(id:int) -> void:
	card_container.deselect_card(id)

func add_card(card_data:CardData) -> void:
	var matching_card_id := cards.find_custom(func(card):return card != null && card.type == card_data.type && card.id == card_data.id)
	if matching_card_id == -1:
		var new_id := cards.find_custom(func(card_):return card_ == null)
		cards[new_id] = card_data
		card_container.add_card(card_data, new_id)
		card_amount += 1
		if card_amount > card_limit:
			orchestrator.pause_cards()
			$Panel.show()
	else:
		if cards[matching_card_id].amount == 10:
			orchestrator.preview_recycle_card(matching_card_id, recycling_value, true)
			orchestrator.apply_recycle_card(matching_card_id, recycling_value, true)
		else:
			cards[matching_card_id].amount += 1
			card_container.increment_card(matching_card_id)

func remove_card(id:int) -> void:
	if cards[id].amount > 1:
		cards[id].amount -= 1
		card_container.decrement_card(id)
	else:
		cards[id] = null
		card_container.remove_card(id)
		card_amount -= 1
		orchestrator.select_hand_card(-1)
		if card_amount <= card_limit:
			orchestrator.unpause_cards()

func unpause() -> void:
	$Panel.hide()
