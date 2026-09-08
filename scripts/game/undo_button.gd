extends Area2D
class_name UndoButton

@export var orchestrator : Orchestrator

var enabled : bool = false
var is_hovered: bool = false

## ----- Initialisation ----- ##

func _ready() -> void:
	UiTheme.bind_node(self, _apply_theme)
	_apply_theme()

## ----- State Logic ----- ##

func enable() -> void:
	enabled = true
	_apply_theme()

func disable() -> void:
	enabled = false
	is_hovered = false
	_apply_theme()


func _apply_theme() -> void:
	UiTheme.apply_hud_circle($background, $icon, is_hovered, enabled)


func set_focus_hover(on: bool) -> void:
	if on:
		_on_mouse_entered()
	else:
		_on_mouse_exited()

## ----- Interactions Logic ----- ##

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if not InputScheme.is_left_click(event) or not enabled:
		return
	orchestrator.undo()

func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	if enabled:
		GameFeedback.play_hover_button()
		is_hovered = true
		_apply_theme()

func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	is_hovered = false
	if enabled:
		_apply_theme()
