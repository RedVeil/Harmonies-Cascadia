extends Node
class_name TutorialController
## Loads data/tutorial_config.json steps, applies gates, drives TutorialCoach.

@export var orchestrator: Orchestrator
@export var coach: TutorialCoach

var _steps: Array = []
var _parts: Array = []
var _index: int = -1
var _current: Dictionary = {}
var _waiting_action: String = ""
var _active: bool = false
var _advance_timer: Timer
var _break_shown_for_index: int = -1


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
	_parts = GameSession.get_tutorial_parts()
	if _steps.is_empty():
		push_warning("TutorialController: no steps in tutorial_config.json")
		return
	_active = true
	_break_shown_for_index = -1
	var start_index := GameSession.get_tutorial_start_step_index()
	_index = start_index - 1
	# Jumping into a later part must not treat the previous part's last step as a break.
	if _index >= 0:
		_break_shown_for_index = _index
	if orchestrator:
		var part := GameSession.get_tutorial_part(GameSession.tutorial_start_part)
		if part.is_empty() and not _parts.is_empty() and typeof(_parts[0]) == TYPE_DICTIONARY:
			part = _parts[0]
		orchestrator.apply_tutorial_part_setup(part)
	_advance()


func stop(mark_completed: bool = true) -> void:
	_active = false
	_waiting_action = ""
	_current = {}
	_break_shown_for_index = -1
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
	if _should_show_part_break():
		_break_shown_for_index = _index
		_show_part_break()
		return
	_index += 1
	while _index < _steps.size():
		_maybe_apply_entering_part_tiles(_index)
		var step: Dictionary = _steps[_index]
		if _should_skip(step):
			_index += 1
			continue
		_enter_step(step)
		return
	_finish()


func _should_show_part_break() -> bool:
	if _index < 0 or _index >= _steps.size():
		return false
	if _break_shown_for_index == _index:
		return false
	if _parts.is_empty():
		return false
	var part := _part_for_step_index(_index)
	if part.is_empty():
		return false
	var part_index := _part_index_of(str(part.get("id", "")))
	if part_index < 0 or part_index >= _parts.size() - 1:
		return false
	var end_id := str(part.get("end", ""))
	if end_id.is_empty():
		return false
	return str(_steps[_index].get("id", "")) == end_id


func _show_part_break() -> void:
	var part := _part_for_step_index(_index)
	var step := {
		"id": "part_break",
		"title": str(part.get("break_title", "Part complete")),
		"body": str(part.get("break_body", "Continue to the next lesson, or end the tutorial.")),
		"highlight": "none",
		"gates": {"allow_actions": []},
		"complete": {
			"type": "continue_button",
			"label": "Continue",
			"skip_label": "End",
		},
	}
	_enter_step(step)


func _maybe_apply_entering_part_tiles(step_index: int) -> void:
	if orchestrator == null:
		return
	var part := _part_for_step_index(step_index)
	if part.is_empty():
		return
	var start_id := str(part.get("start", ""))
	if start_id.is_empty():
		return
	if str(_steps[step_index].get("id", "")) != start_id:
		return
	orchestrator.apply_tutorial_part_tiles(part)


func _part_for_step_index(step_index: int) -> Dictionary:
	if step_index < 0 or step_index >= _steps.size() or _parts.is_empty():
		return {}
	for i in _parts.size():
		var part: Dictionary = _parts[i]
		if typeof(part) != TYPE_DICTIONARY:
			continue
		var start_id := str(part.get("start", ""))
		var end_id := str(part.get("end", ""))
		var start_index := _first_step_index(start_id)
		var end_index := _first_step_index(end_id, start_index)
		if start_index < 0 or end_index < 0:
			continue
		if step_index >= start_index and step_index <= end_index:
			return part
	return {}


func _part_index_of(part_id: String) -> int:
	for i in _parts.size():
		if typeof(_parts[i]) == TYPE_DICTIONARY and str(_parts[i].get("id", "")) == part_id:
			return i
	return -1


func _first_step_index(step_id: String, from_index: int = 0) -> int:
	if step_id.is_empty():
		return -1
	for i in range(maxi(from_index, 0), _steps.size()):
		if typeof(_steps[i]) == TYPE_DICTIONARY and str(_steps[i].get("id", "")) == step_id:
			return i
	return -1


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
		if not _complete_when_met():
			return
		if action == "code_shared" and orchestrator:
			orchestrator.close_in_game_menu()
		_schedule_advance()


func _complete_when_met() -> bool:
	var complete: Dictionary = _current.get("complete", {})
	if typeof(complete) != TYPE_DICTIONARY:
		return true
	match str(complete.get("when", "")):
		"hand_elements_empty":
			return orchestrator != null and orchestrator.hand_element_count() <= 0
		_:
			return true


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
