extends CanvasLayer
class_name AnimalPickerOverlay

## Grid of animal cards; selecting one emits animal_selected.

signal animal_selected(animal_id: int)
signal closed

const CARD_SCENE := preload("res://scenes/card/card.tscn")
const COLUMNS := 6
const CELL := Vector2(100, 180)
const PANEL_PAD := Vector2(28, 24)

var COLOR_BROWN := Color.html("#918478")

var _cards: Array[Card] = []
var _hover_id: int = -1

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _title: Label = $PopupRoot/TitleLabel
@onready var _grid_root: Node2D = $PopupRoot/Scroll/Content/GridRoot
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _scroll: ScrollContainer = $PopupRoot/Scroll
@onready var _scroll_content: Control = $PopupRoot/Scroll/Content


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)


func open() -> void:
	GameFeedback.play_open_popup()
	_hover_id = -1
	_rebuild_grid()
	_layout()
	show()
	OverlayFocus.enable_control(_close_button)
	OverlayFocus.grab_control(_close_button)


func close() -> void:
	GameFeedback.play_close_popup()
	_clear_grid()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if OverlayFocus.is_cancel(event):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


## Duck-typed card host API (like CardContainer).
func hover_card(id: int) -> void:
	if id < 0 or id >= _cards.size() or _cards[id] == null:
		return
	if _hover_id == -1:
		_hover_id = id
		_cards[id].handle_hover()
	elif id != _hover_id:
		_cards[_hover_id].handle_exit()
		_cards[id].handle_hover()
		_hover_id = id


func exit_card(id: int) -> void:
	if id < 0 or id >= _cards.size() or _cards[id] == null:
		return
	if _hover_id == id:
		_hover_id = -1
	_cards[id].handle_exit()


func select_card(id: int) -> void:
	if id < 0 or id >= CardCatalog.animals.size():
		return
	var animal: CardData = CardCatalog.animals[id]
	if animal == null:
		return
	GameFeedback.play_click_button()
	animal_selected.emit(animal.id)
	close()


func _rebuild_grid() -> void:
	_clear_grid()
	_cards.resize(CardCatalog.animals.size())
	_cards.fill(null)
	for i in CardCatalog.animals.size():
		var data: CardData = CardCatalog.animals[i]
		if data == null:
			continue
		var card := CARD_SCENE.instantiate() as Card
		_grid_root.add_child(card)
		card.init(data.duplicate(true), self, i)
		var col := i % COLUMNS
		var row := floori(float(i) / float(COLUMNS))
		# Cards are centered around origin; offset into cell.
		card.apply_layout(Vector2(col * CELL.x + 50.0, row * CELL.y + 110.0), 0.0, 0)
		_cards[i] = card


func _clear_grid() -> void:
	for card in _cards:
		if card != null and is_instance_valid(card):
			card.queue_free()
	_cards.clear()
	_hover_id = -1


func _layout() -> void:
	var count := CardCatalog.animals.size()
	var cols := mini(COLUMNS, maxi(count, 1))
	var rows := ceili(float(maxi(count, 1)) / float(COLUMNS))
	var grid_size := Vector2(cols * CELL.x + 20.0, rows * CELL.y + 20.0)
	var panel_w := 720.0
	var panel_h := 520.0
	_popup_panel.offset_left = -panel_w * 0.5
	_popup_panel.offset_right = panel_w * 0.5
	_popup_panel.offset_top = -panel_h * 0.5
	_popup_panel.offset_bottom = panel_h * 0.5
	_title.offset_left = -panel_w * 0.5 + 24.0
	_title.offset_right = panel_w * 0.5 - 48.0
	_title.offset_top = -panel_h * 0.5 + 12.0
	_title.offset_bottom = -panel_h * 0.5 + 48.0
	_close_button.offset_left = panel_w * 0.5 - 48.0
	_close_button.offset_right = panel_w * 0.5 - 16.0
	_close_button.offset_top = -panel_h * 0.5 + 12.0
	_close_button.offset_bottom = -panel_h * 0.5 + 48.0
	_scroll.offset_left = -panel_w * 0.5 + 16.0
	_scroll.offset_right = panel_w * 0.5 - 16.0
	_scroll.offset_top = -panel_h * 0.5 + 56.0
	_scroll.offset_bottom = panel_h * 0.5 - 16.0
	_scroll.visible = true
	_scroll_content.visible = true
	_scroll_content.custom_minimum_size = grid_size
	_grid_root.position = Vector2.ZERO


func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0


func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close()


func _on_close_gui_input(event: InputEvent) -> void:
	if OverlayFocus.is_activate(event) or InputScheme.is_left_click(event):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
