extends StaticBody3D
class_name HexTile

const SCORE_POP_BASE_Y := 19.0
const QUEST_MOTE_TEXTURE := preload("res://assets/icons/circle.png")

@export_group("Point Preview Animation")
@export var preview_pop_start_scale: float = 0.42
@export var preview_pop_peak_scale: float = 1.38
@export var preview_pop_rest_scale: float = 1.0
@export var preview_pop_up_duration: float = 0.09
@export var preview_pop_settle_duration: float = 0.12

@export_group("Place Score Pop Animation")
@export var score_pop_start_scale: float = 0.5
@export var score_pop_rise: float = 2.05
@export var score_pop_peak_scale: float = 1.85
@export var score_pop_rest_scale: float = 1.5
@export var score_pop_up_duration: float = 0.1
@export var score_pop_settle_duration: float = 0.13
@export var score_pop_float_duration: float = 0.85
@export var score_pop_fade_duration: float = 0.55
@export var score_pop_fade_delay: float = 0.35

@export_group("Outline Flash Animation")
@export var outline_flash_color: Color = Color(1.0, 0.9, 0.45, 1.0)
@export var outline_flash_fade_duration: float = 0.45

@export_group("Place Celebrate Animation")
@export var place_celebrate_sounds: Array[AudioStream] = []
@export var placed_lift: float = 0.7
@export var placed_stretch: Vector3 = Vector3(1.12, 1.1, 1.12)
@export var placed_squash: Vector3 = Vector3(1.14, 0.88, 1.14)
@export var placed_glow: float = 0.24
@export var placed_rise_duration: float = 0.16
@export var placed_land_duration: float = 0.14
@export var placed_spring_duration: float = 0.28
@export var placed_rumble_distance: float = 0.5
@export var placed_rumble_degrees: float = 1.15
@export var placed_rumble_cycles: float = 1.5

@export_group("Contributor Celebrate Animation")
@export var contributor_lift: float = 0.26
@export var contributor_stretch: Vector3 = Vector3(1.05, 1.04, 1.05)
@export var contributor_squash: Vector3 = Vector3(1.08, 0.94, 1.08)
@export var contributor_glow: float = 0.14
@export var contributor_rise_duration: float = 0.14
@export var contributor_land_duration: float = 0.12
@export var contributor_spring_duration: float = 0.22
@export var contributor_rumble_distance: float = 0.28
@export var contributor_rumble_degrees: float = 0.65
@export var contributor_rumble_cycles: float = 1.25

@export_group("Quest Burst")
@export var quest_burst_color: Color = Color(1.0, 0.9, 0.45, 1.0)
@export var quest_burst_mote_count: int = 8
@export var quest_burst_extra_mote_count: int = 10
@export var quest_burst_start_radius: float = 1.4
@export var quest_burst_radius: float = 7.2
@export var quest_burst_rise: float = 2.4
@export var quest_burst_mote_size: float = 0.7
@export var quest_ring_scale: float = 1.6
@export var quest_ring_extra_delay: float = 0.12

var container: HexTileContainer
var coord: Vector2i

var _visuals_root: Node3D
var _committed_visuals: TileVisuals
var _staging_visuals: TileVisuals
var _showing_preview: bool = false
var _feedback_tweens: Dictionary = {}
var _score_pop_playing: bool = false
var _awaiting_place_feedback: bool = false
var _hover_info_pending: bool = false
var _pending_hover_element_tex: Texture2D = null
var _pending_hover_animal_tex: Texture2D = null
var _pending_hover_icon_color: Color = Color.WHITE
var _quest_burst_root: Node3D = null

signal place_feedback_finished


func _ready() -> void:
	input_ray_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	_cache_visual_nodes()
	UiTheme.bind_node(self, _apply_theme)
	_apply_theme()


