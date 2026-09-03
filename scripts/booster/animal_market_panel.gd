extends Node2D
class_name AnimalMarketPanel

signal buy_pressed(offer_index: int)
signal toggle_pressed
signal reroll_pressed(offer_index: int)

var COLOR_BROWN = Color.html("#918478")
## Match booster pack chrome ([Booster.STACK_SCALE] / container x = 0, 100, 200).
const MARKET_SCALE := 0.75
const BOOSTER_SPACING := 100.0
const CARD_HEIGHT_PX := 174.0
const MARKET_BOOSTER_GAP_PX := 40.0
## Sit above packs with a fixed gap.
const OFFERS_Y := -(CARD_HEIGHT_PX * MARKET_SCALE + MARKET_BOOSTER_GAP_PX)
const FADE_DURATION := 0.18
const FADE_STAGGER := 0.09

@export var card_scene: PackedScene
@export var market_hover_height: float = 12.0

var _offers: Array[CardData] = []
var _offer_roots: Array[Node2D] = []
var _cards: Array[Card] = []
var _hover_card_id: int = -1
var _hover_frame: int = -1
var _reroll_hover_id: int = -1
var _buys_enabled: Array[bool] = []
var _reroll_ready_flags: Array[bool] = []
var _expanded: bool = false
var _anim_tween: Tween

@onready var _offers_root: Node2D = $OffersRoot
@onready var _expand_arrow: Area2D = $ExpandArrow
@onready var _expand_icon: Sprite2D = $ExpandArrow/Icon
@onready var _collapse_arrow: Area2D = $CollapseArrow
@onready var _collapse_icon: Sprite2D = $CollapseArrow/Icon


func _ready() -> void:
	if card_scene == null:
		card_scene = load("res://scenes/card/card.tscn")
	_wire_arrow(_expand_arrow)
	_wire_arrow(_collapse_arrow)
	_offers_root.hide()
	_sync_arrow_buttons()


func _wire_arrow(arrow: Area2D) -> void:
	arrow.mouse_entered.connect(_on_arrow_mouse_entered.bind(arrow))
	arrow.mouse_exited.connect(_on_arrow_mouse_exited.bind(arrow))
	arrow.input_event.connect(_on_arrow_input_event)


func is_open() -> bool:
	return _expanded


func open(offers: Array[CardData], _price: int = 0, _credits: int = 0, _reroll_price: int = 0) -> void:
	GameFeedback.play_open_popup()
	_kill_anim()
	_expanded = true
	_offers = offers.duplicate()
	_hover_card_id = -1
	_reroll_hover_id = -1
	_clear_market_touch()
	_rebuild_offers()
	_set_cards_alpha(0.0)
	_offers_root.show()
	_sync_arrow_buttons()
	_refresh_reroll_button_visibility()
	_play_fade_in()


func close() -> void:
	_kill_anim()
	var was_open := _expanded or not _cards.is_empty()
	_expanded = false
	_hover_card_id = -1
	_reroll_hover_id = -1
	_clear_market_touch()
	_sync_arrow_buttons()
	if not was_open:
		_clear_offers()
		_offers_root.hide()
		return
	GameFeedback.play_close_popup()
	if not _has_animatable_cards():
		_finish_close()
		return
	_play_fade_out()


func refresh_offers(offers: Array[CardData]) -> void:
	_offers = offers.duplicate()
	_hover_card_id = -1
	_reroll_hover_id = -1
	if _expanded:
		_kill_anim()
		_rebuild_offers()
		_set_cards_alpha(0.0)
		_refresh_reroll_button_visibility()
		_play_fade_in()
		_sync_arrow_buttons()


func replace_offer(offer_index: int, offer: CardData) -> void:
	if offer_index < 0 or offer_index >= _offers.size():
		return
	_offers[offer_index] = offer
	## Pointer often stays over the slot after X click; mouse_entered won't
	## re-fire on the replacement card until the cursor moves.
	var pointer_was_over := _hover_card_id == offer_index or _reroll_hover_id == offer_index
	if _reroll_hover_id == offer_index:
		_reroll_hover_id = -1
	if _hover_card_id == offer_index:
		_hover_card_id = -1
	if _expanded:
		_rebuild_single_offer(offer_index)
		if offer_index < _cards.size() and _cards[offer_index] != null:
			_cards[offer_index].modulate.a = 1.0
		_refresh_reroll_button_visibility()
		if pointer_was_over:
			call_deferred("_rehover_offer_under_pointer", offer_index)


func set_reroll_enabled(_enabled: bool) -> void:
	pass


func set_reroll_ready_flags(flags: Array[bool]) -> void:
	_reroll_ready_flags = flags.duplicate()
	_refresh_reroll_button_visibility()


