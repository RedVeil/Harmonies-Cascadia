extends Node
class_name Orchestrator

const PuzzleSetupScript := preload("res://scripts/game/puzzle_setup.gd")

signal tutorial_action(action: String, payload: Dictionary)

@export var booster_manager:BoosterManager
@export var card_manager:CardManager
@export var hex_manager:HexManager
@export var score_engine:ScoreEngine
@export var quest_manager:QuestManager
@export var point_counter:PointCounter
@export var undo_button:UndoButton
@export var card_recycling:CardRecycling
@export var tutorial_overlay:TutorialOverlay
@export var settings_overlay:SettingsOverlay
@export var game_over_overlay:GameOverOverlay
@export var in_game_menu:InGameMenu
@export var menu_button:MainMenuButton

@onready var placement_logic:PlacementLogic = $PlacementLogic
@onready var grouping_logic:GroupingLogic = $GroupingLogic

var selected_card_id : int = -1
var cards_paused: bool = false
var tile_hovered : bool = false
var selected_coord : Vector2i = Vector2i.ZERO
var game_over: bool = false

var map_points: int = 0

## Interactive tutorial gates (null / inactive = normal play).
var tutorial_bridge: TutorialBridge = TutorialBridge.new()
var _placed_tile_count: int = 0

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
	GameFeedback.start_background_music()
	if not UiPointerBlock.blocked_changed.is_connected(_on_ui_pointer_blocked_changed):
		UiPointerBlock.blocked_changed.connect(_on_ui_pointer_blocked_changed)
	if game_over_overlay:
		game_over_overlay.continue_pressed.connect(continue_game)
		game_over_overlay.end_pressed.connect(confirm_end_game)
		game_over_overlay.leave_pressed.connect(leave_to_menu)
		game_over_overlay.restart_pressed.connect(restart_run)
	if in_game_menu:
		in_game_menu.restart_pressed.connect(restart_run)
		in_game_menu.end_pressed.connect(_on_in_game_menu_end)
		in_game_menu.back_pressed.connect(_on_in_game_menu_back)
	if not GameSettings.settings_changed.is_connected(_on_graphics_settings_changed):
		GameSettings.settings_changed.connect(_on_graphics_settings_changed)
	call_deferred("_on_graphics_settings_changed")
	_apply_game_mode_ui()

	# Continue flow: restore run state after the scene loads.
	var pending_state = RunSave.consume_pending_state_or_null()
	if pending_state != null and RunSave.supports_mode(GameSession.game_mode):
		# Defer by 1 frame so all managers' @onready vars (e.g. QuestContainer)
		# are initialized before we apply state.
		call_deferred("_apply_pending_run_state_deferred", pending_state)

	if tutorial_bridge and not tutorial_bridge.action_performed.is_connected(_on_tutorial_bridge_action):
		tutorial_bridge.action_performed.connect(_on_tutorial_bridge_action)
	# Interactive tutorial owns first-run coaching; keep slideshow for non-tutorial runs / rules library.
	#if not GameSession.is_tutorial() and not GameSession.is_puzzle():
		#show_tutorial()
	if GameSession.is_puzzle():
		call_deferred("_apply_puzzle_setup")

func _apply_pending_run_state_deferred(pending_state: Variant) -> void:
	if pending_state == null:
		return
	if not RunSave.supports_mode(GameSession.game_mode):
		return
	var state := pending_state as Dictionary
	RunSave.apply_state_to_orchestrator(self, state)
	# The saved state may have been captured while the in-game menu was open,
	# leaving `cards_paused` and `booster_manager.paused` enabled.
	# We want Continue to resume play, so run normal "close menu" unpause logic.
	close_in_game_menu()


func _apply_puzzle_setup() -> void:
	var puzzle := GameSession.puzzle_config
	PuzzleSetupScript.apply(
		puzzle,
		hex_manager,
		score_engine,
		point_counter
	)
	_seed_scripted_hand(puzzle)


func apply_tutorial_part_setup(part: Dictionary) -> void:
	if part.is_empty():
		return
	var setup = part.get("setup", {})
	if typeof(setup) != TYPE_DICTIONARY or setup.is_empty():
		return
	var consumed := int(setup.get("boosters_consumed", 0))
	if booster_manager and consumed > 0:
		for _i in consumed:
			booster_manager.consume_booster_without_hand(0)
	PuzzleSetupScript.apply(setup, hex_manager, score_engine, point_counter)
	_seed_scripted_hand(setup)


