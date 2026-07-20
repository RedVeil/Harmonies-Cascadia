class_name CardData
extends Resource

enum CARD_TYPE {
	ELEMENT = 0,
	ANIMAL = 1,
}

@export var type: CARD_TYPE = CARD_TYPE.ELEMENT
@export var id: int = 0
@export var name: String = ""
# where the card can be placed
@export var placement: Array[Placement] = []
# what has to be surrounding it to score point_score
@export var bonus: Array[Placement] = []
# how many cards of this type are stacked
@export var amount: int = 0
@export var draw_chance: float = 0.0
# used to get the background color of the card
@export var element: GameEnums.ELEMENT = 0
@export var secondary_element: GameEnums.ELEMENT = 0
@export var point_score: int = 0
@export var bonus_points: float = 0
@export var icon: String = ""
@export var models: Array[String] = []
