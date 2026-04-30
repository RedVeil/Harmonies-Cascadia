class_name HexCoord
extends RefCounted

static var DIRECTIONS := [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1)
]

static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dir in DIRECTIONS:
		out.append(c + dir)
	return out

static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq := a.x - b.x
	var dr := a.y - b.y
	var ds := (-a.x - a.y) - (-b.x - b.y)
	return int((abs(dq) + abs(dr) + abs(ds)) / 2)
