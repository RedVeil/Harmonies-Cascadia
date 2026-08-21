class_name TileVisualWarmup
extends RefCounted

const TILE_VISUALS_SCENE := preload("res://scenes/hex/tile_visuals.tscn")
const VIEWPORT_SIZE := Vector2i(128, 128)


static func run(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return

	for path in TileSetupCatalog.get_unique_multimesh_paths():
		TileSetupCatalog.get_or_load_multimesh(path)

	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	host.add_child(viewport)

	var world_root := Node3D.new()
	viewport.add_child(world_root)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50.0, 40.0, 0.0)
	world_root.add_child(light)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 28.0, 36.0)
	world_root.add_child(camera)
	camera.look_at(Vector3(0.0, 8.0, 0.0))
	camera.current = true

	var visuals := TILE_VISUALS_SCENE.instantiate() as TileVisuals
	world_root.add_child(visuals)

	await host.get_tree().process_frame

	var empty_rotations: Array[float] = []
	for spec in TileSetupCatalog.iter_setup_keys():
		var element: int = spec.element
		var level: int = spec.level
		if element < 0 or level < 0:
			continue
		if element == GameEnums.ELEMENT.RIVER:
			var river_count := TileSetupCatalog.get_scene_option_count(element, level, 0)
			for river_index in river_count:
				visuals.apply(
					element,
					level,
					Vector2i.ZERO,
					-1,
					0,
					empty_rotations,
					river_index,
					true,
					false
				)
				await RenderingServer.frame_post_draw
		else:
			visuals.apply(
				element,
				level,
				Vector2i.ZERO,
				-1,
				0,
				empty_rotations,
				-1,
				true,
				false
			)
			await RenderingServer.frame_post_draw

	for animal in CardCatalog.animals:
		if animal == null or animal.models.is_empty():
			continue
		visuals.apply(
			GameEnums.ELEMENT.NONE,
			GameEnums.LEVEL.ANY,
			Vector2i.ZERO,
			animal.id,
			1,
			empty_rotations,
			-1,
			false,
			false
		)
		await RenderingServer.frame_post_draw

	viewport.queue_free()
