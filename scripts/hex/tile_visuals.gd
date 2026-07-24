extends Node3D
class_name TileVisuals

const BASE_SCENE_LAYER_Y_ROTATION := 30.0
const WALK_MARKERS_ROOT_NAME := "walk_markers"
const WALK_PATHS_NAME := "walk_paths"
const LEGACY_MARKER_CONTAINER_NAMES := ["base_markers", "base_marker"]

@export var multimesh_slots: Array[MultiMeshInstance3D] = []
var _scenes_root: Node3D = null
var _active_signature: String = ""
var _multimesh_cache: Dictionary = {}
var _scene_layer_pool: Dictionary = {}
var _active_scene_layer_nodes: Dictionary = {}
var _animals_root: Node3D = null
var _animal_instances: Array[Node3D] = []
var _animal_roam_groups: Array = []
var _displayed_animal_id: int = -1
var _displayed_animal_amount: int = 0


func _ready() -> void:
	_cache_nodes()


func _cache_nodes() -> void:
	if _scenes_root == null:
		_scenes_root = get_node_or_null("Scenes") as Node3D
	if _animals_root == null:
		_animals_root = get_node_or_null("animalModel") as Node3D


func apply(
	element: int,
	level: int,
	coord: Vector2i,
	animal_id: int = -1,
	animal_amount: int = 0,
	scene_layer_rotations: Array[float] = [],
	river_index: int = -1,
	force_refresh: bool = false,
	animate_animals: bool = false
) -> void:
	_cache_nodes()
	var resolved := TileSetupCatalog.resolve_layers(element, level, coord, river_index)
	var signature: String = str(resolved.get("signature", ""))
	var will_rebuild_layers := (
		force_refresh
		or signature != _active_signature
		or _needs_scene_layer_rebuild(resolved.get("scene_layers", []))
	)
	# Animals live on PathFollow under scene-layer Path3Ds; detach before those free.
	if will_rebuild_layers:
		_detach_animals_from_paths()
	var layers_rebuilt := _apply_layers(
		resolved.get("scene_layers", []),
		resolved.get("multi_mesh_layers", []),
		signature,
		scene_layer_rotations,
		force_refresh
	)
	_apply_animal(animal_id, animal_amount, coord, animate_animals, layers_rebuilt)


func _detach_animals_from_paths() -> void:
	for instance in _animal_instances:
		if is_instance_valid(instance) and instance is Animal:
			(instance as Animal).detach_from_path()


func clear_visuals() -> void:
	_cache_nodes()
	_active_signature = ""
	_displayed_animal_id = -1
	_displayed_animal_amount = 0

	# Detach from PathFollow before freeing walk paths under scene layers.
	_clear_animal_instances()

	_purge_orphan_scene_layers({})
	_active_scene_layer_nodes.clear()
	_scene_layer_pool.clear()

	for slot in multimesh_slots:
		if slot != null:
			_clear_multimesh_slot(slot)


func start_animal_roam() -> void:
	for index in _animal_instances.size():
		var instance := _animal_instances[index]
		if not is_instance_valid(instance) or not (instance is Animal):
			continue
		var path: Path3D = null
		if index < _animal_roam_groups.size() and _animal_roam_groups[index] is Path3D:
			var stored_path := _animal_roam_groups[index] as Path3D
			if is_instance_valid(stored_path):
				path = stored_path
		(instance as Animal).start_roam(
			path,
			hash("%s|%d" % [str(instance.get_path()), index])
		)


func place_animals_on_paths() -> void:
	for index in _animal_instances.size():
		var instance := _animal_instances[index]
		if not is_instance_valid(instance) or not (instance is Animal):
			continue
		var path: Path3D = null
		if index < _animal_roam_groups.size() and _animal_roam_groups[index] is Path3D:
			var stored_path := _animal_roam_groups[index] as Path3D
			if is_instance_valid(stored_path):
				path = stored_path
		(instance as Animal).place_on_path(path)