func _apply_theme() -> void:
	var points_label := get_node_or_null("PointsLabel/Fill") as Label3D
	if points_label:
		points_label.font = UiTheme.TITLE_FONT
	var element_bubble := get_node_or_null("HoverInfo/ElementBubble") as Sprite3D
	var animal_bubble := get_node_or_null("HoverInfo/AnimalBubble") as Sprite3D
	if element_bubble:
		element_bubble.modulate = UiTheme.hud_background
		var element_icon := element_bubble.get_node_or_null("Icon") as Sprite3D
		if element_icon:
			element_icon.modulate = UiTheme.secondary
	if animal_bubble:
		animal_bubble.modulate = UiTheme.hud_background
		var animal_icon := animal_bubble.get_node_or_null("Icon") as Sprite3D
		if animal_icon:
			animal_icon.modulate = Color.WHITE


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
	_committed_visuals.apply(element, level, coord, animal_id, 0, scene_layer_rotations)
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
		scene_layer_rotations,
		river_index,
		false,
		false
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
		[],
		river_index,
		true,
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
	if UiPointerBlock.is_blocked():
		return
	container.handle_hover(coord)
	show_outline(Color.WHITE)


func _on_mouse_exited() -> void:
	if InputScheme.uses_touch_confirm() and InputScheme.touch.is_sticky("hex", coord):
		return
	container.handle_exit(coord)
	hide_outline()


func _on_input_event(
	_camera: Camera3D,
	event: InputEvent,
	_event_position: Vector3,
	_normal: Vector3,
	_shape_idx: int
) -> void:
	if UiPointerBlock.is_blocked():
		return
	if not InputScheme.is_left_click(event):
		return
	if InputScheme.uses_touch_confirm():
		if not InputScheme.touch.is_sticky("hex", coord):
			InputScheme.touch.set_target("hex", coord)
			container.handle_hover(coord)
			show_outline(Color.WHITE)
			return
	container.handle_click(coord)


## ----- Points Logic ----- ##

func show_points(points: int) -> void:
	if _score_pop_playing:
		return
	hide_hover_info()
	var root := _prepare_points_label(points)
	root.scale = Vector3.ONE * preview_pop_start_scale
	root.show()
	var pop_time := preview_pop_up_duration + preview_pop_settle_duration
	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"points_preview")
	tween.tween_method(
		_sample_points_pop_scale.bind(
			root,
			preview_pop_start_scale,
			preview_pop_peak_scale,
			preview_pop_rest_scale,
			preview_pop_up_duration,
			preview_pop_settle_duration
		),
		0.0,
		1.0,
		pop_time
	)


func hide_points() -> void:
	if _score_pop_playing:
		return
	$PointsLabel.hide()


func _prepare_points_label(points: int) -> Node3D:
	var root := $PointsLabel as Node3D
	var fill := root.get_node("Fill") as Label3D
	fill.text = "+%d" % points if points > 0 else "%d" % points
	fill.modulate = Color.WHITE
	fill.outline_modulate = Color(0, 0, 0, 1)
	root.position = Vector3(0.0, SCORE_POP_BASE_Y, 0.0)
	root.scale = Vector3.ONE
	return root


## ----- Hover Info Logic ----- ##

const HOVER_ICON_TARGET_PX := 280.0
## Half-distance between element/animal bubbles when both are shown (world units).
const HOVER_BUBBLE_OFFSET_X := 2.5

func show_hover_info(
	element_tex: Texture2D,
	animal_tex: Texture2D,
	icon_color: Color = Color.WHITE
) -> void:
	if _score_pop_playing:
		_pending_hover_element_tex = element_tex
		_pending_hover_animal_tex = animal_tex
		_pending_hover_icon_color = icon_color
		_hover_info_pending = true
		return

	_hover_info_pending = false
	_apply_hover_info(element_tex, animal_tex, icon_color)


func hide_hover_info() -> void:
	_clear_pending_hover_info()
	$HoverInfo/ElementBubble.hide()
	$HoverInfo/AnimalBubble.hide()
	$HoverInfo.hide()


