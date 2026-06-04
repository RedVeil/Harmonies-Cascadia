extends Area2D
class_name Card

@export var scale_speed : float = 1.0
@export var hover_scale: float = 8.0
@export var hover_height: float = 12.0
@export var spawn_duration : float = 0.35
@export var redraw_duration : float = 0.22
@export var layout_duration : float = 0.25

@onready var visuals : Node2D = $visuals
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var placement_tooltip : PlacementTooltip = $PlacementTooltip

var container : CardContainer
var id : int = 0

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
var _layout_tween : Tween

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

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
	play_spawn_animation()

## ----- Interactions Logic ----- ##

func _on_mouse_entered() -> void:
	container.hover_card(id)

func _on_mouse_exited() -> void:
	container.exit_card(id)

func _on_input_event(
	viewport: Viewport,
	event: InputEvent,
	shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			container.select_card(id)

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
	queue_free()

## ----- Animation Logic ----- ##

func play_spawn_animation() -> void:
	_spawn_active = true
	visuals.scale = Vector2.ZERO
	visuals.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visuals, "scale", base_scale, spawn_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "modulate", Color.WHITE, spawn_duration * 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		_spawn_active = false
		visuals.scale = target_scale
	)

func play_redraw_animation() -> void:
	if _spawn_active:
		return
	_redraw_active = true
	var peak_scale := base_scale * 1.12
	var tween := create_tween()
	tween.tween_property(visuals, "scale", peak_scale, redraw_duration * 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", target_scale, redraw_duration * 0.65)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		_redraw_active = false
	)

func animate_layout(target_pos: Vector2, target_angle: float, z: int) -> void:
	set_z(z)
	var needs_motion := position.distance_squared_to(target_pos) > 0.25 \
		or absf(rotation_degrees - target_angle) > 0.1
	if not needs_motion:
		position = target_pos
		rotation_degrees = target_angle
		return
	if _layout_tween and _layout_tween.is_valid():
		_layout_tween.kill()
	_layout_tween = create_tween().set_parallel(true)
	_layout_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_layout_tween.tween_property(self, "position", target_pos, layout_duration)
	_layout_tween.tween_property(self, "rotation_degrees", target_angle, layout_duration)

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
