extends Node2D
class_name PlacementTooltip

enum ArrowSide {
	BELOW = 0,
	RIGHT = 1,
}

const PANEL_SIZE := Vector2(100, 130)
const POINTS_AREA_HEIGHT := 20.0
const HEX_OUTLINE_THIN := preload("res://assets/icons/hex_outline_thin.png")
const HEX_OUTLINE_BOLD := preload("res://assets/icons/hex_outline_bold.png")

var _element_base_position: Vector2
var _animal_base_position: Vector2
var _pattern_bases_captured := false

## ----- Initialisation ----- ##

func init(
	type: int,
	center: Array[Placement],
	bonus: Array[Placement],
	points_text: String = "",
	arrow_side: ArrowSide = ArrowSide.BELOW
) -> void:
	_capture_pattern_bases()
	$Panel.show()

	if type == 0:
		$element.show()
		$animal.hide()
		set_element_placement(center)
	else:
		$element.hide()
		$animal.show()
		set_animal_placement(center, bonus)

	set_points_text(points_text)
	set_arrow_side(arrow_side)

	if type == 0:
		_center_pattern($element)
	else:
		_center_pattern($animal)

func _capture_pattern_bases() -> void:
	if _pattern_bases_captured:
		return
	_element_base_position = $element.position
	_animal_base_position = $animal.position
	_pattern_bases_captured = true

## ----- Points / Arrow ----- ##

func set_points_text(text: String) -> void:
	var label: Label = $Panel/PointsLabel
	if text.is_empty():
		label.hide()
	else:
		label.text = text
		label.show()

func set_arrow_side(side: ArrowSide) -> void:
	$Panel/ArrowDown.visible = (side == ArrowSide.BELOW)
	$Panel/ArrowRight.visible = (side == ArrowSide.RIGHT)

## ----- Pattern Centering ----- ##

func _content_center() -> Vector2:
	if $Panel/PointsLabel.visible:
		return Vector2(PANEL_SIZE.x * 0.5, (PANEL_SIZE.y - POINTS_AREA_HEIGHT) * 0.5)
	return PANEL_SIZE * 0.5

func _is_hex_outline(sprite: Sprite2D) -> bool:
	for child in sprite.get_children():
		if child is Sprite2D and (child as Sprite2D).show_behind_parent:
			return true
	return false

## Position of a descendant Node2D origin in this tooltip's local space.
## Uses the local transform chain so it works before the tooltip is in the scene tree.
func _position_in_tooltip(node: Node2D) -> Vector2:
	var pos := Vector2.ZERO
	var current: Node = node
	while current != null and current != self:
		if current is Node2D:
			pos = (current as Node2D).transform * pos
		current = current.get_parent()
	return pos

func _visible_hex_centers(root: Node2D) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	_collect_hex_centers(root, centers)
	return centers

func _collect_hex_centers(node: Node, centers: Array[Vector2]) -> void:
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Sprite2D and _is_hex_outline(node as Sprite2D):
		centers.append(_position_in_tooltip(node as Node2D))
		return
	for child in node.get_children():
		_collect_hex_centers(child, centers)

func _center_pattern(root: Node2D) -> void:
	if root == $element:
		root.position = _element_base_position
	elif root == $animal:
		root.position = _animal_base_position

	var centers := _visible_hex_centers(root)
	if centers.is_empty():
		return

	var min_p := centers[0]
	var max_p := centers[0]
	for i in range(1, centers.size()):
		min_p = min_p.min(centers[i])
		max_p = max_p.max(centers[i])

	var bbox_center := (min_p + max_p) * 0.5
	root.position += _content_center() - bbox_center

## ----- Element Placement Logic ----- ##

func set_element_placement(center: Array[Placement]) -> void:
	for i in center.size():
		var level = ElementCatalog.elements[center[i].element].levels[0 if center[i].element == 0 else center[i].level - 1]

		var icon: Texture2D = load(level.icon)
		var texture_size := icon.get_size()
		var scale_factor = min(
			300 / texture_size.x,
			300 / texture_size.y
		)

		get_node("element/%d/%d/Sprite2D" % [center.size(), i]).self_modulate = Color.html(level.color)
		get_node("element/%d/%d/Sprite2D/Sprite2D" % [center.size(), i]).texture = icon
		get_node("element/%d/%d/Sprite2D/Sprite2D" % [center.size(), i]).scale = Vector2.ONE * scale_factor
		get_node("element/%d" % [center.size()]).show()

## ----- Animal Placement Logic ----- ##

func set_animal_placement(center: Array[Placement], bonus: Array[Placement]) -> void:
	var push_direction = Vector2i.ZERO
	for b in bonus:
		if b.coords.y == 2:
			push_direction = Vector2i(0, -1)
			break

	if push_direction == Vector2i.ZERO:
		apply_animal_tile_style(center[0], true)
		for b in bonus:
			apply_animal_tile_style(b, false)
	else:
		var new_center = center[0].duplicate(true)
		new_center.coords += push_direction
		apply_animal_tile_style(new_center, true)
		for b in bonus:
			var new_b = b.duplicate(true)
			new_b.coords += push_direction
			apply_animal_tile_style(new_b, false)


func apply_animal_tile_style(placement: Placement, is_center: bool) -> void:
		var outline: Sprite2D = get_node("animal/(%d,%d)" % [placement.coords.x, placement.coords.y])
		if is_center:
			outline.self_modulate = Color.WHITE
			outline.texture = HEX_OUTLINE_BOLD
		else:
			outline.self_modulate = Color.TRANSPARENT
			outline.texture = HEX_OUTLINE_THIN

		var levels: Array = ElementCatalog.elements[placement.element].levels
		var level_index := clampi(placement.level - 1, 0, levels.size() - 1)
		var level = levels[level_index]

		var icon: Texture2D = load(level.icon)
		var texture_size := icon.get_size()
		var scale_factor = min(
			300 / texture_size.x,
			300 / texture_size.y
		)

		get_node("animal/(%d,%d)/Sprite2D" % [placement.coords.x, placement.coords.y]).self_modulate = Color.html(level.color)
		get_node("animal/(%d,%d)/Sprite2D/Sprite2D" % [placement.coords.x, placement.coords.y]).texture = icon
		get_node("animal/(%d,%d)/Sprite2D/Sprite2D" % [placement.coords.x, placement.coords.y]).scale = Vector2.ONE * scale_factor
		outline.show()
