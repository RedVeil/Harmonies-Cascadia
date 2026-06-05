class_name TileStatePreview
extends Resource

var is_valid:bool = false
var coord: Vector2i = Vector2i.ZERO
var tile_data:HexTileData
var points_diff: int = 0
var contributing_coords: Array[Vector2i] = []

## ----- Initialisation ----- ##

func _init(initial_data: Dictionary = {}) -> void:
	is_valid = initial_data.is_valid
	coord = initial_data.coord
	tile_data = initial_data.tile_data
	points_diff = initial_data.points_diff
	contributing_coords.assign(initial_data.contributing_coords) 
