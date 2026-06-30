class_name RiverPreviewLogic
extends RefCounted

const BASE_Y_ROTATION := 30.0

static func apply_to_visual_state(
	state: TileLayersState,
	coord: Vector2i,
	river_neighbor_coords: Array[int]
) -> void:
	var scene_path := ""
	var rotation_steps := 0

	match river_neighbor_coords.size():
		0:
			scene_path = "M"
		1:
			scene_path = "A"
		2:
			if river_neighbor_coords[1] - river_neighbor_coords[0] == 3:
				scene_path = "B"
			else:
				if river_neighbor_coords[1] - river_neighbor_coords[0] == 1:
					scene_path = "C"
				else:
					scene_path = "D"
			rotation_steps = river_neighbor_coords[0]
		3:
			if river_neighbor_coords[2] - river_neighbor_coords[0] == 3:
				if river_neighbor_coords[1] - river_neighbor_coords[0] == 1:
					scene_path = "E"
				else: scene_path = "F"
				rotation_steps = river_neighbor_coords[0]
			else:
				if river_neighbor_coords[2] - river_neighbor_coords[0] == 2:
					scene_path = "G"
					rotation_steps = river_neighbor_coords[0] + 1
				else:
					scene_path = "I"
					rotation_steps = river_neighbor_coords[0]
		4:
			if river_neighbor_coords[2] - river_neighbor_coords[0] == 2:
				if river_neighbor_coords[3] - river_neighbor_coords[2] == 1:
					scene_path = "K"
				else:
					scene_path = "I"
			else:
				scene_path = "J"
			rotation_steps = river_neighbor_coords[0]
		5:
			scene_path = "L"
		6:
			scene_path = "M"
		_:
			scene_path = "M"
	
	return TileLayersState.create([""], [])
