extends CanvasLayer
class_name PuzzleLoadOverlay

## Lists catalog puzzles so the maker can reload an existing definition.

signal puzzle_selected(id: String)
signal closed

var COLOR_BROWN := Color.html("#918478")

@onready var _popup_root: Node2D = $PopupRoot
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _list: VBoxContainer = $PopupRoot/Scroll/List
@onready var _status: Label = $PopupRoot/StatusLabel


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)


func open(current_id: String = "") -> void:
	GameFeedback.play_open_popup()
	_rebuild_list(current_id)
	show()
	OverlayFocus.enable_control(_close_button)
	OverlayFocus.enable_buttons(_list)
	if InputScheme.is_gamepad():
		OverlayFocus.grab_first_button(_list)
	else:
		OverlayFocus.grab_control(_close_button)


func close() -> void:
	GameFeedback.play_close_popup()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if OverlayFocus.is_cancel(event):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _rebuild_list(current_id: String) -> void:
	for child in _list.get_children():
		child.queue_free()
	GameSession.reload_puzzles()
	var puzzles: Array[Dictionary] = GameSession.list_puzzles()
	if puzzles.is_empty():
		_status.text = "No puzzles in puzzles.json."
		return
	_status.text = "Select a puzzle to load it into the maker."
	for i in puzzles.size():
		var puzzle: Dictionary = puzzles[i]
		var id := str(puzzle.get("id", ""))
		if id.is_empty():
			continue
		var title := str(puzzle.get("title", id))
		if title.is_empty():
			title = id
		var button := Button.new()
		var label := title if title == id else "%s  ·  %s" % [title, id]
		button.text = "%d  ·  %s" % [i + 1, label]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", COLOR_BROWN)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_color_override("font_focus_color", COLOR_BROWN)
		if id == current_id:
			button.text = "▸  " + button.text
		button.pressed.connect(_on_puzzle_pressed.bind(id))
		_list.add_child(button)
		WebInstantButton.wire(button)


func _on_puzzle_pressed(id: String) -> void:
	GameFeedback.play_click_button()
	if id.is_empty():
		return
	puzzle_selected.emit(id)


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
