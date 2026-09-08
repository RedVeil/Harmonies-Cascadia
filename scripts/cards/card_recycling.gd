extends Area2D
class_name CardRecycling

@export var orchestrator : Orchestrator
@export var recycling_value : int = 2

var enabled : bool = false
var is_hovered : bool = false
var timer : float = 0.5

## ----- Initialisation ----- ##

func _ready() -> void:
	UiTheme.bind_node(self, _apply_theme)
	_apply_theme()

## ----- State Logic ----- ##

func enable() -> void:
	enabled = true
	_apply_theme()

func disable() -> void:
	enabled = false
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()
	_apply_theme()


func _apply_theme() -> void:
	UiTheme.apply_hud_circle($background, $icon, is_hovered, enabled)

## ----- Interactions Logic ----- ##

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if not InputScheme.is_left_click(event) or not enabled:
		return
	orchestrator.apply_recycle_card(-1, recycling_value, false)

func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	if enabled:
		GameFeedback.play_hover_button()
		is_hovered = true
		timer = 0.5
		_apply_theme()
		orchestrator.preview_recycle_card(-1, recycling_value, false)

func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()
	if enabled:
		_apply_theme()
		orchestrator.reset_recycle_card_preview()


func set_focus_hover(on: bool) -> void:
	if on:
		_on_mouse_entered()
	else:
		_on_mouse_exited()


## ----- Tooltip Logic ----- ##

func _process(delta:float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()
