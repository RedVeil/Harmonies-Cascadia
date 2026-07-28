extends Node2D
class_name BoosterManager

@onready var booster_container : BoosterContainer = $booster_container

@export var orchestrator : Orchestrator

@export var booster_limit: int = 0
@export var boosters_per_reroll: int = 3
@export var random_secondary_chance: float = 50.0
@export var guaranteed_animal_boosters: int = 2

var boosters: Array[BoosterData] = []

var paused: bool = false
var booster_chances: Array[float] = []
var _guaranteed_animals_remaining: int = 0

var pending_elements: int = 0
var elements_played: int = 0
var options_ready: bool = true

var reroll_charges: int = 1
var buys_since_reroll: int = 0

var _rng: RandomNumberGenerator

## ----- Initialisation ----- ##

func _ready() -> void:
	_rng = GameSession.make_rng("booster")
	
	for option in BoosterCatalog.booster_options:
		if option.type < 6:
			booster_chances.append(option.draw_chance)
	
	boosters.resize(booster_limit + 1)
	_guaranteed_animals_remaining = guaranteed_animal_boosters
	
	booster_container.init(self)
	
	for i in range(booster_limit):
		createBooster(i)
	
	_refresh_option_ui()
	_refresh_reroll_ui()

## ----- Pass Data Upstream ----- ##

func select_booster(id: int) -> void:
	if paused:
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
	
	# Only refill progress after the current reroll charge has been spent.
	if reroll_charges <= 0:
		buys_since_reroll += 1
		if buys_since_reroll >= boosters_per_reroll:
			reroll_charges += 1
			buys_since_reroll = 0
	
	createBooster(id)
	_refresh_option_ui()
	_refresh_reroll_ui()

func _try_reroll() -> void:
	if reroll_charges <= 0:
		return
	reroll_charges -= 1
	buys_since_reroll = 0
	for i in range(booster_limit):
		createBooster(i)
	_refresh_reroll_ui()

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
	booster_container.set_reroll_progress(_reroll_progress())
	if reroll_charges > 0:
		booster_container.enable_reroll()
	else:
		booster_container.disable_reroll()

## ----- Create Booster Logic ----- ##

func createBooster(idx: int) -> void:
	var booster = BoosterData.new()
	var option_index: int = pick_weighted(BoosterCatalog.booster_options, booster_chances)
	update_booster_chances(option_index)
	
	var picked_booster = BoosterCatalog.booster_options[option_index]
	var force_animal := idx < booster_limit and _guaranteed_animals_remaining > 0
	
	var cards: Array[CardData] = []
	var booster_points := 0
	var map_points := 0
	var quest_ids: Array[int] = []

	var options = picked_booster.base_content_options.duplicate(true)
	
	if pick_option(picked_booster.extra_card_chance):
		options.append(picked_booster.extra_card_options[pick_weighted(picked_booster.extra_card_options, [])])
	if pick_option(picked_booster.extra_chance) and not picked_booster.extra_content_options.is_empty():
		options.append(picked_booster.extra_content_options[pick_weighted(picked_booster.extra_content_options, [])])

	if pick_option(30.0):
		var quest_id := orchestrator.pick_quest(0, picked_booster.type)
		if quest_id != -1:
			quest_ids.append(quest_id)
	
	for entry in options:
		for i in range(entry.amount):
			var chance = entry.draw_chance
			if force_animal and entry.type == BoosterContentOption.RewardType.ANIMAL:
				chance = 100.0
			if pick_option(chance):
				match entry.type:
					BoosterContentOption.RewardType.ELEMENT:
						cards.append(CardCatalog.elements[entry.id])
					BoosterContentOption.RewardType.ANIMAL:
						var animal: CardData = choose_animal(entry.id)
						if animal.amount > 0:
							cards.append(animal)
					BoosterContentOption.RewardType.BOOSTER_POINT:
						booster_points += entry.amount
					BoosterContentOption.RewardType.MAP_POINT:
						map_points += entry.amount
	
	if force_animal:
		_guaranteed_animals_remaining -= 1
		var has_animal := cards.any(func (card: CardData): return card.type == 1)
		if not has_animal:
			var animal := choose_animal(picked_booster.type)
			if animal.amount > 0:
				cards.append(animal)
	
	booster.type = picked_booster.type
	booster.cards = cards
	booster.booster_points = booster_points
	booster.map_points = map_points
	booster.quest_ids = quest_ids
	
	boosters[idx] = booster

	booster_container.set_booster_visuals(idx, booster)

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
