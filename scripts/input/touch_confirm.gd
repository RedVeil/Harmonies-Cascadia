class_name TouchConfirm
extends RefCounted
## Sticky two-tap confirm for touch: first tap selects/previews, second tap on the same target confirms.

var kind: String = ""
var id: Variant = null
## Increments once per finger-down gesture (ScreenTouch + emulated mouse share one id).
var _press_id: int = 0
var _armed_press_id: int = -1
var _downs: int = 0


func is_sticky(p_kind: String, p_id: Variant) -> bool:
	return kind == p_kind and id == p_id


## True only on a later press than the one that called set_target.
func can_confirm(p_kind: String, p_id: Variant) -> bool:
	return is_sticky(p_kind, p_id) and _press_id != _armed_press_id


func set_target(p_kind: String, p_id: Variant) -> Dictionary:
	var prev := {"kind": kind, "id": id}
	kind = p_kind
	id = p_id
	if _press_id == 0:
		_press_id = 1
		_downs = maxi(_downs, 1)
	_armed_press_id = _press_id
	return prev


func notify_press() -> void:
	_downs += 1
	if _downs == 1:
		_press_id += 1


func notify_release() -> void:
	_downs = maxi(_downs - 1, 0)


func notify_mouse_up() -> void:
	_downs = 0


func clear() -> void:
	kind = ""
	id = null
	_armed_press_id = _press_id


func is_held() -> bool:
	return _downs > 0


func is_set() -> bool:
	return not kind.is_empty()
