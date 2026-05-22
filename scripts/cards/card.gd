extends Area2D
class_name Card

@export var scale_speed : float = 1.0
@export var bounce_height: float = 8.0
@export var bounce_speed: float = 12.0
@export var return_speed: float = 12.0

@onready var visuals : Node2D = $visuals
@onready var stacks : Node2D = $stacks
@onready var collision : CollisionShape2D = $CollisionShape2D
@onready var placement_tooltip : PlacementTooltip = $PlacementTooltip

var container : CardContainer
var id : int = 0

var is_hovered : bool = false
var is_active : bool = false
var base_scale: Vector2 = Vector2(0.1,0.1)
var target_scale : Vector2 = Vector2(0.1,0.1)
var bounce_time : float = 0.0
var base_visuals_position : Vector2 = Vector2.ZERO
var enable_stacking : bool = false
var stack_amount : int = 0
var background_color : Color
var is_booster : bool = false

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = true

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)

func init(cardData:CardData, parent:CardContainer, idx:int, stacking:bool, scale:Vector2, booster:bool) -> void:
	container = parent
	id = idx
	enable_stacking = stacking
	is_booster = booster
	
	target_scale = scale
	base_scale = scale
	
	collision.scale = scale
	placement_tooltip.scale = Vector2.ONE * scale 
	
	background_color = Color.html(ElementCatalog.elements[cardData.element].levels[0].color)
	$visuals/background.modulate = background_color
	
	var icon : Texture2D = load(cardData.icon)
	var texture_size := icon.get_size()
	var scale_factor = min(
		500 / texture_size.x,
		500 / texture_size.y
	)
	$visuals/icon.scale = Vector2.ONE * scale_factor
	$visuals/icon.texture = icon
	
	if !is_booster:
		placement_tooltip.init(cardData.type, cardData.placement, cardData.bonus)
		$visuals/Sprite2D/Label2.text = "?" if cardData.type == 0 else "%d" % cardData.point_score
		$visuals/Sprite2D.show()
	
	if enable_stacking:
		$visuals/Label.show()
		$visuals/Label.text = "%d | %d" % [stack_amount+1, 10]

## ----- Interactions Logic ----- ##

func _on_mouse_entered() -> void:
	is_hovered = true
	if !is_booster:
		placement_tooltip.show()

func _on_mouse_exited() -> void:
	is_hovered = false
	placement_tooltip.hide()

func _on_input_event(
	viewport: Viewport,
	event: InputEvent,
	shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			select()
			container.select_card(id)

## ----- Stack Logic ----- ##

func increment() -> void:
	if enable_stacking and stack_amount < 9:
		stack_amount += 1
		get_node("stacks/stack%d/background" % stack_amount).modulate = background_color
		get_node("stacks/stack%d" % stack_amount).show()
		$visuals/Label.text = "%d | %d" % [stack_amount+1, 10]

func decrement() -> void:
	if enable_stacking and stack_amount > 0:
		get_node("stacks/stack%d" % stack_amount ).hide()
		stack_amount -= 1
		$visuals/Label.text = "%d | %d" % [stack_amount+1, 10]

## ----- Other Logic ----- ##

func select():
	is_active = true
	target_scale = base_scale * 1.2
	collision.scale = target_scale
	placement_tooltip.scale = target_scale
	placement_tooltip.position.y -= 20

func deselect():
	is_active = false
	target_scale = base_scale
	collision.scale = target_scale
	placement_tooltip.scale = target_scale
	placement_tooltip.position.y += 20

func remove_card() -> void:
	queue_free()

## ----- Animation Logic ----- ##

func _process(delta: float) -> void:
	if visuals.scale != target_scale:
		visuals.scale = visuals.scale.lerp(target_scale, delta * scale_speed)
		stacks.scale = stacks.scale.lerp(target_scale, delta * scale_speed)
	
	if is_hovered and !is_active:
		bounce_time += delta
		var y_offset : float = -abs(sin(bounce_time * bounce_speed)) * bounce_height
		visuals.position = base_visuals_position + Vector2(0.0, y_offset)
	else:
		visuals.position = visuals.position.lerp(
			base_visuals_position,
			min(delta * return_speed, 1.0)
		)
