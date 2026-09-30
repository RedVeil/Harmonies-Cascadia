extends Node
## Autoload: true while the cursor is over HUD / popup UI so world tiles
## (and other 3D pickables) do not keep hover/click under those elements.

signal blocked_changed(blocked: bool)

var _hover_ids: Dictionary = {} # instance_id -> true
var _last_blocked: bool = false


func _process(_delta: float) -> void:
	var blocked := is_blocked()
	if blocked == _last_blocked:
		return
	_last_blocked = blocked
	blocked_changed.emit(blocked)


func enter(node: Object) -> void:
	if node == null:
		return
	_hover_ids[node.get_instance_id()] = true


func exit(node: Object) -> void:
	if node == null:
		return
	_hover_ids.erase(node.get_instance_id())


func set_hovering(node: Object, hovering: bool) -> void:
	if hovering:
		enter(node)
	else:
		exit(node)


func is_blocked() -> bool:
	if not _hover_ids.is_empty():
		return true
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.is_visible_in_tree()
