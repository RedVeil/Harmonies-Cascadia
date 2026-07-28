extends Node3D
class_name HexTileContainer

@export var hex_tile: PackedScene
@export var hex_size: float = 11
@export var contributor_stagger: float = 0.06

var hex_manager: HexManager

var tiles_by_coord: Dictionary[Vector2i, HexTile] = {}

var has_hover: bool = false
var hover_target: Vector2i = Vector2i.MAX
var _undo_coord: Vector2i = Vector2i.MAX

var prev_contributing_tiles: Array[Vector2i]
var undo_river_neighbor_tiles: Array[Vector2i] = []
var prev_river_neighbor_tiles: Array[Vector2i] = []


## ----- Initialisation ----- ##

func init(parent: HexManager) -> void:
	hex_manager = parent


## ----- Tile Creation Logic ----- ##

func create_tile(coord: Vector2i) -> void:
	var tile := hex_tile.instantiate() as HexTile
	add_child(tile)
	tile.init(self, coord)
	tile.place_feedback_finished.connect(_on_place_feedback_finished.bind(coord))

	tile.position = HexCoord.axial_to_world(coord, hex_size)
	tiles_by_coord[coord] = tile


## ----- Pass Data Upstream ----- ##

func handle_hover(coord: Vector2i) -> void:
	if has_hover and hover_target != coord:
		reset_tile_visuals(hover_target)
		reset_contributing_tiles()

	has_hover = true
	hover_target = coord
	hex_manager.handle_hover(coord)


func handle_exit(coord: Vector2i) -> void:
	if has_hover && hover_target == coord:
		hex_manager.handle_exit()
		reset_contributing_tiles()
		reset_tile_visuals(hover_target)
		has_hover = false
		hover_target = Vector2i.MAX


func handle_click(coord: Vector2i) -> void:
	hex_manager.handle_click(coord)


func _on_place_feedback_finished(coord: Vector2i) -> void:
	hex_manager.handle_place_feedback_finished(coord)


## ----- Pass Data Downstream ----- ##

func apply_preview(preview: TileStatePreview) -> void:
	if preview.is_valid:
		apply_target_preview_visuals(preview)
		apply_points_preview(preview)
		prev_contributing_tiles.assign(preview.contributing_coords)
	else:
		tiles_by_coord[hover_target].reset_preview()
		tiles_by_coord[hover_target].hide_points()
		tiles_by_coord[hover_target].show_outline(Color.CRIMSON)
		show_tile_info(hover_target)


func place_tile(coord: Vector2i) -> void:
	discard_undo_visuals()

	var target := tiles_by_coord[coord]
	var tile_data := hex_manager.tiles[coord]
	target.kill_animations()

	var river_neighbors: Array[Vector2i] = []
	if tile_data.element == GameEnums.ELEMENT.RIVER:
		river_neighbors = get_element_neighbors(coord, GameEnums.ELEMENT.RIVER)
	target.commit_preview_from_tile_data(tile_data, river_neighbors)

	if prev_river_neighbor_tiles.size() > 0:
		for c in prev_river_neighbor_tiles:
			if hex_manager.tiles[c].element != GameEnums.ELEMENT.RIVER:
				continue
			var neighbor_rivers := get_element_neighbors(c, GameEnums.ELEMENT.RIVER)
			tiles_by_coord[c].commit_preview_from_tile_data(hex_manager.tiles[c], neighbor_rivers)

	target.hide_outline()
	target.hide_points()
	
	_undo_coord = coord
	undo_river_neighbor_tiles = prev_river_neighbor_tiles
	
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


func reset_preview(coord: Vector2i) -> void:
	reset_tile_visuals(coord)
	reset_contributing_tiles()


