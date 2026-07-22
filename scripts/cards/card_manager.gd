extends Node2D
class_name CardManager

@onready var card_container : CardContainer = $CardContainer

@export var orchestrator : Orchestrator
@export var card_limit : int = 12
@export var card_limit_buffer : int = 5
@export var animal_limit : int = 2
@export var recycling_value : int = 2

var cards: Array[CardData] = []
var card_amount: int = 0
var animal_amount: int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	cards.resize(card_limit + card_limit_buffer)
	card_container.init(self, card_limit + card_limit_buffer)

## ----- Pass Data Upstream ----- ##

func select_card(id:int) -> void:
	orchestrator.select_hand_card(id)

## ----- Pass Data Downstream ----- ##

func deselect_card(id:int) -> void:
	card_container.deselect_card(id)

func add_card(card_data:CardData) -> void:
	var hand_card := card_data.duplicate(true)
	var matching_card_id := cards.find_custom(func(card):return card != null && card.type == hand_card.type && card.id == hand_card.id)
	if matching_card_id == -1:
		var new_id := cards.find_custom(func(card_):return card_ == null)
		cards[new_id] = hand_card
		card_container.add_card(hand_card, new_id)
		card_amount += 1
		if hand_card.type == CardData.CARD_TYPE.ANIMAL:
			animal_amount += 1
		if card_amount > card_limit or animal_amount > animal_limit:
			orchestrator.pause_cards()
			_refresh_limit_panel()
	else:
		if cards[matching_card_id].amount == 10:
			orchestrator.preview_recycle_card(matching_card_id, recycling_value, true)
			orchestrator.apply_recycle_card(matching_card_id, recycling_value, true)
		else:
			cards[matching_card_id].amount += hand_card.amount
			card_container.set_card_amount(matching_card_id, cards[matching_card_id].amount)

func remove_card(id:int) -> void:
	var was_animal := cards[id].type == CardData.CARD_TYPE.ANIMAL
	if cards[id].amount > 1:
		cards[id].amount -= 1
		card_container.decrement_card(id)
	else:
		cards[id] = null
		card_container.remove_card(id)
		card_amount -= 1
		if was_animal:
			animal_amount -= 1
		orchestrator.select_hand_card(-1)
		if card_amount <= card_limit and animal_amount <= animal_limit:
			orchestrator.unpause_cards()
		elif cards_over_any_limit():
			_refresh_limit_panel()

func cards_over_any_limit() -> bool:
	return card_amount > card_limit or animal_amount > animal_limit

func _refresh_limit_panel() -> void:
	$Panel.show()
	if animal_amount > animal_limit:
		$Panel/Label.text = "Animal limit reached. Recycle an animal to continue."
	elif card_amount > card_limit:
		$Panel/Label.text = "Hand limit reached. You wont be able to buy new boosters."

func unpause() -> void:
	$Panel.hide()