func _seed_scripted_hand(config: Dictionary) -> void:
	if config.is_empty():
		return
	var raw_tiles = config.get("tiles", [])
	if typeof(raw_tiles) == TYPE_ARRAY:
		_placed_tile_count = maxi(_placed_tile_count, raw_tiles.size())
	var raw_animals = config.get("hand_animal_ids", [])
	if typeof(raw_animals) == TYPE_ARRAY:
		for animal_id in raw_animals:
			var card := _tutorial_animal_card(int(animal_id))
			if card != null:
				add_hand_card(card)
	var raw_elements = config.get("hand_element_ids", [])
	var seeded_elements := 0
	if typeof(raw_elements) == TYPE_ARRAY:
		for element_id in raw_elements:
			var card := _tutorial_element_card(int(element_id))
			if card != null:
				add_hand_card(card)
				seeded_elements += 1
	if booster_manager and seeded_elements > 0:
		booster_manager.seed_pending_elements(seeded_elements)


func apply_tutorial_part_tiles(part: Dictionary) -> void:
	if part.is_empty():
		return
	var setup = part.get("setup", {})
	if typeof(setup) != TYPE_DICTIONARY or setup.is_empty():
		return
	var tiles_only := {"tiles": setup.get("tiles", [])}
	PuzzleSetupScript.apply(tiles_only, hex_manager, score_engine, point_counter)
	var raw_tiles = setup.get("tiles", [])
	if typeof(raw_tiles) == TYPE_ARRAY:
		_placed_tile_count = maxi(_placed_tile_count, raw_tiles.size())


func _tutorial_animal_card(animal_id: int) -> CardData:
	for animal in CardCatalog.animals:
		if animal != null and animal.id == animal_id:
			return animal
	if animal_id >= 0 and animal_id < CardCatalog.animals.size():
		return CardCatalog.animals[animal_id]
	return null


func _tutorial_element_card(element_id: int) -> CardData:
	for element in CardCatalog.elements:
		if element != null and element.id == element_id:
			return element
	if element_id >= 0 and element_id < CardCatalog.elements.size():
		return CardCatalog.elements[element_id]
	return null


func _on_tutorial_bridge_action(action: String, payload: Dictionary) -> void:
	tutorial_action.emit(action, payload)


func set_tutorial_gates(gates: Dictionary) -> void:
	tutorial_bridge.set_gates(gates)


func clear_tutorial_gates() -> void:
	tutorial_bridge.clear_gates()


func tutorial_allows(action: String) -> bool:
	return tutorial_bridge.allows_action(action)


func tutorial_allows_booster(id: int) -> bool:
	return tutorial_bridge.allows_booster(id)


func has_placed_tile() -> bool:
	return _placed_tile_count > 0


func _apply_game_mode_ui() -> void:
	pass


func open_in_game_menu() -> void:
	if in_game_menu == null or score_engine == null:
		return
	if tutorial_bridge.active and not tutorial_bridge.allows_action("open_menu"):
		return
	if selected_card_id != -1:
		card_manager.deselect_card(selected_card_id)
		selected_card_id = -1
		_update_card_recycling_state()
		if tile_hovered:
			hex_manager.reset_preview(selected_coord)
		quest_manager.reset_preview()
		point_counter.reset_preview()
		reset_preview()
	pause_cards()
	undo_button.disable()
	in_game_menu.open(score_engine.total_score, game_over)
	tutorial_bridge.notify("menu_opened")


func close_in_game_menu() -> void:
	game_over = false
	if in_game_menu:
		in_game_menu.close()
	if map_points == 0:
		undo_button.enable()
	unpause_cards()


func _on_in_game_menu_back() -> void:
	close_in_game_menu()


func _on_in_game_menu_end() -> void:
	if game_over:
		return
	if tutorial_bridge.active and not tutorial_bridge.allows_action("end_game"):
		return
	game_over = true
	_submit_daily_score_if_needed()
	if RunSave.supports_mode(GameSession.game_mode):
		RunSave.save_from_orchestrator(self)
	leave_to_menu()


## ----- Handle Booster Interactions ----- ##

func add_hand_card(card:CardData) -> void:
	card_manager.add_card(card)
	undo_button.disable()

## ----- Handle Hand Interactions ----- ##

