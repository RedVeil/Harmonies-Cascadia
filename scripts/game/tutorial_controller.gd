extends Node
class_name TutorialController
## Loads data/tutorial_config.json steps, applies gates, drives TutorialCoach.

@export var orchestrator: Orchestrator
@export var coach: TutorialCoach
@export var tutorial_overlay: TutorialOverlay
@export var camera: Camera3D

@export var hud_boosters: Node2D
@export var hud_hand: Node2D
@export var hud_score: Node2D
@export var hud_undo: Node2D
@export var hud_recycle: Node2D
@export var hud_quests: Node2D
@export var hex_manager: HexManager

var _steps: Array = []
var _index: int = -1
var _current: Dictionary = {}
var _waiting_action: String = ""
var _active: bool = false
var _hud_sizes := {
	"boosters": Vector2(220, 120),
	"hand": Vector2(420, 140),
	"score": Vector2(160, 70),
	"undo": Vector2(56, 56),
	"recycle": Vector2(56, 56),
	"quests": Vector2(200, 100),
}


func _ready() -> void:
	if coach:
		coach.continue_pressed.connect(_on_continue)
		coach.skip_pressed.connect(_on_skip)
		coach.tip_pressed.connect(_on_tip)
	if tutorial_overlay and not tutorial_overlay.closed.is_connected(_on_tip_closed):
		tutorial_overlay.closed.connect(_on_tip_closed)
	if orchestrator:
		if not orchestrator.tutorial_action.is_connected(_on_tutorial_action):
			orchestrator.tutorial_action.connect(_on_tutorial_action)
	if GameSession.is_tutorial():
		call_deferred("start")


func start() -> void:
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
	if orchestrator:
		orchestrator.clear_tutorial_gates()
	if coach:
		coach.hide_coach()
	if mark_completed:
		PlayerProgress.mark_tutorial_completed()


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

	var tip_available := step.has("tip_slide")
	var highlight_rect := _resolve_highlight(step.get("highlight", {}))
	if coach:
		coach.show_step(step, highlight_rect, show_continue, tip_available)


func _resolve_highlight(highlight) -> Rect2:
	if typeof(highlight) != TYPE_DICTIONARY:
		return Rect2()
	var htype := str(highlight.get("type", "none"))
	match htype:
		"hud":
			return _hud_rect(str(highlight.get("target", "")))
		"hex":
			var coord_raw = highlight.get("coord", [0, 0])
			if typeof(coord_raw) == TYPE_ARRAY and coord_raw.size() >= 2:
				return _hex_rect(Vector2i(int(coord_raw[0]), int(coord_raw[1])))
			return Rect2()
		_:
			return Rect2()


func _hud_rect(target: String) -> Rect2:
	var node: Node2D = null
	match target:
		"boosters":
			node = hud_boosters
		"hand":
			node = hud_hand
		"score":
			node = hud_score
		"undo":
			node = hud_undo
		"recycle":
			node = hud_recycle
			# Recycle is per-animal X on hand cards now.
		"quests":
			node = hud_quests
	if node == null or not is_instance_valid(node):
		return Rect2()
	var size: Vector2 = _hud_sizes.get(target, Vector2(120, 80))
	# Slots are anchor points; boosters/hand grow upward/right from the slot.
	var origin := node.global_position
	match target:
		"boosters":
			origin += Vector2(0, -size.y)
		"hand", "recycle":
			origin += Vector2(0, -size.y * 0.35)
			if target == "recycle":
				size = _hud_sizes.get("hand", size)
		"undo":
			origin += Vector2(-size.x * 0.5, -size.y * 0.5)
		"score":
			origin += Vector2(-20, -20)
	return Rect2(origin, size)


func _hex_rect(coord: Vector2i) -> Rect2:
	if hex_manager == null or camera == null:
		return Rect2()
	if not hex_manager.tiles.has(coord):
		return Rect2()
	var tile_node = null
	if hex_manager.hex_container and hex_manager.hex_container.tiles_by_coord.has(coord):
		tile_node = hex_manager.hex_container.tiles_by_coord[coord]
	if tile_node == null or not is_instance_valid(tile_node):
		return Rect2()
	var screen := camera.unproject_position(tile_node.global_position)
	return Rect2(screen - Vector2(40, 40), Vector2(80, 80))


func _on_tutorial_action(action: String, _payload: Dictionary) -> void:
	if not _active:
		return
	if _waiting_action.is_empty():
		return
	if action == _waiting_action:
		_advance()


func _on_continue() -> void:
	if not _active:
		return
	var complete: Dictionary = _current.get("complete", {})
	var complete_type := str(complete.get("type", ""))
	if complete_type == "continue_button" or complete_type == "action_or_continue":
		_advance()


func _on_skip() -> void:
	stop(true)


func _on_tip() -> void:
	if tutorial_overlay == null:
		return
	if not _current.has("tip_slide"):
		return
	var idx := int(_current.get("tip_slide", 0))
	if not tutorial_overlay.is_node_ready():
		await tutorial_overlay.ready
	tutorial_overlay.layer = 14
	tutorial_overlay.show_slide(idx)
	tutorial_overlay.show()
	if coach:
		coach.hide_coach()


func _on_tip_closed() -> void:
	if tutorial_overlay:
		tutorial_overlay.layer = 10
	if _active and not _current.is_empty():
		_enter_step(_current)


func _finish() -> void:
	stop(true)
