extends Node2D
class_name CardManager

@onready var card_container : CardContainer = $CardContainer

@export var orchestrator : Orchestrator
@export var card_limit : int = 12
@export var card_limit_buffer : int = 5
@export var animal_limit : int = 2
@export var recycling_value : int = 2
## When true (or GameSession puzzle maker), ignore hand limits and stacking recycle.
@export var maker_mode: bool = false

var cards: Array[CardData] = []
var card_amount: int = 0
var animal_amount: int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	if maker_mode or GameSession.is_puzzle_maker():
		maker_mode = true
		card_limit = 40
		card_limit_buffer = 20
		animal_limit = 40
	cards.resize(card_limit + card_limit_buffer)
	card_container.init(self, card_limit + card_limit_buffer)

## ----- Pass Data Upstream ----- ##

func select_card(id:int) -> void:
	orchestrator.select_hand_card(id)

func recycle_card(id: int) -> void:
	orchestrator.recycle_hand_animal(id)

## ----- Pass Data Downstream ----- ##

func deselect_card(id:int) -> void:
	card_container.deselect_card(id)

func add_card(card_data:CardData) -> void:
	var hand_card := card_data.duplicate(true)
	var matching_card_id := cards.find_custom(func(card):return card != null && card.type == hand_card.type && card.id == hand_card.id)
	if matching_card_id == -1:
		var new_id := cards.find_custom(func(card_):return card_ == null)
		if new_id == -1:
			push_warning("CardManager: no free hand slot for card id %s" % hand_card.id)
			return
		cards[new_id] = hand_card
		card_container.add_card(hand_card, new_id)
		card_amount += 1
		if hand_card.type == CardData.CARD_TYPE.ANIMAL:
			animal_amount += 1
		if not maker_mode and (card_amount > card_limit or animal_amount > animal_limit):
			orchestrator.pause_cards()
			_refresh_limit_panel()
	else:
		if not maker_mode and cards[matching_card_id].amount == 10:
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
		if orchestrator.selected_card_id == id:
			orchestrator.select_hand_card(-1)
		if card_amount <= card_limit and animal_amount <= animal_limit:
			orchestrator.unpause_cards()
		elif cards_over_any_limit():
			_refresh_limit_panel()

func cards_over_any_limit() -> bool:
	return card_amount > card_limit or animal_amount > animal_limit

func can_accept_animal(card: CardData) -> bool:
	if card == null or card.type != CardData.CARD_TYPE.ANIMAL:
		return false
	if maker_mode:
		return true
	var matching_card_id := cards.find_custom(
		func(existing): return existing != null and existing.type == card.type and existing.id == card.id
	)
	if matching_card_id != -1:
		return true
	return animal_amount < animal_limit

func _refresh_limit_panel() -> void:
	$Panel.show()
	if animal_amount > animal_limit:
		$Panel/Label.text = "Animal limit reached. Recycle an animal to continue."
	elif card_amount > card_limit:
		$Panel/Label.text = "Hand limit reached. You wont be able to buy new boosters."

func unpause() -> void:
	$Panel.hide()


## ----- Endless Continue Apply Helpers ----- ##
##
## Restores hand stack state from the serialized endless save payload.
func apply_saved_state(hand_state: Dictionary) -> void:
	reset_hand_from_state(hand_state)


func reset_hand_from_state(hand_state: Dictionary) -> void:
	if hand_state.is_empty():
		return

	# Remove existing card visuals.
	for i in range(cards.size()):
		if cards[i] != null:
			card_container.remove_card(i)
			cards[i] = null

	card_amount = 0
	animal_amount = 0
	$Panel.hide()

	var saved_cards: Array = hand_state.get("cards", [])
	var max_slots = min(saved_cards.size(), cards.size())

	for i in range(max_slots):
		var entry = saved_cards[i]
		if entry == null:
			continue

		var ctype := int(entry.get("type", CardData.CARD_TYPE.ELEMENT))
		var id := int(entry.get("id", 0))
		var amount := int(entry.get("amount", 0))

		var template := _find_card_template(ctype, id)
		if template == null:
			continue

		var new_card := template.duplicate(true) as CardData
		new_card.amount = amount

		cards[i] = new_card
		card_container.add_card(new_card, i)

	# Restore stored counts (they track filled slots, not copies).
	card_amount = int(hand_state.get("card_amount", card_amount))
	animal_amount = int(hand_state.get("animal_amount", animal_amount))

	# Match limit UI state.
	if card_amount > card_limit or animal_amount > animal_limit:
		_refresh_limit_panel()
	else:
		$Panel.hide()


func _find_card_template(card_type: int, card_id: int) -> CardData:
	if card_type == CardData.CARD_TYPE.ELEMENT:
		for c in CardCatalog.elements:
			if c != null and c.id == card_id:
				return c
		return null

	if card_type == CardData.CARD_TYPE.ANIMAL:
		for c in CardCatalog.animals:
			if c != null and c.id == card_id:
				return c
		return null

	return null
