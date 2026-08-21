extends Area2D
class_name UndoButton

@export var orchestrator : Orchestrator

var enabled : bool = false

## ----- Initialisation ----- ##

func _ready() -> void:
	$icon.self_modulate = Color.GRAY

## ----- State Logic ----- ##

func enable() -> void:
	enabled = true
	
	$background.self_modulate = Color.WHITE
	$icon.self_modulate = Color.html("#918478")

func disable() -> void:
	enabled = false
	
	$background.self_modulate = Color.WHITE
	$icon.self_modulate = Color.GRAY


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
		$background.self_modulate = Color.html("#918478")
		$icon.self_modulate = Color.WHITE

func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	if enabled:
		$background.self_modulate = Color.WHITE
		$icon.self_modulate = Color.html("#918478")
