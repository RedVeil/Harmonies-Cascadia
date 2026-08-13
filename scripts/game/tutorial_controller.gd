extends Node
class_name TutorialController
## Loads data/tutorial_config.json steps, applies gates, drives TutorialCoach.

@export var orchestrator: Orchestrator
@export var coach: TutorialCoach

var _steps: Array = []
var _index: int = -1
var _current: Dictionary = {}
var _waiting_action: String = ""
var _active: bool = false
var _advance_timer: Timer


func _ready() -> void:
	_advance_timer = Timer.new()
	_advance_timer.one_shot = true
	add_child(_advance_timer)
	_advance_timer.timeout.connect(_advance)
	if coach:
		coach.continue_pressed.connect(_on_continue)
		coach.skip_pressed.connect(_on_skip)
	if orchestrator:
		if not orchestrator.tutorial_action.is_connected(_on_tutorial_action):
			orchestrator.tutorial_action.connect(_on_tutorial_action)
	if GameSession.is_tutorial():
		call_deferred("start")


func start() -> void:
	GameSettings.mark_tutorial_played()
	_steps = GameSession.get_tutorial_steps()
	if _steps.is_empty():
		push_warning("TutorialController: no steps in tutorial_config.json")
		return
	_active = true
	_index = -1
	_advance()


func stop(mark_completed: bool = true) -> void:
	_active = false
	_waiting_action = ""
	_current = {}
	if _advance_timer:
		_advance_timer.stop()
	if orchestrator:
		orchestrator.clear_tutorial_gates()
		orchestrator.close_in_game_menu()
	if coach:
		coach.hide_coach()
	if mark_completed:
		GameSettings.mark_tutorial_completed()


func _advance() -> void:
	_index += 1
	while _index < _steps.size():
		var step: Dictionary = _steps[_index]
		if _should_skip(step):
			_index += 1
			continue
		_enter_step(step)
		return
	_finish()


func _should_skip(step: Dictionary) -> bool:
	var skip_if = step.get("skip_if", null)
	if typeof(skip_if) != TYPE_DICTIONARY:
		return false
	match str(skip_if.get("type", "")):
		"has_placed_tile":
			return orchestrator != null and orchestrator.has_placed_tile()
		_:
			return false


func _enter_step(step: Dictionary) -> void:
	_current = step
	var gates: Dictionary = step.get("gates", {})
	if typeof(gates) != TYPE_DICTIONARY:
		gates = {}
	if orchestrator:
		orchestrator.set_tutorial_gates(gates)

	var complete: Dictionary = step.get("complete", {})
	var complete_type := str(complete.get("type", "continue_button"))
	_waiting_action = ""
	var show_continue := false
	match complete_type:
		"continue_button":
			show_continue = true
		"action":
			_waiting_action = str(complete.get("action", ""))
			show_continue = false
		"action_or_continue":
			_waiting_action = str(complete.get("action", ""))
			show_continue = true
		_:
			show_continue = true

	if coach:
		coach.show_step(step, str(step.get("highlight", "")), show_continue)


func _on_tutorial_action(action: String, _payload: Dictionary) -> void:
	if not _active:
		return
	if _waiting_action.is_empty():
		return
	if action == _waiting_action:
		if action == "code_shared" and orchestrator:
			orchestrator.close_in_game_menu()
		_schedule_advance()


func _schedule_advance() -> void:
	if _advance_timer and not _advance_timer.is_stopped():
		return
	var complete: Dictionary = _current.get("complete", {})
	var delay := float(complete.get("delay", 0.0))
	_waiting_action = ""
	if delay > 0.0:
		_advance_timer.start(delay)
		return
	_advance()


func _on_continue() -> void:
	if not _active:
		return
	var complete: Dictionary = _current.get("complete", {})
	var complete_type := str(complete.get("type", ""))
	if complete_type == "continue_button" or complete_type == "action_or_continue":
		_schedule_advance()


func _on_skip() -> void:
	stop(true)
	if orchestrator:
		orchestrator.leave_to_menu()


func _finish() -> void:
	stop(true)
	if orchestrator:
		orchestrator.leave_to_menu()
