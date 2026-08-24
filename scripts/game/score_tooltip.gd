extends Node2D
class_name ScoringTooltip

@export var orchestrator: Orchestrator

var COLOR_BROWN := Color.html("#918478")

## ----- Interactions Logic ----- ##

func _on_button_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	GameFeedback.play_hover_button()
	$Button/background.self_modulate = COLOR_BROWN
	$Button/icon.self_modulate = Color.WHITE

func _on_button_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	$Button/background.self_modulate = Color.WHITE
	$Button/icon.self_modulate = COLOR_BROWN


func set_focus_hover(on: bool) -> void:
	if on:
		_on_button_mouse_entered()
	else:
		_on_button_mouse_exited()

func _on_button_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not InputScheme.is_left_click(event):
		return
	if orchestrator == null:
		return
	var overlay := orchestrator.tutorial_overlay
	if overlay != null and overlay.visible:
		GameFeedback.play_click_button()
		overlay.close()
		return
	if orchestrator.tutorial_bridge.active:
		if not orchestrator.tutorial_bridge.allows_action("open_scoring"):
			return
	GameFeedback.play_click_button()
	await orchestrator.show_score_help()
	orchestrator.tutorial_bridge.notify("scoring_opened")
