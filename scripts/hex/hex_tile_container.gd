extends Node3D
class_name HexTileContainer

@export var hex_tile : PackedScene
@export var hex_size: float = 11
@export var contributor_stagger: float = 0.06

var hex_manager : HexManager

var tiles_by_coord: Dictionary[Vector2i, HexTile] = {}

var has_hover:bool = false
var hover_target:Vector2i = Vector2i.MAX

var backup_target_visuals: TileLayersState
var prev_target_visuals: TileLayersState
var new_target_visuals: TileLayersState

var prev_contributing_tiles : Array[Vector2i]
var prev_river_neighbor_tiles: Array[Vector2i] = []

## ----- Initialisation ----- ##

func init(parent:HexManager) -> void:
	hex_manager = parent

## ----- Tile Creation Logic ----- ##

func create_tile(coord: Vector2i) -> void:
	var tile := hex_tile.instantiate() as Node3D
	tile.init(self, coord, TileSetupCatalog.get_layers_state(0,0, coord))
	add_child(tile)

	tile.position = HexCoord.axial_to_world(coord, hex_size)
	tiles_by_coord[coord] = tile
	

## ----- Pass Data Upstream ----- ##

func handle_hover(coord: Vector2i) -> void:
	## reset previous tile and contributing tiles
	if has_hover and hover_target != coord:
		reset_tile_visuals(hover_target)
		reset_contributing_tiles()

	has_hover = true
	hover_target = coord
	prev_target_visuals = tiles_by_coord[coord].visuals.duplicate_state()

	hex_manager.handle_hover(coord)

func handle_exit(coord: Vector2i) -> void:
	## if the cursor left the map
	if has_hover && hover_target == coord:
		hex_manager.handle_exit()
		reset_contributing_tiles()
		reset_tile_visuals(hover_target)
		has_hover = false
		hover_target = Vector2i.MAX

func handle_click(coord:Vector2i) -> void:
	hex_manager.handle_click(coord)

## ----- Pass Data Downstream ----- ##

func apply_preview(preview:TileStatePreview) -> void:
	if preview.is_valid:
		apply_target_preview_visuals(preview)
		apply_points_preview(preview)
		prev_contributing_tiles.assign(preview.contributing_coords)
	else:
		tiles_by_coord[hover_target].update_visuals(prev_target_visuals)
		tiles_by_coord[hover_target].show_outline(Color.CRIMSON)

func place_tile(coord:Vector2i) -> void:
	backup_target_visuals = prev_target_visuals.duplicate_state()
	prev_target_visuals = new_target_visuals.duplicate_state()

	var target := tiles_by_coord[coord]
	target.kill_animations()
	target.update_visuals(prev_target_visuals)
	target.hide_outline()
	target.hide_points()
	# _refresh_river_neighbor_visuals(coord)
	reset_contributing_tiles()

func play_placement_reward(
	coord: Vector2i,
	points: int,
	contributing_coords: Array[Vector2i]
) -> void:
	tiles_by_coord[coord].play_place_reward(points, hex_manager.tiles[coord].element)

	if points != 0:
		var flash_delay := 0.0
		for contributor in contributing_coords:
			if contributor == coord or !tiles_by_coord.has(contributor):
				continue
			var element := hex_manager.tiles[contributor].element
			tiles_by_coord[contributor].play_contributor_reward(element, flash_delay)
			flash_delay += contributor_stagger

func reset_preview(coord:Vector2i) -> void:
	new_target_visuals = prev_target_visuals.duplicate_state()

	reset_tile_visuals(coord)
	reset_contributing_tiles()

func undo(coord:Vector2i) -> void:
	for tile in tiles_by_coord.values():
		tile.kill_animations()
	prev_target_visuals = backup_target_visuals.duplicate_state()

	reset_tile_visuals(coord)
	# _refresh_river_neighbor_visuals(coord)
	reset_contributing_tiles()

## ----- Tile Preview Logic ----- ##

func apply_target_preview_visuals(preview:TileStatePreview) -> void:
	#var new_state := resolve_visual_state(
		#hover_target,
		#preview.tile_data,
		#preview.coord
	#)
	if preview.element == GameEnums.ELEMENT.RIVER:
		#prev_river_neighbor_tiles = _find_neighbor_tiles_with_element(
			#preview.coord,
			#GameEnums.ELEMENT.RIVER,
			#preview.coord,
			#preview.tile_data
		#)
		prev_river_neighbor_tiles = []
	else:
		prev_river_neighbor_tiles.clear()

	#new_target_visuals = new_state.duplicate_state()
	#tiles_by_coord[hover_target].update_visuals(new_state)

