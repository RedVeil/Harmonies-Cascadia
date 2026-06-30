extends Node3D
class_name TileVisuals

const BASE_SCENE_LAYER_Y_ROTATION := 30.0
const BASE_MARKER_CONTAINER_NAMES := ["base_markers", "base_marker"]

@export var scenes_root: Node3D
@export var multimesh_slots: Array[MultiMeshInstance3D] = []
@export var _active_signature: String = ""
var _multimesh_cache: Dictionary = {}
var _scene_layer_pool: Dictionary = {}
var _active_scene_layer_nodes: Dictionary = {}
var _animal_model_instance: Node3D = null
var _animal_anchor: Node3D
var _displayed_animal_model: String = ""


func _ready() -> void:
	_animal_anchor = $animalModel as Node3D


func update_visuals(state: TileLayersState, coord: Vector2i) -> void:
	if state == null:
		return

	_cache_nodes()
	_apply_layers(state)
	_apply_animal_model(state.animal_model, coord)


func get_scene_layer_node(layer_index: int) -> Node:
	if _scenes_root == null:
		return null
	return _scenes_root.get_node_or_null("SceneLayer%d" % layer_index)


func _cache_nodes() -> void:
	if not is_inside_tree():
		return
	_scenes_root = get_node_or_null("Scenes") as Node3D
	if _scenes_root == null:
		_scenes_root = self

	_multimesh_slots.clear()
	var scatter_root := get_node_or_null("Scatter") as Node3D
	if scatter_root == null:
		return

	for index in MULTIMESH_LAYER_COUNT:
		var slot := scatter_root.get_node_or_null("MultiMeshLayer%d" % index) as MultiMeshInstance3D
		if slot != null:
			_multimesh_slots.append(slot)


func _apply_layers(state: TileLayersState) -> void:
	var layers_signature := state.signature()
	if layers_signature != _active_signature:
		_active_signature = layers_signature
		_apply_scene_layers(state.scene_layers)
		_apply_multimesh_layers(state.multi_mesh_layers)

	for layer_index in state.scene_layer_rotations.size():
		var layer_node = get_scene_layer_node(layer_index)
		if layer_node is Node3D:
			(layer_node as Node3D).rotation_degrees.y = state.scene_layer_rotations[layer_index]


func _apply_scene_layers(resolved_scene_layers: Array) -> void:
	var desired_layers: Dictionary = {}
	for layer_index in resolved_scene_layers.size():
		var scene := _coerce_scene_layer(resolved_scene_layers[layer_index])
		if scene == null:
			continue

		var instance := _get_or_create_scene_layer_instance(layer_index, scene)
		_activate_scene_layer_node(layer_index, instance)
		desired_layers[layer_index] = instance

		var previous_node: Node = _active_scene_layer_nodes.get(layer_index, null)
		if previous_node != null and previous_node != instance:
			_deactivate_scene_layer_node(previous_node)

	for layer_index in _active_scene_layer_nodes.keys():
		if not desired_layers.has(layer_index):
			_deactivate_scene_layer_node(_active_scene_layer_nodes[layer_index])

	_active_scene_layer_nodes = desired_layers


func _apply_multimesh_layers(resolved_multimesh_layers: Array) -> void:
	for slot_index in MULTIMESH_LAYER_COUNT:
		var slot: MultiMeshInstance3D = _multimesh_slots[slot_index]
		if slot == null:
			continue

		if slot_index >= resolved_multimesh_layers.size():
			_clear_multimesh_slot(slot)
			continue

		var path := _coerce_multimesh_path(resolved_multimesh_layers[slot_index])
		if path.is_empty():
			_clear_multimesh_slot(slot)
			continue

		var resolved := _resolve_multimesh_option(path)
		if resolved.is_empty():
			_clear_multimesh_slot(slot)
			continue

		slot.multimesh = resolved["multimesh"]
		slot.material_override = resolved.get("material")
		slot.visible = true


func _apply_animal_model(model_path: String, coord: Vector2i) -> void:
	if model_path == _displayed_animal_model and _animal_model_instance != null:
		_position_animal_at_marker(coord)
		return

	_displayed_animal_model = model_path
	if _animal_model_instance != null:
		_animal_model_instance.queue_free()
		_animal_model_instance = null

	if model_path.is_empty():
		_reset_animal_anchor()
		return
	if not ResourceLoader.exists(model_path):
		push_warning("Animal model does not exist: %s" % model_path)
		return

	var model_resource := load(model_path)
	if model_resource == null or not (model_resource is PackedScene):
		push_warning("Animal model is not a scene: %s" % model_path)
		return

	var model_node := (model_resource as PackedScene).instantiate()
	if not (model_node is Node3D):
		model_node.queue_free()
		push_warning("Animal model root is not Node3D: %s" % model_path)
		return

	_animal_model_instance = model_node as Node3D
	_animal_anchor.add_child(_animal_model_instance)
	_animal_model_instance.position = Vector3.ZERO
	_animal_model_instance.rotation = Vector3.ZERO
	_position_animal_at_marker(coord)


