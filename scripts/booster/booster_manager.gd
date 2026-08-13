extends Node2D
class_name BoosterManager

@onready var booster_container : BoosterContainer = $booster_container

@export var orchestrator : Orchestrator
@export var animal_market : AnimalMarketPanel

@export var booster_limit: int = 0
@export var boosters_per_reroll: int = 3
@export var random_secondary_chance: float = 50.0
@export var guaranteed_animal_boosters: int = 0
@export var animal_market_offer_count: int = 3
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

## 0 = reroll ready; >0 = pack/animal takes remaining until ready again.
var booster_reroll_progress: Array[int] = []
var market_reroll_progress: Array[int] = []

## One animal take per picked booster; available at game start.
var market_buys_remaining: int = 1
var _market_offers: Array[CardData] = []
var _bought_animal_ids: Dictionary = {}

var _rng: RandomNumberGenerator

## Puzzle author queues: remaining entries not yet shown in shop / market slots.
var _puzzle_booster_queue: Array = []
var _puzzle_animal_queue: Array = []

## ----- Initialisation ----- ##

func _ready() -> void:
	_rng = GameSession.make_rng("booster")
	_load_mixed_element_weights_from_catalog()
	
	boosters.resize(booster_limit)
	_init_reroll_progress()
	_guaranteed_animals_remaining = guaranteed_animal_boosters
	
	booster_container.init(self)
	if animal_market == null and has_node("AnimalMarketPanel"):
		animal_market = $AnimalMarketPanel as AnimalMarketPanel
	if animal_market:
		animal_market.buy_pressed.connect(buy_market_animal)
		animal_market.toggle_pressed.connect(toggle_animal_market)
		animal_market.reroll_pressed.connect(reroll_market_slot)

	if GameSession.uses_scripted_shop():
		_init_puzzle_queues()
		_apply_puzzle_market_offers()
		_apply_puzzle_boosters()
	else:
		_ensure_market_offers()
		for i in range(booster_limit):
			createBooster(i)
	
	_refresh_option_ui()
	_refresh_reroll_ui()

func _init_reroll_progress() -> void:
	booster_reroll_progress.clear()
	booster_reroll_progress.resize(booster_limit)
	for i in booster_limit:
		booster_reroll_progress[i] = 0
	market_reroll_progress.clear()
	market_reroll_progress.resize(animal_market_offer_count)
	for i in animal_market_offer_count:
		market_reroll_progress[i] = 0

## ----- Pass Data Upstream ----- ##

func select_booster(id: int) -> void:
	if paused:
		return
	if orchestrator and not orchestrator.tutorial_allows_booster(id):
		return

	if id == 4:
		toggle_animal_market()
		return

	if not options_ready:
		return
	if id < 0 or id >= booster_limit:
		return

	var booster := boosters[id]
	if booster == null or booster.cards.is_empty():
		return
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
	market_buys_remaining = 1

	_tick_reroll_cooldowns()

	createBooster(id)
	_refresh_option_ui()
	_refresh_reroll_ui()
	_refresh_market_buy_ui()
	if orchestrator:
		orchestrator.tutorial_bridge.notify("booster_taken", {"booster_id": id})

func can_reroll_booster(id: int) -> bool:
	if id < 0 or id >= booster_reroll_progress.size():
		return false
	return booster_reroll_progress[id] <= 0

