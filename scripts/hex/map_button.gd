extends Node3D
class_name MapButton

const IDLE_COLOR := Color(0.95686275, 0.8745098, 0.7921569, 0.42)
const HOVER_COLOR := Color(0.9411765, 0.55, 0.28, 0.72)

var hex_manager: HexManager
var my_coord: Vector2i

var _shared_material: StandardMaterial3D
var _hover_count: int = 0


## ----- Initialisation ----- ##

func init(
	manager: HexManager,
	origin: Vector2i,
	new_coords: Array[Vector2i],
	hex_size: float
) -> void:
	hex_manager = manager
	my_coord = origin
	_shared_material = StandardMaterial3D.new()
	_shared_material.albedo_color = IDLE_COLOR
	_shared_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shared_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shared_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for coord in new_coords:
		_create_ghost_hex(coord, hex_size)


func _create_ghost_hex(coord: Vector2i, hex_size: float) -> void:
	var body := StaticBody3D.new()
	body.position = HexCoord.axial_to_world(coord, hex_size)
	body.input_ray_pickable = true
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var r := hex_size
	var h := hex_size * 0.85
	shape.points = PackedVector3Array([
		Vector3(0, h, 0),
		Vector3(r, h, 0),
		Vector3(r * 0.5, h, r * 0.866),
		Vector3(-r * 0.5, h, r * 0.866),
		Vector3(-r, h, 0),
		Vector3(-r * 0.5, h, -r * 0.866),
		Vector3(r * 0.5, h, -r * 0.866),
		Vector3(0, 0, 0),
		Vector3(r, 0, 0),
		Vector3(r * 0.5, 0, r * 0.866),
		Vector3(-r * 0.5, 0, r * 0.866),
		Vector3(-r, 0, 0),
		Vector3(-r * 0.5, 0, -r * 0.866),
		Vector3(r * 0.5, 0, -r * 0.866),
	])
	collision.shape = shape
	body.add_child(collision)

	var mesh_instance := MeshInstance3D.new()
	# Flat-top hex orientation to match axial_to_world layout.
	mesh_instance.rotation_degrees.y = 30.0
	mesh_instance.position.y = hex_size * 0.05
	mesh_instance.material_override = _shared_material
	var mesh := CylinderMesh.new()
	mesh.top_radius = hex_size
	mesh.bottom_radius = hex_size
	mesh.height = hex_size * 0.1
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	body.mouse_entered.connect(_on_mouse_entered)
	body.mouse_exited.connect(_on_mouse_exited)
	body.input_event.connect(_on_input_event)


## ----- Interactions Logic ----- ##

func _on_input_event(
	_camera: Node,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if not InputScheme.is_left_click(event):
		return
	if UiPointerBlock.is_blocked():
		return
	GameFeedback.play_click_button()
	hex_manager.handle_map_button_click(my_coord)


func _on_mouse_entered() -> void:
	if UiPointerBlock.is_blocked():
		return
	_hover_count += 1
	if _hover_count == 1:
		GameFeedback.play_hover_button()
		_set_highlight(true)


func _on_mouse_exited() -> void:
	_hover_count = maxi(_hover_count - 1, 0)
	if _hover_count == 0:
		_set_highlight(false)


func clear_hover_for_ui() -> void:
	_hover_count = 0
	_set_highlight(false)


func _set_highlight(hovered: bool) -> void:
	_shared_material.albedo_color = HOVER_COLOR if hovered else IDLE_COLOR


## ----- Utility Logic ----- ##

func remove_button() -> void:
	queue_free()