func _position_animal_at_marker(coord: Vector2i) -> void:
	if _animal_model_instance == null or _animal_anchor == null:
		return

	var marker: Marker3D = _pick_base_marker(coord)
	if marker == null:
		marker = _pick_fallback_base_marker(coord)

	if marker != null:
		_animal_anchor.global_transform = marker.global_transform
	else:
		_reset_animal_anchor()

	_animal_model_instance.position = Vector3.ZERO
	_animal_model_instance.rotation = Vector3.ZERO


func _pick_base_marker(coord: Vector2i) -> Marker3D:
	var markers := _collect_base_markers()
	if markers.is_empty():
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d,%d|base_marker" % [coord.x, coord.y])
	return markers[rng.randi_range(0, markers.size() - 1)]


func _collect_base_markers() -> Array[Marker3D]:
	var markers: Array[Marker3D] = []
	for layer_node in _active_scene_layer_nodes.values():
		if not (layer_node is Node):
			continue
		var container := _find_marker_container(layer_node as Node, BASE_MARKER_CONTAINER_NAMES)
		if container == null:
			continue
		for child in container.get_children():
			if child is Marker3D:
				markers.append(child)
	return markers


func _pick_fallback_base_marker(coord: Vector2i) -> Marker3D:
	var tile := get_parent()
	if tile == null:
		return null

	var container: Node = null
	for node_name in BASE_MARKER_CONTAINER_NAMES:
		container = tile.get_node_or_null(node_name)
		if container != null:
			break
	if container == null:
		return null

	var markers: Array[Marker3D] = []
	for child in container.get_children():
		if child is Marker3D:
			markers.append(child)
	if markers.is_empty():
		return null

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d,%d|base_marker" % [coord.x, coord.y])
	return markers[rng.randi_range(0, markers.size() - 1)]


func _find_marker_container(root: Node, names: PackedStringArray) -> Node:
	for node_name in names:
		var found := root.find_child(node_name, true, false)
		if found != null:
			return found
	return null


func _reset_animal_anchor() -> void:
	if _animal_anchor == null:
		return
	_animal_anchor.position = Vector3.ZERO
	_animal_anchor.rotation = Vector3.ZERO


func _coerce_scene_layer(entry) -> PackedScene:
	if entry is PackedScene:
		return entry
	if typeof(entry) == TYPE_ARRAY:
		for option in entry:
			if option is PackedScene:
				return option
	return null


func _coerce_multimesh_path(entry) -> String:
	if typeof(entry) == TYPE_STRING:
		return entry
	if typeof(entry) == TYPE_ARRAY:
		for option in entry:
			if typeof(option) == TYPE_STRING and not option.is_empty():
				return option
	return ""


func _resolve_multimesh_option(path: String) -> Dictionary:
	if path.is_empty():
		return {}

	if _multimesh_cache.has(path):
		return _multimesh_cache[path]

	var resource := load(path)
	var resolved := _multimesh_from_resource(resource)
	if not resolved.is_empty():
		_multimesh_cache[path] = resolved
	return resolved


func _multimesh_from_resource(resource: Resource) -> Dictionary:
	if resource is MultiMesh:
		return {"multimesh": resource}

	if resource is PackedScene:
		var temp = resource.instantiate()
		var mesh_instance := _find_multimesh_instance(temp)
		var resolved := {}
		if mesh_instance != null and mesh_instance.multimesh != null:
			resolved = {
				"multimesh": mesh_instance.multimesh,
				"material": mesh_instance.material_override,
			}
		temp.free()
		return resolved

	return {}


func _find_multimesh_instance(node: Node) -> MultiMeshInstance3D:
	if node is MultiMeshInstance3D:
		return node

	for child in node.get_children():
		var found := _find_multimesh_instance(child)
		if found != null:
			return found

	return null


func _get_or_create_scene_layer_instance(layer_index: int, scene: PackedScene) -> Node:
	var scene_path := scene.resource_path
	if not scene_path.is_empty():
		var layer_pool: Dictionary = _scene_layer_pool.get(layer_index, {})
		if layer_pool.has(scene_path):
			return layer_pool[scene_path]

		var pooled_instance := scene.instantiate()
		layer_pool[scene_path] = pooled_instance
		_scene_layer_pool[layer_index] = layer_pool
		return pooled_instance

	return scene.instantiate()


func _activate_scene_layer_node(layer_index: int, node: Node) -> void:
	if node.get_parent() != _scenes_root:
		if node.get_parent() == null:
			_scenes_root.add_child(node)
		else:
			node.reparent(_scenes_root)

	node.name = "SceneLayer%d" % layer_index
	if node is Node3D:
		var node3d := node as Node3D
		node3d.visible = true
		if layer_index == 0:
			node3d.rotation_degrees.y = BASE_SCENE_LAYER_Y_ROTATION
			node3d.position.y = 0.0
		else:
			node3d.rotation_degrees.y = 0.0
			node3d.position.y = 9.5


func _deactivate_scene_layer_node(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false


func _clear_multimesh_slot(slot: MultiMeshInstance3D) -> void:
	slot.material_override = null
	slot.visible = false
	if slot.multimesh != null:
		slot.multimesh = null
