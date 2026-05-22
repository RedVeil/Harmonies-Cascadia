extends Node2D
class_name PlacementTooltip

func _ready() -> void:
	return

func init(type:int, center:Array[Placement],bonus:Array[Placement]) -> void:
	if type == 0:
		$element.show()
		$animal.hide()
		set_element_placement(center)
	else:
		$element.hide()
		$animal.show()
		set_animal_placement(center, bonus)
		

func set_element_placement(center:Array[Placement]) -> void:
	for i in center.size():
		var level = ElementCatalog.elements[center[i].element].levels[0 if center[i].element == 0 else center[i].level-1]
		
		var icon : Texture2D = load(level.icon)
		var texture_size := icon.get_size()
		var scale_factor = min(
			300 / texture_size.x,
			300 / texture_size.y
		)
		
		get_node("element/%d/Sprite2D" % i).self_modulate = Color.html(level.color)
		get_node("element/%d/Sprite2D/Sprite2D" % i).texture = icon
		get_node("element/%d/Sprite2D/Sprite2D" % i).scale = Vector2.ONE * scale_factor
		get_node("element/%d" % i).show()

func set_animal_placement(center:Array[Placement],bonus:Array[Placement]) -> void:
	var push_direction = Vector2i.ZERO
	for b in bonus:
		if b.coords.x == 2:
			push_direction = Vector2i.LEFT
			break
		elif b.coords.x == -2:
			push_direction = Vector2i.RIGHT
			break
		if b.coords.y == 2:
			push_direction = Vector2i(-1 if b.coords.x >= 0 else 1, -1)
			break
		elif b.coords.y == -2:
			push_direction = Vector2i(-1 if b.coords.x >= 0 else 1, 1)
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
		
	
func apply_animal_tile_style(placement: Placement, is_center:bool) -> void:
		if is_center:
			get_node("animal/(%d,%d)" % [placement.coords.x, placement.coords.y]).self_modulate = Color.WHITE
		else:
			get_node("animal/(%d,%d)" % [placement.coords.x, placement.coords.y]).self_modulate = Color.TRANSPARENT
		
		var level = ElementCatalog.elements[placement.element].levels[placement.level-1]
		
		var icon : Texture2D = load(level.icon)
		var texture_size := icon.get_size()
		var scale_factor = min(
			300 / texture_size.x,
			300 / texture_size.y
		)
		
		get_node("animal/(%d,%d)/Sprite2D" % [placement.coords.x, placement.coords.y]).modulate = Color.html(level.color)
		get_node("animal/(%d,%d)/Sprite2D/Sprite2D" % [placement.coords.x, placement.coords.y]).texture = icon
		get_node("animal/(%d,%d)/Sprite2D/Sprite2D" % [placement.coords.x, placement.coords.y]).scale = Vector2.ONE * scale_factor
		get_node("animal/(%d,%d)" % [placement.coords.x, placement.coords.y]).show()
