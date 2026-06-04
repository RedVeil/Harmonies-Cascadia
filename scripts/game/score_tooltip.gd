extends Node2D
class_name ScoringTooltip

var size : Vector2 = Vector2(44.0, 40.0)
var target_size : Vector2 = Vector2(44.0, 40.0)
var base_position : Vector2 = Vector2(0.0,0.0)
var target_position : Vector2 = Vector2(0.0,0.0)
var scale_speed : float = 10.0

@export var orchestrator : Orchestrator
var active_tooltip : int = -1

func _ready() -> void:
	var icons = $icons.get_children()
	for i in icons.size():
		icons[i].init(i, self)

func _process(delta: float) -> void:
	if $Button.position.distance_squared_to(target_position) >= 0.01:
		$Button.position = $Button.position.lerp(target_position, delta * scale_speed)
		$Panel.size = $Panel.size.lerp(target_size, delta * scale_speed)
	
	for icon in $icons.get_children():
		if icon.position.y + 30.0 <= $Button.position.y:
			icon.show()
		else:
			icon.hide()
	
func _on_button_mouse_entered() -> void:
	$Panel.get_theme_stylebox("panel").bg_color = Color.html("#918478")
	$Button/Sprite2D.self_modulate = Color.WHITE

func _on_button_mouse_exited() -> void:
	$Panel.get_theme_stylebox("panel").bg_color = Color.WHITE
	$Button/Sprite2D.self_modulate = Color.html("#918478")

func _on_button_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			GameFeedback.play_click_button()
			if target_position.y == 0.0:
				target_position = Vector2(0.0,280.0)
				target_size = Vector2(44.0, 320.0)
			else:
				target_position = Vector2(0.0,0.0)
				target_size = Vector2(44.0, 40.0)
				$Panel2.hide()

func handle_click_toolip(id:int) -> void:
	if active_tooltip == id:
		$Panel2.hide()
		active_tooltip = -1
	else:
		active_tooltip = id
		$Panel2.show()
		$Panel2/Panel.position.y = (id*50.0) + 4.0
		
		$Panel2/title/Label.text = get_title_text(id)
		$Panel2/description/Label.text = get_description(id)
		$Panel2/graphic/Sprite2D7.texture = get_desc_image(id)

func get_title_text(id:int) -> String:
	match(id):
		0:
			return "Forest"
		1:
			return "Field"
		2:
			return "Mountain"
		3:
			return "River"
		4:
			return "Wetland"
		_:
			return ""

func get_description(id:int) -> String:
	return orchestrator.get_active_rule(id+1).description

func get_desc_image(id:int) -> Texture2D:
	match(id):
		0:
			return load("res://assets/score_tooltip/forest0.png")
		1:
			return load("res://assets/score_tooltip/fields0.png")
		2:
			return load("res://assets/score_tooltip/mountain0.png")
		3:
			return load("res://assets/score_tooltip/river0.png")
		4:
			return load("res://assets/score_tooltip/wetland0.png")
		_:
			return load("res://assets/score_tooltip/forest0.png")
