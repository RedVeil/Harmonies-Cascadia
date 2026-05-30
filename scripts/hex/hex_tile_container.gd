extends Node3D
class_name HexTileContainer

@export var hex_tile : PackedScene
@export var hex_size: float = 2.0

var hex_manager : HexManager

var tiles_by_coord: Dictionary[Vector2i, HexTile] = {}

var has_hover:bool = false
var hover_target:Vector2i = Vector2i.MAX

var prev_target_visuals:HexTileVisuals
var new_target_visuals:HexTileVisuals
var prev_contributing_tiles : Array[Vector2i]

## ----- Initialisation ----- ##

func init(parent:HexManager) -> void:
	hex_manager = parent

## ----- Tile Creation ----- ##

func create_tile(coord: Vector2i) -> void:
	var tile := hex_tile.instantiate() as Node3D
	tile.init(self, coord)
	add_child(tile)

	tile.position = HexCoord.axial_to_world(coord, hex_size)
	tiles_by_coord[coord] = tile

## ----- Pass tile interactions upstream ----- ##

func handle_hover(coord: Vector2i) -> void:
	## reset previous tile and contributing tiles
	if has_hover:
		reset_tile_visuals()
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
		reset_tile_visuals()
		has_hover = false
		hover_target = Vector2i.MAX

func handle_click(coord:Vector2i) -> void:
	hex_manager.handle_click(coord)

## ----- Pass tile interactions downstream ----- ##

func apply_preview(preview:TileStatePreview) -> void:
	if preview.is_valid:
		apply_target_preview_visuals(preview)
		apply_points_preview(preview)
		prev_contributing_tiles.assign(preview.contributing_coords)
	else:
		tiles_by_coord[hover_target].show_outline(Color.CRIMSON)

func place_tile(coord:Vector2i) -> void:
	prev_target_visuals = new_target_visuals
	
	var target = tiles_by_coord[coord]
	target.hide_outline()
	target.hide_points()
	
	reset_contributing_tiles()

func reset_preview(coord:Vector2i) -> void:
	new_target_visuals = prev_target_visuals
	var target = tiles_by_coord[coord]
	target.hide_outline()
	target.hide_points()
	
	reset_contributing_tiles()

## ----- Tile Preview Functions ----- ##

func apply_target_preview_visuals(preview:TileStatePreview) -> void:
	var new_visuals = HexTileVisuals.new()
	var tile_state = preview.tile_data
	var element_level = ElementCatalog.elements[tile_state.element].levels[tile_state.level-1]
	
	new_visuals.color = Color.html(element_level.color)
	new_visuals.icon = load(element_level.icon)
	
	if tile_state.animal_id != -1:
		var animal = CardCatalog.animals[CardCatalog.animals.find_custom(func (animal): return animal.id == tile_state.animal_id)]
		new_visuals.animal_icon = load(animal.icon)
	
	new_target_visuals = new_visuals
	tiles_by_coord[hover_target].update_visuals(new_visuals)

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

## ----- Reset Functions ----- ##

func reset_tile_visuals() -> void:
	var target = tiles_by_coord[hover_target]
	target.update_visuals(prev_target_visuals)
	target.hide_outline()
	target.hide_points()

func reset_contributing_tiles() -> void:
	if prev_contributing_tiles.size() > 0:
		for t in prev_contributing_tiles:
			tiles_by_coord[t].hide_outline()
	prev_contributing_tiles.clear()
