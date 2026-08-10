extends Area2D
class_name Card

@export var scale_speed : float = 1.0
@export var hover_scale: float = 8.0
@export var hover_height: float = 12.0
@export var exit_tween_duration: float = 0.3

@export_group("Spawn Animation")
@export var spawn_duration: float = 0.35
@export var spawn_origin: Vector2 = Vector2.ZERO
@export var spawn_sounds: Array[AudioStream] = []
@export var spawn_sound_volume_db: float = -10.0

@export_group("Redraw Animation")
@export var redraw_duration: float = 0.22
@export var redraw_peak_scale: float = 1.12
@export var redraw_sounds: Array[AudioStream] = []
@export var redraw_sound_volume_db: float = -10.0

const STACK_STEP_PX := 10.0
const STACK_VISUAL_CAP := 4

@onready var visuals : Node2D = $visuals
@onready var hit_area : Control = $HitArea
@onready var placement_tooltip : PlacementTooltip = $PlacementTooltip
@onready var frame : TextureRect = $visuals/Frame
@onready var frame_2 : TextureRect = $visuals/Frame2
@onready var frame_3 : TextureRect = $visuals/Frame3
@onready var frame_4 : TextureRect = $visuals/Frame4
@onready var shadow : TextureRect = $visuals/Shadow

var container : CardContainer
var _interaction_host: Node = null
var id : int = 0

var is_mouse_inside : bool = false
var exit_tween : Tween

var is_active : bool = false
var base_scale: Vector2 = Vector2.ONE
var target_scale : Vector2 =  Vector2.ONE
var base_visuals_position : Vector2 = Vector2.ZERO
var target_visuals_position : Vector2 = Vector2.ZERO
var _hit_area_base_position: Vector2 = Vector2.ZERO
var _hit_area_base_offset_top: float = 0.0
var _shadow_base_offset_top: float = 0.0
var stack_amount : int = 0
var background_color : Color
var base_z_index : int = 0

var element_id : int = 0
var is_animal:bool = false

var _spawn_active : bool = false
var _redraw_active : bool = false
var _spawn_layout_pending : bool = false
var _feedback_tweens: Dictionary = {}
## Sticky hover for touch: survives mouse_exit until another card is hovered or selected.
var _touch_hover_sticky: bool = false

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = false
	_hit_area_base_offset_top = hit_area.offset_top
	_shadow_base_offset_top = shadow.offset_top
	_hit_area_base_position = hit_area.position
	hit_area.pivot_offset = hit_area.size * 0.5
	hit_area.mouse_entered.connect(_on_mouse_entered)
	hit_area.mouse_exited.connect(_on_mouse_exited)
	hit_area.gui_input.connect(_on_gui_input)
	
func init(cardData:CardData, parent:Node, idx:int) -> void:
	if parent is CardContainer:
		container = parent
	_interaction_host = parent
	id = idx
	
	stack_amount = cardData.amount
	
	element_id = cardData.element
	is_animal = cardData.type == 1

	var mat = $visuals/points/background.material.duplicate()
	mat.set_shader_parameter("unfilled_color", Color.html(ElementCatalog.elements[cardData.element].levels.back().color))
	$visuals/points/background.material = mat
	var frame_mat = frame.material.duplicate()
	frame_mat.set_shader_parameter("body_color", Color.html(ElementCatalog.elements[cardData.element].levels.back().color))
	frame_mat.set_shader_parameter("name_color", Color(0.16, 0.17, 0.253, 1))
	frame.material = frame_mat
	frame_2.material = frame_mat
	frame_3.material = frame_mat
	frame_4.material = frame_mat
	
	placement_tooltip.init(cardData.type, cardData.placement, cardData.bonus)
	$visuals/points/Label.text = "%d" % cardData.point_score
	$visuals/CardLabel.text = cardData.name
	_apply_stack_visuals()
	
	$visuals/icon.texture = load(cardData.icon)
	$visuals/icon.show()
	
	if cardData.type == 1:
		$visuals/bonus_points/background.material = mat
		$visuals/bonus_points/Label.text = "+%d" % cardData.bonus_points
		$visuals/bonus_points.show()
		$visuals/points.show()
		
		$visuals/elementicon.texture = load(ElementCatalog.elements[cardData.element].levels[cardData.placement[0].level-1].icon)
		$visuals/elementicon.show()


## ----- Layout Logic ----- ##

func mark_spawn_layout() -> void:
	_spawn_layout_pending = true

func consume_spawn_layout() -> bool:
	var pending := _spawn_layout_pending
	_spawn_layout_pending = false
	return pending

## ----- Interactions Logic ----- ##

func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	is_mouse_inside = true
	# Touch uses tap-to-hover; skip enter-driven hover so single tap stays distinct.
	if TouchMode.is_touch():
		return
	if _interaction_host and _interaction_host.has_method("hover_card"):
		_interaction_host.hover_card(id)
	

func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	is_mouse_inside = false
	if TouchMode.is_touch() and _touch_hover_sticky:
		return
	if _interaction_host and _interaction_host.has_method("exit_card"):
		_interaction_host.exit_card(id)
	

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if TouchMode.is_touch():
				if event.double_click:
					_touch_hover_sticky = false
					GameFeedback.play_click_card()
					if _interaction_host and _interaction_host.has_method("select_card"):
						_interaction_host.select_card(id)
				else:
					_touch_hover_sticky = true
					if _interaction_host and _interaction_host.has_method("hover_card"):
						_interaction_host.hover_card(id)
				get_viewport().set_input_as_handled()
				return
			GameFeedback.play_click_card()
			if _interaction_host and _interaction_host.has_method("select_card"):
				_interaction_host.select_card(id)
			get_viewport().set_input_as_handled()

