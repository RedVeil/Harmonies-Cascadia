extends Node2D
class_name BoosterManager

@onready var booster_container : BoosterContainer = $booster_container

@export var orchestrator : Orchestrator
@export var animal_market : AnimalMarketOverlay

@export var booster_limit: int = 0
@export var boosters_per_reroll: int = 3
@export var random_secondary_chance: float = 50.0
@export var guaranteed_animal_boosters: int = 0
@export var animal_market_offer_count: int = 4
@export var mixed_pack_card_count: int = 4
## Weights for elements 1–5 (Forest, Field, Mountain, River, Wetland). Sum should be ~100.
@export var mixed_element_weights: Array[float] = [30.0, 20.0, 18.0, 22.0, 10.0]

var boosters: Array[BoosterData] = []

var paused: bool = false
var booster_chances: Array[float] = []
var _guaranteed_animals_remaining: int = 0

var pending_elements: int = 0
var elements_played: int = 0
var options_ready: bool = true

var reroll_charges: int = 1
var buys_since_reroll: int = 0

var _market_offers: Array[CardData] = []

var _rng: RandomNumberGenerator

## ----- Initialisation ----- ##

func _ready() -> void:
	_rng = GameSession.make_rng("booster")
	_load_mixed_element_weights_from_catalog()
	
	boosters.resize(booster_limit + 2)
	_guaranteed_animals_remaining = guaranteed_animal_boosters
	
	booster_container.init(self)
	if animal_market:
		animal_market.buy_pressed.connect(buy_market_animal)
		animal_market.close_pressed.connect(close_animal_market)
		animal_market.reroll_pressed.connect(reroll_animal_market)
	_ensure_market_offers()
	
	for i in range(booster_limit):
		createBooster(i)
	createBooster(4)
	
	_refresh_option_ui()
	_refresh_reroll_ui()

## ----- Pass Data Upstream ----- ##

func select_booster(id: int) -> void:
	if paused:
		return
	
	if id == 4:
		open_animal_market()
		return
	
	if id == 3:
		_try_reroll()
		return
	
	if not options_ready:
		return
	if id < 0 or id >= booster_limit:
		return
	
	var booster := boosters[id]
	for card in booster.cards:
		orchestrator.add_hand_card(card)
	if booster.map_points > 0:
		orchestrator.add_map_points(booster.map_points)
	if booster.quest_ids.size() > 0:
		for quest_id in booster.quest_ids:
			orchestrator.add_quest(quest_id)
	
	pending_elements = _count_element_cards(booster)
	elements_played = 0
	options_ready = pending_elements <= 0
	
	# Only refill shared refresh/animal charge after it has been spent.
	if reroll_charges <= 0:
		buys_since_reroll += 1
		if buys_since_reroll >= boosters_per_reroll:
			reroll_charges += 1
			buys_since_reroll = 0
			_market_offers = _generate_market_offers()
	
	createBooster(id)
	_refresh_option_ui()
	_refresh_reroll_ui()

func _try_reroll() -> void:
	if not _spend_reroll_charge():
		return
	for i in range(booster_limit):
		createBooster(i)
	_refresh_reroll_ui()

func _spend_reroll_charge() -> bool:
	if reroll_charges <= 0:
		return false
	reroll_charges -= 1
	buys_since_reroll = 0
	return true

## ----- Play / Undo Progress ----- ##

func notify_element_played() -> void:
	if options_ready or pending_elements <= 0:
		return
	elements_played = mini(elements_played + 1, pending_elements)
	if elements_played >= pending_elements:
		options_ready = true
	_refresh_option_ui()

func notify_element_undone() -> void:
	if pending_elements <= 0:
		return
	elements_played = maxi(elements_played - 1, 0)
	if elements_played < pending_elements:
		options_ready = false
	_refresh_option_ui()

func _count_element_cards(booster: BoosterData) -> int:
	var count := 0
	for card in booster.cards:
		if card.type == CardData.CARD_TYPE.ELEMENT:
			count += 1
	return count

func _option_progress() -> float:
	if options_ready or pending_elements <= 0:
		return 1.0
	return float(elements_played) / float(pending_elements)

func _reroll_progress() -> float:
	if reroll_charges > 0:
		return 1.0
	if boosters_per_reroll <= 0:
		return 1.0
	return float(buys_since_reroll) / float(boosters_per_reroll)

func _refresh_option_ui() -> void:
	var progress := _option_progress()
	booster_container.set_options_progress(progress)
	if options_ready:
		booster_container.enable_options()
	else:
		booster_container.disable_options()

func _refresh_reroll_ui() -> void:
	var progress := _reroll_progress()
	var has_charge := reroll_charges > 0
	booster_container.set_reroll_progress(progress)
	booster_container.set_animal_market_progress(progress)
	if has_charge:
		booster_container.enable_reroll()
		booster_container.enable_animal_market()
	else:
		booster_container.disable_reroll()
		booster_container.disable_animal_market()

## ----- Animal Market ----- ##

func open_animal_market() -> void:
	if animal_market == null or reroll_charges <= 0:
		return
	_ensure_market_offers()
	orchestrator.pause_cards()
	animal_market.open(_market_offers)

