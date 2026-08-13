extends Node2D
class_name ScoringTooltip

var size : Vector2 = Vector2(44.0, 40.0)
var target_size : Vector2 = Vector2(44.0, 40.0)
var base_position : Vector2 = Vector2(0.0,0.0)
var target_position : Vector2 = Vector2(0.0,0.0)
var scale_speed : float = 10.0

@export var orchestrator : Orchestrator
var active_tooltip : int = -1
var _strip_blocking: bool = false

## ----- Initialisation ----- ##

func _ready() -> void:
	var icons = $icons.get_children()
	for i in icons.size():
		icons[i].init(i, self)

## ----- Panel Logic ----- ##

func _process(delta: float) -> void:
	if $Button.position.distance_squared_to(target_position) >= 0.01:
		$Button.position = $Button.position.lerp(target_position, delta * scale_speed)
		$Panel.size = $Panel.size.lerp(target_size, delta * scale_speed)
	
	for icon in $icons.get_children():
		if icon.position.y + 30.0 <= $Button.position.y:
			icon.show()
		else:
			icon.hide()
	_update_pointer_block()

func _update_pointer_block() -> void:
	# Panel uses mouse_filter IGNORE so Area2D icons still pick; manually block tiles under the strip/popup.
	var mouse := get_viewport().get_mouse_position()
	var over = $Panel.get_global_rect().has_point(mouse)
	if $Panel2.visible:
		over = over or $Panel2.get_global_rect().has_point(mouse)
	if over == _strip_blocking:
		return
	_strip_blocking = over
	UiPointerBlock.set_hovering(self, over)

## ----- Interactions Logic ----- ##

func _on_button_mouse_entered() -> void:
	GameFeedback.play_hover_button()
	$Panel.get_theme_stylebox("panel").bg_color = Color.html("#918478")
	$Button/Sprite2D.self_modulate = Color.WHITE

func _on_button_mouse_exited() -> void:
	$Panel.get_theme_stylebox("panel").bg_color = Color.WHITE
	$Button/Sprite2D.self_modulate = Color.html("#918478")

func _on_button_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var expanding := target_position.y == 0.0
			if orchestrator and orchestrator.tutorial_bridge.active:
				if not orchestrator.tutorial_bridge.allows_action("open_scoring"):
					return
			GameFeedback.play_click_button()
			if expanding:
				GameFeedback.play_open_popup()
				target_position = Vector2(0.0,321.0)
				target_size = Vector2(44.0, 360.0)
				if orchestrator:
					orchestrator.tutorial_bridge.notify("scoring_opened")
			else:
				GameFeedback.play_close_popup()
				target_position = Vector2(0.0,0.0)
				target_size = Vector2(44.0, 40.0)
				if active_tooltip != -1:
					active_tooltip = -1
				$Panel2.hide()

func handle_click_toolip(id:int) -> void:
	if id == 5:
		if orchestrator and orchestrator.tutorial_bridge.active:
			if not orchestrator.tutorial_bridge.allows_action("open_tutorial"):
				return
		if active_tooltip != -1:
			GameFeedback.play_close_popup()
		active_tooltip = -1
		$Panel2.hide()
		orchestrator.show_tutorial()
		if orchestrator:
			orchestrator.tutorial_bridge.notify("tutorial_opened")
		return

	if orchestrator and orchestrator.tutorial_bridge.active:
		if not orchestrator.tutorial_bridge.allows_action("open_scoring_rule"):
			return
		# Tutorial forest step only unlocks the Forest icon (id 0).
		if id != 0:
			return

	if active_tooltip == id:
		GameFeedback.play_close_popup()
		$Panel2.hide()
		active_tooltip = -1
		if orchestrator:
			orchestrator.tutorial_bridge.notify("scoring_rule_closes", {"rule_icon_id": id})
	else:
		GameFeedback.play_open_popup()
		active_tooltip = id
		$Panel2.show()
		$Panel2/Panel.position.y = (id*50.0) + 4.0
		
		$Panel2/title/Label.text = orchestrator.get_active_rule(id+1).name
		$Panel2/description/Label.text = orchestrator.get_active_rule(id+1).description
		$Panel2/graphic/Sprite2D7.texture = get_desc_image(orchestrator.get_active_rule(id+1).id)
		if orchestrator:
			orchestrator.tutorial_bridge.notify("scoring_rule_opened", {"rule_icon_id": id})

## ----- Tooltip Content Logic ----- ##

func get_desc_image(id:int) -> Texture2D:
	match(id):
		0:
			return load("res://assets/score_tooltip/f1.webp")
		1:
			return load("res://assets/score_tooltip/f2.webp")
		2:
			return load("res://assets/score_tooltip/f3.webp")
		3:
			return load("res://assets/score_tooltip/a1.webp")
		4:
			return load("res://assets/score_tooltip/a2.webp")
		5:
			return load("res://assets/score_tooltip/a3.webp")
		6:
			return load("res://assets/score_tooltip/m1.webp")
		7:
			return load("res://assets/score_tooltip/m2.webp")
		8:
			return load("res://assets/score_tooltip/m3.webp")
		9:
			return load("res://assets/score_tooltip/r1.webp")
		10:
			return load("res://assets/score_tooltip/r2.webp")
		11:
			return load("res://assets/score_tooltip/r3.webp")
		12:
			return load("res://assets/score_tooltip/w1.webp")
		13:
			return load("res://assets/score_tooltip/w2.webp")
		14:
			return load("res://assets/score_tooltip/w3.webp")
		_:
			return load("res://assets/score_tooltip/f1.webp")