## ----- Stack Logic ----- ##

func set_stack_amount(amount: int, animate: bool = true) -> void:
	if stack_amount == amount:
		return
	stack_amount = amount
	_apply_stack_visuals()
	if animate:
		play_redraw_animation()

func increment() -> void:
	set_stack_amount(stack_amount + 1)

func decrement() -> void:
	if stack_amount > 0:
		set_stack_amount(stack_amount - 1, false)

func _apply_stack_visuals() -> void:
	var depth := mini(maxi(stack_amount, 1), STACK_VISUAL_CAP)
	frame_2.visible = depth >= 2
	frame_3.visible = depth >= 3
	frame_4.visible = depth >= 4

	var extra := float(depth - 1) * STACK_STEP_PX
	shadow.offset_top = _shadow_base_offset_top - extra
	hit_area.offset_top = _hit_area_base_offset_top - extra
	hit_area.pivot_offset = hit_area.size * 0.5
	_hit_area_base_position = hit_area.position
	_sync_hit_area_to_visuals()

## ----- Other Logic ----- ##

func handle_hover() -> void:
	placement_tooltip.show()
	if !is_active:
		GameFeedback.play_hover_card()
		set_select_visuals()

func handle_exit() -> void:
	_touch_hover_sticky = false
	placement_tooltip.hide()
	if !is_active:
		reset_select_visuals()

func select() -> void:
	is_active = true
	_touch_hover_sticky = false
	self.z_index = base_z_index + 100
	if target_visuals_position == base_visuals_position:
		set_select_visuals()

func deselect() -> void:
	is_active = false
	_touch_hover_sticky = false
	self.z_index = base_z_index
	reset_select_visuals()
	placement_tooltip.hide()

func remove_card() -> void:
	kill_animations()
	queue_free()

func set_select_visuals() -> void:
	self.z_index = base_z_index + 20
	target_scale = base_scale * hover_scale
	target_visuals_position = base_visuals_position - Vector2(0.0, hover_height)

func reset_select_visuals() -> void:
	self.z_index = base_z_index
	target_scale = base_scale
	target_visuals_position = base_visuals_position

func set_z(z:int) -> void:
	base_z_index = z
	self.z_index = base_z_index

## ----- Animations ----- ##

func play_spawn_animation(target_pos: Vector2, target_angle: float, z: int) -> void:
	play_animation(&"spawn", {
		"target_pos": target_pos,
		"target_angle": target_angle,
		"z": z,
	})

func play_redraw_animation() -> void:
	if _spawn_active:
		return
	play_animation(&"redraw", {})

func play_animation(name: StringName, params: Dictionary) -> void:
	match name:
		&"spawn":
			_animate_spawn(
				params.get("target_pos", position),
				params.get("target_angle", rotation_degrees),
				params.get("z", base_z_index)
			)
		&"redraw":
			_animate_redraw()

func kill_animations() -> void:
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	_spawn_active = false
	_redraw_active = false

func is_spawn_feedback_active() -> bool:
	return _spawn_active

func apply_layout(target_pos: Vector2, target_angle: float, z: int) -> void:
	set_z(z)
	position = target_pos
	rotation_degrees = target_angle

func _process(delta: float) -> void:
	if not (_spawn_active or _redraw_active):
		if visuals.scale.distance_squared_to(target_scale) >= 0.001 * 0.001:
			visuals.scale = visuals.scale.lerp(target_scale, delta * scale_speed)
			visuals.position = visuals.position.lerp(target_visuals_position, delta * scale_speed)
		elif visuals.position.distance_squared_to(target_visuals_position) >= 0.01 * 0.01:
			visuals.position = visuals.position.lerp(target_visuals_position, delta * scale_speed)
	_sync_hit_area_to_visuals()


func _sync_hit_area_to_visuals() -> void:
	hit_area.scale = visuals.scale
	hit_area.position = _hit_area_base_position + visuals.position

func _animate_spawn(target_pos: Vector2, target_angle: float, z: int) -> void:
	FeedbackAnimHelper.play_sounds(spawn_sounds, spawn_sound_volume_db)

	_spawn_active = true
	set_z(z)
	position = spawn_origin
	rotation_degrees = 0.0
	visuals.scale = Vector2.ZERO
	visuals.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"spawn", true)
	tween.tween_property(visuals, "scale", base_scale, spawn_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "modulate", Color.WHITE, spawn_duration * 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, spawn_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", target_angle, spawn_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		_spawn_active = false
		position = target_pos
		rotation_degrees = target_angle
		visuals.scale = target_scale
	)

func _animate_redraw() -> void:
	FeedbackAnimHelper.play_sounds(redraw_sounds, redraw_sound_volume_db)

	_redraw_active = true
	var peak_scale := base_scale * redraw_peak_scale
	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"redraw")
	tween.tween_property(visuals, "scale", peak_scale, redraw_duration * 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", target_scale, redraw_duration * 0.65)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		_redraw_active = false
	)
