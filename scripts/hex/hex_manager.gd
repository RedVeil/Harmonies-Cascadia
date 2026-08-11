extends Node3D
class_name HexManager

@export var orchestrator : Orchestrator
@export var map_button : PackedScene
@export var map_ring_count : int = 3

@onready var hex_container : HexTileContainer = $HexTileContainer

var tiles : Dictionary[Vector2i, HexTileData] = {}
var hex_map_active : Array[Vector2i] = []
var groups: Dictionary[int, Array] = {}
var next_group_id:int = 0

var prev_coord: Vector2i
var prev_card: Vector2i

var map_buttons: Array[MapButton] = []

var groups_backup: Dictionary[int, Array] = {}
var next_group_id_backup:int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	hex_container.init(self)
	map_ring_count = GameSession.get_map_ring_count()
	create_map(Vector2i.ZERO)

## ----- Tile Creation Logic ----- ##

func create_tiles(origin: Vector2i) -> void:
	for q in range(-map_ring_count, map_ring_count + 1):
		for r in range(-map_ring_count, map_ring_count + 1):
			var c := origin + Vector2i(q, r)
			if HexCoord.distance(origin, c) <= map_ring_count:
				if !tiles.keys().has(c):
					tiles[c] = HexTileData.new()
					hex_container.create_tile(c)

func create_map(map_origin: Vector2i) -> void:
	if !hex_map_active.has(map_origin):
		create_tiles(map_origin)
		hex_map_active.append(map_origin)

## ----- Pass Data Upstream ----- ##

func handle_hover(coord:Vector2i) -> void:
	if orchestrator == null:
		return
	orchestrator.handle_tile_hover(coord)

func handle_exit() -> bool:
	if orchestrator == null:
		return true
	return orchestrator.handle_tile_exit()

func clear_hover_tracking() -> void:
	hex_container.clear_hover_tracking()

func handle_click(coord:Vector2i) -> void:
	if orchestrator == null:
		return
	orchestrator.handle_tile_click(coord)

func handle_place_feedback_finished(coord: Vector2i) -> void:
	if orchestrator == null:
		return
	orchestrator.handle_place_feedback_finished(coord)

func handle_map_button_click(coord:Vector2i) -> void:
	if orchestrator == null:
		return
	orchestrator.handle_map_button_click(coord)

## ----- Pass Data Downstream ----- ##

func apply_preview(preview:TileStatePreview) -> void:
	hex_container.apply_preview(preview)

func apply_placement(coord:Vector2i) -> void:
	hex_container.place_tile(coord)

func play_placement_reward(
	coord: Vector2i,
	points: int,
	contributing_coords: Array[Vector2i]
) -> void:
	hex_container.play_placement_reward(coord, points, contributing_coords)

func reset_preview(coord:Vector2i) -> void:
	hex_container.reset_preview(coord)

func show_tile_info(coord: Vector2i) -> void:
	hex_container.show_tile_info(coord)

func hide_tile_info(coord: Vector2i) -> void:
	hex_container.hide_tile_info(coord)
	
func undo(coord:Vector2i) -> void:
	hex_container.undo(coord)

func discard_undo_visuals() -> void:
	hex_container.discard_undo_visuals()

## ----- Map Logic ----- ##

func show_map_buttons() -> void:
	var available_origins : Array[Vector2i] = []
	for key in hex_map_active:
		var neighbors = HexCoord.map_neighbors(key, map_ring_count)
		for n in neighbors:
			if !available_origins.has(n) && !hex_map_active.has(n):
				available_origins.append(n)
	for origin in available_origins:
		var new_coords := _new_coords_for_origin(origin)
		if not new_coords.is_empty():
			create_map_button(origin, new_coords)

