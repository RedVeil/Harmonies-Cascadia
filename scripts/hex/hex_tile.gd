extends StaticBody3D
class_name HexTile

const SCORE_POP_BASE_Y := 19.0

@export_group("Place Score Pop Animation")
@export var score_pop_sounds: Array[AudioStream] = []
@export var score_pop_rise: float = 1.35
@export var score_pop_peak_scale: float = 0.58
@export var score_pop_up_duration: float = 0.18
@export var score_pop_float_duration: float = 0.85
@export var score_pop_fade_duration: float = 0.55
@export var score_pop_fade_delay: float = 0.35

@export_group("Outline Flash Animation")
@export var outline_sounds: Array[AudioStream] = []
@export var outline_flash_color: Color = Color(1.0, 0.9, 0.45, 1.0)
@export var outline_flash_fade_duration: float = 0.45

@export_group("Place Celebrate Animation")
@export var place_celebrate_sounds: Array[AudioStream] = []
@export var placed_lift: float = 0.15
@export var placed_scale_peak: float = 1.04
@export var placed_glow: float = 0.24
@export var placed_rise_duration: float = 0.24
@export var placed_settle_duration: float = 0.3

@export_group("Contributor Celebrate Animation")
@export var contributor_sounds: Array[AudioStream] = []
@export var contributor_lift: float = 0.09
@export var contributor_scale_peak: float = 1.022
@export var contributor_glow: float = 0.14
@export var contributor_rise_duration: float = 0.2
@export var contributor_settle_duration: float = 0.26

var container: HexTileContainer
var coord: Vector2i

var _visuals_root: Node3D
var _committed_visuals: TileVisuals
var _staging_visuals: TileVisuals
var _showing_preview: bool = false
var _feedback_tweens: Dictionary = {}


func _ready() -> void:
	input_ray_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_cache_visual_nodes()


func _cache_visual_nodes() -> void:
	if _visuals_root != null:
		return
	_visuals_root = $VisualsRoot as Node3D
	_committed_visuals = $VisualsRoot/current as TileVisuals
	_staging_visuals = $VisualsRoot/previous as TileVisuals


func init(parent: HexTileContainer, location: Vector2i) -> void:
	container = parent
	coord = location
	_cache_visual_nodes()
	apply_committed(
		GameEnums.ELEMENT.NONE,
		GameEnums.LEVEL.ANY,
		-1,
		0
	)


func apply_committed(
	element: int,
	level: int,
	animal_id: int = -1,
	orientation_steps: int = 0,
	scene_layer_rotations: Array[float] = []
) -> void:
	_cache_visual_nodes()
	if _showing_preview:
		reset_preview()
	_set_orientation(orientation_steps)
	_committed_visuals.apply(element, level, coord, animal_id, 0, false, scene_layer_rotations)
	_show_committed()


func commit_preview_from_tile_data(
	tile_data: HexTileData,
	river_neighbors: Array[Vector2i] = []
) -> void:
	_cache_visual_nodes()
	if not _showing_preview:
		if tile_data.element == GameEnums.ELEMENT.RIVER:
			var river_data := RiverPreviewLogic.get_river_index_and_rotation(coord, river_neighbors)
			preview_from_tile_data(tile_data, [], river_data[0], river_data[1])
		else:
			preview_from_tile_data(tile_data)
	_showing_preview = false
	_swap_visual_buffers()
	_show_committed()
	_apply_tile_data_to_committed(tile_data, river_neighbors)


func preview_visuals(
	element: int,
	level: int,
	animal_id: int = -1,
	animal_amount: int = 0,
	is_ground_animal: bool = false,
	orientation_steps: int = 0,
	scene_layer_rotations: Array[float] = [],
	river_index: int = -1
) -> void:
	_cache_visual_nodes()
	_set_orientation(orientation_steps)
	_staging_visuals.apply(
		element,
		level,
		coord,
		animal_id,
		animal_amount,
		is_ground_animal,
		scene_layer_rotations,
		river_index
	)
	_committed_visuals.visible = false
	_staging_visuals.visible = true
	_showing_preview = true