func freeze_animals() -> void:
	for instance in _animal_instances:
		if is_instance_valid(instance) and instance is Animal:
			(instance as Animal).freeze()


func ensure_active_layers_visible() -> void:
	_cache_nodes()
	for layer_index in _active_scene_layer_nodes.keys():
		var layer_node: Node = _active_scene_layer_nodes[layer_index]
		if not is_instance_valid(layer_node):
			continue
		var activated := _activate_scene_layer_node(layer_index, layer_node)
		if activated != null:
			_active_scene_layer_nodes[layer_index] = activated


func _apply_layers(
	resolved_scene_layers: Array,
	resolved_multimesh_layers: Array,
	signature: String,
	scene_layer_rotations: Array[float],
	force_refresh: bool = false
) -> bool:
	var needs_rebuild := force_refresh or signature != _active_signature or _needs_scene_layer_rebuild(resolved_scene_layers)
	if needs_rebuild:
		_active_signature = signature
		_apply_scene_layers(resolved_scene_layers)
		_apply_multimesh_layers(resolved_multimesh_layers)

	if _scenes_root == null:
		return needs_rebuild

	for layer_index in scene_layer_rotations.size():
		var layer_node: Node = _active_scene_layer_nodes.get(layer_index, null)
		if layer_node == null:
			layer_node = _scenes_root.get_node_or_null("SceneLayer%d" % layer_index)
		if layer_node is Node3D:
			(layer_node as Node3D).rotation_degrees.y = scene_layer_rotations[layer_index]
	return needs_rebuild


func _needs_scene_layer_rebuild(resolved_scene_layers: Array) -> bool:
	if resolved_scene_layers.is_empty():
		return false
	if _active_scene_layer_nodes.is_empty():
		return true
	for layer_node in _active_scene_layer_nodes.values():
		if not is_instance_valid(layer_node):
			return true
		if not _node_belongs_to_this_visuals(layer_node):
			return true
		if layer_node is Node3D and not (layer_node as Node3D).visible:
			return true
	return false


func _apply_scene_layers(resolved_scene_layers: Array) -> void:
	var desired_layers: Dictionary = {}
	var scenes_by_layer: Dictionary = {}
	for layer_index in resolved_scene_layers.size():
		var scene := _coerce_scene_layer(resolved_scene_layers[layer_index])
		if scene == null:
			continue
		scenes_by_layer[layer_index] = scene
		desired_layers[layer_index] = _get_or_create_scene_layer_instance(layer_index, scene)

	if desired_layers.is_empty():
		return

	_purge_orphan_scene_layers(desired_layers)

	for layer_index in desired_layers.keys():
		var scene: PackedScene = scenes_by_layer[layer_index]
		var instance := _activate_scene_layer_node(layer_index, desired_layers[layer_index], scene)
		if instance != null:
			desired_layers[layer_index] = instance
		else:
			desired_layers.erase(layer_index)

	_active_scene_layer_nodes = desired_layers


func _purge_orphan_scene_layers(desired_layers: Dictionary) -> void:
	if _scenes_root == null:
		return
	var keep: Dictionary = {}
	for node in desired_layers.values():
		keep[node] = true
	for child in _scenes_root.get_children():
		if keep.has(child):
			continue
		_remove_node_from_pool(child)
		child.queue_free()


func _remove_node_from_pool(node: Node) -> void:
	for layer_index in _scene_layer_pool.keys():
		var layer_pool: Dictionary = _scene_layer_pool[layer_index]
		for scene_path in layer_pool.keys():
			if layer_pool[scene_path] == node:
				layer_pool.erase(scene_path)


func _store_pool_instance(layer_index: int, scene: PackedScene, node: Node) -> void:
	var scene_path := scene.resource_path
	if scene_path.is_empty():
		return
	var layer_pool: Dictionary = _scene_layer_pool.get(layer_index, {})
	layer_pool[scene_path] = node
	_scene_layer_pool[layer_index] = layer_pool