func _new_coords_for_origin(origin: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for q in range(-map_ring_count, map_ring_count + 1):
		for r in range(-map_ring_count, map_ring_count + 1):
			var c := origin + Vector2i(q, r)
			if HexCoord.distance(origin, c) <= map_ring_count and not tiles.has(c):
				out.append(c)
	return out

func create_map_button(origin: Vector2i, new_coords: Array[Vector2i]) -> void:
	var button := map_button.instantiate() as MapButton
	add_child(button)
	button.init(self, origin, new_coords, hex_container.hex_size)
	map_buttons.append(button)

func remove_map_buttons() -> void:
	for button in map_buttons:
		button.remove_button()
	map_buttons = []


## ----- Endless Continue Apply Helpers ----- ##
##
## Rebuild board + tile visuals from serialized state.
## Called by `EndlessRunSave.apply_state_to_orchestrator()` after scene load.
func apply_saved_state(board_state: Dictionary) -> void:
	if board_state.is_empty():
		return

	# Remove existing map/buttons/tiles created by HexManager._ready().
	remove_map_buttons()
	hex_map_active.clear()
	groups.clear()
	next_group_id = 0

	# Clear any existing tile nodes and cached tile data.
	for tile in hex_container.tiles_by_coord.values():
		if is_instance_valid(tile):
			tile.queue_free()
	hex_container.tiles_by_coord.clear()
	tiles.clear()

	# Recreate map origins, which recreates all tile nodes + base HexTileData resources.
	var origins_arr: Array = board_state.get("hex_map_active", [])
	for origin_entry in origins_arr:
		var c := _coord_from_arr(origin_entry)
		create_map(c)

	# Apply saved per-tile data (element/level/animal/group/orientation/etc).
	var tiles_arr: Array = board_state.get("tiles", [])
	for entry in tiles_arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var q := int(entry.get("q", 0))
		var r := int(entry.get("r", 0))
		var coord := Vector2i(q, r)
		if not tiles.has(coord):
			# Shouldn't happen if origins were serialized correctly.
			continue
		var t := tiles[coord]
		t.element = entry.get("element", 0)
		t.level = entry.get("level", 0)
		t.animal_id = int(entry.get("animal_id", -1))
		t.animal_amount = int(entry.get("animal_amount", 0))
		t.group_id = int(entry.get("group_id", -1))
		t.hex_map_id = int(entry.get("hex_map_id", 0))
		t.orientation_steps = int(entry.get("orientation_steps", -1))

	# Apply saved group bookkeeping.
	var groups_arr: Array = board_state.get("groups", [])
	for g in groups_arr:
		if typeof(g) != TYPE_DICTIONARY:
			continue
		var gid := int(g.get("id", -1))
		if gid < 0:
			continue
		var coords_out: Array = []
		for c_entry in g.get("coords", []):
			coords_out.append(_coord_from_arr(c_entry))
		groups[gid] = coords_out
	next_group_id = int(board_state.get("next_group_id", 0))

	# Commit visuals to match the saved tile states.
	# For river tiles we must provide the current river-neighbor list so RiverPreviewLogic
	# can compute rotation + river_index.
	for entry in tiles_arr:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var coord := Vector2i(int(entry.get("q", 0)), int(entry.get("r", 0)))
		if not tiles.has(coord) or not hex_container.tiles_by_coord.has(coord):
			continue
		var tile_data: HexTileData = tiles[coord]
		var river_neighbors: Array[Vector2i] = []
		if tile_data.element == GameEnums.ELEMENT.RIVER:
			river_neighbors = hex_container.get_element_neighbors(coord, GameEnums.ELEMENT.RIVER)
		var tile_node: HexTile = hex_container.tiles_by_coord[coord]
		tile_node.commit_preview_from_tile_data(tile_data, river_neighbors)

	# If the saved run had pending map expansions, show the ghost expansion buttons.
	if orchestrator != null and orchestrator.map_points > 0 and GameSession.allows_map_growth():
		show_map_buttons()


func _coord_from_arr(a: Array) -> Vector2i:
	if a.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(a[0]), int(a[1]))
