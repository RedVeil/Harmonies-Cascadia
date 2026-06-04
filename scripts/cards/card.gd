extends Area2D
class_name Card

@export var scale_speed : float = 1.0
@export var hover_scale: float = 8.0
@export var hover_height: float = 12.0

@onready var visuals : Node2D = $visuals
@onready var stacks : Node2D = $stacks
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
	var mat = $visuals/elementIcon.material.duplicate()
	mat.set_shader_parameter("unfilled_color", Color.html(ElementCatalog.elements[cardData.element].levels.back().color))
	$visuals/elementIcon.material = mat
	$visuals/points/background.material = mat
	if cardData.type == 1 and cardData.icon != "":
		var icon : Texture2D = load(cardData.icon)
		var texture_size := icon.get_size()
		var scale_factor = min(
			50 / texture_size.x,
			50 / texture_size.y
		)
		$visuals/icon.scale = Vector2.ONE * scale_factor
		$visuals/icon.texture = icon
		$visuals/icon.show()
		$visuals/elementIcon/Sprite2D.texture = load(ElementCatalog.elements[cardData.element].levels[cardData.placement[0].level-1].icon)
		$visuals/bonus_points/background.material = mat
		$visuals/bonus_points/Label.text = "%d" % cardData.bonus_points if cardData.bonus_points > 0.5 else "1/2"
		$visuals/bonus_points.show()
	else:
		$visuals/elementIcon/Sprite2D.texture = load(ElementCatalog.elements[cardData.element].levels.back().icon)

	placement_tooltip.init(cardData.type, cardData.placement, cardData.bonus)
	$visuals/points/Label.text = "?" if cardData.type == 0 else "%d" % cardData.point_score
	
	$visuals/Label.text = "%d | %d" % [stack_amount, 10]

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
		get_node("stacks/stack%d/background" % stack_amount).modulate = background_color
		get_node("stacks/stack%d" % stack_amount).show()
		$visuals/Label.text = "%d | %d" % [stack_amount, 10]

func decrement() -> void:
	if stack_amount > 0:
		get_node("stacks/stack%d" % stack_amount ).hide()
		stack_amount -= 1
		$visuals/Label.text = "%d | %d" % [stack_amount, 10]

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
	if visuals.scale.distance_squared_to(target_scale) >= 0.001 * 0.001:
		visuals.scale = visuals.scale.lerp(target_scale, delta * scale_speed)
		stacks.scale = stacks.scale.lerp(target_scale, delta * scale_speed)
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
