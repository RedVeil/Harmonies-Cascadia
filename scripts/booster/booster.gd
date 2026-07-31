extends Area2D
class_name Booster

const CIRCLE_TEXTURE := preload("res://assets/icons/circle.png")
const DOT_SCALE := 0.022
const DOT_RING_RADIUS := 10.0

@export var id: int = 0

@onready var icon: Sprite2D = $icon
@onready var background: Sprite2D = $background
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var progress_sprite: Sprite2D = $ProgressBar
@onready var content_dots: Node2D = $ContentDots

var container: BoosterContainer
var enabled: bool = true

var is_hovered: bool = false
var timer: float = 0.5

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = true
	if progress_sprite and progress_sprite.material:
		progress_sprite.material = progress_sprite.material.duplicate()
	if id == 3:
		$Tooltip/Label.text = "Refresh the three booster options (shares cooldown with market refresh)."
	elif id == 4:
		icon.texture = load("res://assets/icons/animal.png")
		$Tooltip/Label.text = "Open the animal market."

func init(parent: BoosterContainer) -> void:
	container = parent

## ----- State Logic ----- ##

func enable() -> void:
	enabled = true
	background.self_modulate = Color.WHITE
	icon.self_modulate = Color.html("#918478")
	content_dots.modulate = Color.WHITE

func disable() -> void:
	enabled = false
	background.self_modulate = Color.WHITE
	icon.self_modulate = Color.GRAY
	content_dots.modulate = Color(1, 1, 1, 0.45)
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()

func set_progress(value: float) -> void:
	if progress_sprite == null or progress_sprite.material == null:
		return
	var mat := progress_sprite.material as ShaderMaterial
	mat.set_shader_parameter("current_value", 0.0)
	mat.set_shader_parameter("lerp_value", clampf(value, 0.0, 1.0))
	mat.set_shader_parameter("third_value", 0.0)

## ----- Interactions Logic ----- ##

func _process(delta: float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()

func _on_mouse_entered() -> void:
	if not enabled:
		return
	background.self_modulate = Color.html("#918478")
	icon.self_modulate = Color.WHITE
	is_hovered = true
	timer = 0.5

func _on_mouse_exited() -> void:
	if not enabled:
		return
	background.self_modulate = Color.WHITE
	icon.self_modulate = Color.html("#918478")
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()


func _on_input_event(
	viewport: Viewport,
	event: InputEvent,
	shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and enabled:
			GameFeedback.play_click_button()
			container.select_booster(id)
			viewport.set_input_as_handled()

## ----- Booster Visual Logic ----- ##

func set_booster_visuals(boosterData: BoosterData) -> void:
	if boosterData.type == 7:
		icon.visible = true
		icon.texture = load("res://assets/icons/animal.png")
		$Tooltip/Label.text = "Open the animal market."
		_clear_content_dots()
		return
	$Tooltip/Label.text = create_tooltip(boosterData)
	if boosterData.type < 6:
		icon.visible = true
		var element = ElementCatalog.elements[boosterData.type]
		var level = element.levels[element.levels.size() - 1]
		icon.texture = load(level.icon)
		_clear_content_dots()
	elif boosterData.type == 6:
		icon.visible = false
		icon.texture = load("res://assets/icons/random.png")
		_update_content_dots(boosterData)


func create_tooltip(boosterData: BoosterData) -> String:
	var element_cards := [0, 0, 0, 0, 0, 0]
	var animal_cards := [0, 0, 0, 0, 0, 0]
	for c in boosterData.cards:
		if c.type == 0:
			element_cards[c.id] += 1
		else:
			animal_cards[c.element] += 1
	
	var contents: Array[String] = []
	for i in element_cards.size():
		if element_cards[i] > 0:
			contents.append("%d %ss" % [element_cards[i], Enums.ELEMENT_NAMES[i]])
	for i in animal_cards.size():
		if animal_cards[i] > 0:
			contents.append("%d %s Animals" % [animal_cards[i], Enums.ELEMENT_NAMES[i]])
	if boosterData.quest_ids.size() > 0:
		contents.append("%d Quests" % boosterData.quest_ids.size())
	if boosterData.map_points > 0:
		contents.append("%d Map Points" % boosterData.map_points)
	
	return "This booster contains:\n" + ", ".join(contents)


func _update_content_dots(boosterData: BoosterData) -> void:
	_clear_content_dots()
	var element_ids: Array[int] = []
	for c in boosterData.cards:
		if c.type == 0:
			element_ids.append(c.id)
		else:
			element_ids.append(c.element)
	_layout_content_dots(element_ids)


func _clear_content_dots() -> void:
	for child in content_dots.get_children():
		child.free()


func _layout_content_dots(element_ids: Array[int]) -> void:
	var count := element_ids.size()
	if count == 0:
		return

	for i in count:
		var pos := Vector2.ZERO
		if count > 1:
			var angle := -PI * 0.5 + TAU * float(i) / float(count)
			pos = Vector2(cos(angle), sin(angle)) * DOT_RING_RADIUS

		var element_id: int = element_ids[i]
		var color := Color.html("#918478")
		if element_id >= 0 and element_id < ElementCatalog.elements.size():
			var element: Element = ElementCatalog.elements[element_id]
			if element.levels.size() > 0:
				color = Color.html(element.levels[0].color)

		var dot := Sprite2D.new()
		dot.texture = CIRCLE_TEXTURE
		dot.scale = Vector2.ONE * DOT_SCALE
		dot.position = pos
		dot.self_modulate = color
		content_dots.add_child(dot)
