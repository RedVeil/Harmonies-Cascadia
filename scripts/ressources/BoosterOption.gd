class_name BoosterOption
extends Resource

@export var type: Enums.BOOSTER_TYPE = 0
@export_range(0, 100, 0) var draw_chance: int = 0
@export var base_content_options: Array[BoosterContentOption] = []
@export_range(0, 100, 0) var extra_chance: int = 0
@export var extra_content_options: Array[BoosterContentOption] = []
