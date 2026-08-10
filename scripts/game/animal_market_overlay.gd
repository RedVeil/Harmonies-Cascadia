extends CanvasLayer
class_name AnimalMarketOverlay

signal buy_pressed(offer_index: int)
signal close_pressed
signal reroll_pressed

var COLOR_BROWN := Color.html("#918478")
const CLOSE_BUTTON_SIZE := Vector2(32.0, 36.0)
const CARD_SIZE := Vector2(94.0, 168.0)
const OFFER_WIDTH := 120.0
const OFFER_GAP := 28.0
const BUY_BUTTON_HEIGHT := 28.0
const REROLL_BUTTON_SIZE := Vector2(160.0, 32.0)
const PANEL_PADDING := Vector2(32.0, 28.0)
const TITLE_HEIGHT := 36.0
const SUBTITLE_HEIGHT := 28.0
const CLOSE_ROW_HEIGHT := 36.0
const CARD_TO_BUY_GAP := 12.0
const BUY_TO_REROLL_GAP := 16.0
## Hand cards lift more on select, so their tooltip sits higher in card.tscn.
## Market hover is smaller — keep the tooltip just above the card.
const MARKET_TOOLTIP_POSITION := Vector2(-49.0, -280.0)

@export var card_scene: PackedScene
@export var market_hover_height: float = 12.0

var _offers: Array[CardData] = []
var _offer_roots: Array[Node2D] = []
var _cards: Array[Card] = []
var _buy_buttons: Array[Control] = []
var _hover_card_id: int = -1
var _reroll_enabled: bool = true
var _buys_enabled: Array[bool] = []
var _disabled_buy_label: String = "Wait"

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _click_blocker: Panel = $PopupRoot/ClickBlocker
@onready var _title_label: Label = $PopupRoot/TitleLabel
@onready var _credits_label: Label = $PopupRoot/CreditsLabel
@onready var _offers_root: Node2D = $PopupRoot/OffersRoot
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _reroll_button: Control = $PopupRoot/RerollButton
@onready var _fullscreen_blocker: ColorRect = $FullscreenBlocker

## ----- Initialisation ----- ##

func _ready() -> void:
	if card_scene == null:
		card_scene = load("res://scenes/card/card.tscn")
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)

## ----- Public API ----- ##

func open(offers: Array[CardData], _price: int = 0, _credits: int = 0, _reroll_price: int = 0) -> void:
	GameFeedback.play_open_popup()
	_offers = offers.duplicate()
	_hover_card_id = -1
	_rebuild_offers()
	_refresh_labels()
	_refresh_reroll_button()
	_layout()
	show()

func refresh_offers(offers: Array[CardData]) -> void:
	_offers = offers.duplicate()
	_hover_card_id = -1
	_rebuild_offers()
	_refresh_labels()
	_refresh_reroll_button()
	_layout()

func replace_offer(offer_index: int, offer: CardData) -> void:
	if offer_index < 0 or offer_index >= _offers.size():
		return
	_offers[offer_index] = offer
	if _hover_card_id == offer_index:
		exit_card(offer_index)
	_rebuild_single_offer(offer_index)
	_refresh_offer_button(offer_index)

func set_reroll_enabled(enabled: bool) -> void:
	_reroll_enabled = enabled
	_refresh_reroll_button()

func set_buys_enabled(enabled_flags: Array[bool], disabled_label: String = "Wait") -> void:
	_buys_enabled = enabled_flags.duplicate()
	_disabled_buy_label = disabled_label
	for i in _buy_buttons.size():
		_refresh_offer_button(i)

func set_status_text(text: String) -> void:
	if _credits_label == null:
		return
	_credits_label.text = text

func update_credits(_credits: int) -> void:
	pass

func close() -> void:
	GameFeedback.play_close_popup()
	_clear_offers()
	hide()

## ----- Card host (duck-typed like CardContainer) ----- ##

func hover_card(id: int) -> void:
	if id < 0 or id >= _cards.size() or _cards[id] == null:
		return
	if _hover_card_id == -1:
		_hover_card_id = id
		_cards[id].handle_hover()
	elif id != _hover_card_id:
		_cards[_hover_card_id].handle_exit()
		_cards[id].handle_hover()
		_hover_card_id = id

func exit_card(id: int) -> void:
	if id < 0 or id >= _cards.size() or _cards[id] == null:
		return
	if _hover_card_id == id:
		_hover_card_id = -1
	_cards[id].handle_exit()

func select_card(id: int) -> void:
	# Card already played click feedback via its HitArea.
	if id < 0 or id >= _offers.size():
		return
	if not _is_buy_enabled(id):
		return
	buy_pressed.emit(id)

## ----- Layout ----- ##

