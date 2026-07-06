class_name RiverPreviewLogic
extends RefCounted

const BASE_Y_ROTATION := 30.0

static func get_river_index_and_rotation(
	coord: Vector2i,
	river_neighbor_coords: Array[Vector2i]
) -> Vector2i:
	var river_index := 0
	var rotation_steps := 0

	var directions: Array[int] = []
	for neighbor in river_neighbor_coords:
		var direction = HexCoord.DIRECTIONS.find_custom(func(direction: Vector2i) -> bool: return direction == (neighbor - coord))
		if direction == 0:
			direction = 6
		directions.append(direction)
	
	directions.sort()
	match directions.size():
		0:
			river_index = 12
		1:
			river_index = 0
			rotation_steps = directions[0] - 1
		2:
			if directions[1] - directions[0] == 3:
				river_index = 1
				rotation_steps = directions[0] - 1
			else:
				if directions[1] - directions[0] == 1:
					river_index = 2
					rotation_steps = directions[0]
				else:
					river_index = 3
					if directions[1] - directions[0] > 2:
						rotation_steps = directions[0] - 1
					else:
						rotation_steps = directions[0] + 1
		3:
			if directions == [1,3,5] || directions == [2,4,6]:
				river_index = 6
				rotation_steps = directions[0] - 1
			elif directions == [1,2,6] || directions == [1,5,6] || directions[2] - directions[0] == 2:
				river_index = 7
				if directions == [1,2,6]:
					rotation_steps = 1 
				elif directions == [1,5,6]:
					rotation_steps = 0
				else:
					rotation_steps = directions[0] + 1
			else:
				if directions == [2,3,5] || directions == [3,4,6] || directions == [1,4,5] || directions == [2,5,6] || directions == [1,3,6] || directions == [1,2,4]:
					river_index = 5
					if directions == [1,3,6]:
						rotation_steps = 5
					elif directions == [1,4,5]:
						rotation_steps = 3
					elif directions == [2,5,6]:
						rotation_steps = 4
					else:
						rotation_steps = directions[0] - 1 
				else:
					river_index = 4
					if directions == [2,3,6]:
						rotation_steps = 2
					elif directions == [1,2,5]:
						rotation_steps = 1
					elif directions == [1,4,6]:
						rotation_steps = 6
					else:
						rotation_steps = directions[1]
		4:
			match directions:
				[1,2,3,5]:
					river_index = 8
					rotation_steps = 2
				[2,3,4,6]:
					river_index = 8
					rotation_steps = 3
				[1,3,4,5]:
					river_index = 8
					rotation_steps = 4
				[1,2,4,6]:
					river_index = 8
					rotation_steps = 1
				[2,4,5,6]:
					river_index = 8
					rotation_steps = 5
				[1,3,5,6]:
					river_index = 8
					rotation_steps = 0
				[2,3,5,6]:
					river_index = 9
					rotation_steps = 5
				[1,2,4,5]:
					river_index = 9
					rotation_steps = 1
				[1,2,5,6]:
					river_index = 10
					rotation_steps = 1
				[1,4,5,6]:
					river_index = 10
					rotation_steps = 0
				[3,4,5,6]:
					river_index = 10
					rotation_steps = 5
				[2,3,4,5]:
					river_index = 10
					rotation_steps = 4
		5:
			river_index = 11
			for i in range(7).size():
				if i != 0 && !directions.has(i):
					rotation_steps = i-1
		6:
			river_index = 12
		_:
			river_index = 12
	if rotation_steps <= 0:
		rotation_steps = 6 - rotation_steps
	elif rotation_steps > 6:
		rotation_steps = rotation_steps - 6
	
	return Vector2i(rotation_steps, river_index)
