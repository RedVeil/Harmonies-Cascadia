class_name RiverTileLogic
extends RefCounted

const FLAT_TOP_YAW_OFFSET := 30.0

const TEMPLATE_ISOLATED: Array[int] = []
const TEMPLATE_END: Array[int] = [0]
const TEMPLATE_STRAIGHT: Array[int] = [0, 3]
const TEMPLATE_BEND_TIGHT: Array[int] = [0, 1]
const TEMPLATE_BEND_OPEN: Array[int] = [0, 2]
## tri_bend1.png stem points south (dir 4) with arms at dirs 3 and 5.
const TEMPLATE_T_JUNCTION: Array[int] = [3, 4, 5]
const TEMPLATE_CROSS: Array[int] = [0, 1, 3, 4]


static func directions_from_mask(neighbor_mask: int) -> Array[int]:
	var directions: Array[int] = []
	for direction_index in HexCoord.DIRECTIONS.size():
		if neighbor_mask & (1 << direction_index):
			directions.append(direction_index)
	return directions


static func resolve(river_pieces: TileRiverPieces, neighbor_directions: Array[int]) -> Dictionary:
	if river_pieces == null:
		return {}

	var sorted_directions := neighbor_directions.duplicate()
	sorted_directions.sort()
	var count := sorted_directions.size()

	if count == 0:
		return _make_result(
			river_pieces.isolated,
			river_pieces.isolated_rotation_offset
		)

	if count == 1:
		return _make_result(
			river_pieces.end_cap,
			_match_rotation(TEMPLATE_END, sorted_directions) + river_pieces.end_cap_rotation_offset
		)

	if count == 2:
		if _are_opposite(sorted_directions[0], sorted_directions[1]):
			return _make_result(
				river_pieces.straight,
				_match_rotation(TEMPLATE_STRAIGHT, sorted_directions) + river_pieces.straight_rotation_offset
			)
		if _is_tight_bend(sorted_directions[0], sorted_directions[1]):
			return _make_result(
				river_pieces.bend,
				_match_rotation(TEMPLATE_BEND_TIGHT, sorted_directions) + river_pieces.bend_rotation_offset
			)
		return _make_result(
			river_pieces.bend_open,
			_match_rotation(TEMPLATE_BEND_OPEN, sorted_directions) + river_pieces.bend_open_rotation_offset
		)

	if count == 3:
		var rotation_step := _match_rotation_step(TEMPLATE_T_JUNCTION, sorted_directions)
		return _make_result(
			river_pieces.t_junction,
			float(rotation_step) * 60.0 + river_pieces.t_junction_rotation_offset
		)

	return _make_result(
		river_pieces.cross,
		_match_rotation(TEMPLATE_CROSS, sorted_directions) + river_pieces.cross_rotation_offset
	)


static func _make_result(scene: PackedScene, rotation_y_degrees: float) -> Dictionary:
	if scene == null:
		return {}
	return {
		"scene": scene,
		"rotation_y_degrees": rotation_y_degrees,
	}


static func _are_opposite(a: int, b: int) -> bool:
	return posmod(a - b, 6) == 3


static func _is_tight_bend(a: int, b: int) -> bool:
	return mini(posmod(a - b, 6), posmod(b - a, 6)) == 1


static func _match_rotation_step(template_directions: Array[int], actual_directions: Array[int]) -> int:
	for rotation_step in HexCoord.DIRECTIONS.size():
		var rotated: Array[int] = []
		for direction_index in template_directions:
			rotated.append((direction_index + rotation_step) % HexCoord.DIRECTIONS.size())
		rotated.sort()
		if rotated == actual_directions:
			return rotation_step
	return actual_directions[0]


static func _match_rotation(template_directions: Array[int], actual_directions: Array[int]) -> float:
	return direction_to_yaw_degrees(_match_rotation_step(template_directions, actual_directions))


static func direction_to_yaw_degrees(direction_index: int) -> float:
	return HexCoord.direction_to_yaw_degrees(direction_index) + FLAT_TOP_YAW_OFFSET
