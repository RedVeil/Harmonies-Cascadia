extends StaticBody3D
class_name HexTile

var container : HexTileContainer
var coord : Vector2i
var visuals : HexTileVisuals

## ----- Initialisation ----- ##

func _ready() -> void:
	input_ray_pickable = true
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	var original_mat := $visuals/StylizedHexTile.material_override as StandardMaterial3D
	$visuals/StylizedHexTile.material_override = original_mat.duplicate()
	
	var new_visuals = HexTileVisuals.new()
	new_visuals.color = Color.html(ElementCatalog.elements[0].levels[0].color)
	new_visuals.icon = load(ElementCatalog.elements[0].levels[0].icon)
	update_visuals(new_visuals)

func init(parent:HexTileContainer, location:Vector2i) -> void:
	container = parent
	coord = location

## ----- Interaction Logic ----- ##

func _on_mouse_entered() -> void:
	container.handle_hover(coord)
	$visuals/StylizedHexTile.material_override.albedo_color = visuals.color.lightened(0.5)
	
func _on_mouse_exited() -> void:
	container.handle_exit(coord)
	$visuals/StylizedHexTile.material_override.albedo_color = visuals.color

func _on_input_event(
	camera: Camera3D,
	event: InputEvent,
	event_position: Vector3,
	normal: Vector3,
	shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			container.handle_click(coord)

## ----- Update Visuals ----- ##

func update_visuals(new_visuals:HexTileVisuals) -> void:
	visuals = new_visuals
	$visuals/StylizedHexTile.material_override.albedo_color = new_visuals.color
	$visuals/StylizedHexTile/elementIcon.texture = new_visuals.icon
	
	if new_visuals.animal_icon:
		$visuals/StylizedHexTile/elementIcon/animalIcon.texture = new_visuals.animal_icon
	else:
		$visuals/StylizedHexTile/elementIcon/animalIcon.texture = null

## ----- Points Logic ----- ##

func show_points(points:int) -> void:
	$visuals/Label3D.text = "%d" % points
	$visuals/Label3D.show()

func hide_points() -> void:
	$visuals/Label3D.hide()

## ----- Outline Logic ----- ##

func show_outline(color:Color) -> void:
	$visuals/MeshInstance3D/outline.modulate = color
	$visuals/MeshInstance3D/outline.show()
	
func hide_outline() -> void:
	$visuals/MeshInstance3D/outline.hide()
