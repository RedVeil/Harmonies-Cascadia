@tool
extends Node3D

const _LAYER_EXTRA_PREFIX := "_ScatterLayerExtra_"

@export_group("Editor Preview")
var _editor_setup: TileSetup
@export var editor_setup: TileSetup:
	get:
		return _editor_setup
	set(value):
		_editor_setup = value
		_queue_editor_setup_apply()

var _editor_river_neighbor_directions: Array[int] = []
@export var editor_river_neighbor_directions: Array[int] = []:
	get:
		return _editor_river_neighbor_directions
	set(value):
		_editor_river_neighbor_directions = value
		_queue_editor_setup_apply()

@export_tool_button("Apply Setup", "Reload") var _editor_apply_setup_action:
	get: return _apply_editor_setup

var _setup_scatter_layers: Array[TileScatterLayer] = []
var _setup_ground_material: Material
var _setup_center_features: Array[TileCenterFeature] = []
var _pick_random_center_feature: bool = true
var _setup_exclusion_padding: float = 0.15

var _hex_top: MeshInstance3D
var _ground: MeshInstance3D
var _center_features_root: Node3D

var _multimesh_slots: Array[MultiMeshInstance3D] = []
var _layer_extras: Dictionary = {}
var _scene_cache: Dictionary = {}
var _exclusion_zones: Array[Rect2] = []
var _active_setup_signature: String = ""


func _enter_tree() -> void:
	_cache_scene_nodes()
	if Engine.is_editor_hint():
		call_deferred("_apply_editor_setup")


func _ready() -> void:
	_cache_scene_nodes()
	_multimesh_slots = _gather_multimesh_slots()
	if Engine.is_editor_hint() and editor_setup != null:
		call_deferred("_apply_editor_setup")


func _cache_scene_nodes() -> void:
	if not is_inside_tree():
		return
	_ground = get_node_or_null("Ground") as MeshInstance3D
	_hex_top = get_node_or_null("HexTop") as MeshInstance3D
	_center_features_root = get_node_or_null("CenterFeatures") as Node3D


func _queue_editor_setup_apply() -> void:
	if not Engine.is_editor_hint():
		return
	call_deferred("_apply_editor_setup")


func _apply_editor_setup() -> void:
	if not Engine.is_editor_hint() or editor_setup == null:
		return
	if not is_inside_tree():
		return

	_cache_scene_nodes()
	if _ground == null or _hex_top == null:
		push_warning("Tile_Default: scene nodes not ready for editor preview.")
		return

	if _multimesh_slots.is_empty():
		_multimesh_slots = _gather_multimesh_slots()

	var context := {}
	if editor_setup.river_pieces != null:
		context["neighbor_directions"] = editor_river_neighbor_directions

	_active_setup_signature = ""
	var signature := "%s|editor|%s" % [
		editor_setup.resource_path,
		str(editor_river_neighbor_directions)
	]
	apply_setup(editor_setup, context, signature)


func apply_setup(setup: TileSetup, context: Dictionary = {}, setup_signature: String = "") -> void:
	if setup == null:
		return

	_cache_scene_nodes()
	if _ground == null or _hex_top == null:
		return

	if not setup_signature.is_empty() and setup_signature == _active_setup_signature:
		return

	_setup_scatter_layers = setup.scatter_layers
	_setup_exclusion_padding = setup.exclusion_padding
	_setup_ground_material = setup.ground_material

	if setup.river_pieces != null:
		var neighbor_directions: Array = context.get("neighbor_directions", [])
		_apply_river_ground_material(neighbor_directions)
		_apply_river_center_piece(setup, neighbor_directions)
	else:
		_setup_center_features = setup.center_features.duplicate()
		_pick_random_center_feature = setup.pick_random_center_feature
		_apply_ground_material()

	if not setup_signature.is_empty():
		_active_setup_signature = setup_signature

	scatter_meshes()


func _apply_ground_material() -> void:
	if _setup_ground_material != null:
		_ground.material_override = _setup_ground_material


func _apply_river_ground_material(neighbor_directions: Array) -> void:
	if _setup_ground_material == null:
		return

	var material := _setup_ground_material.duplicate()
	if material is ShaderMaterial:
		material.set_shader_parameter("modulate", Color(0.55, 0.72, 0.92, 1.0))
		material.set_shader_parameter("global_uv_offset", _river_flow_offset(neighbor_directions))

	_ground.material_override = material


