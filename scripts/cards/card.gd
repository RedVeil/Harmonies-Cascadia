extends Area2D
class_name Card

@export var scale_speed : float = 1.0
@export var hover_scale: float = 8.0
@export var hover_height: float = 12.0
@export var exit_tween_duration: float = 0.3

@export_group("Spawn Animation")
@export var spawn_duration: float = 0.35
@export var spawn_origin: Vector2 = Vector2.ZERO
@export var spawn_play_sound: bool = true

@export_group("Redraw Animation")
@export var redraw_duration: float = 0.22
@export var redraw_peak_scale: float = 1.12
@export var redraw_play_sound: bool = true

@onready var visuals : Node2D = $visuals
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var placement_tooltip : PlacementTooltip = $PlacementTooltip

var container : CardContainer
var id : int = 0

var is_mouse_inside : bool = false
var exit_tween : Tween

var is_active : bool = false
var base_scale: Vector2 = Vector2.ONE
var target_scale : Vector2 =  Vector2.ONE
var base_visuals_position : Vector2 = Vector2.ZERO
var target_visuals_position : Vector2 = Vector2.ZERO
var stack_amount : int = 0
var background_color : Color
var base_z_index : int = 0

var element_id : int = 0
var is_animal:bool = false

var _spawn_active : bool = false
var _redraw_active : bool = false
var _spawn_layout_pending : bool = false
var _feedback_tweens: Dictionary = {}

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	# $visuals/background.material = $visuals/background.material.duplicate(true)

func init(cardData:CardData, parent:CardContainer, idx:int) -> void:
	container = parent
	id = idx
	
	stack_amount = cardData.amount
	
	element_id = cardData.element
	is_animal = cardData.type == 1
	
	$visuals/background.texture = load(get_card_background(cardData.element))
	
	var mat = $visuals/element.material.duplicate()
	mat.set_shader_parameter("unfilled_color", Color.html(ElementCatalog.elements[cardData.element].levels.back().color))
	$visuals/element.material = mat
	$visuals/points/background.material = mat
	
	if cardData.type == 1 and cardData.icon != "":
		var icon : Texture2D = load(cardData.icon)
		$visuals/animal.texture = icon
		$visuals/animal.show()
		
		$visuals/element/icon.texture = load(ElementCatalog.elements[cardData.element].levels[cardData.placement[0].level-1].icon)
		
		$visuals/bonus_points/background.material = mat
		$visuals/bonus_points/Label.text = "%d" % cardData.bonus_points if cardData.bonus_points > 0.5 else "1/2"
		$visuals/bonus_points.show()
	else:
		$visuals/element/icon.texture = load(ElementCatalog.elements[cardData.element].levels.back().icon)

	placement_tooltip.init(cardData.type, cardData.placement, cardData.bonus)
	$visuals/points/Label.text = "?" if cardData.type == 0 else "%d" % cardData.point_score
	
	$visuals/Label.text = "x %d" % stack_amount

func mark_spawn_layout() -> void:
	_spawn_layout_pending = true

func consume_spawn_layout() -> bool:
	var pending := _spawn_layout_pending
	_spawn_layout_pending = false
	return pending

## ----- Interactions Logic ----- ##

func _on_mouse_entered() -> void:
	is_mouse_inside = true
	container.hover_card(id)
	

func _on_mouse_exited() -> void:
	is_mouse_inside = false
	container.exit_card(id)
	#setNormalState()
	

func _on_input_event(
	viewport: Viewport,
	event: InputEvent,
	shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			GameFeedback.play_click_card()
			container.select_card(id)
	
	#if event is InputEventMouseMotion and is_mouse_inside:
		#var mouse_position = event.position
		#var relative_mouse_position = mouse_position - global_position
		#
		##divide by scale to make independant of scale
		##subtract by size/2.0 to center the mouse pos
		## var centred_mouse_postion = relative_mouse_position/scale - $visuals/background.size/2.0
		#
		#$visuals/background.material.set_shader_parameter("_mousePos", relative_mouse_position)

## ----- Stack Logic ----- ##

func increment() -> void:
	if stack_amount < 10:
		stack_amount += 1
		$visuals/Label.text = "x %d " % stack_amount
		play_redraw_animation()

func decrement() -> void:
	if stack_amount > 0:
		stack_amount -= 1
		$visuals/Label.text = "x %d" % stack_amount

## ----- Other Logic ----- ##

func handle_hover() -> void:
	placement_tooltip.show()
	if !is_active:
		GameFeedback.play_hover_card()
		set_select_visuals()

func handle_exit() -> void:
	placement_tooltip.hide()
	if !is_active:
		reset_select_visuals()

func select() -> void:
	is_active = true
	self.z_index = base_z_index + 100
	if target_visuals_position == base_visuals_position:
		set_select_visuals()

func deselect() -> void:
	is_active = false
	self.z_index = base_z_index
	reset_select_visuals()

func remove_card() -> void:
	kill_animations()
	queue_free()

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

func _animate_spawn(target_pos: Vector2, target_angle: float, z: int) -> void:
	if spawn_play_sound:
		GameFeedback.play_draw_card()

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
	if redraw_play_sound:
		GameFeedback.play_draw_card()

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

func set_z(z:int) -> void:
	base_z_index = z
	self.z_index = base_z_index

func set_select_visuals() -> void:
	self.z_index = base_z_index + 20
	target_scale = base_scale * hover_scale
	collision.scale = target_scale
	# placement_tooltip.scale = target_scale
	target_visuals_position = visuals.position - Vector2(0.0, hover_height)

func reset_select_visuals() -> void:
	self.z_index = base_z_index
	target_scale = base_scale
	collision.scale = target_scale
	# placement_tooltip.scale = target_scale
	target_visuals_position = base_visuals_position

func _process(delta: float) -> void:
	if _spawn_active or _redraw_active:
		return
	if visuals.scale.distance_squared_to(target_scale) >= 0.001 * 0.001:
		visuals.scale = visuals.scale.lerp(target_scale, delta * scale_speed)
		visuals.position = visuals.position.lerp(target_visuals_position, delta * scale_speed)
		collision.position = collision.position.lerp(target_visuals_position, delta * scale_speed)

func get_card_background(element:int) -> String:
	match(element):
		1:
			return "res://assets/cards/forest_card.png"
		2:
			return "res://assets/cards/field_card.png"
		3:
			return "res://assets/cards/mountain_card.png"
		4:
			return "res://assets/cards/river_card.png"
		5:
			return "res://assets/cards/wetland_card.png"
		_:
			return "res://assets/cards/forest_card.png"