func _apply_hover_info(
	element_tex: Texture2D,
	animal_tex: Texture2D,
	icon_color: Color
) -> void:
	var element_bubble: Sprite3D = $HoverInfo/ElementBubble
	var animal_bubble: Sprite3D = $HoverInfo/AnimalBubble
	var show_element := element_tex != null
	var show_animal := animal_tex != null

	if show_element:
		element_bubble.modulate = UiTheme.hud_background
		_apply_hover_icon(element_bubble.get_node("Icon") as Sprite3D, element_tex, icon_color)
		element_bubble.show()
	else:
		element_bubble.hide()

	if show_animal:
		animal_bubble.modulate = UiTheme.hud_background
		_apply_hover_icon(animal_bubble.get_node("Icon") as Sprite3D, animal_tex, Color.WHITE)
		animal_bubble.show()
	else:
		animal_bubble.hide()

	if show_element and show_animal:
		element_bubble.position.x = -HOVER_BUBBLE_OFFSET_X
		animal_bubble.position.x = HOVER_BUBBLE_OFFSET_X
	elif show_element:
		element_bubble.position.x = 0.0
	elif show_animal:
		animal_bubble.position.x = 0.0

	if show_element or show_animal:
		$HoverInfo.show()
	else:
		$HoverInfo.hide()


func _apply_hover_icon(icon: Sprite3D, tex: Texture2D, icon_color: Color) -> void:
	icon.texture = tex
	icon.modulate = icon_color
	var size := tex.get_size()
	var max_dim := maxf(size.x, size.y)
	var scale_factor := HOVER_ICON_TARGET_PX / max_dim if max_dim > 0.0 else 1.0
	icon.scale = Vector3.ONE * scale_factor


func _clear_pending_hover_info() -> void:
	_hover_info_pending = false
	_pending_hover_element_tex = null
	_pending_hover_animal_tex = null
	_pending_hover_icon_color = Color.WHITE


func _flush_pending_hover_info() -> void:
	if not _hover_info_pending:
		return
	var element_tex := _pending_hover_element_tex
	var animal_tex := _pending_hover_animal_tex
	var icon_color := _pending_hover_icon_color
	_clear_pending_hover_info()
	_apply_hover_info(element_tex, animal_tex, icon_color)


## ----- Outline Logic ----- ##

func show_outline(color: Color) -> void:
	$outline.modulate = color
	$outline.show()


func hide_outline() -> void:
	$outline.hide()


## ----- Animations ----- ##

func place_celebrate_duration() -> float:
	return placed_rise_duration + placed_land_duration + placed_spring_duration


func play_place_reward(points: int, element: int, quest_count: int = 0) -> void:
	_awaiting_place_feedback = true
	play_animation(&"place", {
		"points": points,
		"element": element,
		"quest_count": quest_count,
	})
	_try_emit_place_feedback_finished()


func play_contributor_reward(element: int, delay: float = 0.0) -> void:
	play_animation(&"contributor", {"element": element, "delay": delay})


func play_animation(anim_name: StringName, params: Dictionary) -> void:
	match anim_name:
		&"place":
			_animate_place(
				params.get("points", 0),
				params.get("element", GameEnums.ELEMENT.NONE),
				params.get("quest_count", 0)
			)
		&"contributor":
			_animate_contributor(
				params.get("element", GameEnums.ELEMENT.NONE),
				params.get("delay", 0.0)
			)


func kill_animations() -> void:
	# Place feedback (score pop / celebrate / outline) runs to completion;
	# hover/exit/preview resets must not cut it off.
	var spare_place_feedback := _awaiting_place_feedback
	var keys := _feedback_tweens.keys()
	for key in keys:
		if key == &"score_pop":
			continue
		if spare_place_feedback and (
			key == &"celebrate"
			or key == &"outline"
			or key == &"quest_burst_motion"
		):
			continue
		var tween: Tween = _feedback_tweens[key]
		if tween.is_valid():
			tween.kill()
		_feedback_tweens.erase(key)
	if not spare_place_feedback or not _feedback_tweens.has(&"celebrate"):
		_reset_celebrate_visuals()
	if not spare_place_feedback or not _feedback_tweens.has(&"outline"):
		_reset_outline_visuals()
	if not spare_place_feedback or not _feedback_tweens.has(&"quest_burst_motion"):
		_clear_quest_burst()
	_try_emit_place_feedback_finished()


