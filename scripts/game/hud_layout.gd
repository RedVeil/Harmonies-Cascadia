extends CanvasLayer
## Keeps Node2D HUD widgets aligned to edge-anchored Control slots.
## Widgets are siblings of Root (not children of slots) so their Control
## tooltips/labels keep Node2D-local layout instead of inheriting slot size.

@onready var _root: Control = $Root

var _pairs: Array[Array] = []

func _ready() -> void:
	_pairs = [
		[$Root/PointCounterSlot, $PointCounter],
		[$Root/QuestManagerSlot, $QuestManager],
		[$Root/BoosterManagerSlot, $BoosterManager],
		[$Root/CardManagerSlot, $CardManager],
		[$Root/ScoreTooltipSlot, $ScoreTooltip],
		[$Root/MenuButtonSlot, $MenuButton],
		[$Root/PlayCounterSlot, $PlayCounter],
		[$Root/UndoButtonSlot, $UndoButton],
	]
	add_to_group("puzzle_maker_hud")
	get_viewport().size_changed.connect(_relayout)
	_root.resized.connect(_relayout)
	call_deferred("_relayout")


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10):
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	visible = not visible
	var toolbar := get_parent().get_node_or_null("MakerToolbar")
	if toolbar:
		toolbar.visible = visible
	get_viewport().set_input_as_handled()


func _relayout() -> void:
	for pair in _pairs:
		var slot: Control = pair[0]
		var widget = pair[1]
		if slot == null or widget == null:
			continue
		if not is_instance_valid(widget):
			continue
		widget.global_position = slot.global_position
