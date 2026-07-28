extends CanvasLayer
class_name GameOverOverlay

signal restart_pressed

var COLOR_BROWN := Color.html("#918478")

@onready var _score_label: Label = $PopupRoot/ScoreLabel
@onready var _restart_button: Control = $PopupRoot/RestartButton
@onready var _popup_root: Node2D = $PopupRoot


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_set_restart_hover(false)


func open(final_score: int) -> void:
	_score_label.text = "Score: %d" % final_score
	show()


func close() -> void:
	hide()


func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0


func _on_restart_pressed() -> void:
	GameFeedback.play_click_button()
	restart_pressed.emit()


func _set_restart_hover(hovered: bool) -> void:
	var background: TextureRect = _restart_button.get_node("Background")
	var label: Label = _restart_button.get_node("Label")
	if hovered:
		background.self_modulate = COLOR_BROWN
		label.add_theme_color_override("font_color", Color.WHITE)
	else:
		background.self_modulate = Color.WHITE
		label.add_theme_color_override("font_color", COLOR_BROWN)


func _handle_gui_click(event: InputEvent, callback: Callable) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			callback.call()


func _on_restart_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_restart_pressed)


func _on_restart_mouse_entered() -> void:
	_set_restart_hover(true)


func _on_restart_mouse_exited() -> void:
	_set_restart_hover(false)


func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