func _apply_river_center_piece(setup: TileSetup, neighbor_directions: Array) -> void:
	if setup.river_pieces == null:
		return

	var resolved := RiverTileLogic.resolve(setup.river_pieces, neighbor_directions)
	if resolved.is_empty() or resolved["scene"] == null:
		return

	var feature := TileCenterFeature.new()
	feature.scene = resolved["scene"]
	feature.rotation_degrees.y = (
		resolved["rotation_y_degrees"]
		+ setup.river_pieces.base_rotation_offset
		+ setup.river_pieces.art_rotation_offset
	)
	feature.location = setup.river_pieces.offset
	feature.scale = setup.river_pieces.scale
	if setup.river_pieces.material != null:
		feature.material = setup.river_pieces.material
	_setup_center_features = [feature]


func _river_flow_offset(neighbor_directions: Array) -> Vector2:
	if neighbor_directions.is_empty():
		return Vector2(1.0, 2.0)

	var flow := Vector2.ZERO
	for direction_index in neighbor_directions:
		var yaw := deg_to_rad(HexCoord.direction_to_yaw_degrees(direction_index))
		flow += Vector2(cos(yaw), sin(yaw))

	if flow.is_zero_approx():
		return Vector2(1.0, 2.0)

	return flow.normalized() * 0.75


func scatter_meshes() -> void:
	_place_center_features()
	_multimesh_slots = _gather_multimesh_slots()
	_clear_all_layer_extras()

	for slot_index in _multimesh_slots.size():
		var slot: MultiMeshInstance3D = _multimesh_slots[slot_index]
		if slot_index >= _setup_scatter_layers.size() or _setup_scatter_layers[slot_index] == null:
			_clear_multimesh(slot)
			continue

		_scatter_layer(slot, _setup_scatter_layers[slot_index], slot_index)


func _scatter_layer(
	slot: MultiMeshInstance3D,
	layer: TileScatterLayer,
	layer_index: int
) -> void:
	if layer.mesh_scenes.is_empty():
		_clear_multimesh(slot)
		return

	var min_count := mini(layer.mesh_count_range.x, layer.mesh_count_range.y)
	var max_count := maxi(layer.mesh_count_range.x, layer.mesh_count_range.y)
	var instance_count := randi_range(min_count, max_count)

	var hex_radius := _get_hex_top_radius(layer.hex_radius_inset)
	var grid_points: Array[Vector2] = []
	if layer.use_jittered_grid:
		grid_points = _jittered_grid_points_in_flat_top_hex(
			hex_radius,
			instance_count,
			_exclusion_zones
		)

	var transforms_by_scene: Dictionary = {}
	for index in instance_count:
		var scene: PackedScene = layer.mesh_scenes.pick_random()
		if not transforms_by_scene.has(scene):
			transforms_by_scene[scene] = []

		var point: Variant = null
		if layer.use_jittered_grid:
			if index < grid_points.size():
				point = grid_points[index]
		else:
			point = _random_point_in_flat_top_hex(hex_radius, _exclusion_zones)

		if point == null:
			continue

		var instance_transform := _transform_from_hex_point(layer, slot, point)
		if instance_transform != null:
			transforms_by_scene[scene].append(instance_transform)

	if transforms_by_scene.is_empty():
		_clear_multimesh(slot)
		return

	var scene_entries: Array = transforms_by_scene.keys()
	_assign_multimesh(slot, layer, scene_entries[0], transforms_by_scene[scene_entries[0]])

	for scene_index in range(1, scene_entries.size()):
		var extra := slot.duplicate() as MultiMeshInstance3D
		extra.name = "%s%d_%d" % [_LAYER_EXTRA_PREFIX, layer_index, scene_index]
		slot.get_parent().add_child(extra)
		if not _layer_extras.has(layer_index):
			_layer_extras[layer_index] = []
		_layer_extras[layer_index].append(extra)
		_assign_multimesh(extra, layer, scene_entries[scene_index], transforms_by_scene[scene_entries[scene_index]])

	if layer.register_exclusions:
		_register_scatter_exclusions(slot, layer, transforms_by_scene)


