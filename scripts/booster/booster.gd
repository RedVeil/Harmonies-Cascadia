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
		$Tooltip/Label.text = "Open the animal market (1 credit per animal)."

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
			GameFeedback.play_click_button()
			container.select_booster(id)
			viewport.set_input_as_handled()

## ----- Booster Visual Logic ----- ##

func set_booster_visuals(boosterData: BoosterData) -> void:
	if boosterData.type == 7:
		$Tooltip/Label.text = "Open the animal market (1 credit per animal)."
		return
	$Tooltip/Label.text = create_tooltip(boosterData)
	if boosterData.type < 6:
		var element = ElementCatalog.elements[boosterData.type]
		var level = element.levels[element.levels.size()-1]
		icon.texture = load(level.icon)
	elif boosterData.type == 6:
		icon.texture = load("res://assets/icons/random.png")


func create_tooltip(boosterData: BoosterData) -> String:
	var element_cards := [0,0,0,0,0,0]
	var animal_cards := [0,0,0,0,0,0]
	for c in boosterData.cards:
		if c.type == 0:
			element_cards[c.id] += 1
		else:
			animal_cards[c.element] += 1
	
	var contents : Array[String] = []
	for i in element_cards.size():
		if element_cards[i] > 0:
			contents.append("%d %ss" % [element_cards[i], Enums.ELEMENT_NAMES[i]])
	for i in animal_cards.size():
		if animal_cards[i] > 0:
			contents.append("%d %s Animals" % [animal_cards[i], Enums.ELEMENT_NAMES[i]])
	if boosterData.booster_points > 0:
		contents.append("%d Booster Points" % boosterData.booster_points)
	if boosterData.quest_ids.size() > 0:
		contents.append("%d Quests" % boosterData.quest_ids.size())
	if boosterData.map_points > 0:
		contents.append("%d Map Points" % boosterData.map_points)
	
	return "This booster contains:\n" + ", ".join(contents)
