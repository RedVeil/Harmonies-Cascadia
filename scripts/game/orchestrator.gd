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
@export var end_game_button:EndGameButton

@onready var placement_logic:PlacementLogic = $PlacementLogic
@onready var grouping_logic:GroupingLogic = $GroupingLogic

var selected_card_id : int = -1
var cards_paused: bool = false
var tile_hovered : bool = false
var selected_coord : Vector2i = Vector2i.ZERO
var game_over: bool = false
## Sticky tile preview for touch: survives mouse_exit until place/deselect/new tap.
var touch_preview_locked: bool = false

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
	if not GameSettings.settings_changed.is_connected(_on_graphics_settings_changed):
		GameSettings.settings_changed.connect(_on_graphics_settings_changed)
	call_deferred("_on_graphics_settings_changed")
	_apply_game_mode_ui()
	if tutorial_bridge and not tutorial_bridge.action_performed.is_connected(_on_tutorial_bridge_action):
		tutorial_bridge.action_performed.connect(_on_tutorial_bridge_action)
	# Interactive tutorial owns first-run coaching; keep slideshow for non-tutorial runs / rules library.
	if not GameSession.is_tutorial() and not GameSession.is_puzzle():
		show_tutorial()
	if GameSession.is_puzzle():
		call_deferred("_apply_puzzle_setup")


func _apply_puzzle_setup() -> void:
	PuzzleSetupScript.apply(
		GameSession.puzzle_config,
		hex_manager,
		score_engine,
		point_counter
	)


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
	if end_game_button == null:
		return
	if GameSession.game_mode == GameSession.GameMode.ENDLESS:
		end_game_button.hide()
		end_game_button.disable()
	else:
		end_game_button.show()
		end_game_button.enable()

## ----- Handle Booster Interactions ----- ##

func add_hand_card(card:CardData) -> void:
	card_manager.add_card(card)
	undo_button.disable()

## ----- Handle Hand Interactions ----- ##

func select_hand_card(id:int) -> void:
	if game_over:
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
		_clear_touch_preview_lock()
		if tile_hovered:
			# Force-clear sticky touch preview (mouse may already have left).
			tile_hovered = false
			_hover_slide_coord = Vector2i(2147483647, 2147483647)
			hex_manager.hide_tile_info(selected_coord)
			hex_manager.reset_preview(selected_coord)
			hex_manager.clear_hover_tracking()
			quest_manager.reset_preview()
			point_counter.reset_preview()
			reset_preview()
			return
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
	if selected_card_id != -1:
		card_manager.deselect_card(selected_card_id)
		selected_card_id = -1
		_update_card_recycling_state()
		if tile_hovered:
			hex_manager.reset_preview(selected_coord)
		quest_manager.reset_preview()
		point_counter.reset_preview()
		reset_preview()
	_clear_touch_preview_lock()
	pause_cards()
	undo_button.disable()
	if end_game_button:
		end_game_button.disable()
	if game_over_overlay:
		game_over_overlay.open_confirm(score_engine.total_score)


func continue_game() -> void:
	if game_over:
		return
	if game_over_overlay:
		game_over_overlay.close()
	_apply_game_mode_ui()
	if map_points == 0:
		undo_button.enable()
	unpause_cards()


func confirm_end_game() -> void:
	if game_over:
		return
	game_over = true
	if game_over_overlay:
		game_over_overlay.show_results(score_engine.total_score)


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
		GameSession.begin_tutorial_run()
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

	var selected_card := card_manager.cards[card_id]
	if selected_card.type != CardData.CARD_TYPE.ANIMAL:
		return

	var count := selected_card.amount
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
		if TouchMode.is_touch():
			touch_preview_locked = true
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
	if TouchMode.is_touch() and touch_preview_locked:
		return false

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
		card_manager.remove_card(selected_card_id)
		if placed_was_element:
			booster_manager.notify_element_played()
		
		_clear_touch_preview_lock()
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


func _clear_touch_preview_lock() -> void:
	touch_preview_locked = false

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
