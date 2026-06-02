class_name BoosterContentOption
extends Resource

enum RewardType {
	ELEMENT = 0,
	ANIMAL = 1,
	QUEST = 2,
	BOOSTER_POINT = 3,
	MAP_POINT = 4,
}

@export var type: RewardType = RewardType.ELEMENT
@export var id: int = 0
@export var amount: int = 1
@export_range(0, 100, 0) var draw_chance: float = 0.0
