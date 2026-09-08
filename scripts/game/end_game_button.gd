extends Area2D
class_name EndGameButton

@export var orchestrator: Orchestrator

var enabled: bool = true
var is_hovered: bool = false
var timer: float = 0.5

func _ready() -> void:
	UiTheme.bind_node(self, _refresh_visuals)
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


func set_focus_hover(on: bool) -> void:
	if on:
		_on_mouse_entered()
	else:
		_on_mouse_exited()


func _refresh_visuals() -> void:
	UiTheme.apply_hud_circle($background, $icon, is_hovered, enabled)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not InputScheme.is_left_click(event) or not enabled:
		return
	GameFeedback.play_click_button()
	orchestrator.end_game()


func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	if enabled:
		GameFeedback.play_hover_button()
		is_hovered = true
		timer = 0.5
		_refresh_visuals()


func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()
	if enabled:
		_refresh_visuals()


func _process(delta: float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()
