class_name TileScatterLayer
extends Resource

@export_group("Meshes")
@export var mesh_scenes: Array[PackedScene] = []
@export var mesh_count_range: Vector2i = Vector2i(3, 8)
@export_range(0.0, 1.0, 0.01) var hex_radius_inset: float = 0.15
@export var offset: Vector3 = Vector3.ZERO

@export_group("Transform")
@export var scale: Vector2 = Vector2.ONE
@export var rotation_y_range: Vector2 = Vector2(0.0, 360.0)

@export_group("Material")
@export var materials: Array[Material] = []

@export_group("Placement")
@export var use_jittered_grid: bool = false
@export var register_exclusions: bool = true

@export_group("Rendering")
@export var cast_shadow: bool = true
