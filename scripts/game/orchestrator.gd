extends Node
class_name Orchestrator

@export var booster_manager:BoosterManager
@export var card_manager:CardManager
@export var hex_manager:HexManager
@export var score_engine:ScoreEngine
@export var quest_manager:QuestManager
@export var point_counter:PointCounter

@onready var placement_logic:PlacementLogic = $PlacementLogic
@onready var grouping_logic:GroupingLogic = $GroupingLogic

var selected_card_id : int = -1
var cards_paused: bool = false
var tile_hovered : bool = false
var selected_coord : Vector2i = Vector2i.ZERO

var map_points: int = 0

## HexTile Preview State
var placement_valid : bool = false
var contributing_coords : Array[Vector2i] = []
var old_groups : Array[int] = []
var new_group : int = -1
var tile_data_preview : HexTileData

var new_group_score : int = 0
var new_element_score : int = 0
var new_quest_score : int = 0

func _ready() -> void:
	var vp := get_viewport()
	vp.physics_object_picking = true
	vp.physics_object_picking_sort = true
	vp.physics_object_picking_first_only = true

## ----- Handle Booster Interactions ----- ##

func add_hand_card(card:CardData) -> void:
	card_manager.add_card(card)

## ----- Handle Hand Interactions ----- ##

func select_hand_card(id:int) -> void:
	var new_selection = id
	
	## deselect selection
	if selected_card_id == id:
		new_selection = -1
		card_manager.deselect_card(id)
	## deselect previous selection
	elif selected_card_id != id and new_selection != -1 and selected_card_id != -1:
		card_manager.deselect_card(selected_card_id)
		
	selected_card_id = new_selection

func pause_cards() -> void:
	# cards_paused = true
	booster_manager.paused = true
	
func unpause_cards() -> void:
	# cards_paused = false
	booster_manager.paused = false
	card_manager.unpause()
	
func preview_recycle_card(id:int, amount:int, id_known:bool) -> void:
	if id_known:
		booster_manager.preview_booster_points(amount)
	else:
		if selected_card_id != -1:
			booster_manager.preview_booster_points(amount)
	
func apply_recycle_card(id:int, amount:int, id_known:bool) -> void:
	var card_id = id if id_known else selected_card_id
	if selected_card_id != -1:
		booster_manager.apply_booster_points()
		card_manager.remove_card(card_id)
		if selected_card_id != -1:
			preview_recycle_card(card_id, card_manager.recycling_value, true)

func reset_recycle_card_preview() -> void:
	booster_manager.reset_preview()

## ----- Handle Tile Interactions ----- ##

func handle_tile_hover(coord:Vector2i) -> void:
	tile_hovered = true
	selected_coord = coord
	
	if selected_card_id != -1 and !cards_paused:
		var preview:TileStatePreview
		var selected_card = card_manager.cards[selected_card_id]
		if selected_card.type == 0:
			preview = handle_element_preview(coord, selected_card)
		else:
			preview = handle_animal_preview(coord, selected_card)
		
		hex_manager.apply_preview(preview)
		booster_manager.preview_booster_points(preview.points_diff)
		point_counter.preview_progress(score_engine.total_score + preview.points_diff)
		# quest_manager.preview_progress()

func handle_tile_exit() -> void:
	tile_hovered = false
	
	booster_manager.reset_preview()
	hex_manager.reset_preview(selected_coord)
	quest_manager.reset_preview()
	point_counter.reset_preview()
	reset_preview()

func handle_tile_click(coord: Vector2i) -> void:
	if selected_card_id != -1 and placement_valid and !cards_paused:
		var selected_card = card_manager.cards[selected_card_id]
		if selected_card.type == 0:
			if old_groups.size() == 0:
				hex_manager.groups[new_group] = [coord]
				hex_manager.next_group_id += 1
			if old_groups.size() == 1:
				if !hex_manager.groups[old_groups[0]].has(coord):
					tile_data_preview.group_id = old_groups[0]
					hex_manager.groups[old_groups[0]].append(coord)
			if old_groups.size() > 1:
				var new_group_members : Array[Vector2i] = [coord]
				for g in old_groups:
					for m in hex_manager.groups[g]:
						hex_manager.tiles[m].group_id = old_groups[0]
						new_group_members.append(m)
					hex_manager.groups.erase(g)
					score_engine.points_per_element_group.erase(g)
				hex_manager.groups[old_groups[0]] = new_group_members
				
			score_engine.points_per_element_group[new_group] = new_group_score
			score_engine.element_score = new_element_score
			score_engine.quest_score = new_quest_score
			score_engine.total_score = new_element_score + new_quest_score + score_engine.animal_score
		else:
			score_engine.quest_score = new_quest_score
			score_engine.animal_score += selected_card.point_score
			score_engine.total_score = score_engine.animal_score + new_quest_score + score_engine.element_score
			
		hex_manager.tiles[coord] = tile_data_preview
			
		hex_manager.apply_placement(coord)
		card_manager.remove_card(selected_card_id)
		booster_manager.apply_booster_points()
		quest_manager.apply_preview()
		point_counter.apply_preview()
		
		reset_preview()
		
		if card_manager.cards[selected_card_id]:
			handle_tile_hover(coord)
		else:
			selected_card_id = -1


