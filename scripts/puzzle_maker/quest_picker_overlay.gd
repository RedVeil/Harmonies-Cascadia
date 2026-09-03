extends CanvasLayer
class_name QuestPickerOverlay

## Grid of quest tooltips; selecting one emits quest_selected.

signal quest_selected(quest_id: int)
signal closed

const TOOLTIP_SCENE := preload("res://scenes/game/placement_tooltip.tscn")
const COLUMNS := 5
const CELL := Vector2(120, 150)

var COLOR_BROWN := Color.html("#918478")

var _tips: Array[PlacementTooltip] = []
var _buttons: Array[Button] = []

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _title: Label = $PopupRoot/TitleLabel
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _scroll: ScrollContainer = $PopupRoot/Scroll
@onready var _scroll_content: Control = $PopupRoot/Scroll/Content


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)


func open() -> void:
	GameFeedback.play_open_popup()
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


func _rebuild_grid() -> void:
	_clear_grid()
	for i in QuestCatalog.quest_options.size():
		var quest: Quest = QuestCatalog.quest_options[i]
		if quest == null:
			continue
		var tip := TOOLTIP_SCENE.instantiate() as PlacementTooltip
		_scroll_content.add_child(tip)
		tip.init(1, quest.placement, quest.bonus, "=%d" % quest.points, PlacementTooltip.ArrowSide.BELOW)
		var col := i % COLUMNS
		var row := floori(float(i) / float(COLUMNS))
		tip.position = Vector2(col * CELL.x, row * CELL.y)
		_tips.append(tip)

		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_ALL
		btn.position = tip.position
		btn.size = Vector2(100, 130)
		btn.tooltip_text = "%s (#%d)" % [quest.name, quest.id]
		btn.pressed.connect(_on_quest_pressed.bind(quest.id))
		_scroll_content.add_child(btn)
		_buttons.append(btn)


func _clear_grid() -> void:
	for tip in _tips:
		if is_instance_valid(tip):
			tip.queue_free()
	_tips.clear()
	for btn in _buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_buttons.clear()


func _on_quest_pressed(quest_id: int) -> void:
	GameFeedback.play_click_button()
	quest_selected.emit(quest_id)
	close()


func _layout() -> void:
	var count := QuestCatalog.quest_options.size()
	var cols := mini(COLUMNS, maxi(count, 1))
	var rows := ceili(float(maxi(count, 1)) / float(COLUMNS))
	var grid_size := Vector2(
		(cols - 1) * CELL.x + 100.0,
		(rows - 1) * CELL.y + 130.0
	)
	var panel_w := clampf(grid_size.x + 56.0, 420.0, 720.0)
	var panel_h := clampf(minf(grid_size.y, 400.0) + 90.0, 300.0, 540.0)
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
	_scroll.offset_left = -panel_w * 0.5 + 20.0
	_scroll.offset_right = panel_w * 0.5 - 20.0
	_scroll.offset_top = -panel_h * 0.5 + 56.0
	_scroll.offset_bottom = panel_h * 0.5 - 20.0
	_scroll_content.custom_minimum_size = Vector2(grid_size.x + 20.0, grid_size.y + 20.0)


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
