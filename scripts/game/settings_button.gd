extends Area2D
class_name SettingsButton

@export var settings_overlay: SettingsOverlay

var is_hovered: bool = false


func _ready() -> void:
	$icon.self_modulate = Color.html("#918478")
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not InputScheme.is_left_click(event):
		return
	GameFeedback.play_click_button()
	if settings_overlay != null:
		settings_overlay.open()


func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	GameFeedback.play_hover_button()
	$background.self_modulate = Color.html("#918478")
	$icon.self_modulate = Color.WHITE
	is_hovered = true


func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	$background.self_modulate = Color.WHITE
	$icon.self_modulate = Color.html("#918478")
	is_hovered = false