func select_hand_card(id:int) -> void:
	if game_over:
		return

	## Clear selection (e.g. card removed / recycle). Never deselect_card(-1).
	if id < 0:
		if selected_card_id != -1:
			card_manager.deselect_card(selected_card_id)
		selected_card_id = -1
		_update_card_recycling_state()
		_restore_hovered_tile_info()
		return

	var new_selection = id

	## deselect selection — always allowed so players can clear a bad pick
	if selected_card_id == id:
		new_selection = -1
		card_manager.deselect_card(id)
	else:
		if id >= 0 and id < card_manager.cards.size():
			var card := card_manager.cards[id]
			if card != null and not tutorial_bridge.allows_card(card):
				return
		## deselect previous selection
		if selected_card_id != id and new_selection != -1 and selected_card_id != -1:
			card_manager.deselect_card(selected_card_id)

	selected_card_id = new_selection
	_update_card_recycling_state()
	if new_selection == -1:
		_restore_hovered_tile_info()
	else:
		tutorial_bridge.notify("card_selected", {"card_id": new_selection})
		if tile_hovered:
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
	if game_over:
		return
	if map_points > 0:
		return
	if card_manager.card_amount > card_manager.card_limit:
		return
	if card_manager.animal_amount > card_manager.animal_limit:
		return
	cards_paused = false
	booster_manager.paused = false
	card_manager.unpause()

## ----- Game Over ----- ##

func end_game() -> void:
	if game_over:
		return
	if tutorial_bridge.active and not tutorial_bridge.allows_action("end_game"):
		return
	open_in_game_menu()


func continue_game() -> void:
	if game_over:
		return
	if game_over_overlay:
		game_over_overlay.close()
	close_in_game_menu()


func confirm_end_game() -> void:
	if game_over:
		return
	game_over = true
	_submit_daily_score_if_needed()
	if in_game_menu:
		in_game_menu.open(score_engine.total_score, true)
	elif game_over_overlay:
		game_over_overlay.show_results(score_engine.total_score)


func _submit_daily_score_if_needed() -> void:
	if GameSession.game_mode != GameSession.GameMode.DAILY:
		return
	if score_engine == null:
		return
	var player_id := GameSettings.player_id.strip_edges()
	var player_name := GameSettings.player_name.strip_edges()
	if player_id.is_empty() or player_name.is_empty():
		return
	SupabaseClient.submit_daily_score(player_id, player_name, score_engine.total_score)


func leave_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func restart_run() -> void:
	if GameSession.game_mode == GameSession.GameMode.DAILY:
		GameSession.begin_daily_run()
	elif GameSession.game_mode == GameSession.GameMode.ENDLESS:
		GameSession.begin_endless_run()
	elif GameSession.game_mode == GameSession.GameMode.CHALLENGE:
		GameSession.begin_challenge_run(
			GameSession.run_seed,
			GameSession.ring_count,
			GameSession.reference_score
		)
	elif GameSession.game_mode == GameSession.GameMode.TUTORIAL:
		GameSession.begin_tutorial_run(GameSession.tutorial_start_part)
	elif GameSession.game_mode == GameSession.GameMode.PUZZLE:
		GameSession.begin_puzzle_run(GameSession.puzzle_id)
	else:
		GameSession.begin_normal_run(GameSession.map_size)
	get_tree().call_deferred("reload_current_scene")

func preview_recycle_card(_id:int, _amount:int, _id_known:bool) -> void:
	pass
	
func apply_recycle_card(id:int, _amount:int, id_known:bool) -> void:
	if tutorial_bridge.active and not tutorial_bridge.allows_action("recycle"):
		return
	var card_id := id if id_known else selected_card_id
	if card_id < 0 or card_manager.cards[card_id] == null:
		return

	if id_known:
		GameFeedback.play_recycle()
		card_manager.remove_card(card_id)
		undo_button.disable()
		tutorial_bridge.notify("recycled", {"card_id": card_id})
		return

	recycle_hand_animal(card_id)

## Recycle a specific hand animal (full stack), e.g. from its per-card X button.
func recycle_hand_animal(card_id: int) -> void:
	if tutorial_bridge.active and not tutorial_bridge.allows_action("recycle"):
		return
	if card_id < 0 or card_id >= card_manager.cards.size():
		return
	var card := card_manager.cards[card_id]
	if card == null or card.type != CardData.CARD_TYPE.ANIMAL:
		return
	var count := card.amount
	# #region agent log
	_dbg87("E", "orchestrator.gd:recycle_hand_animal", "recycling hand animal", {
		"card_id": card_id,
		"amount": count,
		"catalog_id": card.id,
	})
	# #endregion
	for i in count:
		GameFeedback.play_recycle()
		card_manager.remove_card(card_id)
	undo_button.disable()
	_update_card_recycling_state()
	tutorial_bridge.notify("recycled", {"card_id": card_id})

func reset_recycle_card_preview() -> void:
	pass

## ----- Handle Tile Interactions ----- ##

