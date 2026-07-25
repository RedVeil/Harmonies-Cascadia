extends Node2D
class_name BoosterManager

@onready var booster_container : BoosterContainer = $booster_container

@export var orchestrator : Orchestrator
@export var animal_market : AnimalMarketOverlay

@export var booster_limit:int = 0
@export var base_booster_point_cost:int = 10
@export var booster_point_multiplier:float = 1.2
@export var booster_point_flat_increase:int = 0
@export var start_booster_points:int = 3
@export var random_secondary_chance: float = 50.0
@export var guaranteed_animal_boosters: int = 0
@export var animal_market_price: int = 1
@export var animal_market_offer_count: int = 4
@export var animal_market_reroll_price: int = 1
@export var mixed_pack_card_count: int = 4
## Weights for elements 1–5 (Forest, Field, Mountain, River, Wetland). Sum should be ~100.
@export var mixed_element_weights: Array[float] = [30.0, 20.0, 18.0, 22.0, 10.0]

@export_group("Points Reward Animation")
@export var punch_scale: float = 1.14
@export var punch_up_duration: float = 0.12
@export var punch_settle_duration: float = 0.2
@export var progress_base_scale: Vector2 = Vector2(0.15, 0.15)
@export var progress_peak_scale: Vector2 = Vector2(0.165, 0.165)
@export var points_reward_sounds: Array[AudioStream] = []

var booster_point_cost:int = 0
var booster_points:int = 0
var acc_points:int = 0

var booster_point_cost_preview:int = 0
var booster_points_preview:int = 0
var acc_points_preview:int = 0

var booster_point_cost_backup:int = 0
var booster_points_backup:int = 0
var acc_points_backup:int = 0

var boosters: Array[BoosterData] = []

var paused:bool = false
var booster_chances : Array[float] = []
var _guaranteed_animals_remaining: int = 0

var is_hovered : bool = false
var timer : float = 0.5

var _feedback_tweens: Dictionary = {}

var booster_label : Label
var booster_progress_sprite : Sprite2D
var _rng: RandomNumberGenerator

var _market_offers: Array[CardData] = []

## ----- Initialisation ----- ##

func _ready() -> void:
	_rng = GameSession.make_rng("booster")
	_load_mixed_element_weights_from_catalog()
	
	boosters.resize(booster_limit + 2)
	booster_points = start_booster_points
	booster_point_cost = base_booster_point_cost
	_guaranteed_animals_remaining = guaranteed_animal_boosters
	
	booster_label = $hex/Label
	booster_progress_sprite = $hex/Sprite2D2
	$hex/Label.text = "%d" % booster_points
	$Tooltip/Label.text = "These are your credits. Earn credits by placing tiles, finishing quests or recycling cards. (0 / %d)" % booster_point_cost
	
	$hex/Sprite2D2.material.set_shader_parameter("current_value", 0.0)
	$hex/Sprite2D2.material.set_shader_parameter("lerp_value", 0.0)
	$hex/Sprite2D2.material.set_shader_parameter("third_value", 0.0)
	
	booster_container.init(self)
	if animal_market:
		animal_market.buy_pressed.connect(buy_market_animal)
		animal_market.close_pressed.connect(close_animal_market)
		animal_market.reroll_pressed.connect(reroll_animal_market)
	_ensure_market_offers()
	
	for i in range(booster_limit):
		createBooster(i)
	createBooster(3)
	createBooster(4)
	call_deferred("ensure_hex_label_pivot")

## ----- Pass Data Upstream ----- ##

func select_booster(id:int) -> void:
	if paused:
		return
	if id == 4:
		open_animal_market()
		return
	if booster_points <= 0:
		return
	change_booster_points(-1)
	if id == 3:
		for i in range(booster_limit):
			createBooster(i)
	else:
		var booster = boosters[id]
		for card in booster.cards:
			orchestrator.add_hand_card(card)
		if booster.booster_points > 0:
			change_booster_points(booster.booster_points)
		if booster.map_points > 0:
			orchestrator.add_map_points(booster.map_points)
		if booster.quest_ids.size() > 0:
			for quest_id in booster.quest_ids:
				orchestrator.add_quest(quest_id)
		
		createBooster(id)

func change_booster_points(amount:int) -> void:
	booster_points += amount
	$hex/Label.text = "%d" % booster_points

## ----- Pass Data Downstream ----- ##

