extends Area2D
class_name UndoButton

@export var orchestrator : Orchestrator

var enabled : bool = false
var is_hovered : bool = false
var timer : float = 0.5

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
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()

## ----- Interactions Logic ----- ##

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and enabled:
			orchestrator.undo()

func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	if enabled:
		GameFeedback.play_hover_button()
		$background.self_modulate = Color.html("#918478")
		$icon.self_modulate = Color.WHITE
		is_hovered = true
		timer = 0.5

func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	if enabled:
		$background.self_modulate = Color.WHITE
		$icon.self_modulate = Color.html("#918478")
		is_hovered = false
		timer = 0.5
		$Tooltip.hide()

## ----- Tooltip Logic ----- ##

func _process(delta:float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()
