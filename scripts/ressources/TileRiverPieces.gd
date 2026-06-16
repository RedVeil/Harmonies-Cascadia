class_name TileRiverPieces
extends Resource

@export_group("Pieces")
@export var isolated: PackedScene
@export var end_cap: PackedScene
@export var straight: PackedScene
@export var bend: PackedScene
@export var bend_open: PackedScene
@export var t_junction: PackedScene
@export var cross: PackedScene

@export_group("Placement")
@export var offset: Vector3 = Vector3.ZERO
@export var scale: Vector3 = Vector3.ONE
## Aligns pieces with the Ground mesh yaw baked into tile_default.tscn.
@export var base_rotation_offset: float = 30.0
## Mask art uses vertical connections; river templates assume direction 0 is +X.
@export var art_rotation_offset: float = 0.0
## Optional override for all river piece meshes. Leave empty to use each scene's material.
@export var material: Material

@export_group("Rotation Offsets")
@export var isolated_rotation_offset: float = 0.0
@export var end_cap_rotation_offset: float = 0.0
@export var straight_rotation_offset: float = 0.0
@export var bend_rotation_offset: float = 0.0
@export var bend_open_rotation_offset: float = 0.0
@export var t_junction_rotation_offset: float = 0.0
@export var cross_rotation_offset: float = 0.0