func _on_ui_pointer_blocked_changed(blocked: bool) -> void:
	if not blocked:
		return
	if tile_hovered:
		hex_manager.hex_container.handle_exit(selected_coord)
	for map_btn in hex_manager.map_buttons:
		if map_btn != null and map_btn.has_method("clear_hover_for_ui"):
			map_btn.clear_hover_for_ui()


func handle_tile_hover(coord:Vector2i) -> void:
	if UiPointerBlock.is_blocked():
		return
	var entered_new_tile := coord != _hover_slide_coord
	_hover_slide_coord = coord
	tile_hovered = true
	selected_coord = coord

	if entered_new_tile:
		GameFeedback.run_tile_hover_slide()

	if selected_card_id != -1 and !cards_paused:
		placement_valid = false
		var preview:TileStatePreview
		var selected_card = card_manager.cards[selected_card_id]
		if selected_card.type == 0:
			preview = handle_element_preview(coord, selected_card)
		else:
			preview = handle_animal_preview(coord, selected_card)
					
		hex_manager.apply_preview(preview)
		last_points_diff = preview.points_diff
		point_counter.preview_progress(score_engine.total_score + preview.points_diff)
	else:
		hex_manager.show_tile_info(coord)

func handle_tile_exit() -> bool:
	tile_hovered = false
	_hover_slide_coord = Vector2i(2147483647, 2147483647)
	
	hex_manager.hide_tile_info(selected_coord)
	hex_manager.reset_preview(selected_coord)
	quest_manager.reset_preview()
	point_counter.reset_preview()
	reset_preview()
	return true

func handle_tile_click(coord: Vector2i) -> void:
	if UiPointerBlock.is_blocked():
		return
	if selected_card_id != -1 and placement_valid and !cards_paused:
		var selected_card = card_manager.cards[selected_card_id]
		var tile_data: HexTileData = hex_manager.tiles[coord] if hex_manager.tiles.has(coord) else null
		if not tutorial_bridge.allows_place_coord(coord, tile_data, placement_valid):
			return
		
		selected_card_backup = selected_card.duplicate(true)
		coord_backup = coord
		tile_backup = hex_manager.tiles[coord].duplicate(true)
		
		score_engine.element_score_backup = score_engine.element_score
		score_engine.animal_score_backup = score_engine.animal_score
		score_engine.quest_score_backup = score_engine.quest_score
		quest_manager.prepare_place_undo()
		
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
		else:
			var animal_multiplier_score := _animal_bonus_multiplier_score(selected_card)
			if score_engine.placed_animals.has(selected_card.id):
				score_engine.placed_animals[selected_card.id] += 1
			else:
				score_engine.placed_animals[selected_card.id] = 1
			
			score_engine.animal_score += selected_card.point_score + animal_multiplier_score
			
		hex_manager.tiles[coord] = tile_data_preview

		var quest_points := 0
		if selected_card.type == 0:
			quest_points = quest_manager.evaluate_pattern_quests(
				coord,
				hex_manager.tiles,
				placement_logic
			)
		score_engine.quest_score += quest_points
		score_engine.total_score = (
			score_engine.element_score + score_engine.animal_score + score_engine.quest_score
		)
		last_points_diff += quest_points
					
		hex_manager.apply_placement(coord)
		hex_manager.play_placement_reward(coord, last_points_diff, contributing_coords)
		# Commit HUD score before remove_card: emptying a stack deselects and
		# would otherwise wipe preview before apply_preview can animate it.
		point_counter.preview_progress(score_engine.total_score)
		point_counter.apply_preview(true)
		var placed_was_element = selected_card.type == CardData.CARD_TYPE.ELEMENT
		# #region agent log
		_dbg87("E", "orchestrator.gd:place", "removing placed card from hand", {
			"selected_card_id": selected_card_id,
			"card_type": selected_card.type,
			"catalog_id": selected_card.id,
			"amount_before": selected_card.amount,
		})
		# #endregion
		card_manager.remove_card(selected_card_id)
		if placed_was_element:
			booster_manager.notify_element_played()
		
		reset_preview()
		if map_points == 0:
			undo_button.enable()

		if not card_manager.cards[selected_card_id]:
			selected_card_id = -1

		_placed_tile_count += 1
		tutorial_bridge.notify("tile_placed", {
			"coord": coord,
			"card_type": selected_card_backup.type,
			"card_id": selected_card_backup.id,
		})


