extends Node2D
class_name CardContainer

var parent : Node

@export var layout_rect: ColorRect
@export var card_scene: PackedScene
@export var max_gap : float = 60.0
@export var enable_stacking : bool = false
@export var card_scale : Vector2 = Vector2(0.1, 0.1)

var cards: Array[Node2D] = []
var card_amount : int = 0

## ----- Initialisation ----- ##

func init(parent_:Node, limit:int) -> void:
	parent = parent_
	cards.resize(limit)

## ----- Pass Interactions and Data Upstream ----- ##

func select_card(id:int) -> void:
	parent.select_card(id)

## ----- Pass Interactions and Data Downstream ----- ##

func deselect_card(id) -> void:
	cards[id].deselect()

func add_card(card_data:CardData, id:int, is_booster:bool) -> void:
	var card := card_scene.instantiate() as Node2D
	cards[id] = card
	card_amount += 1
	
	add_child(card)
	card.init(card_data, self, id, enable_stacking, card_scale, is_booster)
	
	_layout_cards()

func remove_card(id:int) -> void:
	card_amount -= 1
	cards[id].remove_card()
	cards[id] = null
	
	_layout_cards()

func increment_card(id:int) -> void:
	cards[id].increment()

func decrement_card(id:int) -> void:
	cards[id].decrement()

## ----- Layout Logic ----- ##

func _layout_cards() -> void:
	var center_x := layout_rect.position.x + layout_rect.size.x / 2.0
	var center_y := layout_rect.position.y + layout_rect.size.y / 2.0
	var rect_width := layout_rect.size.x

	var gap: float = min(rect_width / float(card_amount), max_gap)

	# Distance from first card center to last card center.
	var total_width := gap * float(card_amount - 1)

	for i in card_amount:
		var card := cards[i]
		if card != null:
			var x := center_x - total_width / 2.0 + gap * float(i)
			card.position = Vector2(x, center_y)
			card.z_index = i
