extends Node2D
class_name BoosterContainer

var parent : Node

@export var boosters: Array[Booster] = []

## ----- Initialisation ----- ##

func _ready() -> void:
	for b in boosters:
		b.init(self)

func init(parent_:Node) -> void:
	parent = parent_

## ----- Pass Interactions and Data Upstream ----- ##

func select_booster(id:int) -> void:
	parent.select_booster(id)

## ----- Pass Interactions and Data Downstream ----- ##

func set_booster_visuals(id:int, boosterData:BoosterData) -> void:
	if id != 3:
		boosters[id].set_booster_visuals(boosterData)