func _animate_place(points: int, element: int, quest_count: int) -> void:
	if points != 0:
		_animate_score_pop(points)
	_animate_outline_flash(0.0)
	if element != GameEnums.ELEMENT.NONE:
		_animate_celebrate(true, 0.0)
	if quest_count > 0:
		_animate_quest_burst(quest_count)


func _animate_contributor(element: int, delay: float) -> void:
	_animate_outline_flash(delay)
	if element != GameEnums.ELEMENT.NONE:
		_animate_celebrate(false, delay)


func _animate_score_pop(points: int) -> void:
	_score_pop_playing = true
	# Hide any visible inspect bubbles without clearing a pending show.
	$HoverInfo/ElementBubble.hide()
	$HoverInfo/AnimalBubble.hide()
	$HoverInfo.hide()
	var root := _prepare_points_label(points)
	var fill := root.get_node("Fill") as Label3D
	root.scale = Vector3.ONE * score_pop_start_scale
	root.show()

	var pop_time := score_pop_up_duration + score_pop_settle_duration
	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"score_pop", true)
	tween.tween_method(
		_sample_points_pop_scale.bind(
			root,
			score_pop_start_scale,
			score_pop_peak_scale,
			score_pop_rest_scale,
			score_pop_up_duration,
			score_pop_settle_duration
		),
		0.0,
		1.0,
		pop_time
	)
	tween.tween_property(root, "position:y", SCORE_POP_BASE_Y + score_pop_rise, score_pop_float_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().set_parallel(true)
	tween.tween_property(fill, "modulate:a", 0.0, score_pop_fade_duration)\
		.set_delay(score_pop_fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(fill, "outline_modulate:a", 0.0, score_pop_fade_duration)\
		.set_delay(score_pop_fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_score_pop_finished)


func _sample_points_pop_scale(
	t: float,
	root: Node3D,
	start_scale: float,
	peak_scale: float,
	rest_scale: float,
	up_duration: float,
	settle_duration: float
) -> void:
	root.scale = Vector3.ONE * FeedbackAnimHelper.pop_scale(
		t,
		start_scale,
		peak_scale,
		rest_scale,
		up_duration,
		settle_duration
	)


func _on_score_pop_finished() -> void:
	_score_pop_playing = false
	_feedback_tweens.erase(&"score_pop")
	_reset_score_pop_visuals()
	_flush_pending_hover_info()
	_try_emit_place_feedback_finished()


func _animate_outline_flash(delay: float) -> void:
	var outline: Sprite3D = $outline
	outline.modulate = outline_flash_color
	outline.show()

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"outline")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(outline, "modulate:a", 0.0, outline_flash_fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_outline_flash_finished)


func _animate_celebrate(strong: bool, delay: float) -> void:
	if strong:
		FeedbackAnimHelper.play_sounds(place_celebrate_sounds)
	_cache_visual_nodes()

	var lift := placed_lift if strong else contributor_lift
	var stretch := placed_stretch if strong else contributor_stretch
	var squash := placed_squash if strong else contributor_squash
	var rise_duration := placed_rise_duration if strong else contributor_rise_duration
	var land_duration := placed_land_duration if strong else contributor_land_duration
	var spring_duration := placed_spring_duration if strong else contributor_spring_duration
	var rumble_distance := placed_rumble_distance if strong else contributor_rumble_distance
	var rumble_degrees := placed_rumble_degrees if strong else contributor_rumble_degrees
	var rumble_cycles := placed_rumble_cycles if strong else contributor_rumble_cycles
	var total := rise_duration + land_duration + spring_duration

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"celebrate")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(
		_apply_celebrate_sample.bind(
			lift,
			stretch,
			squash,
			rise_duration,
			land_duration,
			spring_duration,
			rumble_distance,
			rumble_degrees,
			rumble_cycles
		),
		0.0,
		1.0,
		total
	)
	tween.finished.connect(_on_celebrate_finished)


