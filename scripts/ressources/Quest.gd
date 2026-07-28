class_name Quest
extends Resource

enum QuestType {
	PATTERN = 0,
}

@export var id: int = 0
@export var name: String = ""
@export var description: String = ""
@export var type: QuestType = QuestType.PATTERN
@export var placement: Array[Placement] = []
@export var bonus: Array[Placement] = []
@export var points: int = 0

func matches_tile_role(element: int, level: int) -> bool:
	for p in placement:
		if p.element == element and p.level == level:
			return true
	for b in bonus:
		if b.element == element and b.level == level:
			return true
	return false

func center_element() -> int:
	if placement.is_empty():
		return 0
	return placement[0].element
