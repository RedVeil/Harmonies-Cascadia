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
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	if not (key >= KEY_F1 and key <= KEY_F6) and key != KEY_F10:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	match key:
		KEY_F1:
			_toggle_node($PointCounter)
		KEY_F2:
			_toggle_group([$ScoreTooltip, $MenuButton, $UndoButton])
		KEY_F3:
			_toggle_node($QuestManager)
		KEY_F4:
			_toggle_booster_part(_market_nodes(), _pack_nodes())
		KEY_F5:
			_toggle_booster_part(_pack_nodes(), _market_nodes())
		KEY_F6:
			_toggle_node($CardManager)
		KEY_F10:
			visible = not visible
			var toolbar := get_parent().get_node_or_null("MakerToolbar")
			if toolbar:
				toolbar.visible = visible
		_:
			return
	get_viewport().set_input_as_handled()


func _toggle_node(node: Node) -> void:
	if not (node is CanvasItem):
		return
	(node as CanvasItem).visible = not (node as CanvasItem).visible


func _toggle_group(nodes: Array) -> void:
	var show := not _any_visible(nodes)
	_set_visible(nodes, show)


func _toggle_booster_part(targets: Array, siblings: Array) -> void:
	var manager := get_node_or_null("BoosterManager") as CanvasItem
	if manager == null:
		return
	if manager.visible and _any_visible(targets):
		_set_visible(targets, false)
		return
	_set_visible(targets, true)
	if not manager.visible:
		_set_visible(siblings, false)
		manager.visible = true


func _market_nodes() -> Array:
	var manager := get_node_or_null("BoosterManager") as BoosterManager
	if manager == null:
		return []
	return [manager.animal_market]


func _pack_nodes() -> Array:
	var manager := get_node_or_null("BoosterManager") as BoosterManager
	if manager == null:
		return []
	return [manager.booster_container, manager.pack_counter]


func _any_visible(nodes: Array) -> bool:
	for node in nodes:
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
	return false


func _set_visible(nodes: Array, show: bool) -> void:
	for node in nodes:
		if node is CanvasItem:
			(node as CanvasItem).visible = show


func _relayout() -> void:
	for pair in _pairs:
		var slot: Control = pair[0]
		var widget = pair[1]
		if slot == null or widget == null:
			continue
		if not is_instance_valid(widget):
			continue
		widget.global_position = slot.global_position
