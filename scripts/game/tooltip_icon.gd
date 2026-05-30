extends Sprite2D
class_name TooltipIcon

@export var icon : Texture2D 

var container : ScoringTooltip
var id: int = -1

func _ready() -> void:
	$Sprite2D.texture = icon

func init(idx:int, parent: ScoringTooltip) -> void:
	id = idx
	container = parent

func _on_area_2d_mouse_entered() -> void:
	self.self_modulate = Color.html("#918478")
	$Sprite2D.self_modulate = Color.html("#f4dfca")

func _on_area_2d_mouse_exited() -> void:
	self.self_modulate = Color.html("#f4dfca")
	$Sprite2D.self_modulate = Color.html("#918478")

func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			container.handle_click_toolip(id)
