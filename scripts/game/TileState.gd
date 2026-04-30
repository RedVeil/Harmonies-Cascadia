class_name TileState
extends RefCounted

enum Element {
	NONE,
	FOREST,
	FIELD,
	MOUNTAIN,
	RIVER,
	WETLANDS
}

var element: Element = Element.NONE
var animal: int = 0
var stack_count: int = 0

func clone() -> TileState:
	var copy := TileState.new()
	copy.element = element
	copy.animal = animal
	copy.stack_count = stack_count
	return copy

func spec_key() -> String:
	return "%d:%d" % [int(element), int(stack_count)]
