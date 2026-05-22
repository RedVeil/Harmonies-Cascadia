extends Node
class_name GroupingLogic

func group_by_element(
	coord:Vector2i, 
	element:int, 
	hex_manager:HexManager
	) -> Dictionary:
	var neighbors = HexCoord.neighbors(coord)
	var eligble_neighbors: Array[Vector2i] = []

	for n in neighbors:
		if hex_manager.tiles.has(n) and hex_manager.tiles[n].element == element:
			eligble_neighbors.append(n)
			
	var contributing_coords: Array[Vector2i] = []
	var old_group_ids: Array[int] = []
	var new_group_id: int = -1

	if eligble_neighbors.size() == 0:
		new_group_id = hex_manager.next_group_id
	elif eligble_neighbors.size() == 1:
		old_group_ids = [hex_manager.tiles[eligble_neighbors[0]].group_id]
		new_group_id = hex_manager.tiles[eligble_neighbors[0]].group_id
		contributing_coords.assign(hex_manager.groups[old_group_ids[0]])
	else:
		for n in eligble_neighbors:
			var group_id: int = hex_manager.tiles[n].group_id
			if not old_group_ids.has(group_id):
				old_group_ids.append(group_id)
				for c in hex_manager.groups[group_id]:
					contributing_coords.append(c)
		new_group_id = old_group_ids[0]
	
	return {"contributing_coords":contributing_coords, "old_group_ids":old_group_ids, "new_group_id":new_group_id}
