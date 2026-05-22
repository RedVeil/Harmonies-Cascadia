extends Node
class_name PlacementLogic

func is_valid_element_placement(
	target:HexTileData, 
	options: Array[Placement]
	) -> bool:
	return is_valid_center(target, options)

func is_valid_animal_placement(
	coord: Vector2i,
	target: HexTileData,
	options: Array[Placement],
	bonus: Array[Placement],
	tiles: Dictionary[Vector2i, HexTileData]
	) -> Dictionary:
	if is_valid_center(target, options):
		var rotated_bonus = bonus.duplicate(true)
		# transform bonus coords from relative to world coords
		for b in rotated_bonus:
			b.coords = coord + b.coords
			
		# rotate pattern and check if its valid
		for i in range(6):
			var valid = true
			for b in rotated_bonus:
				b.coords = HexCoord.rotate_left(b.coords)
				valid = is_valid_bonus_tile(tiles, b)
			if valid:
				return {"is_valid": true, "coords": rotated_bonus.map(func(obj):return obj.coords)}
		return {"is_valid": false, "coords": []}
	else:
		return {"is_valid": false, "coords": []}


func is_valid_center(target:HexTileData, options: Array[Placement]) -> bool:
	return options.find_custom(
		func(option):return option.element == target.element && option.level == target.level
	) != -1

func is_valid_bonus_tile(tiles: Dictionary[Vector2i, HexTileData], requirement:Placement) -> bool:
	if tiles.has(requirement.coords):
		var target = tiles[requirement.coords]
		return target.element == requirement.element and target.level == requirement.level
	else:
		return false
