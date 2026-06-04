extends Node2D
class_name BoosterManager

@onready var booster_container : BoosterContainer = $booster_container

@export var orchestrator : Orchestrator

@export var booster_limit:int = 0
@export var base_booster_point_cost:int = 10
@export var booster_point_multiplier:float = 1.2
@export var start_booster_points:int = 3

var booster_point_cost:int = 0
var booster_points:int = 0
var acc_points:int = 0

var booster_point_cost_preview:int = 0
var booster_points_preview:int = 0
var acc_points_preview:int = 0

var boosters: Array[BoosterData] = []

var paused:bool = false
var booster_chances : Array[float] = []

var is_hovered : bool = false
var timer : float = 0.5

## ----- Initialisation ----- ##

func _ready() -> void:
	seed(randi())
	
	for option in BoosterCatalog.booster_options:
		if option.type < 6:
			booster_chances.append(option.draw_chance)
	
	boosters.resize(booster_limit + 2)
	booster_points = start_booster_points
	booster_point_cost = base_booster_point_cost
	
	$hex/Label.text = "%d" % booster_points
	$Tooltip/Label.text = "These are your booster points. Earn booster points by placing tiles, finishing quests or recycling cards. (0 / %d)" % booster_point_cost
	
	$hex/Sprite2D2.material.set_shader_parameter("current_value", 0.0)
	$hex/Sprite2D2.material.set_shader_parameter("lerp_value", 0.0)
	$hex/Sprite2D2.material.set_shader_parameter("third_value", 0.0)
	
	booster_container.init(self)
	
	#for i in range(booster_limit):
		#createBooster(i)
	createBooster(0)
	createBooster(1)

## ----- Pass Data Upstream ----- ##

func select_booster(id:int) -> void:
	if booster_points > 0 and !paused:
		change_booster_points(-1)
		
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
	if points == 0:
		return

	# Safety: never allow a 0-cost loop
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
		booster_point_cost_preview = ceili(float(booster_point_cost_preview) * booster_point_multiplier)

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
	
	$Tooltip/Label.text = "These are your booster points. Earn booster points by placing tiles, finishing quests or recycling cards. (%d / %d)" % [acc_points_preview, booster_point_cost_preview]


func apply_booster_points() -> void:
	change_booster_points(booster_points_preview - booster_points)
	acc_points = acc_points_preview
	booster_point_cost = booster_point_cost_preview
	
	$hex/Sprite2D2.material.set_shader_parameter("current_value", 0.0)
	$hex/Sprite2D2.material.set_shader_parameter("lerp_value", float(acc_points) / float(booster_point_cost))
	$hex/Sprite2D2.material.set_shader_parameter("third_value",  0.0)
	
	$Tooltip/Label.text = "These are your booster points. Earn booster points by placing tiles, finishing quests or recycling cards. (%d / %d)" % [acc_points, booster_point_cost]


func reset_preview() -> void:
	booster_points_preview = booster_points
	acc_points_preview = acc_points
	booster_point_cost_preview = booster_point_cost
	
	apply_booster_points()
	
## ----- Create Booster Logic ----- ##

func createBooster(idx:int) -> void:
	var booster = BoosterData.new()
	var option_index : int = 0
	if idx == 1:
		option_index = BoosterCatalog.booster_options.find_custom(func (option): return option.type == 6)
	elif idx == 0:
		option_index = BoosterCatalog.booster_options.find_custom(func (option): return option.type == 7)
	else:
		option_index = pick_weighted(BoosterCatalog.booster_options, booster_chances)
		update_booster_chances(option_index)
	
	var picked_booster = BoosterCatalog.booster_options[option_index]
		
	var cards : Array[CardData] = []
	var booster_points := 0
	var map_points := 0
	var quest_ids : Array[int] = []
	
	var options = picked_booster.base_content_options.duplicate(true)
		
	if pick_option(picked_booster.extra_card_chance):
		options.append(picked_booster.extra_card_options[pick_weighted(picked_booster.extra_card_options, [])])
	if pick_option(picked_booster.extra_chance):
		options.append(picked_booster.extra_content_options[pick_weighted(picked_booster.extra_content_options, [])])
		
	for entry in options:
		for i in range(entry.amount):
			if pick_option(entry.draw_chance):
				match entry.type:
					BoosterContentOption.RewardType.ELEMENT:
						cards.append(CardCatalog.elements[entry.id])
					BoosterContentOption.RewardType.ANIMAL:
						var filtered_by_element = CardCatalog.animals.filter(func (card): return card.element == entry.id)
						if filtered_by_element.size() > 0:
							cards.append(filtered_by_element.pick_random())
					BoosterContentOption.RewardType.QUEST:
						var quest_element = picked_booster.type if picked_booster.type < 6 else randi_range(1,5)
						var quest_id = orchestrator.pick_quest(entry.id, quest_element)
						if quest_id != -1:
							quest_ids.append(quest_id)
					BoosterContentOption.RewardType.BOOSTER_POINT:
						booster_points += entry.amount
					BoosterContentOption.RewardType.MAP_POINT:
						map_points += entry.amount
	
	booster.type = picked_booster.type
	booster.cards = cards
	booster.booster_points = booster_points
	booster.map_points = map_points
	booster.quest_ids = quest_ids
	
	boosters[idx] = booster

	booster_container.set_booster_visuals(idx, picked_booster.type, quest_ids.size() > 0)

func pick_weighted(options: Array[Variant], chances: Array[float]) -> int:
	var roll := randf_range(0.0, 99.9)
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
	return randf_range(0.0, 99.9) < chance

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
