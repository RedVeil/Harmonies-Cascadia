extends Node2D
class_name BoosterContainer

var parent: Node

@export var boosters: Array[Booster] = []

## ----- Initialisation ----- ##

func _ready() -> void:
	for b in boosters:
		b.init(self)

func init(parent_: Node) -> void:
	parent = parent_

## ----- Pass Interactions and Data Upstream ----- ##

func select_booster(id: int) -> void:
	parent.select_booster(id)

## ----- Pass Interactions and Data Downstream ----- ##

func set_booster_visuals(id: int, boosterData: BoosterData) -> void:
	if id != 3:
		boosters[id].set_booster_visuals(boosterData)

func enable_options() -> void:
	for i in range(mini(3, boosters.size())):
		boosters[i].enable()

func disable_options() -> void:
	for i in range(mini(3, boosters.size())):
		boosters[i].disable()

func set_options_progress(value: float) -> void:
	for i in range(mini(3, boosters.size())):
		boosters[i].set_progress(value)

func enable_reroll() -> void:
	if boosters.size() > 3:
		boosters[3].enable()

func disable_reroll() -> void:
	if boosters.size() > 3:
		boosters[3].disable()

func set_reroll_progress(value: float) -> void:
	if boosters.size() > 3:
		boosters[3].set_progress(value)