func buy_market_animal(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _market_offers.size():
		return
	if not _spend_reroll_charge():
		return
	var bought := _market_offers[offer_index]
	orchestrator.add_hand_card(bought)
	_refresh_reroll_ui()
	close_animal_market()

func reroll_animal_market() -> void:
	if animal_market == null:
		return
	_market_offers = _generate_market_offers()
	animal_market.refresh_offers(_market_offers)

func close_animal_market() -> void:
	if animal_market:
		animal_market.close()
	orchestrator.unpause_cards()

func _ensure_market_offers() -> void:
	if _market_offers.size() < animal_market_offer_count:
		_market_offers = _generate_market_offers()

func _generate_market_offers() -> Array[CardData]:
	var offers: Array[CardData] = []
	var used_ids: Dictionary = {}
	var element := 1
	var attempts := 0
	var max_attempts := animal_market_offer_count * 8
	while offers.size() < animal_market_offer_count and attempts < max_attempts:
		attempts += 1
		var animal := choose_animal(element)
		element = element % 5 + 1
		if animal.amount <= 0:
			continue
		if used_ids.has(animal.id):
			continue
		used_ids[animal.id] = true
		offers.append(animal)
	return offers

## ----- Create Booster Logic ----- ##

func createBooster(idx: int) -> void:
	var booster = BoosterData.new()
	if idx == 4:
		booster.type = 7
		boosters[idx] = booster
		booster_container.set_booster_visuals(idx, booster)
		return

	# Shop slots: always exactly N independently weighted element tiles.
	booster.type = 6
	booster.cards = _create_mixed_element_pack()
	booster.booster_points = 0
	booster.map_points = 0
	if pick_option(30.0):
		var quest_id := orchestrator.pick_quest(0, _pick_pack_quest_element(booster.cards))
		if quest_id != -1:
			booster.quest_ids.append(quest_id)
	boosters[idx] = booster
	booster_container.set_booster_visuals(idx, booster)

func _load_mixed_element_weights_from_catalog() -> void:
	if mixed_element_weights.size() < 5:
		mixed_element_weights = [30.0, 20.0, 18.0, 22.0, 10.0]
	for option in BoosterCatalog.booster_options:
		if option.type >= 1 and option.type <= 5:
			mixed_element_weights[option.type - 1] = option.draw_chance

func _create_mixed_element_pack() -> Array[CardData]:
	var cards: Array[CardData] = []
	var element_ids: Array[Variant] = [1, 2, 3, 4, 5]
	for _i in mixed_pack_card_count:
		var element_id: int = element_ids[pick_weighted(element_ids, mixed_element_weights)]
		cards.append(CardCatalog.elements[element_id])
	return cards

func _pick_pack_quest_element(cards: Array[CardData]) -> int:
	var counts: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	var present: Array[Variant] = []
	var weights: Array[float] = []
	for card in cards:
		if card.type != CardData.CARD_TYPE.ELEMENT:
			continue
		if card.id < 1 or card.id > 5:
			continue
		counts[card.id - 1] += 1.0
	for element_id in range(1, 6):
		var count := counts[element_id - 1]
		if count <= 0.0:
			continue
		present.append(element_id)
		weights.append(count)
	if present.is_empty():
		return _rng.randi_range(1, 5)
	# Convert raw counts to percentage-style weights for pick_weighted.
	var total := 0.0
	for w in weights:
		total += w
	var chances: Array[float] = []
	for w in weights:
		chances.append((w / total) * 100.0)
	return present[pick_weighted(present, chances)]


func pick_weighted(options: Array[Variant], chances: Array[float]) -> int:
	var roll := _rng.randf_range(0.0, 99.9)
	var running := 0.0
	
	for i in options.size():
		if chances.size() > 0:
			running += chances[i]
		else:
			running += options[i].draw_chance
		if roll < running:
			return i
	
	return options.size() - 1

func pick_option(chance: float) -> bool:
	return _rng.randf_range(0.0, 99.9) < chance

func update_booster_chances(winner: int) -> void:
	var diff: float = booster_chances[winner] - max(booster_chances[winner] - 10.0, 0.0)
	var increase: float = diff / (booster_chances.size() - 1)
	
	for i in booster_chances.size():
		if i == winner:
			booster_chances[i] -= diff
		else:
			booster_chances[i] = min(booster_chances[i] + increase, 100.0)

## ----- Utility Logic ----- ##

func choose_animal(element: int) -> CardData:
	var secondary_elements = [0, 0, 0, 0, 0, 0]
	for b in boosters:
		if b != null && b.type < 6:
			for c in b.cards:
				if c.type == 0:
					secondary_elements[c.id] += c.amount
	if orchestrator:
		var hand_elements = orchestrator.get_secondary_elements()
		for i in hand_elements.size():
			secondary_elements[i] += hand_elements[i]
	
	var total = secondary_elements.reduce(func (a, n): return a + n, 0)
	var secondary_chances: Array[float]
	if total > 0:
		for e in secondary_elements:
			secondary_chances.append((float(e) / float(total)) * 100.0)
	
	var secondary_element = 0
	## X% chance to pick a random secondary element
	if pick_option(random_secondary_chance if total > 0 else 100.0):
		secondary_element = _pick_random([1, 2, 3, 4, 5])
	else:
		secondary_element = pick_weighted([0, 1, 2, 3, 4, 5], secondary_chances)
	
	var filtered_by_element = CardCatalog.animals.filter(func (card): return card.element == element)
	if filtered_by_element.size() > 0:
		var filtered_by_secondary_element = filtered_by_element.filter(func (card): return card.secondary_element == secondary_element)
		if filtered_by_secondary_element.size() > 0:
			return _pick_random(filtered_by_secondary_element)
		else:
			return _pick_random(filtered_by_element)
	else:
		return CardData.new()


func _pick_random(options: Array) -> Variant:
	return options[_rng.randi_range(0, options.size() - 1)]
