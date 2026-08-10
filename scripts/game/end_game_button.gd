extends Area2D
class_name EndGameButton

@export var orchestrator: Orchestrator

var enabled: bool = true
var is_hovered: bool = false
var timer: float = 0.5

var COLOR_BROWN := Color.html("#918478")


func _ready() -> void:
	_refresh_visuals()


func enable() -> void:
	enabled = true
	_refresh_visuals()


func disable() -> void:
	enabled = false
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()
	_refresh_visuals()


func _refresh_visuals() -> void:
	if enabled:
		$background.self_modulate = Color.WHITE
		$icon.self_modulate = COLOR_BROWN
	else:
		$background.self_modulate = Color.WHITE
		$icon.self_modulate = Color.GRAY


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and enabled:
			GameFeedback.play_click_button()
			orchestrator.end_game()


func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	if enabled:
		GameFeedback.play_hover_button()
		$background.self_modulate = COLOR_BROWN
		$icon.self_modulate = Color.WHITE
		is_hovered = true
		timer = 0.5


func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	if enabled:
		$background.self_modulate = Color.WHITE
		$icon.self_modulate = COLOR_BROWN
		is_hovered = false
		timer = 0.5
		$Tooltip.hide()


func _process(delta: float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()