func preview_from_tile_data(
	tile_data: HexTileData, 
	scene_layer_rotations: Array[float] = [], 
	rotation_steps:int = -1, 
	river_index:int = -1
	) -> void:
	preview_visuals(
		tile_data.element,
		tile_data.level,
		tile_data.animal_id,
		tile_data.animal_amount,
		tile_data.is_ground_animal,
		_resolve_orientation_steps(tile_data) if rotation_steps == -1 else rotation_steps,
		scene_layer_rotations,
		river_index
	)


func reset_preview() -> void:
	if not _showing_preview:
		return
	_show_committed()
	_staging_visuals.clear_visuals()
	_showing_preview = false


func commit_preview() -> void:
	if _showing_preview:
		_showing_preview = false
		_swap_visual_buffers()
	_show_committed()
	_committed_visuals.ensure_active_layers_visible()


func restore_undo_visual() -> void:
	_swap_visual_buffers()
	_show_committed()
	_showing_preview = false
	_staging_visuals.clear_visuals()
	_committed_visuals.ensure_active_layers_visible()


func discard_undo_buffer() -> void:
	_staging_visuals.clear_visuals()


func _swap_visual_buffers() -> void:
	var temp := _committed_visuals
	_committed_visuals = _staging_visuals
	_staging_visuals = temp


func _show_committed() -> void:
	_committed_visuals.visible = true
	_staging_visuals.visible = false


func _apply_tile_data_to_committed(
	tile_data: HexTileData,
	river_neighbors: Array[Vector2i] = []
) -> void:
	var rotation_steps := _resolve_orientation_steps(tile_data)
	var river_index := -1
	if tile_data.element == GameEnums.ELEMENT.RIVER:
		var river_data := RiverPreviewLogic.get_river_index_and_rotation(coord, river_neighbors)
		rotation_steps = river_data[0]
		river_index = river_data[1]
	_set_orientation(rotation_steps)
	_committed_visuals.apply(
		tile_data.element,
		tile_data.level,
		coord,
		tile_data.animal_id,
		tile_data.animal_amount,
		tile_data.is_ground_animal,
		[],
		river_index,
		true
	)
	_committed_visuals.ensure_active_layers_visible()


func _set_orientation(orientation_steps: int) -> void:
	_cache_visual_nodes()
	_visuals_root.rotation_degrees.y = HexCoord.direction_to_yaw_degrees(orientation_steps)


func _resolve_orientation_steps(tile_data: HexTileData) -> int:
	if tile_data.orientation_steps >= 0:
		return tile_data.orientation_steps
	if tile_data.element != GameEnums.ELEMENT.RIVER:
		return HexCoord.pick_orientation_steps(coord)
	return 0


## ----- Interactions Logic ----- ##

func _on_mouse_entered() -> void:
	container.handle_hover(coord)
	show_outline(Color.WHITE)


func _on_mouse_exited() -> void:
	container.handle_exit(coord)
	hide_outline()


