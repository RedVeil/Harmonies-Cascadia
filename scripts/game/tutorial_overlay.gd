extends CanvasLayer
class_name TutorialOverlay

signal closed

enum View { SCORING, STACKING }

const COLUMN_COUNT := 5
const DIVIDER_WIDTH := 1.0

var TEXT_BROWN := Color.html("#918478")
var DIVIDER_COLOR := Color.html("#918478")

@export var orchestrator: Orchestrator
@export var image: Texture2D
@export var book_icon: Texture2D
@export var help_icon: Texture2D

@onready var _popup_root: Node2D = $PopupRoot
@onready var _image_display: Sprite2D = $PopupRoot/ImageDisplay
@onready var _scoring_row: HBoxContainer = $PopupRoot/ScoringRow
@onready var _close_button: Button = $PopupRoot/CloseButton
@onready var _toggle_button: Button = $PopupRoot/ToggleButton

var _view: View = View.SCORING
var _columns: Array[VBoxContainer] = []

## ----- Initialisation ----- ##

func _ready() -> void:
	hide()
	_toggle_button.focus_mode = Control.FOCUS_NONE
	_close_button.focus_mode = Control.FOCUS_NONE
	_build_scoring_row()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_apply_view()

## ----- Public API ----- ##

func open() -> void:
	open_stacking()

func open_scoring() -> void:
	_open_view(View.SCORING)

func open_stacking() -> void:
	if image == null:
		return
	_open_view(View.STACKING)

func close() -> void:
	if orchestrator and orchestrator.tutorial_bridge.active:
		if not orchestrator.tutorial_bridge.allows_action("close_tutorial"):
			return
	GameFeedback.play_close_popup()
	hide()
	closed.emit()
	if orchestrator:
		orchestrator.tutorial_bridge.notify("tutorial_closed")

## ----- View ----- ##

func _open_view(view: View) -> void:
	var was_hidden := not visible
	_view = view
	if was_hidden:
		GameFeedback.play_open_popup()
	_apply_view()
	show()

func _apply_view() -> void:
	var scoring := _view == View.SCORING
	_scoring_row.visible = scoring
	_image_display.visible = not scoring
	if scoring:
		_populate_scoring()
		_toggle_button.icon = book_icon
	else:
		if image:
			_image_display.texture = image
		_toggle_button.icon = help_icon

func _populate_scoring() -> void:
	if orchestrator == null:
		return
	for i in _columns.size():
		var rule: ScoringRule = orchestrator.get_active_rule(i + 1)
		if rule == null:
			continue
		var title := _columns[i].get_node("Title") as Label
		var graphic := _columns[i].get_node("Graphic") as TextureRect
		var description := _columns[i].get_node("Description") as Label
		title.text = rule.name
		description.text = rule.description
		graphic.texture = get_desc_image(rule.id)
		_fit_graphic(graphic)

func get_desc_image(id: int) -> Texture2D:
	match id:
		0:
			return load("res://assets/score_tooltip/f1.webp")
		1:
			return load("res://assets/score_tooltip/f2.webp")
		2:
			return load("res://assets/score_tooltip/f3.webp")
		3:
			return load("res://assets/score_tooltip/a1.webp")
		4:
			return load("res://assets/score_tooltip/a2.webp")
		5:
			return load("res://assets/score_tooltip/a3.webp")
		6:
			return load("res://assets/score_tooltip/m1.webp")
		7:
			return load("res://assets/score_tooltip/m2.webp")
		8:
			return load("res://assets/score_tooltip/m3.webp")
		9:
			return load("res://assets/score_tooltip/r1.webp")
		10:
			return load("res://assets/score_tooltip/r2.webp")
		11:
			return load("res://assets/score_tooltip/r3.webp")
		12:
			return load("res://assets/score_tooltip/w1.webp")
		13:
			return load("res://assets/score_tooltip/w2.webp")
		14:
			return load("res://assets/score_tooltip/w3.webp")
		_:
			return load("res://assets/score_tooltip/f1.webp")

## ----- Layout ----- ##

func _center_popup_root() -> void:
	_popup_root.position = get_viewport().get_visible_rect().size / 2.0

func _column_width() -> float:
	var row_width := _scoring_row.size.x
	if row_width <= 1.0:
		row_width = absf(_scoring_row.offset_right - _scoring_row.offset_left)
	var sep := _scoring_row.get_theme_constant("separation")
	var usable := row_width - DIVIDER_WIDTH * 4.0 - float(sep) * 8.0
	return maxf(usable / float(COLUMN_COUNT), 80.0)

func _fit_graphic(graphic: TextureRect) -> void:
	var tex := graphic.texture
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0:
		return
	graphic.custom_minimum_size = Vector2(0.0, _column_width() * tex_size.y / tex_size.x)

## ----- Scoring columns ----- ##

func _build_scoring_row() -> void:
	_columns.clear()
	for child in _scoring_row.get_children():
		child.queue_free()
	for i in COLUMN_COUNT:
		if i > 0:
			var divider := ColorRect.new()
			divider.custom_minimum_size = Vector2(DIVIDER_WIDTH, 0.0)
			divider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			divider.color = DIVIDER_COLOR
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			divider.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_scoring_row.add_child(divider)
		var column := _make_column()
		_scoring_row.add_child(column)
		_columns.append(column)

func _make_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.add_theme_color_override("font_color", TEXT_BROWN)
	title.add_theme_color_override("font_outline_color", TEXT_BROWN)
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_font_size_override("font_size", 20)
	title.text = "Rule"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)

	var graphic := TextureRect.new()
	graphic.name = "Graphic"
	graphic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	graphic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	graphic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(graphic)

	var description := Label.new()
	description.name = "Description"
	description.autowrap_mode = TextServer.AUTOWRAP_WORD
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description.add_theme_color_override("font_color", TEXT_BROWN)
	description.add_theme_constant_override("line_spacing", -5)
	description.add_theme_font_size_override("font_size", 14)
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(description)

	return column

## ----- Interactions ----- ##

func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close()

func _on_close_mouse_entered() -> void:
	GameFeedback.play_hover_button()

func _on_toggle_pressed() -> void:
	if _view == View.SCORING:
		if orchestrator and orchestrator.tutorial_bridge.active:
			if not orchestrator.tutorial_bridge.allows_action("open_tutorial"):
				return
		if image == null:
			return
		GameFeedback.play_click_button()
		_view = View.STACKING
		_apply_view()
		if orchestrator:
			orchestrator.tutorial_bridge.notify("tutorial_opened")
	else:
		GameFeedback.play_click_button()
		_view = View.SCORING
		_apply_view()

func _on_toggle_mouse_entered() -> void:
	GameFeedback.play_hover_button()

func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