func _apply_multimesh_layers(resolved_multimesh_layers: Array) -> void:
	for slot_index in multimesh_slots.size():
		var slot: MultiMeshInstance3D = multimesh_slots[slot_index]
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


func _apply_animal(
	animal_id: int,
	animal_amount: int,
	coord: Vector2i,
	animate_animals: bool,
	layers_rebuilt: bool = false
) -> void:
	if (
		animal_id == _displayed_animal_id
		and animal_amount == _displayed_animal_amount
		and not _animal_instances.is_empty()
	):
		# Scene-layer rebuild can free old paths; rebind before roam/place.
		if layers_rebuilt or not _animal_roam_groups_are_valid():
			_refresh_animal_roam_groups(coord)
		if animate_animals:
			start_animal_roam()
		else:
			place_animals_on_paths()
		return

	_clear_animal_instances()
	_displayed_animal_id = animal_id
	_displayed_animal_amount = animal_amount

	if animal_id == -1 or animal_amount <= 0 or _animals_root == null:
		return

	var model_paths := _resolve_animal_model_paths(animal_id)
	if model_paths.is_empty():
		return

	for _i in animal_amount:
		var model_path: String = model_paths.pick_random()
		if model_path.is_empty():
			continue
		if not ResourceLoader.exists(model_path):
			push_warning("Animal model does not exist: %s" % model_path)
			continue

		var model_resource := load(model_path)
		if model_resource == null or not (model_resource is PackedScene):
			push_warning("Animal model is not a scene: %s" % model_path)
			continue

		var model_node := (model_resource as PackedScene).instantiate()
		if not (model_node is Node3D):
			model_node.queue_free()
			push_warning("Animal model root is not Node3D: %s" % model_path)
			continue

		_animals_root.add_child(model_node)
		_animal_instances.append(model_node as Node3D)

	_position_animals_in_groups(coord, animate_animals)


func _resolve_animal_model_paths(animal_id: int) -> Array[String]:
	if animal_id == -1:
		return []
	for card in CardCatalog.animals:
		if card.id == animal_id:
			return card.models
	return []


func _animal_roam_groups_are_valid() -> bool:
	if _animal_roam_groups.size() != _animal_instances.size():
		return false
	for stored in _animal_roam_groups:
		if stored == null:
			continue
		if not (stored is Path3D) or not is_instance_valid(stored):
			return false
	return true


## Rebind roam paths from live scene layers without teleporting animals.
func _refresh_animal_roam_groups(coord: Vector2i) -> void:
	_animal_roam_groups.clear()
	var paths := _collect_walk_paths()
	if paths.is_empty():
		paths = _collect_fallback_walk_paths()

	for index in _animal_instances.size():
		if not is_instance_valid(_animal_instances[index]) or paths.is_empty():
			_animal_roam_groups.append(null)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d,%d|walk_path|%d" % [coord.x, coord.y, index])
		var path_index := rng.randi_range(0, paths.size() - 1)
		_animal_roam_groups.append(paths[path_index])


func _position_animals_in_groups(coord: Vector2i, animate_animals: bool) -> void:
	_animal_roam_groups.clear()
	var paths := _collect_walk_paths()
	if paths.is_empty():
		paths = _collect_fallback_walk_paths()

	for index in _animal_instances.size():
		var instance := _animal_instances[index]
		if not is_instance_valid(instance):
			_animal_roam_groups.append(null)
			continue
		if paths.is_empty():
			_animal_roam_groups.append(null)
			if instance is Animal:
				(instance as Animal).freeze()
			continue

		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d,%d|walk_path|%d" % [coord.x, coord.y, index])

		var path_index := rng.randi_range(0, paths.size() - 1)
		var path: Path3D = paths[path_index]
		_animal_roam_groups.append(path)

		var curve := path.curve
		var start_offset := -1.0
		if curve != null and curve.get_baked_length() > 0.05:
			start_offset = rng.randf_range(0.0, curve.get_baked_length())

		if instance is Animal:
			var animal := instance as Animal
			if animate_animals:
				animal.start_roam(
					path,
					hash("%d,%d|roam|%d" % [coord.x, coord.y, index]),
					start_offset
				)
			else:
				animal.place_on_path(path, start_offset)
		elif curve != null and start_offset >= 0.0:
			instance.global_position = path.global_transform * curve.sample_baked(start_offset)


