extends Node3D
class_name MenuDiorama

const TILE_VISUALS_SCENE := preload("res://scenes/hex/tile_visuals.tscn")
const RING_COUNT := 2
const HEX_SIZE := 11.0
const ANIMAL_MIN := 4
const ANIMAL_MAX := 8

var _rng := RandomNumberGenerator.new()
var _setups: Array[Dictionary] = []
var _tiles: Dictionary = {}
var _visuals: Array[TileVisuals] = []
var _right_column: Control
var _board_ready: bool = false


func _ready() -> void:
	_rng.randomize()
	_cache_setups()
	_build_board()
	_apply_animal_motion()
	if not GameSettings.settings_changed.is_connected(_apply_animal_motion):
		GameSettings.settings_changed.connect(_apply_animal_motion)
	var board := $Board as Node3D
	if board != null:
		board.visible = false
	_bind_available_space()
	set_process(true)


func _exit_tree() -> void:
	if GameSettings.settings_changed.is_connected(_apply_animal_motion):
		GameSettings.settings_changed.disconnect(_apply_animal_motion)
	_unbind_available_space()


func _process(_delta: float) -> void:
	_center_board_in_available_space()
	if _board_ready:
		set_process(false)


func _cache_setups() -> void:
	_setups.clear()
	for spec in TileSetupCatalog.iter_setup_keys():
		var element := int(spec.get("element", -1))
		var level := int(spec.get("level", -1))
		if element <= int(GameEnums.ELEMENT.NONE) or level < 0:
			continue
		_setups.append({"element": element, "level": level})


func _pick_setup() -> Dictionary:
	if _setups.is_empty():
		return {
			"element": int(GameEnums.ELEMENT.FOREST),
			"level": int(GameEnums.LEVEL.SMALL),
		}
	return _setups[_rng.randi_range(0, _setups.size() - 1)]


func _build_board() -> void:
	_assign_tiles()
	_assign_animals()
	_spawn_visuals()
	call_deferred("_disable_picking", self)


func _assign_tiles() -> void:
	_tiles.clear()
	var origin := Vector2i.ZERO
	for q in range(-RING_COUNT, RING_COUNT + 1):
		for r in range(-RING_COUNT, RING_COUNT + 1):
			var coord := origin + Vector2i(q, r)
			if HexCoord.distance(origin, coord) > RING_COUNT:
				continue
			var setup := _pick_setup()
			_tiles[coord] = {
				"element": int(setup["element"]),
				"level": int(setup["level"]),
				"animal_id": -1,
				"animal_amount": 0,
			}