func _assign_multimesh(
	target: MultiMeshInstance3D,
	layer: TileScatterLayer,
	scene: PackedScene,
	instance_transforms: Array
) -> void:
	var scene_data := _get_scene_data(scene)
	if scene_data.is_empty():
		_clear_multimesh(target)
		return

	var material_setup := _prepare_scatter_mesh(scene_data["mesh"], layer)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = material_setup["mesh"]
	multimesh.instance_count = instance_transforms.size()

	var mesh_offset: Transform3D = scene_data["mesh_transform"]
	var placement_offset := _layer_placement_offset(layer)
	for index in instance_transforms.size():
		multimesh.set_instance_transform(index, instance_transforms[index] * placement_offset * mesh_offset)

	target.multimesh = multimesh
	target.material_override = material_setup["material_override"]
	target.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if layer.cast_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	target.visible = instance_transforms.size() > 0


func _prepare_scatter_mesh(base_mesh: Mesh, layer: TileScatterLayer) -> Dictionary:
	var surface_count := base_mesh.get_surface_count()
	if layer.materials.is_empty():
		return {"mesh": base_mesh, "material_override": null}

	if surface_count == 1 and layer.materials[0] != null:
		return {"mesh": base_mesh, "material_override": layer.materials[0]}

	var mesh := base_mesh.duplicate() as Mesh
	for surface_index in layer.materials.size():
		if surface_index >= surface_count:
			break
		var material := layer.materials[surface_index]
		if material != null:
			mesh.surface_set_material(surface_index, material)

	return {"mesh": mesh, "material_override": null}


func _get_scene_data(scene: PackedScene) -> Dictionary:
	if _scene_cache.has(scene):
		return _scene_cache[scene]

	var root := scene.instantiate()
	var mesh_instance := _find_mesh_instance(root)
	if mesh_instance == null or mesh_instance.mesh == null:
		root.queue_free()
		return {}

	var mesh_transform := Transform3D.IDENTITY
	if root is MeshInstance3D:
		mesh_transform = root.transform
	elif root != mesh_instance:
		mesh_transform = root.global_transform.affine_inverse() * mesh_instance.global_transform

	var scene_data := {
		"mesh": mesh_instance.mesh,
		"material": mesh_instance.get_active_material(0),
		"mesh_transform": mesh_transform,
	}
	_scene_cache[scene] = scene_data
	root.queue_free()
	return scene_data


func _place_center_features() -> void:
	_clear_center_features()
	_exclusion_zones.clear()

	var features_to_place := _resolve_center_features_to_place()
	if features_to_place.is_empty():
		return

	var ground_top_y := _get_ground_top_y()

	for feature in features_to_place:
		var instance := feature.scene.instantiate()
		_center_features_root.add_child(instance)
		_place_feature(instance, feature, ground_top_y)
		if feature.register_exclusions:
			_exclusion_zones.append_array(_collect_exclusion_zones(instance))


func _resolve_center_features_to_place() -> Array[TileCenterFeature]:
	var valid_features: Array[TileCenterFeature] = []
	for feature in _setup_center_features:
		if feature != null and feature.scene != null:
			valid_features.append(feature)

	if valid_features.is_empty():
		return []

	if _pick_random_center_feature and valid_features.size() > 1:
		return [valid_features.pick_random()]

	return valid_features


func _clear_center_features() -> void:
	if _center_features_root == null:
		return
	for child in _center_features_root.get_children():
		child.free()


func _get_ground_top_y() -> float:
	if _ground.mesh == null:
		return 1.0

	var ground_aabb := _ground.mesh.get_aabb()
	return _ground.position.y + ground_aabb.position.y + ground_aabb.size.y