func _collect_walk_paths() -> Array[Path3D]:
	var paths: Array[Path3D] = []
	for layer_node in _active_scene_layer_nodes.values():
		if not (layer_node is Node):
			continue
		paths.append_array(_walk_paths_from_root(layer_node as Node))
	return paths


func _collect_fallback_walk_paths() -> Array[Path3D]:
	var tile := _get_owner_tile()
	if tile == null:
		return []
	return _walk_paths_from_root(tile)


func _walk_paths_from_root(root: Node) -> Array[Path3D]:
	var paths: Array[Path3D] = []
	var walk_root := root.find_child(WALK_MARKERS_ROOT_NAME, true, false)
	if walk_root != null:
		var paths_root := walk_root.get_node_or_null(WALK_PATHS_NAME)
		if paths_root != null:
			for child in paths_root.get_children():
				if child is Path3D and (child as Path3D).curve != null:
					paths.append(child as Path3D)
		if not paths.is_empty():
			return paths
		# Also accept Path3D nodes nested anywhere under walk_markers.
		_collect_path3d_recursive(walk_root, paths)
		if not paths.is_empty():
			return paths

	for legacy_name in LEGACY_MARKER_CONTAINER_NAMES:
		var legacy := root.find_child(legacy_name, true, false)
		if legacy == null and root.has_node(NodePath(legacy_name)):
			legacy = root.get_node(NodePath(legacy_name))
		if legacy != null:
			_collect_path3d_recursive(legacy, paths)
	return paths


func _collect_path3d_recursive(node: Node, paths: Array[Path3D]) -> void:
	if node is Path3D and (node as Path3D).curve != null:
		paths.append(node as Path3D)
	for child in node.get_children():
		_collect_path3d_recursive(child, paths)


func _get_owner_tile() -> HexTile:
	var node: Node = self
	while node != null:
		if node is HexTile:
			return node as HexTile
		node = node.get_parent()
	return null


func _clear_animal_instances() -> void:
	for instance in _animal_instances:
		if is_instance_valid(instance):
			if instance is Animal:
				(instance as Animal).stop_roam()
			instance.queue_free()
	_animal_instances.clear()
	_animal_roam_groups.clear()


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
			var pooled: Node = layer_pool[scene_path]
			if is_instance_valid(pooled) and _node_belongs_to_this_visuals(pooled):
				return pooled
			layer_pool.erase(scene_path)

		var pooled_instance := scene.instantiate()
		layer_pool[scene_path] = pooled_instance
		_scene_layer_pool[layer_index] = layer_pool
		return pooled_instance

	return scene.instantiate()


func _node_belongs_to_this_visuals(node: Node) -> bool:
	_cache_nodes()
	if not is_instance_valid(node):
		return false
	if node.get_parent() == null:
		return true
	var current: Node = node
	while current != null:
		if current == _scenes_root:
			return true
		if current.name == "Scenes" and current != _scenes_root:
			return false
		current = current.get_parent()
	return false


func _activate_scene_layer_node(
	layer_index: int,
	node: Node,
	scene: PackedScene = null
) -> Node:
	_cache_nodes()
	if node.get_parent() != _scenes_root:
		if node.get_parent() != null and not _node_belongs_to_this_visuals(node):
			if scene == null:
				return null
			node = scene.instantiate()
			_store_pool_instance(layer_index, scene, node)
		if node.get_parent() == null:
			_scenes_root.add_child(node)
		elif node.get_parent() != _scenes_root:
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
	return node


func _clear_multimesh_slot(slot: MultiMeshInstance3D) -> void:
	slot.material_override = null
	slot.visible = false
	if slot.multimesh != null:
		slot.multimesh = null
