class_name HexCoord
extends RefCounted

## ----- Directions ----- ##

static var DIRECTIONS : Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1)
]

static var MAP_DIRECTIONS : Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(2, -1),
	Vector2i(1, -2),
	Vector2i(-1, -1),
	Vector2i(-2, 1),
	Vector2i(-1, 2)
] 

## ----- Neighbour Logic ----- ##

static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in DIRECTIONS:
		out.append(c + dir)
	return out

static func map_neighbors(c: Vector2i, distance:int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in MAP_DIRECTIONS:
		out.append(c + (dir*distance))
	return out

## ----- Distance Logic ----- ##

static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := (-a.x - a.y) - (-b.x - b.y)
	return int((abs(dq) + abs(dr) + abs(ds)) / 2)

## ----- Coordinate Conversion ----- ##

static func axial_to_world(coord: Vector2i, hex_size: float) -> Vector3:
	var q := coord.x
	var r := coord.y

	# Flat-top version
	var x := hex_size * 1.5 * float(q)
	var z := hex_size * sqrt(3.0) * (float(r) + float(q) / 2.0)

	return Vector3(x, 0.0, z)

static func axial_to_world_pointy(coord: Vector2i, hex_size: float) -> Vector3:
	var q := coord.x
	var r := coord.y

	var x := hex_size * sqrt(3.0) * (float(q) + float(r) / 2.0)
	var z := hex_size * 1.5 * float(r)

	return Vector3(x, 0.0, z)
	
## ----- Transform Logic ----- ##

static func rotate_clockwise(point: Vector2i, center: Vector2i) -> Vector2i:
	var q := point.x - center.x
	var r := point.y - center.y

	return center + Vector2i(q + r, -q)

static func mirror(point: Vector2i, center: Vector2i) -> Vector2i:
	var q := point.x - center.x
	var r := point.y - center.y

	# mirror across one hex axis
	var mirrored := Vector2i(q + r, -r)

	return center + mirrored
