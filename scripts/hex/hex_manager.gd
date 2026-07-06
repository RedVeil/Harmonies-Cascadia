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
	orchestrator.handle_tile_hover(coord)

func handle_exit() -> void:
	orchestrator.handle_tile_exit()

func handle_click(coord:Vector2i) -> void:
	orchestrator.handle_tile_click(coord)

func handle_map_button_click(coord:Vector2i) -> void:
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
	
func undo(coord:Vector2i) -> void:
	hex_container.undo(coord)

func discard_undo_visuals() -> void:
	hex_container.discard_undo_visuals()

## ----- Map Logic ----- ##

func show_map_buttons() -> void:
	var available_coords : Array[Vector2i] = []
	for key in hex_map_active:
		var neighbors = HexCoord.map_neighbors(key, map_ring_count)
		for n in neighbors:
			if !available_coords.has(n) && !hex_map_active.has(n):
				available_coords.append(n)
	for coord in available_coords:
		create_map_button(coord)

func create_map_button(coord:Vector2i) -> void:
	var button := map_button.instantiate() as Node3D
	button.init(self, coord)
	add_child(button)
	button.position = HexCoord.axial_to_world(coord , 2.0)
	map_buttons.append(button)

func remove_map_buttons() -> void:
	for button in map_buttons:
		button.remove_button()
	map_buttons = []