func set_buys_enabled(enabled_flags: Array[bool], _disabled_label: String = "Wait") -> void:
	_buys_enabled = enabled_flags.duplicate()
	_apply_buy_visuals()


func set_status_text(_text: String) -> void:
	pass


func update_credits(_credits: int) -> void:
	pass


func _apply_buy_visuals() -> void:
	for i in _cards.size():
		var card := _cards[i]
		if card == null:
			continue
		card.set_desaturated(not _is_buy_enabled(i))
	_refresh_reroll_button_visibility()


## ----- Card host (duck-typed like CardContainer) ----- ##

func hover_card(id: int) -> void:
	if not _expanded:
		return
	if id < 0 or id >= _cards.size() or _cards[id] == null:
		return
	if _hover_card_id != id:
		_hover_frame = Engine.get_process_frames()
	if _hover_card_id == -1:
		_hover_card_id = id
		_cards[id].handle_hover()
	elif id != _hover_card_id:
		_cards[_hover_card_id].handle_exit()
		_cards[id].handle_hover()
		_hover_card_id = id
	_refresh_reroll_button_visibility()


func exit_card(id: int) -> void:
	if InputScheme.touch.is_sticky("market", id):
		return
	if id < 0 or id >= _cards.size() or _cards[id] == null:
		return
	# Keep hover while pointer moves onto this offer's X button.
	if _reroll_hover_id == id:
		return
	if _hover_card_id == id:
		_hover_card_id = -1
	_cards[id].handle_exit()
	_refresh_reroll_button_visibility()


func select_card(id: int) -> void:
	if not _expanded:
		return
	if id < 0 or id >= _offers.size():
		return
	var same_frame_hover := _hover_card_id == id and _hover_frame == Engine.get_process_frames()
	if InputScheme.uses_touch_confirm() or same_frame_hover or InputScheme.touch.is_sticky("market", id):
		var preview := not InputScheme.touch.can_confirm("market", id) or same_frame_hover
		if preview:
			if not InputScheme.touch.is_sticky("market", id):
				var prev := InputScheme.touch.set_target("market", id)
				if String(prev.get("kind", "")) == "market" and prev.get("id", id) != id:
					_unhover_other_offer(int(prev["id"]))
			hover_card(id)
			return
	elif _reroll_hover_id == id:
		return
	if not _is_buy_enabled(id):
		return
	buy_pressed.emit(id)
	InputScheme.touch.clear()


func _unhover_other_offer(other_id: int) -> void:
	if other_id < 0 or other_id >= _cards.size() or _cards[other_id] == null:
		return
	if _hover_card_id == other_id:
		_hover_card_id = -1
	if _reroll_hover_id == other_id:
		_reroll_hover_id = -1
	_cards[other_id].handle_exit()
	_refresh_reroll_button_visibility()


func _clear_market_touch() -> void:
	if InputScheme.touch.kind == "market":
		InputScheme.touch.clear()


func reroll_card(id: int) -> void:
	if not _is_buy_enabled(id):
		return
	if not _is_reroll_ready(id):
		return
	reroll_pressed.emit(id)
	if InputScheme.uses_touch_confirm():
		InputScheme.touch.set_target("market", id)


func set_recycle_hover(id: int, hovering: bool) -> void:
	if hovering:
		if _reroll_hover_id == id and _hover_card_id == id:
			return
		_reroll_hover_id = id
		if _hover_card_id != id and id >= 0 and id < _cards.size() and _cards[id] != null:
			if _hover_card_id != -1 and _hover_card_id < _cards.size() and _cards[_hover_card_id] != null:
				_cards[_hover_card_id].handle_exit()
			_hover_card_id = id
			_cards[id].handle_hover()
	elif _reroll_hover_id == id:
		_reroll_hover_id = -1
	else:
		return
	_refresh_reroll_button_visibility()


## ----- Layout ----- ##

func _sync_arrow_buttons() -> void:
	UiPointerBlock.exit(_expand_arrow)
	UiPointerBlock.exit(_collapse_arrow)
	_expand_arrow.visible = not _expanded
	_expand_arrow.input_pickable = not _expanded
	_collapse_arrow.visible = _expanded
	_collapse_arrow.input_pickable = _expanded
	_reset_arrow_colors(_expand_icon)
	_reset_arrow_colors(_collapse_icon)


func _reset_arrow_colors(icon: Sprite2D) -> void:
	icon.modulate = Color.WHITE


func _clear_offers() -> void:
	for child in _offers_root.get_children():
		child.queue_free()
	_offer_roots.clear()
	_cards.clear()
	_hover_card_id = -1
	_reroll_hover_id = -1