func can_reroll_market(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= market_reroll_progress.size():
		return false
	return market_reroll_progress[offer_index] <= 0

func reroll_booster_slot(id: int) -> void:
	if paused:
		return
	if orchestrator and orchestrator.tutorial_bridge.active \
			and not orchestrator.tutorial_allows("reroll"):
		return
	if not can_reroll_booster(id):
		return
	if id < 0 or id >= booster_limit:
		return
	createBooster(id)
	booster_reroll_progress[id] = maxi(boosters_per_reroll, 1)
	_refresh_option_ui()
	_refresh_reroll_ui()
	if orchestrator:
		orchestrator.tutorial_bridge.notify("booster_rerolled", {"booster_id": id})

func reroll_market_slot(offer_index: int) -> void:
	if paused:
		return
	if animal_market == null:
		return
	if orchestrator and orchestrator.tutorial_bridge.active \
			and not orchestrator.tutorial_allows("reroll"):
		return
	if not can_reroll_market(offer_index):
		return
	if offer_index < 0 or offer_index >= _market_offers.size():
		return
	var replacement: CardData
	if GameSession.uses_scripted_shop():
		replacement = _dequeue_puzzle_animal()
	else:
		replacement = _generate_market_offer_at(offer_index, _market_used_ids(offer_index))
	_market_offers[offer_index] = replacement
	animal_market.replace_offer(offer_index, replacement)
	if offer_index < market_reroll_progress.size():
		market_reroll_progress[offer_index] = maxi(boosters_per_reroll, 1)
	_refresh_reroll_ui()
	_refresh_market_buy_ui()

func _tick_reroll_cooldowns() -> void:
	for i in booster_reroll_progress.size():
		if booster_reroll_progress[i] > 0:
			booster_reroll_progress[i] -= 1
	for i in market_reroll_progress.size():
		if market_reroll_progress[i] > 0:
			market_reroll_progress[i] -= 1

## ----- Play / Undo Progress ----- ##

func notify_element_played() -> void:
	if options_ready or pending_elements <= 0:
		return
	elements_played = mini(elements_played + 1, pending_elements)
	if elements_played >= pending_elements:
		options_ready = true
	_refresh_option_ui()
	_refresh_market_buy_ui()

func notify_element_undone() -> void:
	if pending_elements <= 0:
		return
	elements_played = maxi(elements_played - 1, 0)
	if elements_played < pending_elements:
		options_ready = false
	_refresh_option_ui()
	_refresh_market_buy_ui()

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

func _refresh_option_ui() -> void:
	var progress := _option_progress()
	booster_container.set_options_progress(progress)
	if options_ready:
		booster_container.enable_options()
		_disable_empty_option_slots()
	else:
		booster_container.disable_options()
	_refresh_reroll_ui()


func _disable_empty_option_slots() -> void:
	for i in range(mini(booster_limit, booster_container.boosters.size())):
		var data := boosters[i] if i < boosters.size() else null
		if data == null or data.cards.is_empty():
			booster_container.boosters[i].disable()

func _refresh_reroll_ui() -> void:
	for i in range(mini(booster_limit, booster_container.boosters.size())):
		booster_container.set_booster_reroll_ready(i, can_reroll_booster(i))
	if animal_market and animal_market.is_node_ready():
		var flags: Array[bool] = []
		for i in animal_market_offer_count:
			flags.append(can_reroll_market(i))
		animal_market.set_reroll_ready_flags(flags)

## ----- Animal Market ----- ##

func toggle_animal_market() -> void:
	if paused:
		return
	if orchestrator and not orchestrator.tutorial_allows_booster(4):
		return
	if animal_market != null and animal_market.is_open():
		close_animal_market()
	else:
		open_animal_market()

func open_animal_market() -> void:
	if animal_market == null:
		return
	if orchestrator and not orchestrator.tutorial_allows_booster(4):
		return
	_ensure_market_offers()
	animal_market.open(_market_offers)
	_refresh_reroll_ui()
	_refresh_market_buy_ui()
	if orchestrator:
		orchestrator.tutorial_bridge.notify("animal_market_opened", {})

func buy_market_animal(offer_index: int) -> void:
	if orchestrator and orchestrator.tutorial_bridge.active \
			and not orchestrator.tutorial_allows("buy_animal"):
		return
	if offer_index < 0 or offer_index >= _market_offers.size():
		return
	if market_buys_remaining <= 0:
		_refresh_market_buy_ui()
		return
	var bought := _market_offers[offer_index]
	if not _is_valid_market_offer(bought):
		_refresh_market_buy_ui()
		return
	if orchestrator and orchestrator.tutorial_bridge.active \
			and not orchestrator.tutorial_bridge.allows_animal_buy(bought.id):
		return
	if not orchestrator.card_manager.can_accept_animal(bought):
		_refresh_market_buy_ui()
		return
	orchestrator.add_hand_card(bought)
	_bought_animal_ids[bought.id] = true
	market_buys_remaining = maxi(market_buys_remaining - 1, 0)
	var replacement: CardData
	if GameSession.uses_scripted_shop():
		replacement = _dequeue_puzzle_animal()
	else:
		replacement = _generate_market_offer_at(offer_index, _market_used_ids(offer_index))
	_market_offers[offer_index] = replacement
	if animal_market:
		animal_market.replace_offer(offer_index, replacement)
	_tick_reroll_cooldowns()
	_refresh_reroll_ui()
	_refresh_market_buy_ui()
	if orchestrator:
		orchestrator.tutorial_bridge.notify("animal_bought", {"animal_id": bought.id})

func close_animal_market() -> void:
	if animal_market:
		animal_market.close()

func _can_buy_market_offer(offer: CardData) -> bool:
	if market_buys_remaining <= 0:
		return false
	if not _is_valid_market_offer(offer):
		return false
	return orchestrator.card_manager.can_accept_animal(offer)

func _market_status_text() -> String:
	if market_buys_remaining <= 0:
		return "Take another booster to take an animal"
	var any_valid := false
	var any_accept := false
	for offer in _market_offers:
		if not _is_valid_market_offer(offer):
			continue
		any_valid = true
		if orchestrator.card_manager.can_accept_animal(offer):
			any_accept = true
			break
	if any_valid and not any_accept:
		return "Animal hand limit reached"
	return "Take 1 animal per booster"

func _refresh_market_buy_ui() -> void:
	if animal_market == null or not animal_market.is_node_ready():
		return
	if not animal_market.is_open():
		return
	var can_buy: Array[bool] = []
	for offer in _market_offers:
		can_buy.append(_can_buy_market_offer(offer))
	var disabled_label := "Full" if market_buys_remaining > 0 else "Wait"
	animal_market.set_buys_enabled(can_buy, disabled_label)
	animal_market.set_status_text(_market_status_text())

func _ensure_market_offers() -> void:
	if _market_offers.size() != animal_market_offer_count:
		_market_offers = _generate_market_offers()

func _is_valid_market_offer(offer: CardData) -> bool:
	return offer != null and offer.amount > 0

func _market_blocked_ids(exclude_index: int = -1) -> Dictionary:
	var blocked: Dictionary = _bought_animal_ids.duplicate()
	for i in _market_offers.size():
		if i == exclude_index:
			continue
		var offer := _market_offers[i]
		if _is_valid_market_offer(offer):
			blocked[offer.id] = true
	return blocked

func _market_used_ids(exclude_index: int = -1) -> Dictionary:
	return _market_blocked_ids(exclude_index)

func _generate_market_offer_at(slot_index: int, used_ids: Dictionary) -> CardData:
	var blocked: Dictionary = used_ids.duplicate()
	for bought_id in _bought_animal_ids:
		blocked[bought_id] = true
	var element := (slot_index % 5) + 1
	var attempts := 0
	var max_attempts := 64
	while attempts < max_attempts:
		attempts += 1
		var animal := choose_animal(element)
		element = element % 5 + 1
		if not _is_valid_market_offer(animal):
			continue
		if blocked.has(animal.id):
			continue
		return animal
	return CardData.new()

func _generate_market_offers() -> Array[CardData]:
	var offers: Array[CardData] = []
	var used_ids: Dictionary = _bought_animal_ids.duplicate()
	for i in animal_market_offer_count:
		var animal := _generate_market_offer_at(i, used_ids)
		if _is_valid_market_offer(animal):
			used_ids[animal.id] = true
		offers.append(animal)
	return offers

## ----- Create Booster Logic ----- ##

func createBooster(idx: int) -> void:
	var booster = BoosterData.new()
	if GameSession.uses_scripted_shop():
		boosters[idx] = _dequeue_puzzle_booster()
		booster_container.set_booster_visuals(idx, boosters[idx])
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


func _init_puzzle_queues() -> void:
	_puzzle_booster_queue.clear()
	_puzzle_animal_queue.clear()
	var shop_cfg: Dictionary = GameSession.get_scripted_shop_config()
	var raw_boosters = shop_cfg.get("boosters", [])
	if typeof(raw_boosters) == TYPE_ARRAY:
		_puzzle_booster_queue = raw_boosters.duplicate()
	var raw_animals = shop_cfg.get("animal_market", [])
	if typeof(raw_animals) == TYPE_ARRAY:
		_puzzle_animal_queue = raw_animals.duplicate()


func _apply_puzzle_boosters() -> void:
	for i in range(booster_limit):
		boosters[i] = _dequeue_puzzle_booster()
		booster_container.set_booster_visuals(i, boosters[i])


func _dequeue_puzzle_booster() -> BoosterData:
	if _puzzle_booster_queue.is_empty():
		return _booster_from_puzzle_entry(null)
	var entry = _puzzle_booster_queue.pop_front()
	return _booster_from_puzzle_entry(entry)


func _booster_from_puzzle_entry(entry) -> BoosterData:
	var booster := BoosterData.new()
	booster.type = 6
	booster.booster_points = 0
	booster.map_points = 0
	if entry == null or typeof(entry) != TYPE_DICTIONARY:
		return booster
	booster.map_points = int(entry.get("map_points", 0))
	var quest_ids = entry.get("quest_ids", [])
	if typeof(quest_ids) == TYPE_ARRAY:
		for qid in quest_ids:
			booster.quest_ids.append(int(qid))
	var elements = entry.get("elements", [])
	if typeof(elements) != TYPE_ARRAY:
		return booster
	for element_id in elements:
		var eid := int(element_id)
		if eid >= 0 and eid < CardCatalog.elements.size():
			booster.cards.append(CardCatalog.elements[eid])
	return booster


func _apply_puzzle_market_offers() -> void:
	_market_offers = _fill_market_from_puzzle_queue()


func _fill_market_from_puzzle_queue() -> Array[CardData]:
	var offers: Array[CardData] = []
	for _i in animal_market_offer_count:
		offers.append(_dequeue_puzzle_animal())
	return offers


func _dequeue_puzzle_animal() -> CardData:
	while not _puzzle_animal_queue.is_empty():
		var entry = _puzzle_animal_queue.pop_front()
		if entry == null:
			return CardData.new()
		var animal_id := int(entry)
		if animal_id < 0:
			return CardData.new()
		if animal_id < CardCatalog.animals.size():
			return CardCatalog.animals[animal_id]
		push_warning("Puzzle animal id %d not in catalog; skipping." % animal_id)
	return CardData.new()

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


## ----- Endless Continue Apply Helpers ----- ##
func apply_saved_state(booster_state: Dictionary) -> void:
	if booster_state.is_empty():
		return

	# Paused state gates input; Orchestrator also restores `cards_paused`.
	paused = bool(booster_state.get("paused", paused))

	# Restore booster cards.
	var saved_boosters: Array = booster_state.get("boosters", [])
	for i in range(booster_limit):
		var entry = saved_boosters[i] if i < saved_boosters.size() else null
		if entry == null:
			# Booster visuals: fall back to a safe empty BoosterData.
			var empty := BoosterData.new()
			empty.type = 0
			empty.booster_points = 0
			empty.map_points = 0
			empty.quest_ids = []
			empty.cards = []
			boosters[i] = empty
			booster_container.set_booster_visuals(i, empty)
			continue

		var b := BoosterData.new()
		b.type = int(entry.get("type", 0))
		b.booster_points = int(entry.get("booster_points", 0))
		b.map_points = int(entry.get("map_points", 0))
		b.quest_ids = []
		var qids: Array = entry.get("quest_ids", [])
		if typeof(qids) == TYPE_ARRAY:
			for qid in qids:
				b.quest_ids.append(int(qid))

		b.cards = []
		var saved_cards: Array = entry.get("cards", [])
		if typeof(saved_cards) == TYPE_ARRAY:
			for c_entry in saved_cards:
				if c_entry == null or typeof(c_entry) != TYPE_DICTIONARY:
					continue
				var ctype := int(c_entry.get("type", CardData.CARD_TYPE.ELEMENT))
				var cid := int(c_entry.get("id", 0))
				var amt := int(c_entry.get("amount", 0))

				var template := _find_card_template(ctype, cid)
				if template == null:
					continue
				var card := template.duplicate(true) as CardData
				card.amount = amt
				b.cards.append(card)

		boosters[i] = b
		booster_container.set_booster_visuals(i, b)

	# Restore reroll / market state arrays.
	booster_reroll_progress.assign(booster_state.get("booster_reroll_progress", booster_reroll_progress))
	market_reroll_progress.assign(booster_state.get("market_reroll_progress", market_reroll_progress))

	# Ensure arrays have expected lengths.
	booster_reroll_progress.resize(booster_limit)
	booster_reroll_progress.fill(0)
	if market_reroll_progress.size() != animal_market_offer_count:
		market_reroll_progress.resize(animal_market_offer_count)
	market_reroll_progress.fill(0)

	market_buys_remaining = int(booster_state.get("market_buys_remaining", market_buys_remaining))
	options_ready = bool(booster_state.get("options_ready", options_ready))
	pending_elements = int(booster_state.get("pending_elements", pending_elements))
	elements_played = int(booster_state.get("elements_played", elements_played))

	# Restore market offers + bought tracking.
	var saved_offers: Array = booster_state.get("market_offers", [])
	_market_offers = []
	if typeof(saved_offers) == TYPE_ARRAY:
		for o_entry in saved_offers:
			if o_entry == null or typeof(o_entry) != TYPE_DICTIONARY:
				_market_offers.append(null)
				continue
			var ctype := int(o_entry.get("type", CardData.CARD_TYPE.ELEMENT))
			var cid := int(o_entry.get("id", 0))
			var amt := int(o_entry.get("amount", 0))
			var template := _find_card_template(ctype, cid)
			if template == null:
				_market_offers.append(null)
				continue
			var card := template.duplicate(true) as CardData
			card.amount = amt
			_market_offers.append(card)

	_bought_animal_ids = {}
	var saved_bought: Dictionary = booster_state.get("bought_animal_ids", {})
	if typeof(saved_bought) == TYPE_DICTIONARY:
		for k in saved_bought.keys():
			_bought_animal_ids[int(k)] = true

	# Restore paused-time visuals for marker timers.
	_refresh_option_ui()
	_refresh_reroll_ui()
	_refresh_market_buy_ui()

	# If market panel is open, update it immediately.
	if animal_market and animal_market.is_node_ready():
		animal_market.refresh_offers(_market_offers)


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