func _place_feature(root: Node, feature: TileCenterFeature, ground_top_y: float) -> void:
	root.scale = feature.scale
	root.rotation_degrees = feature.rotation_degrees
	var placement_offset := _feature_placement_offset(feature)
	root.position = placement_offset

	var mesh_instances := _find_all_mesh_instances(root)
	if mesh_instances.is_empty():
		root.position.y = ground_top_y + feature.location.y
		return

	var lowest_y := INF
	for mesh_instance in mesh_instances:
		var mesh_to_tile : Transform3D = root.global_transform.affine_inverse() * mesh_instance.global_transform
		for corner in _aabb_corners(mesh_instance.mesh.get_aabb()):
			lowest_y = minf(lowest_y, (mesh_to_tile * corner).y)

	if lowest_y != INF:
		root.position.y = ground_top_y + feature.location.y - lowest_y

	if feature.material != null:
		for mesh_instance in mesh_instances:
			mesh_instance.material_override = feature.material


func _layer_placement_offset(layer: TileScatterLayer) -> Transform3D:
	return Transform3D(Basis.IDENTITY, layer.offset)


func _feature_placement_offset(feature: TileCenterFeature) -> Vector3:
	var rotation_basis := Basis.from_euler(feature.rotation_degrees * (PI / 180.0))
	return rotation_basis * feature.location


func _register_scatter_exclusions(
	slot: MultiMeshInstance3D,
	layer: TileScatterLayer,
	transforms_by_scene: Dictionary
) -> void:
	var placement_offset := _layer_placement_offset(layer)

	for scene in transforms_by_scene:
		var scene_data := _get_scene_data(scene)
		if scene_data.is_empty():
			continue

		var mesh: Mesh = scene_data["mesh"]
		var mesh_offset: Transform3D = scene_data["mesh_transform"]
		var aabb := mesh.get_aabb()

		for instance_transform in transforms_by_scene[scene]:
			var mesh_to_hex = (
				_hex_top.global_transform.affine_inverse()
				* slot.global_transform
				* instance_transform
				* placement_offset
				* mesh_offset
			)
			var footprint := _aabb_xz_rect(aabb, mesh_to_hex)
			if footprint.size.x > 0.0 and footprint.size.y > 0.0:
				_exclusion_zones.append(footprint.grow(_setup_exclusion_padding))


func _collect_exclusion_zones(feature_root: Node) -> Array[Rect2]:
	var zones: Array[Rect2] = []

	for mesh_instance in _find_all_mesh_instances(feature_root):
		var footprint := _mesh_footprint_on_hex_top(mesh_instance, feature_root)
		if footprint.size.x > 0.0 and footprint.size.y > 0.0:
			zones.append(footprint.grow(_setup_exclusion_padding))

	return zones


func _mesh_footprint_on_hex_top(mesh_instance: MeshInstance3D, feature_root: Node) -> Rect2:
	var mesh_to_hex := _hex_top.global_transform.affine_inverse() * mesh_instance.global_transform
	return _aabb_xz_rect(mesh_instance.mesh.get_aabb(), mesh_to_hex)


func _aabb_xz_rect(aabb: AABB, transform: Transform3D) -> Rect2:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF

	for corner in _aabb_corners(aabb):
		var point := transform * corner
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_z = minf(min_z, point.z)
		max_z = maxf(max_z, point.z)

	return Rect2(min_x, min_z, max_x - min_x, max_z - min_z)


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var min_corner := aabb.position
	var max_corner := aabb.position + aabb.size
	return [
		min_corner,
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
		max_corner,
	]


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node

	for child in node.get_children():
		var found := _find_mesh_instance(child)
		if found != null:
			return found

	return null


func _find_all_mesh_instances(node: Node) -> Array[MeshInstance3D]:
	var instances: Array[MeshInstance3D] = []
	_gather_mesh_instances(node, instances)
	return instances


