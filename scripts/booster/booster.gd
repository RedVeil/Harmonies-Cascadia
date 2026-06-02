extends Area2D
class_name Booster

@export var id : int = 0

@onready var icon : Sprite2D = $icon
@onready var background : Sprite2D = $background
@onready var collision : CollisionShape2D = $CollisionShape2D

var container : BoosterContainer

var is_hovered : bool = false
var timer : float = 0.5

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = true
	
	if id == 4:
		icon.texture = load("res://assets/icons/animal.png")
		$Tooltip/Label.text = "Buy this booster to get random animal cards."

func init(parent:BoosterContainer) -> void:
	container = parent

## ----- Interactions Logic ----- ##

func _process(delta:float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()

func _on_mouse_entered() -> void:
	background.self_modulate = Color.html("#918478")
	$icon.self_modulate = Color.WHITE
	is_hovered = true
	timer = 0.5
	
func _on_mouse_exited() -> void:
	background.self_modulate = Color.WHITE
	$icon.self_modulate = Color.html("#918478")
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()

func _on_input_event(
	viewport: Viewport,
	event: InputEvent,
	shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			container.select_booster(id)

## ----- Booster Visual Logic ----- ##

func set_booster_visuals(type:Enums.BOOSTER_TYPE) -> void:
	if type < 6:
		var element = ElementCatalog.elements[type]
		var level = element.levels[element.levels.size()-1]
		icon.texture = load(level.icon)
		$Tooltip/Label.text = "Buy this booster to get element and animal cards for %s." % element.name
