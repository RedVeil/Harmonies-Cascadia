class_name TileSetupState
extends Resource

var setup: TileSetup
var neighbor_directions: Array[int] = []


static func from_setup(
	tile_setup: TileSetup,
	river_neighbor_directions: Array[int] = []
) -> TileSetupState:
	var state := TileSetupState.new()
	state.setup = tile_setup
	state.neighbor_directions = river_neighbor_directions.duplicate()
	return state


func duplicate_state() -> TileSetupState:
	return from_setup(setup, neighbor_directions)


func get_context() -> Dictionary:
	if setup != null and setup.river_pieces != null:
		return {"neighbor_directions": neighbor_directions}
	if neighbor_directions.is_empty():
		return {}
	return {"neighbor_directions": neighbor_directions}


func signature() -> String:
	var setup_path := setup.resource_path if setup != null else ""
	var sorted_directions := neighbor_directions.duplicate()
	sorted_directions.sort()
	var direction_parts: PackedStringArray = []
	for direction_index in sorted_directions:
		direction_parts.append(str(direction_index))
	return "%s|%s" % [setup_path, ",".join(direction_parts)]


func matches(other: TileSetupState) -> bool:
	if other == null:
		return false
	return signature() == other.signature()