func undo(coord: Vector2i) -> void:
	for tile in tiles_by_coord.values():
		tile.kill_animations()

	var target := tiles_by_coord[coord]
	target.restore_undo_visual()
	
	if undo_river_neighbor_tiles.size() > 0:
		for c in undo_river_neighbor_tiles:
			tiles_by_coord[c].restore_undo_visual()
		undo_river_neighbor_tiles.clear()
	
	target.hide_outline()
	target.hide_points()
	_undo_coord = Vector2i.MAX
	reset_contributing_tiles()


func discard_undo_visuals() -> void:
	if _undo_coord == Vector2i.MAX or not tiles_by_coord.has(_undo_coord):
		return
	tiles_by_coord[_undo_coord].discard_undo_buffer()
	undo_river_neighbor_tiles.clear()
	_undo_coord = Vector2i.MAX


## ----- Tile Preview Logic ----- ##

func apply_target_preview_visuals(preview: TileStatePreview) -> void:
	prev_river_neighbor_tiles.clear()
	if preview.element == GameEnums.ELEMENT.RIVER:
		prev_river_neighbor_tiles = get_element_neighbors(preview.coord, GameEnums.ELEMENT.RIVER)
		preview_river_tile(preview.coord, preview.tile_data, prev_river_neighbor_tiles)
	else:
		tiles_by_coord[hover_target].preview_from_tile_data(preview.tile_data)

func preview_river_tile(coord:Vector2i, tile_data:HexTileData, river_neighbors:Array[Vector2i]) -> void:
	if tile_data.element != GameEnums.ELEMENT.RIVER:
		return
	var river_data = RiverPreviewLogic.get_river_index_and_rotation(coord, river_neighbors)
	tiles_by_coord[coord].preview_from_tile_data(tile_data, [], river_data[0], river_data[1])

func get_element_neighbors(coord:Vector2i, element:GameEnums.ELEMENT) -> Array[Vector2i]:
	var neighbors : Array[Vector2i] = []
	for neighbor in HexCoord.neighbors(coord):
		if tiles_by_coord.has(neighbor) and hex_manager.tiles[neighbor].element == element:
			neighbors.append(neighbor)
	return neighbors

func apply_points_preview(preview: TileStatePreview) -> void:
	hide_tile_info(hover_target)
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

func show_tile_info(coord: Vector2i) -> void:
	if not tiles_by_coord.has(coord) or not hex_manager.tiles.has(coord):
		return
	var data: HexTileData = hex_manager.tiles[coord]
	var element_tex: Texture2D = null
	var animal_tex: Texture2D = null

	var element := ElementCatalog.elements[data.element]
	var level_index := 0 if data.element == GameEnums.ELEMENT.NONE else clampi(data.level - 1, 0, element.levels.size() - 1)
	var level := element.levels[level_index]
	element_tex = load(level.icon) as Texture2D
	var icon_color := Color.html("#918478")

	if data.animal_id != -1:
		for card in CardCatalog.animals:
			if card.id == data.animal_id:
				if card.icon != "":
					animal_tex = load(card.icon) as Texture2D
				break

	var tile := tiles_by_coord[coord]
	tile.hide_points()
	tile.show_hover_info(element_tex, animal_tex, icon_color)
	tile.show_outline(Color.WHITE)


func hide_tile_info(coord: Vector2i) -> void:
	if tiles_by_coord.has(coord):
		tiles_by_coord[coord].hide_hover_info()


func reset_tile_visuals(coord: Vector2i) -> void:
	var target = tiles_by_coord[coord]
	target.kill_animations()
	target.reset_preview()
	target.hide_outline()
	target.hide_points()
	target.hide_hover_info()

	for river_coord in prev_river_neighbor_tiles:
		if tiles_by_coord.has(river_coord):
			tiles_by_coord[river_coord].reset_preview()


func reset_contributing_tiles() -> void:
	if prev_contributing_tiles.size() > 0:
		for t in prev_contributing_tiles:
			tiles_by_coord[t].hide_outline()
	prev_contributing_tiles.clear()
	prev_river_neighbor_tiles.clear()