func preview_booster_points(points:int) -> void:
	if booster_point_cost_preview <= 0:
		booster_point_cost_preview = booster_point_cost
	
	var booster_progress = acc_points + points
	if booster_progress < 0:
		booster_progress = 0
	
	booster_points_preview = booster_points
	acc_points_preview = acc_points
	booster_point_cost_preview = booster_point_cost
	
	while booster_progress >= booster_point_cost_preview:
		booster_progress -= booster_point_cost_preview
		booster_points_preview += 1
		booster_point_cost_preview = ceili(
			(float(booster_point_cost_preview) + float(booster_point_flat_increase)) * booster_point_multiplier
		)
	
	acc_points_preview = booster_progress
	
	
	var progress = float(acc_points_preview) / float(booster_point_cost_preview)
	var booster_point_diff = booster_points_preview - booster_points
	if booster_point_diff > 0:
		$hex/Sprite2D2.material.set_shader_parameter("current_value", 0.0)
		$hex/Sprite2D2.material.set_shader_parameter("lerp_value", 0.0)
		$hex/Sprite2D2.material.set_shader_parameter("third_value", progress)
	else:
		if acc_points_preview == acc_points:
			$hex/Sprite2D2.material.set_shader_parameter("current_value", 0.0)
			$hex/Sprite2D2.material.set_shader_parameter("lerp_value", progress)
			$hex/Sprite2D2.material.set_shader_parameter("third_value",  0.0)
		elif acc_points_preview > acc_points:
			$hex/Sprite2D2.material.set_shader_parameter("current_value", 0.0)
			$hex/Sprite2D2.material.set_shader_parameter("lerp_value", float(acc_points) / float(booster_point_cost_preview))
			$hex/Sprite2D2.material.set_shader_parameter("third_value",  progress)
		else:
			$hex/Sprite2D2.material.set_shader_parameter("current_value", progress)
			$hex/Sprite2D2.material.set_shader_parameter("lerp_value", float(acc_points) / float(booster_point_cost_preview))
			$hex/Sprite2D2.material.set_shader_parameter("third_value",  0.0)
	
	$Tooltip/Label.text = "These are your credits. Earn credits by placing tiles, finishing quests or recycling cards. (%d / %d)" % [acc_points_preview, booster_point_cost_preview]


func apply_booster_points(animate_reward: bool = false) -> void:
	booster_point_cost_backup = booster_point_cost
	booster_points_backup = booster_points
	acc_points_backup = acc_points
	var gained_points := booster_points_preview - booster_points
	var gained_acc := acc_points_preview - acc_points
	
	change_booster_points(gained_points)
	acc_points = acc_points_preview
	booster_point_cost = booster_point_cost_preview
	apply_current_style()
	if animate_reward and (gained_points > 0 or gained_acc > 0):
		play_animation(&"points_reward", {})

func reset_preview() -> void:
	kill_animations()
	booster_points_preview = booster_points
	acc_points_preview = acc_points
	booster_point_cost_preview = booster_point_cost
	apply_current_style()

func undo() -> void:
	kill_animations()
	change_booster_points(booster_points_backup - booster_points)
	acc_points = acc_points_backup
	booster_point_cost = booster_point_cost_backup
	apply_current_style()
	
## ----- Animal Market ----- ##

func open_animal_market() -> void:
	if animal_market == null:
		return
	_ensure_market_offers()
	orchestrator.pause_cards()
	animal_market.open(
		_market_offers,
		animal_market_price,
		booster_points,
		animal_market_reroll_price
	)

