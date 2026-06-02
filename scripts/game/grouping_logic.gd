extends Node
class_name GroupingLogic

func group_by_element(
	coord:Vector2i, 
	element:int, 
	hex_manager:HexManager
	) -> Dictionary:
	var neighbors = HexCoord.neighbors(coord)
	var eligble_groups: Array[int] = []
	
	if hex_manager.tiles[coord].group_id != -1:
		eligble_groups.append(hex_manager.tiles[coord].group_id)
	
	for n in neighbors:
		if hex_manager.tiles.has(n) and hex_manager.tiles[n].element == element:
			var group = hex_manager.tiles[n].group_id
			if !eligble_groups.has(group):
				eligble_groups.append(group)
			
	var contributing_coords: Array[Vector2i] = []
	var old_group_ids: Array[int] = []
	var new_group_id: int = -1
	
	if eligble_groups.size() == 0:
		new_group_id = hex_manager.next_group_id
	elif eligble_groups.size() == 1:
		old_group_ids = eligble_groups
		new_group_id = eligble_groups[0]
		contributing_coords.assign(hex_manager.groups[new_group_id])
	else:
		for g in eligble_groups:
			if not old_group_ids.has(g):
				old_group_ids.append(g)
				for c in hex_manager.groups[g]:
					contributing_coords.append(c)
		new_group_id = old_group_ids[0]
		
	if !contributing_coords.has(coord):
		contributing_coords.append(coord)
		
	return {"contributing_coords":contributing_coords, "old_group_ids":old_group_ids, "new_group_id":new_group_id}
