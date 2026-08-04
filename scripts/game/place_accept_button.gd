extends Area2D
class_name PlaceAcceptButton

@export var orchestrator: Orchestrator

var enabled: bool = false
var is_hovered: bool = false

var COLOR_BROWN := Color.html("#918478")


func _ready() -> void:
	hide_accept()


func show_accept() -> void:
	enabled = true
	visible = true
	_refresh_visuals()


func hide_accept() -> void:
	enabled = false
	visible = false
	is_hovered = false
	_refresh_visuals()


func _refresh_visuals() -> void:
	if enabled:
		$background.self_modulate = Color.WHITE
		$Label.add_theme_color_override("font_color", COLOR_BROWN)
	else:
		$background.self_modulate = Color.WHITE
		$Label.add_theme_color_override("font_color", Color.GRAY)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and enabled:
			GameFeedback.play_click_button()
			orchestrator.accept_touch_placement()


func _on_mouse_entered() -> void:
	if enabled:
		$background.self_modulate = COLOR_BROWN
		$Label.add_theme_color_override("font_color", Color.WHITE)
		is_hovered = true


func _on_mouse_exited() -> void:
	if enabled:
		$background.self_modulate = Color.WHITE
		$Label.add_theme_color_override("font_color", COLOR_BROWN)
		is_hovered = false
