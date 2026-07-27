extends Node
class_name Orchestrator

@export var booster_manager:BoosterManager
@export var card_manager:CardManager
@export var hex_manager:HexManager
@export var score_engine:ScoreEngine
@export var quest_manager:QuestManager
@export var point_counter:PointCounter
@export var undo_button:UndoButton
@export var card_recycling:CardRecycling
@export var tutorial_overlay:TutorialOverlay

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
var last_points_diff : int = 0
var _hover_slide_coord := Vector2i(2147483647, 2147483647)

var coord_backup : Vector2i
var selected_card_backup : CardData 
var tile_backup : HexTileData
var old_groups_backup : Array[int] = []
var new_group_backup : int = -1
var new_group_score_backup : int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	var vp := get_viewport()
	vp.physics_object_picking = true
	vp.physics_object_picking_sort = true
	vp.physics_object_picking_first_only = true
	# show_tutorial()

## ----- Handle Booster Interactions ----- ##

func add_hand_card(card:CardData) -> void:
	card_manager.add_card(card)
	undo_button.disable()

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
	_update_card_recycling_state()
	if tile_hovered:
		if new_selection == -1:
			booster_manager.reset_preview()
			hex_manager.reset_preview(selected_coord)
			quest_manager.reset_preview()
			point_counter.reset_preview()
			reset_preview()
		handle_tile_hover(selected_coord)

func _update_card_recycling_state() -> void:
	if card_recycling == null:
		return
	if selected_card_id != -1:
		var selected_card := card_manager.cards[selected_card_id]
		if selected_card != null and selected_card.type == CardData.CARD_TYPE.ANIMAL:
			card_recycling.enable()
			return
	card_recycling.disable()

func pause_cards() -> void:
	cards_paused = true
	booster_manager.paused = true
	
func unpause_cards() -> void:
	if map_points > 0:
		return
	if card_manager.card_amount > card_manager.card_limit:
		return
	if card_manager.animal_amount > card_manager.animal_limit:
		return
	cards_paused = false
	booster_manager.paused = false
	card_manager.unpause()
	
func preview_recycle_card(id:int, amount:int, id_known:bool) -> void:
	if id_known:
		booster_manager.preview_booster_points(amount)
		return
	if selected_card_id == -1:
		return
	var selected_card := card_manager.cards[selected_card_id]
	if selected_card == null or selected_card.type != CardData.CARD_TYPE.ANIMAL:
		return
	booster_manager.preview_booster_points(amount * selected_card.amount)
	
func apply_recycle_card(id:int, amount:int, id_known:bool) -> void:
	var card_id := id if id_known else selected_card_id
	if card_id < 0 or card_manager.cards[card_id] == null:
		return
	
	if id_known:
		GameFeedback.play_recycle()
		booster_manager.apply_booster_points()
		card_manager.remove_card(card_id)
		undo_button.disable()
		if selected_card_id != -1 and card_manager.cards[selected_card_id] != null:
			preview_recycle_card(selected_card_id, card_manager.recycling_value, true)
		return
	
	var selected_card := card_manager.cards[card_id]
	if selected_card.type != CardData.CARD_TYPE.ANIMAL:
		return
	
	var count := selected_card.amount
	for i in count:
		GameFeedback.play_recycle()
		booster_manager.preview_booster_points(amount)
		booster_manager.apply_booster_points()
		card_manager.remove_card(card_id)
	undo_button.disable()
	_update_card_recycling_state()

func reset_recycle_card_preview() -> void:
	booster_manager.reset_preview()

## ----- Handle Tile Interactions ----- ##

func handle_tile_hover(coord:Vector2i) -> void:
	var entered_new_tile := coord != _hover_slide_coord
	_hover_slide_coord = coord
	tile_hovered = true
	selected_coord = coord
	
	if selected_card_id != -1 and !cards_paused:
		if entered_new_tile:
			GameFeedback.run_tile_hover_slide()
		var preview:TileStatePreview
		var selected_card = card_manager.cards[selected_card_id]
		if selected_card.type == 0:
			preview = handle_element_preview(coord, selected_card)
		else:
			preview = handle_animal_preview(coord, selected_card)
					
		hex_manager.apply_preview(preview)
		last_points_diff = preview.points_diff
		booster_manager.preview_booster_points(preview.points_diff)
		point_counter.preview_progress(score_engine.total_score + preview.points_diff)
	else:
		hex_manager.show_tile_info(coord)

func handle_tile_exit() -> void:
	tile_hovered = false
	_hover_slide_coord = Vector2i(2147483647, 2147483647)
	
	booster_manager.reset_preview()
	hex_manager.hide_tile_info(selected_coord)
	hex_manager.reset_preview(selected_coord)
	quest_manager.reset_preview()
	point_counter.reset_preview()
	reset_preview()

