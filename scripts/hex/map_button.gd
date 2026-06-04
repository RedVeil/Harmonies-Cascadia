extends StaticBody3D
class_name MapButton

@onready var mesh : MeshInstance3D = $MeshInstance3D/MeshInstance3D

var hex_manager: HexManager
var my_coord:Vector2i

func _ready() -> void:
	input_ray_pickable = true
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	mesh.material_override = mesh.mesh.material.duplicate()

func init(container:HexManager, coord:Vector2i,) -> void:
	hex_manager = container
	my_coord = coord
	
func remove_button() -> void:
	queue_free()

func _on_input_event(camera: Node, event: InputEvent, event_position: Vector3, normal: Vector3, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			GameFeedback.play_click_button()
			hex_manager.handle_map_button_click(my_coord)

func _on_mouse_entered() -> void:
	mesh.material_override.albedo_color = Color.html("#bb281e")

func _on_mouse_exited() -> void:
	mesh.material_override.albedo_color = Color.html("#f04738")