func apply_points_preview(preview:TileStatePreview) -> void:
	if preview.points_diff > 0:
		show_positive_preview(preview)
	elif preview.points_diff < 0:
		show_negative_preview(preview)
	else:
		show_neutral_preview(preview)

func show_positive_preview(preview: TileStatePreview) -> void:
	tiles_by_coord[hover_target].show_outline(Color.WHITE)
	tiles_by_coord[hover_target].show_points(preview.points_diff)

	for coord in preview.contributing_coords:
		if coord != hover_target:
			tiles_by_coord[coord].show_outline(Color.GOLD)

func show_negative_preview(preview: TileStatePreview) -> void:
	tiles_by_coord[hover_target].show_outline(Color.WHITE)
	tiles_by_coord[hover_target].show_points(preview.points_diff)

	for coord in preview.contributing_coords:
		if coord != hover_target:
			tiles_by_coord[coord].show_outline(Color.CRIMSON)

func show_neutral_preview(preview: TileStatePreview) -> void:
	tiles_by_coord[hover_target].show_outline(Color.WHITE)
	tiles_by_coord[hover_target].show_points(preview.points_diff)

## ----- Reset Logic ----- ##

func reset_tile_visuals(coord:Vector2i) -> void:
	var target = tiles_by_coord[coord]
	target.kill_animations()
	target.update_visuals(prev_target_visuals)
	target.hide_outline()
	target.hide_points()


#func resolve_visual_state(
	#coord: Vector2i,
	#tile_state: HexTileData,
	#preview_coord: Vector2i = Vector2i.MAX,
#) -> TileLayersState:
	#var state : TileLayersState = 
	#_apply_tile_data_to_visual_state(state, tile_state, coord)
#
	#if tile_state.element == GameEnums.ELEMENT.RIVER:
		#var river_neighbors := _find_neighbor_tiles_with_element(
			#coord,
			#GameEnums.ELEMENT.RIVER,
			#preview_coord
		#)
		## _apply_river_preview(state, coord, river_neighbors)
		#tile_state.orientation_steps = state.orientation_steps
	#else:
		#state = TileSetupCatalog.get_layers_state(
		#tile_state.element,
		#tile_state.level,
		#coord
	#)
	#return state
#
#
#func _apply_tile_data_to_visual_state(
	#state: TileLayersState,
	#tile_state: HexTileData,
	#coord: Vector2i
#) -> void:
	#state.element = tile_state.element
#
	#if tile_state.element != GameEnums.ELEMENT.RIVER:
		#if tile_state.orientation_steps >= 0:
			#state.orientation_steps = tile_state.orientation_steps
		#else:
			#state.orientation_steps = HexCoord.pick_orientation_steps(coord)
			#tile_state.orientation_steps = state.orientation_steps
#
	#state.animal_model = ""
	#if tile_state.animal_id != -1:
		#var animal = CardCatalog.animals[
			#CardCatalog.animals.find_custom(func (entry): return entry.id == tile_state.animal_id)
		#]
		#state.animal_model = animal.model
#
#
#func _refresh_river_neighbor_visuals(coord: Vector2i) -> void:
	#for direction in HexCoord.DIRECTIONS:
		#var neighbor := coord + direction
		#if not tiles_by_coord.has(neighbor) or not hex_manager.tiles.has(neighbor):
			#continue
		#if hex_manager.tiles[neighbor].element != GameEnums.ELEMENT.RIVER:
			#continue
		#var state := resolve_visual_state(neighbor, hex_manager.tiles[neighbor])
		#tiles_by_coord[neighbor].update_visuals(state)
#
#
#func _find_neighbor_tiles_with_element(
	#coord: Vector2i,
	#element: int,
	#preview_coord: Vector2i = Vector2i.MAX,
	#preview_state: HexTileData = null
#) -> Array[int]:
	#var neighbors: Array[int] = []
	#for i in HexCoord.DIRECTIONS.size():
		#var neighbor := coord + HexCoord.DIRECTIONS[i]
		#if not hex_manager.tiles.has(neighbor):
			#continue
		#if _element_at(neighbor, preview_coord, preview_state) == element:
			#neighbors.append(i)
	#print(neighbors)
	#neighbors.sort()
	#return neighbors
#
#
#func _element_at(
	#coord: Vector2i,
	#preview_coord: Vector2i,
	#preview_state: HexTileData
#) -> int:
	#if preview_state != null and coord == preview_coord:
		#return preview_state.element
	#return hex_manager.tiles[coord].element


func reset_contributing_tiles() -> void:
	if prev_contributing_tiles.size() > 0:
		for t in prev_contributing_tiles:
			tiles_by_coord[t].hide_outline()
	prev_contributing_tiles.clear()
	prev_river_neighbor_tiles.clear()