func handle_tile_click(coord: Vector2i) -> void:
	if selected_card_id != -1 and placement_valid and !cards_paused:
		var selected_card = card_manager.cards[selected_card_id]
		
		selected_card_backup = selected_card.duplicate(true)
		coord_backup = coord
		tile_backup = hex_manager.tiles[coord].duplicate(true)
		
		score_engine.element_score_backup = score_engine.element_score
		score_engine.animal_score_backup = score_engine.animal_score
		score_engine.quest_score_backup = score_engine.quest_score
		
		if selected_card.type == 0:
			old_groups_backup = old_groups.duplicate(true)
			new_group_backup = new_group
			new_group_score_backup = new_group_score
			hex_manager.groups_backup = hex_manager.groups.duplicate(true)
			score_engine.points_per_element_group_backup = score_engine.points_per_element_group.duplicate(true)
			
			if old_groups.size() == 0:
				hex_manager.groups[new_group] = [coord]
				hex_manager.next_group_id_backup = hex_manager.next_group_id
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
			score_engine.element_score = score_engine.new_element_score
			score_engine.quest_score = score_engine.new_quest_score
			score_engine.total_score = score_engine.new_element_score + score_engine.new_quest_score + score_engine.animal_score
		else:
			var animal_multiplier_score = 0
			if score_engine.placed_animals.has(selected_card.id):
				var animal_amount = score_engine.placed_animals[selected_card.id]
				animal_multiplier_score = int(animal_amount * selected_card.bonus_points)
				score_engine.placed_animals[selected_card.id] = animal_amount + 1
			else:
				score_engine.placed_animals[selected_card.id] = 1
			
			score_engine.quest_score = score_engine.new_quest_score
			score_engine.animal_score += selected_card.point_score + animal_multiplier_score
			score_engine.total_score = score_engine.animal_score + score_engine.new_quest_score + score_engine.element_score
			
		hex_manager.tiles[coord] = tile_data_preview
					
		hex_manager.apply_placement(coord)
		hex_manager.play_placement_reward(coord, last_points_diff, contributing_coords)
		# Commit HUD score before remove_card: emptying a stack deselects and
		# would otherwise wipe preview before apply_preview can animate it.
		booster_manager.apply_booster_points(true)
		quest_manager.apply_preview()
		point_counter.apply_preview(true)
		card_manager.remove_card(selected_card_id)
		
		reset_preview()
		if map_points == 0:
			undo_button.enable()
		
		if not card_manager.cards[selected_card_id]:
			selected_card_id = -1
		if tile_hovered and selected_card_id == -1:
			hex_manager.show_tile_info(coord)


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
		score_engine.new_element_score = score_engine.calc_total_group_score(old_groups) + new_group_score
		score_engine.new_quest_score = score_engine.quest_score + quest_manager.preview_element_quests(
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
			"points_diff": (score_engine.new_element_score - score_engine.element_score) + (score_engine.new_quest_score - score_engine.quest_score), 
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
		tile_data_preview.animal_amount = CardCatalog.animals[card.id].visual_amount

		contributing_coords.assign(placement_res.coords)
		
		score_engine.new_quest_score = score_engine.quest_score + quest_manager.preview_animal_quests(card.id)
		var animal_multiplier_score = 0
		if score_engine.placed_animals.has(card.id):
			var animal_amount = score_engine.placed_animals[card.id]
			animal_multiplier_score = int(animal_amount * card.bonus_points)
		
		return TileStatePreview.new({
			"is_valid":true,
			"coord":coord,
			"tile_data": tile_data_preview,
			"points_diff": card.point_score + animal_multiplier_score + (score_engine.new_quest_score - score_engine.quest_score),
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

## ----- Undo Logic ----- ##

func undo() -> void:
	GameFeedback.play_undo()
	booster_manager.undo() # works
	quest_manager.undo() # to be tested
	point_counter.undo() # works
	# Placement consumes one copy; restore exactly one (not the full pre-place stack).
	var restore_card := selected_card_backup.duplicate(true)
	restore_card.amount = 1
	card_manager.add_card(restore_card)
	
	score_engine.element_score = score_engine.element_score_backup
	score_engine.animal_score = score_engine.animal_score_backup
	score_engine.quest_score = score_engine.quest_score_backup
	score_engine.total_score = score_engine.element_score + score_engine.animal_score + score_engine.quest_score
	
	if selected_card_backup.type == 0: # works
		score_engine.points_per_element_group = score_engine.points_per_element_group_backup.duplicate(true)
		hex_manager.groups = hex_manager.groups_backup.duplicate(true)
		if old_groups_backup.size() == 0: # works
			hex_manager.next_group_id = hex_manager.next_group_id_backup
		if old_groups_backup.size() > 1: # works
			for g in old_groups_backup:
				for m in hex_manager.groups[g]:
					hex_manager.tiles[m].group_id = g
	else:
		if score_engine.placed_animals[selected_card_backup.id] > 1: # works
			score_engine.placed_animals[selected_card_backup.id] -= 1
		else: # works
			score_engine.placed_animals.erase(selected_card_backup.id) 
		
	hex_manager.tiles[coord_backup] = tile_backup.duplicate(true)
	hex_manager.undo(coord_backup) # works
	undo_button.disable() # works

## ----- Utility Logic ----- ##

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
	score_engine.new_element_score = 0
	score_engine.new_quest_score = 0

func get_neighbor_contributing_coords(group_coords:Array[Vector2i]) -> Array[Vector2i]:
	var coords : Array[Vector2i] = []
	if group_coords.size() > 1:
		coords = group_coords.duplicate(true)
	for coord in group_coords:
		var neighbors = HexCoord.neighbors(coord)
		for n in neighbors:
			if hex_manager.tiles.has(n) and !coords.has(n):
				coords.append(n)
	return coords

func get_secondary_elements() -> Array[int]:
	var elements : Array[int] = [0,0,0,0,0,0]
	for card in card_manager.cards:
		if card != null and card.type == 0:
			elements[card.id] += card.amount
	return elements

## ----- Map Point Logic ----- ##

func add_map_points(val:int) -> void:
	map_points += val
	hex_manager.discard_undo_visuals()
	hex_manager.show_map_buttons()
	undo_button.disable()
	pause_cards()
	point_counter.show_map_alert()

func handle_map_button_click(coord:Vector2i) -> void:
	map_points -= 1
	hex_manager.create_map(coord)
	hex_manager.remove_map_buttons()
	
	if map_points == 0:
		point_counter.hide_map_alert()
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

## ----- Score Tutorial ----- ##

func show_tutorial() -> void:
	if tutorial_overlay:
		tutorial_overlay.open()
