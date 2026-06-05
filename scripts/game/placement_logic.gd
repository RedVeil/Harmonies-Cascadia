extends Node
class_name PlacementLogic

## ----- Placement Logic ----- ##

func is_valid_element_placement(
	target:HexTileData, 
	options: Array[Placement]
	) -> bool:
	if target.animal_id == -1:
		return is_valid_center(target, options)
	else:
		return false

func is_valid_animal_placement(
	coord: Vector2i,
	target: HexTileData,
	options: Array[Placement],
	bonus: Array[Placement],
	tiles: Dictionary[Vector2i, HexTileData]
	) -> Dictionary:
	if target.animal_id == -1:
		if is_valid_center(target, options):
			return check_bonus_pattern(coord, bonus, tiles)
		else:
			return {"is_valid": false, "coords": []}
	else:
			return {"is_valid": false, "coords": []}

func is_valid_center(target:HexTileData, options: Array[Placement]) -> bool:
	return options.find_custom(
		func(option):return option.element == target.element && option.level == target.level
	) != -1

func check_bonus_pattern(
	coord: Vector2i,
	bonus: Array[Placement],
	tiles: Dictionary[Vector2i, HexTileData]
) -> Dictionary:
	var base_coords: Array[Vector2i] = []

	for b in bonus:
		base_coords.append(coord + b.coords)

	for mirrored in [false, true]:
		var test_coords: Array[Vector2i] = []

		for p in base_coords:
			if mirrored:
				test_coords.append(HexCoord.mirror(p, coord))
			else:
				test_coords.append(p)

		for i in range(6):
			var valid: Array[bool] = []
			valid.resize(bonus.size())
			valid.fill(false)

			for idx in bonus.size():
				if tiles.keys().has(test_coords[idx]):
					valid[idx] = is_valid_bonus_tile(tiles[test_coords[idx]], bonus[idx])

			if !valid.has(false):
				return {
					"is_valid": true,
					"coords": test_coords.duplicate()
				}

			for idx in test_coords.size():
				test_coords[idx] = HexCoord.rotate_clockwise(test_coords[idx], coord)

	return {
		"is_valid": false,
		"coords": []
	}

func is_valid_bonus_tile(tile: HexTileData, requirement:Placement) -> bool:
	return tile.element == requirement.element and tile.level == requirement.level