func _gather_mesh_instances(node: Node, instances: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		instances.append(node)

	for child in node.get_children():
		_gather_mesh_instances(child, instances)


func _gather_multimesh_slots() -> Array[MultiMeshInstance3D]:
	var slots: Array[MultiMeshInstance3D] = []
	var scatter_root := get_node_or_null("Scatter")
	if scatter_root == null:
		return slots

	for child in scatter_root.get_children():
		if child is MultiMeshInstance3D:
			slots.append(child)

	return slots


func _clear_multimesh(target: MultiMeshInstance3D) -> void:
	target.material_override = null
	if target.multimesh == null:
		target.visible = false
		return

	target.multimesh.instance_count = 0
	target.visible = false


func _clear_layer_extras(layer_index: int) -> void:
	if not _layer_extras.has(layer_index):
		return

	for extra in _layer_extras[layer_index]:
		if is_instance_valid(extra):
			extra.queue_free()
	_layer_extras.erase(layer_index)


func _clear_all_layer_extras() -> void:
	for layer_index in _layer_extras.keys():
		_clear_layer_extras(layer_index)


func _transform_from_hex_point(
	layer: TileScatterLayer,
	target: MultiMeshInstance3D,
	point: Vector2
) -> Transform3D:
	var rotation_y := deg_to_rad(randf_range(layer.rotation_y_range.x, layer.rotation_y_range.y))
	var scale_factor := randf_range(layer.scale.x, layer.scale.y)
	var instance_scale := Vector3.ONE * scale_factor

	var instance_basis := Basis.from_euler(Vector3(0.0, rotation_y, 0.0)).scaled(instance_scale)
	var local_on_hex := Transform3D(instance_basis, Vector3(point.x, 0.0, point.y))

	var world_transform := _hex_top.global_transform * local_on_hex
	return target.global_transform.affine_inverse() * world_transform


func _jittered_grid_points_in_flat_top_hex(
	radius: float,
	count: int,
	exclusion_zones: Array[Rect2]
) -> Array[Vector2]:
	if count <= 0:
		return []

	const MAX_GRID_DIM := 64
	const OVERSAMPLE_FACTOR := 3.0

	var min_cells := maxi(ceili(float(count) * OVERSAMPLE_FACTOR), count + 1)
	var grid_dim := maxi(ceili(sqrt(float(min_cells))), 2)
	var candidates: Array[Vector2] = []
	var used_grid_dim := grid_dim

	while candidates.size() < min_cells and grid_dim <= MAX_GRID_DIM:
		used_grid_dim = grid_dim
		candidates = _flat_top_hex_grid_centers(radius, grid_dim)
		grid_dim += 1

	if candidates.is_empty():
		return []

	candidates.shuffle()

	var cell_size := (2.0 * radius) / float(used_grid_dim)
	var jitter_half := cell_size * 0.45
	var points: Array[Vector2] = []

	for candidate in candidates:
		if points.size() >= count:
			break

		var point := candidate
		for _attempt in 8:
			var jittered := candidate + Vector2(
				randf_range(-jitter_half, jitter_half),
				randf_range(-jitter_half, jitter_half)
			)
			if not _is_point_in_flat_top_hex(jittered, radius):
				continue
			if _is_point_in_exclusion(jittered, exclusion_zones):
				continue
			point = jittered
			break

		if _is_point_in_exclusion(point, exclusion_zones):
			continue
		if not _is_point_in_flat_top_hex(point, radius):
			continue

		points.append(point)

	return points


func _flat_top_hex_grid_centers(radius: float, grid_dim: int) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	var cell_size := (2.0 * radius) / float(grid_dim)

	for row in grid_dim:
		for col in grid_dim:
			var center := Vector2(
				-radius + (col + 0.5) * cell_size,
				-radius + (row + 0.5) * cell_size
			)
			if _is_point_in_flat_top_hex(center, radius):
				centers.append(center)

	return centers


func _get_hex_top_radius(inset: float) -> float:
	var mesh := _hex_top.mesh
	if mesh == null:
		return 2.0

	var radius := maxf(mesh.get_aabb().size.x, mesh.get_aabb().size.z) * 0.5
	return maxf(radius * (1.0 - inset), 0.1)


func _random_point_in_flat_top_hex(radius: float, exclusion_zones: Array[Rect2]) -> Variant:
	for _attempt in 64:
		var point := Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
		if not _is_point_in_flat_top_hex(point, radius):
			continue
		if _is_point_in_exclusion(point, exclusion_zones):
			continue
		return point

	return null


func _is_point_in_exclusion(point: Vector2, exclusion_zones: Array[Rect2]) -> bool:
	for zone in exclusion_zones:
		if zone.has_point(point):
			return true
	return false


func _is_point_in_flat_top_hex(point: Vector2, radius: float) -> bool:
	var ax := absf(point.x)
	var az := absf(point.y)
	var half_height := radius * 0.8660254
	return az <= half_height and ax + az * 0.5773503 <= radius