func _apply_celebrate_sample(
	t: float,
	lift: float,
	stretch: Vector3,
	squash: Vector3,
	rise_duration: float,
	land_duration: float,
	spring_duration: float,
	rumble_distance: float,
	rumble_degrees: float,
	rumble_cycles: float
) -> void:
	var total := rise_duration + land_duration + spring_duration
	if total <= 0.0:
		return
	var elapsed := t * total
	var y := 0.0
	var scale := Vector3.ONE
	if elapsed <= rise_duration:
		y = Tween.interpolate_value(0.0, lift, elapsed, rise_duration, Tween.TRANS_QUAD, Tween.EASE_OUT)
		scale = Tween.interpolate_value(Vector3.ONE, stretch - Vector3.ONE, elapsed, rise_duration, Tween.TRANS_BACK, Tween.EASE_OUT)
	elif elapsed <= rise_duration + land_duration:
		var land_elapsed := elapsed - rise_duration
		y = Tween.interpolate_value(lift, -lift, land_elapsed, land_duration, Tween.TRANS_QUAD, Tween.EASE_IN)
		scale = Tween.interpolate_value(stretch, squash - stretch, land_elapsed, land_duration, Tween.TRANS_QUAD, Tween.EASE_IN)
	else:
		var spring_elapsed := elapsed - rise_duration - land_duration
		scale = Tween.interpolate_value(squash, Vector3.ONE - squash, spring_elapsed, spring_duration, Tween.TRANS_BACK, Tween.EASE_OUT)

	var rumble_start := rise_duration
	var shove := Vector2.ZERO
	var rock := Vector2.ZERO
	if elapsed > rumble_start and total > rumble_start:
		var rumble_u := clampf((elapsed - rumble_start) / (total - rumble_start), 0.0, 1.0)
		var decay := pow(1.0 - rumble_u, 1.35)
		var wave := sin(rumble_u * TAU * rumble_cycles)
		shove = Vector2(wave, wave * 0.35) * rumble_distance * decay
		rock = Vector2(wave * 0.85, wave * 0.25) * rumble_degrees * decay

	var yaw := _visuals_root.rotation_degrees.y
	_visuals_root.position = Vector3(shove.x, y, shove.y)
	_visuals_root.scale = scale
	_visuals_root.rotation_degrees = Vector3(rock.x, yaw, rock.y)


func _animate_quest_burst(quest_count: int) -> void:
	if _feedback_tweens.has(&"quest_burst_motion"):
		var existing: Tween = _feedback_tweens[&"quest_burst_motion"]
		if existing != null and existing.is_valid():
			existing.kill()
		_feedback_tweens.erase(&"quest_burst_motion")
	_clear_quest_burst()
	_start_quest_burst_motion(quest_count)