func buy_market_animal(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _market_offers.size():
		return
	if booster_points < animal_market_price:
		return
	var bought := _market_offers[offer_index]
	change_booster_points(-animal_market_price)
	orchestrator.add_hand_card(bought)
	var replacement := _generate_single_market_offer(_market_offer_used_ids(offer_index))
	_market_offers[offer_index] = replacement
	if animal_market:
		animal_market.replace_offer(offer_index, replacement)
		animal_market.update_credits(booster_points)

func reroll_animal_market() -> void:
	if animal_market == null:
		return
	if booster_points < animal_market_reroll_price:
		return
	change_booster_points(-animal_market_reroll_price)
	_market_offers = _generate_market_offers()
	animal_market.refresh_offers(_market_offers)
	animal_market.update_credits(booster_points)

func close_animal_market() -> void:
	if animal_market:
		animal_market.close()
	orchestrator.unpause_cards()

func _ensure_market_offers() -> void:
	if _market_offers.size() < animal_market_offer_count:
		_market_offers = _generate_market_offers()

func _market_offer_used_ids(exclude_index: int = -1) -> Dictionary:
	var used_ids: Dictionary = {}
	for i in _market_offers.size():
		if i == exclude_index:
			continue
		var offer := _market_offers[i]
		if offer != null and offer.amount > 0:
			used_ids[offer.id] = true
	return used_ids

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

func _generate_single_market_offer(used_ids: Dictionary) -> CardData:
	var element := _rng.randi_range(1, 5)
	var attempts := 0
	while attempts < 40:
		attempts += 1
		var animal := choose_animal(element)
		element = element % 5 + 1
		if animal.amount <= 0:
			continue
		if used_ids.has(animal.id):
			continue
		return animal
	# Fallback: allow a duplicate if catalog is too thin.
	return choose_animal(_rng.randi_range(1, 5))

## ----- Create Booster Logic ----- ##

func createBooster(idx:int) -> void:
	var booster = BoosterData.new()
	if idx == 4:
		booster.type = 7
		#booster.cards = []
		boosters[idx] = booster
		booster_container.set_booster_visuals(idx, booster)
		return
	if idx == 3:
		# Reroll slot — no pack contents.
		booster.type = 6
		#booster.cards = []
		boosters[idx] = booster
		return

	# Shop slots: always exactly N independently weighted element tiles.
	booster.type = 6
	booster.cards = _create_mixed_element_pack()
	booster.booster_points = 0
	booster.map_points = 0
	# booster.quest_ids = []
	
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
	
	return options.size() -1

func pick_option(chance:float) -> bool:
	return _rng.randf_range(0.0, 99.9) < chance

func update_booster_chances(winner:int) -> void:
	var diff : float = booster_chances[winner] - max(booster_chances[winner] - 10.0, 0.0)
	var increase : float = diff / (booster_chances.size()-1)
	
	for i in booster_chances.size():
		if i == winner:
			booster_chances[i] -= diff
		else:
			booster_chances[i] = min(booster_chances[i] + increase, 100.0)

## ----- Tooltip Logic ----- ##

func _process(delta:float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()

func _on_mouse_entered() -> void:
	is_hovered = true
	timer = 0.5

func _on_mouse_exited() -> void:
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()

## ----- Animations ----- ##

func play_animation(name: StringName, _params: Dictionary) -> void:
	match name:
		&"points_reward":
			_animate_points_reward()

func kill_animations() -> void:
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	apply_current_style()

func ensure_hex_label_pivot() -> void:
	booster_label.pivot_offset = booster_label.size * 0.5

func _animate_points_reward() -> void:
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	FeedbackAnimHelper.play_sounds(points_reward_sounds)

	ensure_hex_label_pivot()
	booster_label.scale = Vector2.ONE
	booster_progress_sprite.scale = progress_base_scale

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"punch")
	tween.set_parallel(true)
	tween.tween_property(booster_label, "scale", Vector2(punch_scale, punch_scale), punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(booster_progress_sprite, "scale", progress_peak_scale, punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(booster_label, "scale", Vector2.ONE, punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(booster_progress_sprite, "scale", progress_base_scale, punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

## ----- Utility Logic ----- ##

func apply_current_style() -> void:
	$hex/Sprite2D2.material.set_shader_parameter("current_value", 0.0)
	$hex/Sprite2D2.material.set_shader_parameter("lerp_value", float(acc_points) / float(booster_point_cost))
	$hex/Sprite2D2.material.set_shader_parameter("third_value",  0.0)
	
	$Tooltip/Label.text = "These are your credits. Earn credits by placing tiles, finishing quests or recycling cards. (%d / %d)" % [acc_points, booster_point_cost]


func choose_animal(element:int) -> CardData:
	var secondary_elements = [0,0,0,0,0,0]
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
	var secondary_chances : Array[float]
	if total > 0:
		for e in secondary_elements:
			secondary_chances.append((float(e) / float(total)) * 100.0)
	
	var secondary_element = 0
	## X% chance to pick a random secondary element
	if pick_option(random_secondary_chance if total > 0 else 100.0):
		secondary_element = _pick_random([1, 2, 3, 4, 5])
	else:
		secondary_element = pick_weighted([0,1,2,3,4,5], secondary_chances)
	
	
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