func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0
	_fullscreen_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _set_panel_rect(panel: Panel, width: float, height: float) -> void:
	panel.offset_left = -width / 2.0
	panel.offset_top = -height / 2.0
	panel.offset_right = width / 2.0
	panel.offset_bottom = height / 2.0

func _set_control_rect(control: Control, center: Vector2, size: Vector2) -> void:
	control.offset_left = center.x - size.x / 2.0
	control.offset_top = center.y - size.y / 2.0
	control.offset_right = center.x + size.x / 2.0
	control.offset_bottom = center.y + size.y / 2.0

func _offer_column_height() -> float:
	return CARD_SIZE.y + CARD_TO_BUY_GAP + BUY_BUTTON_HEIGHT

func _layout() -> void:
	var offer_count := maxi(_offers.size(), 1)
	var offers_width := offer_count * OFFER_WIDTH + (offer_count - 1) * OFFER_GAP
	var column_height := _offer_column_height()
	var panel_width := PANEL_PADDING.x * 2.0 + maxf(offers_width, 280.0)
	var panel_height := (
		CLOSE_ROW_HEIGHT
		+ TITLE_HEIGHT
		+ SUBTITLE_HEIGHT
		+ column_height
		+ BUY_TO_REROLL_GAP
		+ REROLL_BUTTON_SIZE.y
		+ PANEL_PADDING.y * 2.0
	)

	_set_panel_rect(_popup_panel, panel_width, panel_height)
	_set_panel_rect(_click_blocker, panel_width, panel_height)

	_title_label.position = Vector2(-panel_width / 2.0 + PANEL_PADDING.x, -panel_height / 2.0 + CLOSE_ROW_HEIGHT)
	_title_label.size = Vector2(panel_width - PANEL_PADDING.x * 2.0, TITLE_HEIGHT)

	_credits_label.position = Vector2(-panel_width / 2.0 + PANEL_PADDING.x, -panel_height / 2.0 + CLOSE_ROW_HEIGHT + TITLE_HEIGHT)
	_credits_label.size = Vector2(panel_width - PANEL_PADDING.x * 2.0, SUBTITLE_HEIGHT)

	_offers_root.position = Vector2(
		0.0,
		-panel_height / 2.0 + CLOSE_ROW_HEIGHT + TITLE_HEIGHT + SUBTITLE_HEIGHT + PANEL_PADDING.y + column_height / 2.0
	)

	_set_control_rect(
		_close_button,
		Vector2(
			panel_width / 2.0 - PANEL_PADDING.x - CLOSE_BUTTON_SIZE.x / 2.0,
			-panel_height / 2.0 + CLOSE_ROW_HEIGHT + TITLE_HEIGHT / 2.0
		),
		CLOSE_BUTTON_SIZE
	)

	_set_control_rect(
		_reroll_button,
		Vector2(0.0, panel_height / 2.0 - PANEL_PADDING.y - REROLL_BUTTON_SIZE.y / 2.0),
		REROLL_BUTTON_SIZE
	)

func _clear_offers() -> void:
	for child in _offers_root.get_children():
		child.queue_free()
	_offer_roots.clear()
	_cards.clear()
	_buy_buttons.clear()
	_hover_card_id = -1

func _rebuild_offers() -> void:
	_clear_offers()

	var count := _offers.size()
	var total_width := count * OFFER_WIDTH + maxi(count - 1, 0) * OFFER_GAP
	var start_x := -total_width / 2.0 + OFFER_WIDTH / 2.0

	for i in count:
		var slot := Node2D.new()
		slot.name = "Offer%d" % i
		slot.position = Vector2(start_x + i * (OFFER_WIDTH + OFFER_GAP), 0.0)
		_offers_root.add_child(slot)
		_offer_roots.append(slot)
		_cards.append(null)
		_buy_buttons.append(null)
		_rebuild_single_offer(i)

