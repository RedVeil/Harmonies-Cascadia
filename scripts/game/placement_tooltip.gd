extends Node2D
class_name PlacementTooltip

enum ArrowSide {
	BELOW = 0,
	RIGHT = 1,
}

const _PANEL_SIZE_DEFAULT := Vector2(100, 120)
const _PANEL_SIZE_WITH_POINTS := Vector2(100, 140)
const _ARROW_SIZE := Vector2(16, 16)

## ----- Initialisation ----- ##

func _ready() -> void:
	return

func init(
	type: int,
	center: Array[Placement],
	bonus: Array[Placement],
	points_text: String = "",
	arrow_side: ArrowSide = ArrowSide.BELOW
) -> void:
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

## ----- Points / Arrow ----- ##

func set_points_text(text: String) -> void:
	var label: Label = $Panel/PointsLabel
	if text.is_empty():
		label.hide()
		$Panel.size = _PANEL_SIZE_DEFAULT
		$Panel.offset_right = _PANEL_SIZE_DEFAULT.x
		$Panel.offset_bottom = _PANEL_SIZE_DEFAULT.y
	else:
		label.text = text
		label.show()
		$Panel.size = _PANEL_SIZE_WITH_POINTS
		$Panel.offset_right = _PANEL_SIZE_WITH_POINTS.x
		$Panel.offset_bottom = _PANEL_SIZE_WITH_POINTS.y

func set_arrow_side(side: ArrowSide) -> void:
	var arrow: Panel = $Panel/Arrow
	var panel_size := Vector2($Panel.offset_right, $Panel.offset_bottom)
	match side:
		ArrowSide.BELOW:
			var x := (panel_size.x - _ARROW_SIZE.x) * 0.5
			var y := panel_size.y - (_ARROW_SIZE.y * 0.5)
			arrow.offset_left = x
			arrow.offset_top = y
			arrow.offset_right = x + _ARROW_SIZE.x
			arrow.offset_bottom = y + _ARROW_SIZE.y
		ArrowSide.RIGHT:
			var x := -(_ARROW_SIZE.x * 0.5)
			var y := (panel_size.y - _ARROW_SIZE.y) * 0.5
			arrow.offset_left = x
			arrow.offset_top = y
			arrow.offset_right = x + _ARROW_SIZE.x
			arrow.offset_bottom = y + _ARROW_SIZE.y

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
		if is_center:
			get_node("animal/(%d,%d)" % [placement.coords.x, placement.coords.y]).self_modulate = Color.WHITE
		else:
			get_node("animal/(%d,%d)" % [placement.coords.x, placement.coords.y]).self_modulate = Color.TRANSPARENT

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
		get_node("animal/(%d,%d)" % [placement.coords.x, placement.coords.y]).show()