func _rebuild_offers() -> void:
	_clear_offers()
	var count := _offers.size()
	for i in count:
		var slot := Node2D.new()
		slot.name = "Offer%d" % i
		# Same origins as booster_container packs (0, 100, 200).
		slot.position = Vector2(float(i) * BOOSTER_SPACING, 0.0)
		_offers_root.add_child(slot)
		_offer_roots.append(slot)
		_cards.append(null)
		_rebuild_single_offer(i)
	_offers_root.position = Vector2(0.0, OFFERS_Y)


func _rebuild_single_offer(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _offer_roots.size():
		return
	var slot := _offer_roots[offer_index]
	for child in slot.get_children():
		if child is Card:
			var old_card := child as Card
			UiPointerBlock.exit(old_card)
			if old_card.recycle_btn != null:
				UiPointerBlock.exit(old_card.recycle_btn)
		child.queue_free()

	var offer := _offers[offer_index]
	var has_offer := offer != null and offer.amount > 0
	if not has_offer:
		_cards[offer_index] = null
		return

	var card := card_scene.instantiate() as Card
	card.name = "Card"
	card.scale = Vector2(MARKET_SCALE, MARKET_SCALE)
	card.hover_height = market_hover_height
	slot.add_child(card)
	card.init(offer, self, offer_index)
	card.set_z(offer_index + 1)
	card.set_desaturated(not _is_buy_enabled(offer_index))
	_cards[offer_index] = card


func _rehover_offer_under_pointer(offer_index: int) -> void:
	if not _expanded:
		return
	if offer_index < 0 or offer_index >= _cards.size():
		return
	var card := _cards[offer_index]
	if card == null or card.card_area == null:
		return
	var mouse := card.card_area.get_global_mouse_position()
	var over_card := card.card_area.get_global_rect().has_point(mouse)
	var over_empty := card.empty_area != null \
		and card.empty_area.get_global_rect().has_point(mouse)
	if not over_card and not over_empty:
		return
	card.is_mouse_inside = true
	UiPointerBlock.enter(card)
	hover_card(offer_index)


func _is_reroll_ready(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= _reroll_ready_flags.size():
		return true
	return _reroll_ready_flags[offer_index]


func _refresh_reroll_button_visibility() -> void:
	for i in _cards.size():
		var card := _cards[i]
		if card == null:
			continue
		var show := _expanded and _is_buy_enabled(i) and _is_reroll_ready(i) \
			and (_hover_card_id == i or _reroll_hover_id == i)
		card.refresh_recycle_button(show)


func _set_cards_alpha(alpha: float) -> void:
	for card in _cards:
		if card != null:
			card.modulate.a = alpha


func _has_animatable_cards() -> bool:
	for card in _cards:
		if card != null:
			return true
	return false


func _kill_anim() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null


func _play_fade_in() -> void:
	if not _has_animatable_cards():
		return
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	for i in _cards.size():
		var card := _cards[i]
		if card == null:
			continue
		_anim_tween.tween_property(card, "modulate:a", 1.0, FADE_DURATION) \
			.set_delay(float(i) * FADE_STAGGER) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_fade_out() -> void:
	if not _has_animatable_cards():
		_finish_close()
		return
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	var last_i := _cards.size() - 1
	for i in _cards.size():
		var card := _cards[i]
		if card == null:
			continue
		var delay := float(last_i - i) * FADE_STAGGER
		_anim_tween.tween_property(card, "modulate:a", 0.0, FADE_DURATION) \
			.set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	_anim_tween = null
	_clear_offers()
	_offers_root.hide()


func _is_buy_enabled(offer_index: int) -> bool:
	if offer_index < 0 or offer_index >= _offers.size():
		return false
	var offer := _offers[offer_index]
	if offer == null or offer.amount <= 0:
		return false
	if _buys_enabled.is_empty():
		return true
	if offer_index >= _buys_enabled.size():
		return false
	return _buys_enabled[offer_index]


## ----- Arrow / reroll input ----- ##

func _on_arrow_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not InputScheme.is_left_click(event):
		return
	GameFeedback.play_click_button()
	toggle_pressed.emit()
	get_viewport().set_input_as_handled()


func _on_arrow_mouse_entered(arrow: Area2D) -> void:
	if not arrow.input_pickable or not arrow.visible:
		return
	UiPointerBlock.enter(arrow)
	GameFeedback.play_hover_button()
	var icon: Sprite2D = arrow.get_node("Icon")
	icon.modulate = COLOR_BROWN


func _on_arrow_mouse_exited(arrow: Area2D) -> void:
	UiPointerBlock.exit(arrow)
	_reset_arrow_colors(arrow.get_node("Icon"))
