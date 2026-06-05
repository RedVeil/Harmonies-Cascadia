extends Area2D
class_name CardRecycling

@export var orchestrator : Orchestrator
@export var recycling_value : int = 2

var is_hovered : bool = false
var timer : float = 0.5

## ----- Interactions Logic ----- ##

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			orchestrator.apply_recycle_card(-1, recycling_value, false)

func _on_mouse_entered() -> void:
	$background.self_modulate = Color.html("#918478")
	$icon.self_modulate = Color.WHITE
	orchestrator.preview_recycle_card(-1, recycling_value, false)
	is_hovered = true
	timer = 0.5

func _on_mouse_exited() -> void:
	$background.self_modulate = Color.WHITE
	$icon.self_modulate = Color.html("#918478")
	orchestrator.reset_recycle_card_preview()
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()

## ----- Tooltip Logic ----- ##

func _process(delta:float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()