func _assign_animals() -> void:
	var coords: Array[Vector2i] = []
	for key in _tiles:
		coords.append(key)
	for i in range(coords.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := coords[i]
		coords[i] = coords[j]
		coords[j] = tmp
	var target := _rng.randi_range(ANIMAL_MIN, ANIMAL_MAX)
	var placed := 0
	for coord in coords:
		if placed >= target:
			break
		var spec: Dictionary = _tiles[coord]
		var animal := _pick_animal_for_element(int(spec["element"]))
		if animal == null:
			continue
		spec["animal_id"] = animal.id
		spec["animal_amount"] = maxi(1, animal.visual_amount)
		placed += 1


func _pick_animal_for_element(element: int) -> CardData:
	var candidates: Array[CardData] = []
	for animal in CardCatalog.animals:
		if animal == null or animal.models.is_empty():
			continue
		if int(animal.element) != element:
			continue
		candidates.append(animal)
	if candidates.is_empty():
		return null
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _spawn_visuals() -> void:
	var board := $Board as Node3D
	for key in _tiles:
		var coord: Vector2i = key
		var spec: Dictionary = _tiles[coord]
		var wrapper := Node3D.new()
		wrapper.name = "Tile_%d_%d" % [coord.x, coord.y]
		wrapper.position = HexCoord.axial_to_world(coord, HEX_SIZE)
		board.add_child(wrapper)

		var river_index := -1
		var orientation_steps := 0
		if int(spec["element"]) == GameEnums.ELEMENT.RIVER:
			var river_data := RiverPreviewLogic.get_river_index_and_rotation(
				coord,
				_river_neighbors(coord)
			)
			orientation_steps = river_data.x
			river_index = river_data.y
		else:
			orientation_steps = HexCoord.pick_orientation_steps(coord)
		wrapper.rotation_degrees.y = HexCoord.direction_to_yaw_degrees(orientation_steps)

		var visuals := TILE_VISUALS_SCENE.instantiate() as TileVisuals
		wrapper.add_child(visuals)
		visuals.apply(
			int(spec["element"]),
			int(spec["level"]),
			coord,
			int(spec["animal_id"]),
			int(spec["animal_amount"]),
			[],
			river_index,
			true,
			false
		)
		visuals.ensure_active_layers_visible()
		_disable_picking(wrapper)
		_visuals.append(visuals)


func _river_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for neighbor in HexCoord.neighbors(coord):
		if not _tiles.has(neighbor):
			continue
		if int(_tiles[neighbor]["element"]) == GameEnums.ELEMENT.RIVER:
			neighbors.append(neighbor)
	return neighbors


func _disable_picking(node: Node) -> void:
	if node is CollisionObject3D:
		(node as CollisionObject3D).input_ray_pickable = false
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_picking(child)


func _bind_available_space() -> void:
	var vp := get_viewport()
	if vp != null and not vp.size_changed.is_connected(_on_available_space_changed):
		vp.size_changed.connect(_on_available_space_changed)
	_cache_right_column()


func _unbind_available_space() -> void:
	var vp := get_viewport()
	if vp != null and vp.size_changed.is_connected(_on_available_space_changed):
		vp.size_changed.disconnect(_on_available_space_changed)
	if _right_column != null and is_instance_valid(_right_column):
		if _right_column.resized.is_connected(_on_available_space_changed):
			_right_column.resized.disconnect(_on_available_space_changed)
	_right_column = null


func _on_available_space_changed() -> void:
	call_deferred("_center_board_in_available_space")


func _cache_right_column() -> void:
	var found: Control = null
	var host := get_parent()
	if host != null:
		found = host.find_child("RightColumn", true, false) as Control
	if found == null:
		var scene := get_tree().current_scene
		if scene != null:
			found = scene.find_child("RightColumn", true, false) as Control
	if found == _right_column:
		return
	if _right_column != null and is_instance_valid(_right_column):
		if _right_column.resized.is_connected(_on_available_space_changed):
			_right_column.resized.disconnect(_on_available_space_changed)
	_right_column = found
	if _right_column != null and not _right_column.resized.is_connected(_on_available_space_changed):
		_right_column.resized.connect(_on_available_space_changed)


func _target_canvas_center() -> Vector2:
	if _right_column == null or not is_instance_valid(_right_column):
		_cache_right_column()
	if (
		_right_column != null
		and _right_column.is_visible_in_tree()
		and _right_column.size.x > 1.0
		and _right_column.size.y > 1.0
	):
		return _right_column.get_global_rect().get_center()
	return Vector2.ZERO


func _board_ground_centroid(board: Node3D) -> Vector3:
	var acc := Vector3.ZERO
	var count := 0
	for child in board.get_children():
		var node := child as Node3D
		if node == null:
			continue
		acc += node.global_position
		count += 1
	if count <= 0:
		var origin := board.global_position
		origin.y = 0.0
		return origin
	var centroid := acc / float(count)
	centroid.y = 0.0
	return centroid


func _center_board_in_available_space() -> void:
	var camera := $Camera3D as Camera3D
	var board := $Board as Node3D
	if camera == null or board == null or not is_inside_tree():
		return
	var target := _target_canvas_center()
	if target == Vector2.ZERO:
		return
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(target),
		camera.project_ray_normal(target)
	)
	if hit == null:
		return
	var centroid := _board_ground_centroid(board)
	var offset: Vector3 = hit - centroid
	offset.y = 0.0
	if offset.length_squared() > 0.0001:
		board.global_position += offset
	board.visible = true
	_board_ready = true


func _apply_animal_motion() -> void:
	var frozen := GameSettings.animal_motion == GameSettings.AnimalMotion.FROZEN
	for visuals in _visuals:
		if not is_instance_valid(visuals):
			continue
		if frozen:
			visuals.freeze_animals()
		else:
			visuals.start_animal_idle_loop()