func _start_quest_burst_motion(quest_count: int) -> void:
	var outline := $outline as Sprite3D
	var root := Node3D.new()
	root.name = "QuestBurst"
	add_child(root)
	_quest_burst_root = root

	var mote_count := quest_burst_extra_mote_count if quest_count >= 2 else quest_burst_mote_count
	var duration := place_celebrate_duration()
	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"quest_burst_motion", true)

	for i in mote_count:
		var mote := _make_quest_mote()
		root.add_child(mote)
		var angle := TAU * float(i) / float(mote_count) + 0.4
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var origin_y := outline.position.y
		mote.position = Vector3(0.0, origin_y, 0.0) + direction * quest_burst_start_radius
		var end := Vector3(0.0, origin_y + quest_burst_rise, 0.0) + direction * quest_burst_radius
		tween.tween_property(mote, "position", end, duration)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(mote, "modulate:a", 0.0, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(mote, "scale", Vector3.ONE * 0.15, duration)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var ring := _make_quest_ring(outline)
	root.add_child(ring)
	tween.tween_property(ring, "scale", outline.scale * quest_ring_scale, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	if quest_count >= 2:
		var second := _make_quest_ring(outline)
		second.modulate.a = 0.0
		root.add_child(second)
		tween.tween_method(
			_sample_quest_ring.bind(second, outline.scale, outline.scale * (quest_ring_scale + 0.25), duration),
			0.0,
			1.0,
			duration
		)

	tween.finished.connect(_on_quest_burst_motion_finished)


func _sample_quest_ring(
	u: float,
	ring: Sprite3D,
	start_scale: Vector3,
	end_scale: Vector3,
	total: float
) -> void:
	if total <= 0.0:
		return
	var lead := minf(quest_ring_extra_delay, total * 0.45)
	var elapsed := u * total
	if elapsed < lead:
		ring.scale = start_scale
		var hidden := quest_burst_color
		hidden.a = 0.0
		ring.modulate = hidden
		return
	var span := maxf(total - lead, 0.001)
	var local := (elapsed - lead) / span
	ring.scale = start_scale.lerp(end_scale, local)
	var color := quest_burst_color
	color.a = 1.0 - local
	ring.modulate = color


func _make_quest_mote() -> Sprite3D:
	var mote := Sprite3D.new()
	mote.texture = QUEST_MOTE_TEXTURE
	mote.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var tex_size := QUEST_MOTE_TEXTURE.get_size()
	var max_dim := maxf(tex_size.x, tex_size.y)
	mote.pixel_size = quest_burst_mote_size / max_dim if max_dim > 0.0 else 0.01
	mote.modulate = quest_burst_color
	mote.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mote.render_priority = 4
	return mote


func _make_quest_ring(outline: Sprite3D) -> Sprite3D:
	var ring := Sprite3D.new()
	ring.texture = outline.texture
	ring.axis = outline.axis
	ring.position = outline.position
	ring.scale = outline.scale
	ring.modulate = quest_burst_color
	ring.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring


func _on_quest_burst_motion_finished() -> void:
	_feedback_tweens.erase(&"quest_burst_motion")
	_clear_quest_burst()
	_try_emit_place_feedback_finished()


func _clear_quest_burst() -> void:
	if _quest_burst_root != null and is_instance_valid(_quest_burst_root):
		_quest_burst_root.queue_free()
	_quest_burst_root = null


func _on_outline_flash_finished() -> void:
	_feedback_tweens.erase(&"outline")
	_reset_outline_visuals()
	_try_emit_place_feedback_finished()


func _on_celebrate_finished() -> void:
	_feedback_tweens.erase(&"celebrate")
	_reset_celebrate_visuals()
	_try_emit_place_feedback_finished()


func _has_active_place_feedback_tween() -> bool:
	for key in [&"score_pop", &"outline", &"celebrate", &"quest_burst_motion"]:
		if not _feedback_tweens.has(key):
			continue
		var tween: Tween = _feedback_tweens[key]
		if tween != null and tween.is_valid():
			return true
	return false


func _try_emit_place_feedback_finished() -> void:
	if not _awaiting_place_feedback:
		return
	if _has_active_place_feedback_tween():
		return
	_awaiting_place_feedback = false
	place_feedback_finished.emit()


func _reset_score_pop_visuals() -> void:
	var root := $PointsLabel as Node3D
	root.hide()
	root.position = Vector3(0.0, SCORE_POP_BASE_Y, 0.0)
	root.scale = Vector3.ONE
	var fill := root.get_node("Fill") as Label3D
	fill.modulate = Color.WHITE
	fill.outline_modulate = Color(0, 0, 0, 1)


func _reset_outline_visuals() -> void:
	var outline: Sprite3D = $outline
	outline.hide()
	outline.modulate = Color.WHITE


func _reset_celebrate_visuals() -> void:
	_cache_visual_nodes()
	var yaw := _visuals_root.rotation_degrees.y
	_visuals_root.position = Vector3.ZERO
	_visuals_root.scale = Vector3.ONE
	_visuals_root.rotation_degrees = Vector3(0.0, yaw, 0.0)