func handle_place_feedback_finished(coord: Vector2i) -> void:
	if tile_hovered and selected_coord == coord:
		handle_tile_hover(coord)


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
		
		## reset tile_data after points calculation
		hex_manager.tiles[coord].element = prev_element
		hex_manager.tiles[coord].level -= 1
		hex_manager.tiles[coord].group_id = var_prev_group
				
		return TileStatePreview.new({
			"is_valid":true,
			"coord":coord, 
			"tile_data": tile_data_preview,
			"points_diff": score_engine.new_element_score - score_engine.element_score, 
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
		
		var animal_multiplier_score := _animal_bonus_multiplier_score(card)
		
		return TileStatePreview.new({
			"is_valid":true,
			"coord":coord,
			"tile_data": tile_data_preview,
			"points_diff": card.point_score + animal_multiplier_score,
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

## Bonus scales with already-placed count, capped at catalog amount - 1.
func _animal_bonus_multiplier_score(card: CardData) -> int:
	if not score_engine.placed_animals.has(card.id):
		return 0
	var already_placed: int = score_engine.placed_animals[card.id]
	var max_scale_count := maxi(CardCatalog.animals[card.id].amount - 1, 0)
	return int(mini(already_placed, max_scale_count) * card.bonus_points)

## ----- Undo Logic ----- ##

func undo() -> void:
	if tutorial_bridge.active and not tutorial_bridge.allows_action("undo"):
		return
	quest_manager.undo() # to be tested
	point_counter.undo() # works
	# Placement consumes one copy; restore exactly one (not the full pre-place stack).
	var restore_card := selected_card_backup.duplicate(true)
	restore_card.amount = 1
	card_manager.add_card(restore_card)
	if selected_card_backup.type == CardData.CARD_TYPE.ELEMENT:
		booster_manager.notify_element_undone()

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
	_placed_tile_count = maxi(_placed_tile_count - 1, 0)
	tutorial_bridge.notify("undone", {"coord": coord_backup})

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


func _restore_hovered_tile_info() -> void:
	if not tile_hovered:
		return
	hex_manager.reset_preview(selected_coord)
	quest_manager.reset_preview()
	point_counter.reset_preview()
	reset_preview()
	handle_tile_hover(selected_coord)


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


func hand_element_count() -> int:
	if card_manager == null:
		return 0
	var count := 0
	for card in card_manager.cards:
		if card != null and card.type == CardData.CARD_TYPE.ELEMENT:
			count += maxi(card.amount, 0)
	return count

## ----- Map Point Logic ----- ##

func add_map_points(val:int) -> void:
	if not GameSession.allows_map_growth() or val <= 0:
		return
	map_points += val
	hex_manager.discard_undo_visuals()
	hex_manager.show_map_buttons()
	undo_button.disable()
	pause_cards()
	point_counter.show_map_alert()

func handle_map_button_click(coord:Vector2i) -> void:
	if not GameSession.allows_map_growth():
		return
	if tutorial_bridge.active and not tutorial_bridge.allows_action("map_expand"):
		return
	map_points -= 1
	hex_manager.create_map(coord)
	hex_manager.remove_map_buttons()

	if map_points == 0:
		point_counter.hide_map_alert()
		unpause_cards()
	else:
		hex_manager.show_map_buttons()
	tutorial_bridge.notify("map_expanded", {"coord": coord})

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
	if tutorial_overlay == null:
		return
	# TutorialOverlay is a later sibling, so it may not have finished _ready yet.
	if not tutorial_overlay.is_node_ready():
		await tutorial_overlay.ready
	tutorial_overlay.open()


func show_settings() -> void:
	open_in_game_menu()
	if in_game_menu:
		in_game_menu.open_settings_panel()
		return
	if settings_overlay == null:
		return
	if not settings_overlay.is_node_ready():
		await settings_overlay.ready
	settings_overlay.open()


func _on_graphics_settings_changed() -> void:
	if hex_manager == null or hex_manager.hex_container == null:
		return
	for tile in hex_manager.hex_container.tiles_by_coord.values():
		if not is_instance_valid(tile):
			continue
		for path in [&"VisualsRoot/current", &"VisualsRoot/previous"]:
			var visuals := tile.get_node_or_null(NodePath(path)) as TileVisuals
			if visuals == null:
				continue
			match GameSettings.animal_motion:
				GameSettings.AnimalMotion.FROZEN:
					visuals.freeze_animals()
				GameSettings.AnimalMotion.IDLE_SPECIAL:
					visuals.start_animal_idle_loop()
				GameSettings.AnimalMotion.FULL_ROAM:
					visuals.start_animal_roam()

# #region agent log
func _dbg87(hyp: String, loc: String, msg: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "87ce77",
		"hypothesisId": hyp,
		"location": loc,
		"message": msg,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
	}
	var path := "c:/Users/leonn/Documents/Harmonies-Cascadia/debug-87ce77.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f.seek_end()
	if f != null:
		f.store_line(JSON.stringify(payload))
		f.close()
# #endregion
