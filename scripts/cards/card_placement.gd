extends Node2D
class_name CardPlacement

const HEX_OUTLINE_THIN := preload("res://assets/icons/hex_outline_thin.png")
const HEX_OUTLINE_BOLD := preload("res://assets/icons/hex_outline_bold.png")
const MAIN_OUTLINE_SCALE := 1.2
var COLOR_HEX_BORDER_MAIN := Color.WHITE
var COLOR_HEX_BORDER_BONUS := Color(0.78, 0.78, 0.78, 1.0)

func init(card_data: CardData) -> void:
	$element.hide()
	$animal.hide()
	_hide_children($element)
	_hide_children($animal)

	if card_data.type == CardData.CARD_TYPE.ANIMAL:
		$animal.show()
		var pattern: Node2D = $animal.get_node(card_data.pattern)
		pattern.show()
		_style_animal_pattern(pattern, card_data)
	else:
		$element.show()
		$element.get_node(card_data.pattern).show()

func _hide_children(root: Node) -> void:
	for child in root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).hide()

func _style_animal_pattern(pattern: Node2D, card_data: CardData) -> void:
	var by_coords: Dictionary = {}
	if card_data.placement.size() > 0:
		by_coords[card_data.placement[0].coords] = card_data.placement[0]
	for bonus in card_data.bonus:
		by_coords[bonus.coords] = bonus

	for hex in pattern.get_children():
		if not hex is Sprite2D:
			continue
		var coords := _coords_from_name(hex.name)
		if not by_coords.has(coords):
			continue
		_apply_hex_style(hex as Sprite2D, by_coords[coords], coords == Vector2i.ZERO)

func _coords_from_name(node_name: String) -> Vector2i:
	var inner := node_name.trim_prefix("(").trim_suffix(")")
	var parts := inner.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))

func _apply_hex_style(outline: Sprite2D, placement: Placement, is_center: bool) -> void:
	var fill: Sprite2D = outline.get_node("Sprite2D")
	if is_center:
		outline.self_modulate = COLOR_HEX_BORDER_MAIN
		outline.texture = HEX_OUTLINE_BOLD
		outline.scale = Vector2.ONE * MAIN_OUTLINE_SCALE
		fill.scale = Vector2.ONE / MAIN_OUTLINE_SCALE
	else:
		outline.self_modulate = COLOR_HEX_BORDER_BONUS
		outline.texture = HEX_OUTLINE_THIN
		outline.scale = Vector2.ONE
		fill.scale = Vector2.ONE

	var levels: Array = ElementCatalog.elements[placement.element].levels
	var level_index := 0 if placement.element == 0 else clampi(placement.level - 1, 0, levels.size() - 1)
	var level = levels[level_index]

	var icon: Texture2D = load(level.icon)
	var texture_size := icon.get_size()
	var scale_factor := minf(300.0 / texture_size.x, 300.0 / texture_size.y)

	fill.self_modulate = Color.html(level.color)
	var icon_sprite: Sprite2D = fill.get_node("Sprite2D")
	icon_sprite.texture = icon
	icon_sprite.scale = Vector2.ONE * scale_factor
