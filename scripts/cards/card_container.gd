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
var recycle_hover_id : int = -1
var _relayout_queued : bool = false

## ----- Initialisation ----- ##

func init(parent_:Node, limit:int) -> void:
	parent = parent_
	cards.resize(limit)

## ----- Pass Data Upstream ----- ##

func select_card(id:int) -> void:
	cards[id].select()
	parent.select_card(id)

func recycle_card(id: int) -> void:
	if parent.has_method("recycle_card"):
		parent.recycle_card(id)

## ----- Pass Data Downstream ----- ##

func deselect_card(id) -> void:
	if id == null or int(id) < 0 or int(id) >= cards.size():
		return
	if cards[id] == null:
		return
	cards[id].deselect()

func add_card(card_data:CardData, id:int) -> void:
	var card := card_scene.instantiate() as Card
	cards[id] = card
	card_amount += 1
	
	add_child(card)
	card.init(card_data, self, id)
	card.mark_spawn_layout()
	
	_queue_layout()

func remove_card(id:int) -> void:
	card_amount -= 1
	if hover_card_id == id:
		hover_card_id = -1
	if recycle_hover_id == id:
		recycle_hover_id = -1
	if cards[id] != null:
		cards[id].remove_card()
	cards[id] = null
	
	_queue_layout()

func increment_card(id:int) -> void:
	cards[id].increment()

func set_card_amount(id:int, amount:int) -> void:
	cards[id].set_stack_amount(amount)

func decrement_card(id:int) -> void:
	cards[id].decrement()

## ----- Hover Logic ----- ##

func hover_card(id:int) -> void:
	if hover_card_id == -1:
		hover_card_id = id
		cards[id].handle_hover()
	else:
		if id != hover_card_id:
			cards[hover_card_id].handle_exit()
			cards[id].handle_hover()
			hover_card_id = id
	_refresh_recycle_button(id)

func exit_card(id:int) -> void:
	# Keep hover while pointer moves onto this card's recycle X.
	if recycle_hover_id == id:
		return
	if hover_card_id == id:
		hover_card_id = -1
	cards[id].handle_exit()
	_refresh_recycle_button(id)

func set_recycle_hover(id: int, hovering: bool) -> void:
	if hovering:
		recycle_hover_id = id
		if hover_card_id != id and id >= 0 and id < cards.size() and cards[id] != null:
			if hover_card_id != -1 and cards[hover_card_id] != null:
				cards[hover_card_id].handle_exit()
			hover_card_id = id
			cards[id].handle_hover()
	elif recycle_hover_id == id:
		recycle_hover_id = -1
	_refresh_recycle_button(id)

func _refresh_recycle_button(id: int) -> void:
	if id < 0 or id >= cards.size() or cards[id] == null:
		return
	var card := cards[id] as Card
	if card != null and card.has_method("refresh_recycle_button"):
		card.refresh_recycle_button(hover_card_id == id or recycle_hover_id == id)

## ----- Layout Logic ----- ##

func _queue_layout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	call_deferred("_flush_layout")

func _flush_layout() -> void:
	_relayout_queued = false
	_layout_cards()

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
		var card := visible_cards[i] as Card

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

		var target_pos := Vector2(x, y)
		if card.consume_spawn_layout():
			card.play_spawn_animation(target_pos, angle, i * 2)
		else:
			card.apply_layout(target_pos, angle, i * 2)

## ----- Utility Logic ----- ##

func _center_out_slot(i: int) -> int:
	if i == 0:
		return 0
	
	var step := int(ceil(float(i) / 2.0))
	
	if i % 2 == 1:
		return step # right
	else:
		return -step # left
