extends StaticBody3D
class_name HexTile

const SCORE_POP_BASE_Y := 3.367

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

var container : HexTileContainer
var coord : Vector2i
var tile_orientation_steps: int = 0
var visuals : HexTileVisuals
var committed_setup: TileSetupState
var preview_setup: TileSetupState

var _displayed_setup_signature: String = ""
var _feedback_tweens: Dictionary = {}

## ----- Initialisation ----- ##

func _ready() -> void:
	input_ray_pickable = true
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	var original_mat := $visuals/StylizedHexTile.material_override as StandardMaterial3D
	$visuals/StylizedHexTile.material_override = original_mat.duplicate()
	
	var new_visuals = HexTileVisuals.new()
	new_visuals.color = Color.html(ElementCatalog.elements[0].levels[0].color)
	new_visuals.icon = load(ElementCatalog.elements[0].levels[0].icon)
	update_visuals(new_visuals)
	_apply_tile_orientation()
	commit_setup(
		TileSetupState.from_setup(
			TileSetupCatalog.get_setup(GameEnums.ELEMENT.NONE, GameEnums.LEVEL.ANY),
			[]
		)
	)

func init(parent:HexTileContainer, location:Vector2i) -> void:
	container = parent
	coord = location
	_ensure_orientation_steps()


func _ensure_orientation_steps() -> void:
	var tile_state := container.hex_manager.tiles[coord]
	if tile_state.orientation_steps < 0:
		tile_state.orientation_steps = HexCoord.pick_orientation_steps(coord)
	tile_orientation_steps = tile_state.orientation_steps


func _apply_tile_orientation() -> void:
	$visuals/Tile_Default.rotation_degrees.y = HexCoord.direction_to_yaw_degrees(tile_orientation_steps)

## ----- Interactions Logic ----- ##

func _on_mouse_entered() -> void:
	container.handle_hover(coord)
	$visuals/StylizedHexTile.material_override.albedo_color = visuals.color.darkened(0.3)
	
func _on_mouse_exited() -> void:
	container.handle_exit(coord)
	$visuals/StylizedHexTile.material_override.albedo_color = visuals.color

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

## ----- Update Visuals Logic ----- ##

func update_visuals(new_visuals:HexTileVisuals) -> void:
	visuals = new_visuals
	$visuals/StylizedHexTile.material_override.albedo_color = new_visuals.color
	$visuals/StylizedHexTile/elementIcon.texture = new_visuals.icon
	
	if new_visuals.animal_icon:
		$visuals/StylizedHexTile/animalIcon.texture = new_visuals.animal_icon
		$visuals/StylizedHexTile/animalIcon.show()
	else:
		$visuals/StylizedHexTile/animalIcon.texture = null
		$visuals/StylizedHexTile/animalIcon.hide()


func show_committed_setup() -> void:
	if committed_setup != null:
		_apply_setup_state(committed_setup)


func set_preview_setup(state: TileSetupState) -> void:
	if preview_setup != null and preview_setup.matches(state):
		_apply_setup_state(state)
		return

	preview_setup = state.duplicate_state()
	_apply_setup_state(preview_setup)


func discard_preview_setup() -> void:
	if preview_setup == null:
		return

	preview_setup = null
	show_committed_setup()


func commit_setup(state: TileSetupState) -> void:
	if preview_setup != null:
		committed_setup = preview_setup.duplicate_state()
		preview_setup = null
		return

	committed_setup = state.duplicate_state()
	_apply_setup_state(committed_setup)


func _apply_setup_state(state: TileSetupState) -> void:
	if state == null or state.setup == null:
		return

	var setup_signature := state.signature()
	if setup_signature == _displayed_setup_signature:
		return

	_displayed_setup_signature = setup_signature
	$visuals/Tile_Default.apply_setup(state.setup, state.get_context(), setup_signature)

## ----- Points Logic ----- ##

func show_points(points:int) -> void:
	$visuals/Sprite3D/Label3D.text = "%d" % points
	if points > 0:
		$visuals/Sprite3D.modulate = Color.GOLD
	if points < 0:
		$visuals/Sprite3D.modulate = Color.CRIMSON
	
	if points != 0:
		$visuals/Sprite3D.show()

func hide_points() -> void:
	$visuals/Sprite3D.hide()

## ----- Outline Logic ----- ##

func show_outline(color:Color) -> void:
	$visuals/outline.modulate = color
	$visuals/outline.show()
	
func hide_outline() -> void:
	$visuals/outline.hide()

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
	var sprite: Sprite3D = $visuals/Sprite3D
	var label: Label3D = $visuals/Sprite3D/Label3D
	if points > 0:
		label.text = "+%d" % points
		sprite.modulate = Color(1.0, 0.88, 0.35, 1.0)
	else:
		label.text = "%d" % points
		sprite.modulate = Color(0.95, 0.35, 0.35, 1.0)

	sprite.visible = true
	sprite.position.y = SCORE_POP_BASE_Y
	sprite.scale = Vector3(0.2, 0.2, 0.2)

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
	var outline: Sprite3D = $visuals/outline
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
	var tile_visuals: Node3D = $visuals
	var mesh: MeshInstance3D = $visuals/StylizedHexTile
	var material := mesh.material_override as StandardMaterial3D

	var lift := placed_lift if strong else contributor_lift
	var peak_scale := Vector3.ONE * (placed_scale_peak if strong else contributor_scale_peak)
	var glow_amount := placed_glow if strong else contributor_glow
	var rise_duration := placed_rise_duration if strong else contributor_rise_duration
	var settle_duration := placed_settle_duration if strong else contributor_settle_duration

	var base_color := visuals.color
	var glow_color := base_color.lightened(glow_amount)

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"celebrate")
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(tile_visuals, "position:y", lift, rise_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tile_visuals, "scale", peak_scale, rise_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color", glow_color, rise_duration * 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(tile_visuals, "position:y", 0.0, settle_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(tile_visuals, "scale", Vector3.ONE, settle_duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(material, "albedo_color", base_color, settle_duration * 0.85)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_reset_celebrate_visuals)

func _reset_score_pop_visuals() -> void:
	var sprite: Sprite3D = $visuals/Sprite3D
	sprite.hide()
	sprite.modulate = Color.WHITE
	sprite.position.y = SCORE_POP_BASE_Y
	sprite.scale = Vector3(0.5, 0.5, 0.5)

func _reset_outline_visuals() -> void:
	var outline: Sprite3D = $visuals/outline
	outline.hide()
	outline.modulate = Color.WHITE

func _reset_celebrate_visuals() -> void:
	var tile_visuals: Node3D = $visuals
	var mesh: MeshInstance3D = $visuals/StylizedHexTile
	var material := mesh.material_override as StandardMaterial3D
	tile_visuals.position = Vector3.ZERO
	tile_visuals.scale = Vector3.ONE
	if visuals:
		material.albedo_color = visuals.color