## ----- Handle Tile Preview ----- ##

func handle_element_preview(coord:Vector2i, card:CardData) -> TileStatePreview:
	if placement_logic.is_valid_element_placement(hex_manager.tiles[coord], card.placement):
		var prev_element = hex_manager.tiles[coord].element
		var var_prev_group =  hex_manager.tiles[coord].group_id
		
		var grouping_res = grouping_logic.group_by_element(coord, card.id, hex_manager)
		contributing_coords = grouping_res.contributing_coords
		old_groups = grouping_res.old_group_ids
		new_group = grouping_res.new_group_id
		tile_data_preview = create_tile_data_preview(coord, card.id, new_group)
		placement_valid = true
		
		## Change coords to neighbors for neighbor special rule
		if score_engine.active_rules[card.id].special_rule == 2:
			contributing_coords = get_neighbor_contributing_coords(contributing_coords)
		
		new_group_score = score_engine.calc_group_score(coord, contributing_coords, card.id, hex_manager.tiles)
		new_element_score = score_engine.calc_total_group_score(old_groups) + new_group_score
		new_quest_score = score_engine.quest_score + quest_manager.preview_element_quests(
			card.id, 
			old_groups,
			new_group,
			coord, 
			contributing_coords, 
			hex_manager.tiles
		)
		
		## reset tile_data after points calculation
		hex_manager.tiles[coord].element = prev_element
		hex_manager.tiles[coord].level -= 1
		hex_manager.tiles[coord].group_id = var_prev_group
		
		return TileStatePreview.new({
			"is_valid":true,
			"coord":coord, 
			"tile_data": tile_data_preview,
			"points_diff": (new_element_score - score_engine.element_score) + (new_quest_score - score_engine.quest_score), 
			"contributing_coords":contributing_coords
			})
	else:
		return TileStatePreview.new({
			"is_valid":false,
			"coord":Vector2i.MAX, 
			"tile_data": HexTileData.new(),
			"points_diff": 0, 
			"contributing_coords":[]
			})
		

func handle_animal_preview(coord:Vector2i, card:CardData) -> TileStatePreview:
	var placement_res = placement_logic.is_valid_animal_placement(
		coord,
		hex_manager.tiles[coord],
		card.placement,
		card.bonus,
		hex_manager.tiles
	)
	if placement_res.is_valid:
		placement_valid = true
		
		tile_data_preview = hex_manager.tiles[coord].duplicate(true)
		tile_data_preview.animal_id = card.id

		contributing_coords.assign(placement_res.coords)
		
		new_quest_score = score_engine.quest_score + quest_manager.preview_animal_quests(card.id)
		
		return TileStatePreview.new({
			"is_valid":true,
			"coord":coord,
			"tile_data": tile_data_preview,
			"points_diff": card.point_score + (new_quest_score - score_engine.quest_score),
			"contributing_coords":placement_res.coords
		})
	else:
		return TileStatePreview.new({
			"is_valid":false,
			"coord":Vector2i.MAX, 
			"tile_data": HexTileData.new(),
			"points_diff": 0, 
			"contributing_coords":[]
			})

## ----- Utility Functions ----- ##

func create_tile_data_preview(coord:Vector2i, element:int, group_id:int) -> HexTileData:
	var prev_element = hex_manager.tiles[coord].element
	hex_manager.tiles[coord].element = element
	hex_manager.tiles[coord].level += 1
	hex_manager.tiles[coord].group_id = group_id
	return hex_manager.tiles[coord].duplicate(true)

func reset_preview() -> void:
	placement_valid = false
	contributing_coords = []
	old_groups  = []
	new_group = -1
	new_group_score = 0
	new_element_score = 0
	new_quest_score = 0

func get_neighbor_contributing_coords(group_coords:Array[Vector2i]) -> Array[Vector2i]:
	var coords : Array[Vector2i] = group_coords.duplicate(true)
	for coord in group_coords:
		var neighbors = HexCoord.neighbors(coord)
		for n in neighbors:
			if hex_manager.tiles.has(n) and !coords.has(n):
				coords.append(n)
	return coords

## ----- Map Point Logic ----- ##

func add_map_points(val:int) -> void:
	map_points += val
	hex_manager.show_map_buttons()
	pause_cards()

func handle_map_button_click(coord:Vector2i) -> void:
	map_points -= 1
	hex_manager.create_map(coord)
	hex_manager.remove_map_buttons()
	
	if map_points == 0:
		unpause_cards()
	else:
		hex_manager.show_map_buttons()


## ----- Quest Logic ----- ##

func add_quest(id:int) -> void:
	quest_manager.add_quest(id)

func pick_quest(type:int, element:int) -> int:
	return quest_manager.pick_quest(type, element)


## ----- Score Tooltip Logic ----- ##

func get_active_rule(type:int) -> ScoringRule:
	return score_engine.active_rules[type]
