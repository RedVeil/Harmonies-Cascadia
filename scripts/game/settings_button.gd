extends Area2D
class_name SettingsButton

@export var settings_overlay: SettingsOverlay

var is_hovered: bool = false


func _ready() -> void:
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	UiTheme.bind_node(self, _apply_theme)
	_apply_theme()


func _apply_theme() -> void:
	UiTheme.apply_hud_circle($background, $icon, is_hovered)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not InputScheme.is_left_click(event):
		return
	GameFeedback.play_click_button()
	if settings_overlay != null:
		settings_overlay.open()


func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	GameFeedback.play_hover_button()
	is_hovered = true
	_apply_theme()


func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	is_hovered = false
	_apply_theme()