func _rebuild_single_offer(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _offer_roots.size():
		return
	var slot := _offer_roots[offer_index]
	for child in slot.get_children():
		child.queue_free()

	var offer := _offers[offer_index]
	var column_height := _offer_column_height()
	var has_offer := offer != null and offer.amount > 0

	if has_offer:
		var card := card_scene.instantiate() as Card
		card.name = "Card"
		card.hover_height = market_hover_height
		card.position = Vector2(0.0, -column_height / 2.0 + CARD_SIZE.y / 2.0)
		slot.add_child(card)
		card.init(offer, self, offer_index)
		# Offset so card 0 stays above PopupPanel; shadow uses relative z_index -1.
		card.set_z(offer_index + 1)
		card.placement_tooltip.position = MARKET_TOOLTIP_POSITION
		card.placement_tooltip.z_index = 20
		_cards[offer_index] = card
	else:
		_cards[offer_index] = null

	var buy_button := Control.new()
	buy_button.name = "BuyButton"
	buy_button.z_index = 3
	buy_button.position = Vector2(-OFFER_WIDTH / 2.0 + 10.0, column_height / 2.0 - BUY_BUTTON_HEIGHT)
	buy_button.size = Vector2(OFFER_WIDTH - 20.0, BUY_BUTTON_HEIGHT)
	buy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	buy_button.gui_input.connect(_on_buy_gui_input.bind(offer_index))
	buy_button.mouse_entered.connect(_on_buy_mouse_entered.bind(offer_index))
	buy_button.mouse_exited.connect(_on_buy_mouse_exited.bind(offer_index))
	slot.add_child(buy_button)
	_buy_buttons[offer_index] = buy_button

	var buy_bg := ColorRect.new()
	buy_bg.name = "Background"
	buy_bg.color = Color.WHITE
	buy_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buy_button.add_child(buy_bg)

	var buy_label := Label.new()
	buy_label.name = "Label"
	buy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buy_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	buy_label.add_theme_color_override("font_color", COLOR_BROWN)
	buy_label.add_theme_font_size_override("font_size", 12)
	buy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buy_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buy_button.add_child(buy_label)

	_refresh_offer_button(offer_index)

func _refresh_labels() -> void:
	_title_label.text = "Animal Market"
	if _credits_label.text.is_empty():
		_credits_label.text = "Take 1 animal per booster"

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

func _refresh_offer_button(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _buy_buttons.size():
		return
	var buy_button := _buy_buttons[offer_index]
	if buy_button == null:
		return
	var buy_label: Label = buy_button.get_node("Label")
	var buy_bg: ColorRect = buy_button.get_node("Background")
	var offer := _offers[offer_index] if offer_index < _offers.size() else null
	var has_offer := offer != null and offer.amount > 0

	if _is_buy_enabled(offer_index):
		buy_label.text = "Take"
		buy_bg.color = Color.WHITE
		buy_label.add_theme_color_override("font_color", COLOR_BROWN)
		buy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		buy_label.text = "—" if not has_offer else _disabled_buy_label
		buy_bg.color = Color(0.85, 0.85, 0.85, 1.0)
		buy_label.add_theme_color_override("font_color", Color.GRAY)
		buy_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_reroll_button() -> void:
	if _reroll_button == null:
		return
	var label: Label = _reroll_button.get_node("Label")
	var bg: ColorRect = _reroll_button.get_node("Background")
	if _reroll_enabled:
		label.text = "Refresh"
		bg.color = Color.WHITE
		label.add_theme_color_override("font_color", COLOR_BROWN)
		_reroll_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		label.text = "Refresh (cooling down)"
		bg.color = Color(0.85, 0.85, 0.85, 1.0)
		label.add_theme_color_override("font_color", Color.GRAY)
		_reroll_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

## ----- Input ----- ##

func _handle_gui_click(event: InputEvent, callback: Callable) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			callback.call()
			get_viewport().set_input_as_handled()

func _on_close_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_close_pressed)

func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close_pressed.emit()

func _on_reroll_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_reroll_pressed)

func _on_reroll_pressed() -> void:
	if not _reroll_enabled:
		return
	GameFeedback.play_click_button()
	reroll_pressed.emit()

func _on_buy_gui_input(event: InputEvent, offer_index: int) -> void:
	_handle_gui_click(event, func (): _on_buy_pressed(offer_index))

func _on_buy_pressed(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _offers.size():
		return
	if not _is_buy_enabled(offer_index):
		return
	GameFeedback.play_click_button()
	buy_pressed.emit(offer_index)

func _on_close_mouse_entered() -> void:
	GameFeedback.play_hover_button()
	_close_button.get_node("Label").add_theme_color_override("font_color", Color.WHITE)

func _on_close_mouse_exited() -> void:
	_close_button.get_node("Label").add_theme_color_override("font_color", COLOR_BROWN)

func _on_reroll_mouse_entered() -> void:
	if not _reroll_enabled:
		return
	GameFeedback.play_hover_button()
	_reroll_button.get_node("Background").color = COLOR_BROWN
	_reroll_button.get_node("Label").add_theme_color_override("font_color", Color.WHITE)

func _on_reroll_mouse_exited() -> void:
	_refresh_reroll_button()

func _on_buy_mouse_entered(offer_index: int) -> void:
	if offer_index < 0 or offer_index >= _buy_buttons.size():
		return
	if not _is_buy_enabled(offer_index):
		return
	var buy_button := _buy_buttons[offer_index]
	if buy_button == null:
		return
	GameFeedback.play_hover_button()
	buy_button.get_node("Background").color = COLOR_BROWN
	buy_button.get_node("Label").add_theme_color_override("font_color", Color.WHITE)

func _on_buy_mouse_exited(offer_index: int) -> void:
	_refresh_offer_button(offer_index)

func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