func _on_input_event(
	_camera: Camera3D,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			container.handle_click(coord)


## ----- Points Logic ----- ##

func show_points(points: int) -> void:
	$Sprite3D/Label3D.text = "%d" % points
	if points > 0:
		$Sprite3D.modulate = Color.GOLD
	if points < 0:
		$Sprite3D.modulate = Color.CRIMSON

	if points != 0:
		$Sprite3D.show()


func hide_points() -> void:
	$Sprite3D.hide()


## ----- Outline Logic ----- ##

func show_outline(color: Color) -> void:
	$outline.modulate = color
	$outline.show()


func hide_outline() -> void:
	$outline.hide()


## ----- Animations ----- ##

func play_place_reward(points: int, element: int) -> void:
	play_animation(&"place", {"points": points, "element": element})


func play_contributor_reward(element: int, delay: float = 0.0) -> void:
	play_animation(&"contributor", {"element": element, "delay": delay})


func play_animation(name: StringName, params: Dictionary) -> void:
	match name:
		&"place":
			_animate_place(params.get("points", 0), params.get("element", GameEnums.ELEMENT.NONE))
		&"contributor":
			_animate_contributor(
				params.get("element", GameEnums.ELEMENT.NONE),
				params.get("delay", 0.0)
			)


func kill_animations() -> void:
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	_reset_celebrate_visuals()
	_reset_score_pop_visuals()
	_reset_outline_visuals()


func _animate_place(points: int, element: int) -> void:
	if points != 0:
		_animate_score_pop(points)
	_animate_outline_flash(0.0)
	if element != GameEnums.ELEMENT.NONE:
		_animate_celebrate(true, 0.0)


func _animate_contributor(element: int, delay: float) -> void:
	_animate_outline_flash(delay)
	if element != GameEnums.ELEMENT.NONE:
		_animate_celebrate(false, delay)


func _animate_score_pop(points: int) -> void:
	FeedbackAnimHelper.play_sounds(score_pop_sounds)
	var sprite: Sprite3D = $Sprite3D
	var label: Label3D = $Sprite3D/Label3D
	if points > 0:
		label.text = "+%d" % points
		sprite.modulate = Color(1.0, 0.88, 0.35, 1.0)
	else:
		label.text = "%d" % points
		sprite.modulate = Color(0.95, 0.35, 0.35, 1.0)

	sprite.visible = true
	sprite.position.y = SCORE_POP_BASE_Y
	sprite.scale = Vector3(1.0, 1.0, 1.0)

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"score_pop", true)
	tween.tween_property(sprite, "scale", Vector3.ONE * score_pop_peak_scale, score_pop_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", SCORE_POP_BASE_Y + score_pop_rise, score_pop_float_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, score_pop_fade_duration)\
		.set_delay(score_pop_fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_reset_score_pop_visuals)


func _animate_outline_flash(delay: float) -> void:
	FeedbackAnimHelper.play_sounds(outline_sounds)
	var outline: Sprite3D = $outline
	outline.modulate = outline_flash_color
	outline.show()

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"outline")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(outline, "modulate:a", 0.0, outline_flash_fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_reset_outline_visuals)


func _animate_celebrate(strong: bool, delay: float) -> void:
	if strong:
		FeedbackAnimHelper.play_sounds(place_celebrate_sounds)
	else:
		FeedbackAnimHelper.play_sounds(contributor_sounds)
	_cache_visual_nodes()

	var lift := placed_lift if strong else contributor_lift
	var peak_scale := Vector3.ONE * (placed_scale_peak if strong else contributor_scale_peak)
	var rise_duration := placed_rise_duration if strong else contributor_rise_duration
	var settle_duration := placed_settle_duration if strong else contributor_settle_duration

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"celebrate")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(_visuals_root, "position:y", lift, rise_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visuals_root, "scale", peak_scale, rise_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_visuals_root, "position:y", 0.0, settle_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_visuals_root, "scale", Vector3.ONE, settle_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_reset_celebrate_visuals)


func _reset_score_pop_visuals() -> void:
	var sprite: Sprite3D = $Sprite3D
	sprite.hide()
	sprite.modulate = Color.WHITE
	sprite.position.y = SCORE_POP_BASE_Y
	sprite.scale = Vector3(0.5, 0.5, 0.5)


func _reset_outline_visuals() -> void:
	var outline: Sprite3D = $outline
	outline.hide()
	outline.modulate = Color.WHITE


func _reset_celebrate_visuals() -> void:
	_cache_visual_nodes()
	_visuals_root.position = Vector3.ZERO
	_visuals_root.scale = Vector3.ONE
