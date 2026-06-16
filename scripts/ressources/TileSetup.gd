class_name TileSetup
extends Resource

@export var scatter_layers: Array[TileScatterLayer] = []
@export var ground_material: Material
@export var exclusion_padding: float = 0.15

@export_group("Center")
@export var center_features: Array[TileCenterFeature] = []
@export var pick_random_center_feature: bool = true

@export_group("River")
@export var river_pieces: TileRiverPieces
