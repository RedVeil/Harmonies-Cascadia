extends Node3D
class_name HexTileContainer

@export var hex_tile : PackedScene
@export var hex_size: float = 10.0
@export var contributor_stagger: float = 0.06

var hex_manager : HexManager

var tiles_by_coord: Dictionary[Vector2i, HexTile] = {}

var has_hover:bool = false
var hover_target:Vector2i = Vector2i.MAX

var backup_target_visuals:HexTileVisuals
var prev_target_visuals:HexTileVisuals
var new_target_visuals:HexTileVisuals

var prev_contributing_tiles : Array[Vector2i]

## ----- Initialisation ----- ##

func init(parent:HexManager) -> void:
	hex_manager = parent

## ----- Tile Creation Logic ----- ##

func create_tile(coord: Vector2i) -> void:
	var tile := hex_tile.instantiate() as Node3D
	tile.init(self, coord)
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
	prev_target_visuals = tiles_by_coord[coord].visuals
	
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
		tiles_by_coord[hover_target].discard_preview_setup()
		tiles_by_coord[hover_target].show_outline(Color.CRIMSON)

func place_tile(coord:Vector2i) -> void:
	backup_target_visuals = prev_target_visuals.duplicate(true)
	prev_target_visuals = new_target_visuals.duplicate(true)

	var target := tiles_by_coord[coord]
	target.kill_animations()
	target.update_visuals(prev_target_visuals)
	target.hide_outline()
	target.hide_points()
	commit_tile_setup(coord)
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
	new_target_visuals = prev_target_visuals.duplicate(true)
	
	reset_tile_visuals(coord)
	reset_contributing_tiles()

func undo(coord:Vector2i) -> void:
	for tile in tiles_by_coord.values():
		tile.kill_animations()
	prev_target_visuals = backup_target_visuals.duplicate(true)
	
	reset_tile_visuals(coord)
	commit_tile_setup(coord)
	reset_contributing_tiles()

## ----- Tile Preview Logic ----- ##

func apply_target_preview_visuals(preview:TileStatePreview) -> void:
	var new_visuals = HexTileVisuals.new()
	var tile_state = preview.tile_data
	var element_level = ElementCatalog.elements[tile_state.element].levels[tile_state.level-1]
	
	new_visuals.color = Color.html(element_level.color)
	new_visuals.icon = load(element_level.icon)
	
	if tile_state.animal_id != -1:
		var animal = CardCatalog.animals[CardCatalog.animals.find_custom(func (animal): return animal.id == tile_state.animal_id)]
		new_visuals.animal_icon = load(animal.icon)
		new_visuals.animal_model = animal.model
	
	new_target_visuals = new_visuals
	tiles_by_coord[hover_target].update_visuals(new_visuals)
	apply_preview_setup(hover_target, tile_state)

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
	target.discard_preview_setup()
	target.update_visuals(prev_target_visuals)
	target.show_committed_setup()
	target.hide_outline()
	target.hide_points()


func apply_preview_setup(coord: Vector2i, tile_state: HexTileData) -> void:
	var setup_state := resolve_setup_state(coord, tile_state, coord, tile_state)
	tiles_by_coord[coord].set_preview_setup(setup_state)


func commit_tile_setup(coord: Vector2i) -> void:
	_commit_setup_at(coord)
	for direction in HexCoord.DIRECTIONS:
		var neighbor := coord + direction
		if hex_manager.tiles.has(neighbor) and hex_manager.tiles[neighbor].element == GameEnums.ELEMENT.RIVER:
			_commit_setup_at(neighbor)


func resolve_setup_state(
	coord: Vector2i,
	tile_state: HexTileData,
	preview_coord: Vector2i = Vector2i.MAX,
	preview_state: HexTileData = null
) -> TileSetupState:
	var setup := TileSetupCatalog.get_setup(tile_state.element, tile_state.level)
	var neighbor_directions: Array[int] = []
	if tile_state.element == GameEnums.ELEMENT.RIVER:
		neighbor_directions = _get_local_river_neighbor_directions(coord, preview_coord, preview_state)
	return TileSetupState.from_setup(setup, neighbor_directions)


func _commit_setup_at(coord: Vector2i) -> void:
	if not tiles_by_coord.has(coord) or not hex_manager.tiles.has(coord):
		return

	var setup_state := resolve_setup_state(coord, hex_manager.tiles[coord])
	tiles_by_coord[coord].commit_setup(setup_state)


func _tile_element_at(
	coord: Vector2i,
	preview_coord: Vector2i,
	preview_state: HexTileData
) -> int:
	if preview_state != null and coord == preview_coord:
		return preview_state.element
	return hex_manager.tiles[coord].element


func _get_river_neighbor_mask(
	coord: Vector2i,
	preview_coord: Vector2i = Vector2i.MAX,
	preview_state: HexTileData = null
) -> int:
	var mask := 0
	for direction_index in HexCoord.DIRECTIONS.size():
		var neighbor := coord + HexCoord.DIRECTIONS[direction_index]
		if not hex_manager.tiles.has(neighbor):
			continue
		if _tile_element_at(neighbor, preview_coord, preview_state) == GameEnums.ELEMENT.RIVER:
			mask |= 1 << direction_index
	return mask


func _get_river_neighbor_directions(
	coord: Vector2i,
	preview_coord: Vector2i = Vector2i.MAX,
	preview_state: HexTileData = null
) -> Array[int]:
	return RiverTileLogic.directions_from_mask(
		_get_river_neighbor_mask(coord, preview_coord, preview_state)
	)


func _get_local_river_neighbor_directions(
	coord: Vector2i,
	preview_coord: Vector2i = Vector2i.MAX,
	preview_state: HexTileData = null
) -> Array[int]:
	var world_directions := _get_river_neighbor_directions(coord, preview_coord, preview_state)
	if not tiles_by_coord.has(coord):
		return world_directions
	return HexCoord.directions_world_to_local(
		world_directions,
		tiles_by_coord[coord].tile_orientation_steps
	)

func reset_contributing_tiles() -> void:
	if prev_contributing_tiles.size() > 0:
		for t in prev_contributing_tiles:
			tiles_by_coord[t].hide_outline()
	prev_contributing_tiles.clear()
