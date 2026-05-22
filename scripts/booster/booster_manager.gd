extends Node2D
class_name BoosterManager

@onready var card_container : CardContainer = $CardContainer

@export var orchestrator : Orchestrator

var booster_limit:int = 0
var booster_point_cost:int = 0

var booster_points:int = 3
var acc_points:int = 0

var booster_points_preview:int = 0
var acc_points_preview:int = 0

var boosters: Array[Booster] = []

var paused:bool = false


## ----- Initialisation ----- ##

func _ready() -> void:
	booster_limit = BoosterCatalog.booster_limit
	booster_point_cost = BoosterCatalog.booster_point_cost
	
	boosters.resize(booster_limit)
	card_container.init(self, booster_limit)
	
	$AccPointBar/Label.text = "0 / %d" % booster_point_cost
	$BoosterPointLabel/CurrentPoints.text = "%d" % booster_points
	
	$AccPointBar/ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$AccPointBar/ProgressBar.material.set_shader_parameter("lerp_value", 0.0)
	$AccPointBar/ProgressBar.material.set_shader_parameter("third_value", 0.0)
	
	for i in range(booster_limit):
		createBooster(i)

## ----- Pass Data Upstream ----- ##

func select_card(id:int) -> void:
	if booster_points > 0 and !paused:
		change_booster_points(-1)
		
		var booster = boosters[id]
		for card in booster.cards:
			orchestrator.add_hand_card(card)
		if booster.booster_points > 0:
			change_booster_points(booster.booster_points)
	
		card_container.remove_card(id)
		createBooster(id)
	if paused:
		card_container.deselect_card(id)

func change_booster_points(amount:int) -> void:
	booster_points += amount
	$BoosterPointLabel/CurrentPoints.text = "%d" % booster_points

## ----- Pass Data Downstream ----- ##

func preview_booster_points(points:int) -> void:
	if points == 0:
		return
	
	var points_ = acc_points + points
	if points_ < 0:
		points_ = 0
	
	booster_points_preview = booster_points + int(floor(points_ / booster_point_cost))
	acc_points_preview = points_ % booster_point_cost
	
	var progress = float(acc_points_preview) / float(booster_point_cost)
	var booster_point_diff = booster_points_preview - booster_points
	if booster_point_diff > 0:
		$BoosterPointLabel/PreviewPoints.text = "+ %d" % booster_point_diff
		$BoosterPointLabel/PreviewPoints.show()
		
		$AccPointBar/ProgressBar.material.set_shader_parameter("current_value", 0.0)
		$AccPointBar/ProgressBar.material.set_shader_parameter("lerp_value", 0.0)
		$AccPointBar/ProgressBar.material.set_shader_parameter("third_value", progress)
	else:
		$BoosterPointLabel/PreviewPoints.hide()
		
		if acc_points_preview == acc_points:
			$AccPointBar/ProgressBar.material.set_shader_parameter("current_value", 0.0)
			$AccPointBar/ProgressBar.material.set_shader_parameter("lerp_value", progress)
			$AccPointBar/ProgressBar.material.set_shader_parameter("third_value",  0.0)
		elif acc_points_preview > acc_points:
			$AccPointBar/ProgressBar.material.set_shader_parameter("current_value", 0.0)
			$AccPointBar/ProgressBar.material.set_shader_parameter("lerp_value", float(acc_points) / float(booster_point_cost))
			$AccPointBar/ProgressBar.material.set_shader_parameter("third_value",  progress)
		else:
			$AccPointBar/ProgressBar.material.set_shader_parameter("current_value", progress)
			$AccPointBar/ProgressBar.material.set_shader_parameter("lerp_value", float(acc_points) / float(booster_point_cost))
			$AccPointBar/ProgressBar.material.set_shader_parameter("third_value",  0.0)
	
	$AccPointBar/Label.text = "%d / %d" % [acc_points_preview, booster_point_cost]


func apply_booster_points() -> void:
	$BoosterPointLabel/PreviewPoints.hide()
	
	change_booster_points(booster_points_preview - booster_points)
	acc_points = acc_points_preview
	
	$AccPointBar/ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$AccPointBar/ProgressBar.material.set_shader_parameter("lerp_value", float(acc_points) / float(booster_point_cost))
	$AccPointBar/ProgressBar.material.set_shader_parameter("third_value",  0.0)
	
	$AccPointBar/Label.text = "%d / %d" % [acc_points, booster_point_cost]

func reset_preview() -> void:
	booster_points_preview = booster_points
	acc_points_preview = acc_points
	
	apply_booster_points()
	
## ----- Create Booster Logic ----- ##

func createBooster(idx:int) -> void:
	var booster = Booster.new()
	var picked_booster = pick_weighted(BoosterCatalog.booster_options)
	
	var cards : Array[CardData] = []
	var booster_points := 0
	var map_points := 0
	var quest_ids : Array[int] = []
	
	var options = picked_booster.base_content_options.duplicate(true)
		
	if pick_option(picked_booster.extra_chance):
		options.append(pick_weighted(picked_booster.extra_content_options))
		
	for entry in options:
		for i in range(entry.amount):
			if pick_option(entry.draw_chance):
				match entry.type:
					BoosterContentOption.RewardType.ELEMENT:
						cards.append(CardCatalog.elements[entry.id])
					BoosterContentOption.RewardType.ANIMAL:
						cards.append(CardCatalog.animals[entry.id])
					BoosterContentOption.RewardType.QUEST:
						# Roll random quest
						quest_ids.append(entry.id)
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
	
	var booster_card = CardData.new()
	booster_card.element = picked_booster.type
	booster_card.icon = ElementCatalog.elements[picked_booster.type].levels[0].icon
	
	card_container.add_card(booster_card, idx, true)

func pick_weighted(elements: Array[Variant]) -> Variant:
	var roll := randi() % 100
	var running := 0
	for element in elements:
		running += element.draw_chance
		if roll < running:
			return element
	return elements.back()

func pick_option(chance:int) -> bool:
	return randi() % 100 < chance
