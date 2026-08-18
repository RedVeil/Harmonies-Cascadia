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

func reroll_booster(id: int) -> void:
	if parent and parent.has_method("reroll_booster_slot"):
		parent.reroll_booster_slot(id)

## ----- Pass Interactions and Data Downstream ----- ##

func set_booster_visuals(id: int, boosterData: BoosterData) -> void:
	if id < 0 or id >= boosters.size():
		return
	boosters[id].set_booster_visuals(boosterData)

func enable_options() -> void:
	for b in boosters:
		b.enable()

func disable_options() -> void:
	for b in boosters:
		b.disable()

func set_options_progress(value: float) -> void:
	for b in boosters:
		b.set_progress(value)

func set_booster_reroll_ready(id: int, ready: bool) -> void:
	if id < 0 or id >= boosters.size():
		return
	boosters[id].set_reroll_ready(ready)
