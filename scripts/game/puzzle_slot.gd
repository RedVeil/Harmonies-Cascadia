extends VBoxContainer
class_name PuzzleSlot

signal selected(id: String)

var COLOR_WHITE := Color.WHITE
var COLOR_NUMBER_HOVER := Color.html("#918478")
var COLOR_STAR_EARNED := Color.html("#F2B05C")
var COLOR_LOCKED := Color(1.0, 1.0, 1.0, 0.4)

const STAR_ICON := preload("res://assets/icons/IconsFlat15_64px.png")

var puzzle_id: String = ""

var _unlocked: bool = true
var _box_normal: StyleBoxFlat
var _box_hover: StyleBoxFlat

@onready var _button: Button = $NumberButton
@onready var _star_nodes: Array[TextureRect] = []


func _ready() -> void:
	_star_nodes = [$Stars/Star1, $Stars/Star2, $Stars/Star3]
	_build_styles()
	_apply_box_style(false)
	_button.pressed.connect(_on_pressed)
	_button.mouse_entered.connect(_on_mouse_entered)
	_button.mouse_exited.connect(_on_mouse_exited)
	WebInstantButton.wire(_button)
	_button.focus_entered.connect(_on_focus_entered)
	_button.focus_exited.connect(_on_focus_exited)


func setup(id: String, number: int, unlocked: bool, rating: String) -> void:
	puzzle_id = id
	_unlocked = unlocked
	if _button == null:
		await ready
	_button.text = str(number)
	_set_stars(rating)
	if _unlocked:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP
		_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		modulate = COLOR_LOCKED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_apply_box_style(false)


func _build_styles() -> void:
	_box_normal = StyleBoxFlat.new()
	_box_normal.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	_box_normal.set_border_width_all(3)
	_box_normal.set_corner_radius_all(8)
	_box_normal.border_color = COLOR_WHITE
	_box_normal.set_content_margin_all(0)

	_box_hover = StyleBoxFlat.new()
	_box_hover.bg_color = COLOR_WHITE
	_box_hover.set_border_width_all(3)
	_box_hover.set_corner_radius_all(8)
	_box_hover.border_color = COLOR_WHITE
	_box_hover.set_content_margin_all(0)


func _apply_box_style(hovered: bool) -> void:
	if _button == null:
		return
	var box := _box_hover if hovered and _unlocked else _box_normal
	_button.add_theme_stylebox_override("normal", box)
	_button.add_theme_stylebox_override("hover", box)
	_button.add_theme_stylebox_override("pressed", box)
	_button.add_theme_stylebox_override("disabled", _box_normal)
	_button.add_theme_stylebox_override("focus", box)
	var number_color := COLOR_NUMBER_HOVER if hovered and _unlocked else COLOR_WHITE
	_button.add_theme_color_override("font_color", number_color)
	_button.add_theme_color_override("font_hover_color", number_color)
	_button.add_theme_color_override("font_pressed_color", number_color)
	_button.add_theme_color_override("font_focus_color", number_color)
	_button.add_theme_color_override("font_disabled_color", COLOR_WHITE)


func _set_stars(rating: String) -> void:
	var filled := 0
	match rating:
		"bronze":
			filled = 1
		"silver":
			filled = 2
		"gold":
			filled = 3
		_:
			filled = 0
	for i in _star_nodes.size():
		var star := _star_nodes[i]
		star.texture = STAR_ICON
		star.modulate = COLOR_STAR_EARNED if i < filled else COLOR_WHITE


func _on_pressed() -> void:
	if not _unlocked or puzzle_id.is_empty():
		return
	selected.emit(puzzle_id)


func _on_mouse_entered() -> void:
	if not _unlocked:
		return
	GameFeedback.play_hover_button()
	_apply_box_style(true)


func _on_mouse_exited() -> void:
	if _button.has_focus():
		return
	_apply_box_style(false)


func _on_focus_entered() -> void:
	if not _unlocked:
		return
	_apply_box_style(true)


func _on_focus_exited() -> void:
	if _button.is_hovered():
		return
	_apply_box_style(false)
