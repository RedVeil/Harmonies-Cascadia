class_name HexGrid
extends RefCounted

var ring_count: int
var tile_size: float
var origin: Vector2
var coords: Array[Vector2i] = []
var coord_set := {}

func _init(p_ring_count: int = 5, p_tile_size: float = 42.0, p_origin: Vector2 = Vector2.ZERO):
	ring_count = p_ring_count
	tile_size = p_tile_size
	origin = p_origin
	_generate()

func _generate() -> void:
	coords.clear()
	coord_set.clear()
	for q in range(-ring_count, ring_count + 1):
		for r in range(-ring_count, ring_count + 1):
			var c := Vector2i(q, r)
			if HexCoord.distance(Vector2i.ZERO, c) <= ring_count:
				coords.append(c)
				coord_set[c] = true

func has_coord(c: Vector2i) -> bool:
	return coord_set.has(c)

func neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for n in HexCoord.neighbors(c):
		if has_coord(n):
			out.append(n)
	return out

func axial_to_world(c: Vector2i) -> Vector2:
	var x := tile_size * (sqrt(3.0) * c.x + sqrt(3.0) / 2.0 * c.y)
	var y := tile_size * (1.5 * c.y)
	return origin + Vector2(x, y)

func world_to_axial(pos: Vector2) -> Vector2i:
	var p := pos - origin
	var qf := (sqrt(3.0) / 3.0 * p.x - 1.0 / 3.0 * p.y) / tile_size
	var rf := (2.0 / 3.0 * p.y) / tile_size
	return _hex_round(qf, rf)

func _hex_round(qf: float, rf: float) -> Vector2i:
	var sf: float = -qf - rf
	var q := roundi(qf)
	var r := roundi(rf)
	var s := roundi(sf)

	var q_diff: float = absf(float(q) - qf)
	var r_diff: float = absf(float(r) - rf)
	var s_diff: float = absf(float(s) - sf)

	if q_diff > r_diff and q_diff > s_diff:
		q = -r - s
	elif r_diff > s_diff:
		r = -q - s

	return Vector2i(q, r)
