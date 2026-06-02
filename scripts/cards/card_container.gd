extends Node2D
class_name CardContainer

var parent : Node

@export var layout_rect: ColorRect
@export var card_scene: PackedScene

@export var fan_width : float = 250.0 # predefined max width
@export var max_angle : float = 15.0         # total-ish visual fan strength
@export var arc_height : float = 30.0        # how much the center rises
@export var card_gap : float = 60.0
@export var angle_step: float = 10.0

var cards: Array[Node2D] = []
var card_amount : int = 0
var hover_card_id : int = -1

## ----- Initialisation ----- ##

func init(parent_:Node, limit:int) -> void:
	parent = parent_
	cards.resize(limit)

## ----- Pass Interactions and Data Upstream ----- ##

func select_card(id:int) -> void:
	cards[id].select()
	parent.select_card(id)

## ----- Pass Interactions and Data Downstream ----- ##

func deselect_card(id) -> void:
	cards[id].deselect()

func add_card(card_data:CardData, id:int) -> void:
	var card := card_scene.instantiate() as Node2D
	cards[id] = card
	card_amount += 1
	
	add_child(card)
	card.init(card_data, self, id)
	
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

## ----- Handle Hover logic ----- ##

func hover_card(id:int) -> void:
	if hover_card_id == -1:
		hover_card_id = id
		cards[id].handle_hover()
	else:
		if id != hover_card_id:
			cards[hover_card_id].handle_exit()
			cards[id].handle_hover()
			hover_card_id = id

func exit_card(id:int) -> void:
	if hover_card_id == id:
		hover_card_id = -1
	cards[id].handle_exit()

## ----- Layout Logic ----- ##

func _layout_cards() -> void:
	var visible_cards: Array = []

	for card in cards:
		if card != null:
			visible_cards.append(card)

	var count := visible_cards.size()
	if count == 0:
		return
	
	visible_cards.sort_custom(func (a,b): return a.element_id < b.element_id)
	var element_cards = visible_cards.filter(func (card): return !card.is_animal)
	var animal_cards = visible_cards.filter(func (card): return card.is_animal)
	visible_cards = element_cards + animal_cards
	
	var center_x := layout_rect.position.x + layout_rect.size.x / 2.0
	var center_y := layout_rect.position.y + layout_rect.size.y / 2.0

	var max_width : float = min(layout_rect.size.x, fan_width)

	var total_width := card_gap * float(count - 1)
	total_width = min(total_width, max_width)

	var gap := 0.0
	if count > 1:
		gap = total_width / float(count - 1)

	var max_offset : float = max(0.5, float(count - 1) / 2.0)

	for i in count:
		var card = visible_cards[i]

		# -0.5 / 0.5 for 2 cards,
		# -1.5 / -0.5 / 0.5 / 1.5 for 4 cards, etc.
		var offset := float(i) - float(count - 1) / 2.0

		var x := center_x - total_width / 2.0 + gap * float(i)

		var normalized : float = offset / max_offset

		# Center cards highest, outer cards lower.
		var height_factor : float = 1.0 - normalized * normalized
		var y : float = center_y - arc_height * height_factor

		# Angle grows outward from the center.
		var angle : float = offset * angle_step
		angle = clamp(angle, -max_angle, max_angle)

		card.position = Vector2(x, y)
		card.rotation_degrees = angle

		# z_index increases from left to right.
		card.set_z(i*2)

func _center_out_slot(i: int) -> int:
	if i == 0:
		return 0
	
	var step := int(ceil(float(i) / 2.0))
	
	if i % 2 == 1:
		return step # right
	else:
		return -step # left
