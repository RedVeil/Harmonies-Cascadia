extends Node2D

const HexGrid = preload("res://scripts/hex/HexGrid.gd")
const HexCoord = preload("res://scripts/hex/HexCoord.gd")
const TileState = preload("res://scripts/game/TileState.gd")
const ScoreEngine = preload("res://scripts/scoring/ScoreEngine.gd")
const AnimalSystem = preload("res://scripts/animals/AnimalSystem.gd")
const SpiritSystem = preload("res://scripts/spirits/SpiritSystem.gd")

const ELEMENT_KEYS := {
	KEY_1: TileState.Element.FOREST,
	KEY_2: TileState.Element.FIELD,
	KEY_3: TileState.Element.MOUNTAIN,
	KEY_4: TileState.Element.RIVER,
	KEY_5: TileState.Element.WETLANDS
}

const MAP_SIZE_VERY_SMALL := 0
const MAP_SIZE_SMALL := 1
const MAP_SIZE_NORMAL := 2
const MAP_SIZE_LARGE := 3
const MAP_SIZE_EXTRA_LARGE := 4

const DIFFICULTY_BEGINNER := 0
const DIFFICULTY_EASY := 1
const DIFFICULTY_NORMAL := 2
const DIFFICULTY_ADVANCED := 3
const DIFFICULTY_CHALLENGE := 4

const CARD_KIND_ELEMENT := "element"
const CARD_KIND_ANIMAL := "animal"
const CAMERA_BASE_ORIGIN := Vector2(640, 360)
const CAMERA_PAN_SPEED := 480.0

var selected_map_size: int = MAP_SIZE_NORMAL
var selected_difficulty: int = DIFFICULTY_NORMAL

var ring_count: int = 10
var unlocked_ring_count: int = 0
var progression_steps: Array[Dictionary] = []
var progression_step_index: int = 0
var grid := HexGrid.new(ring_count, 38.0, CAMERA_BASE_ORIGIN)
var board := {}
var score_engine := ScoreEngine.new()
var animal_system := AnimalSystem.new()
var spirit_system := SpiritSystem.new()

var current_turn: int = 1
var total_score: int = 0
var selected_mode: String = CARD_KIND_ELEMENT
var selected_element: int = TileState.Element.FOREST
var selected_animal: int = 0
var hand_cards: Array[Dictionary] = []
var selected_card_key: String = ""
var max_hand_size: int = 7
var animal_base_chance: float = 0.20
var animal_current_chance: float = 0.20
var element_draw_weights: Dictionary = {}
var hovered_coord := Vector2i(99999, 99999)
var hovered_hand_card_key: String = ""
var has_placed_first_forest := false
var game_finished := false
var camera_offset := Vector2.ZERO
var is_drag_panning := false
var recent_group_highlight_tiles: Array[Vector2i] = []
var recent_group_highlight_ttl: float = 0.0
var recent_group_highlight_duration: float = 0.85
var last_element_delta_info: String = "none"
var left_drag_start_pos := Vector2.ZERO
var left_drag_moved := false

var hud_label: Label
var rng := RandomNumberGenerator.new()
var debug_button: Button
var debug_popup: PopupPanel
var rules_tab_box: VBoxContainer
var draw_cards_tab_box: VBoxContainer
var globals_tab_box: VBoxContainer

func _ready() -> void:
	rng.randomize()
	_load_config()
	score_engine.load_elements_csv("res://data/elements.csv")
	score_engine.load_rules_json("res://data/element_rules.json")
	_load_progression_csv("res://data/progression.csv")
	animal_system.load_animals_csv("res://data/animals.csv")
	_sync_element_draw_weights()
	_apply_difficulty_card_settings()
	score_engine.init_rule_sets()
	for c in grid.coords:
		board[c] = TileState.new()
	_apply_progression_unlocks(total_score)
	_draw_initial_hand()
	_create_hud()
	_create_debug_ui()
	queue_redraw()

func _load_config() -> void:
	var cfg: Resource = load("res://data/game_config.tres")
	if cfg == null:
		return
	var cfg_ring = cfg.get("ring_count")
	if cfg_ring != null:
		ring_count = int(cfg_ring)
	var cfg_unlocked_ring = cfg.get("unlocked_ring_count")
	if cfg_unlocked_ring != null:
		unlocked_ring_count = int(cfg_unlocked_ring)
	var cfg_map_size = cfg.get("map_size")
	if cfg_map_size != null:
		selected_map_size = int(cfg_map_size)
	var cfg_difficulty = cfg.get("difficulty")
	if cfg_difficulty != null:
		selected_difficulty = int(cfg_difficulty)
	unlocked_ring_count = clampi(unlocked_ring_count, 0, ring_count)
	grid = HexGrid.new(ring_count, 38.0, CAMERA_BASE_ORIGIN)
	_apply_camera_origin()
	var cfg_penalties = cfg.get("penalties_enabled")
	if cfg_penalties != null:
		animal_system.penalties_enabled = bool(cfg_penalties)

func _create_hud() -> void:
	return

func _create_debug_ui() -> void:
	debug_button = Button.new()
	debug_button.text = "Debug"
	debug_button.position = Vector2(20, 20)
	debug_button.size = Vector2(92, 34)
	debug_button.pressed.connect(_on_debug_button_pressed)
	add_child(debug_button)

	debug_popup = PopupPanel.new()
	debug_popup.size = Vector2(560, 460)
	debug_popup.position = Vector2(26, 64)
	add_child(debug_popup)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 8)
	debug_popup.add_child(root)

	var title := Label.new()
	title.text = "Debug Tools"
	root.add_child(title)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tabs)

	rules_tab_box = VBoxContainer.new()
	rules_tab_box.name = "Rules"
	tabs.add_child(rules_tab_box)

	draw_cards_tab_box = VBoxContainer.new()
	draw_cards_tab_box.name = "Draw Cards"
	tabs.add_child(draw_cards_tab_box)

	globals_tab_box = VBoxContainer.new()
	globals_tab_box.name = "Globals"
	tabs.add_child(globals_tab_box)

	_rebuild_rules_debug_menu()
	_rebuild_draw_cards_debug_menu()
	_rebuild_globals_debug_menu()

func _rebuild_rules_debug_menu() -> void:
	if rules_tab_box == null:
		return
	for child in rules_tab_box.get_children():
		child.queue_free()

	var element_keys := ["forest", "field", "mountain", "river", "wetlands"]
	for element_key in element_keys:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s:" % element_key.capitalize()
		label.custom_minimum_size = Vector2(140, 0)
		row.add_child(label)

		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rules := score_engine.available_rule_ids_for(element_key)
		for rid in rules:
			picker.add_item(rid)
		var current_rule := score_engine.rule_id_for(element_key)
		for i in range(picker.item_count):
			if picker.get_item_text(i) == current_rule:
				picker.select(i)
				break
		picker.item_selected.connect(_on_rule_picker_item_selected.bind(element_key, picker))
		row.add_child(picker)
		rules_tab_box.add_child(row)

func _rebuild_draw_cards_debug_menu() -> void:
	if draw_cards_tab_box == null:
		return
	for child in draw_cards_tab_box.get_children():
		child.queue_free()

	var elements_title := Label.new()
	elements_title.text = "Element Cards"
	draw_cards_tab_box.add_child(elements_title)

	var element_row := HBoxContainer.new()
	element_row.add_theme_constant_override("separation", 6)
	draw_cards_tab_box.add_child(element_row)
	for e in score_engine.element_order():
		var b := Button.new()
		b.text = _element_name(e)
		b.pressed.connect(_on_debug_draw_card_pressed.bind(CARD_KIND_ELEMENT, e))
		element_row.add_child(b)

	var animals_title := Label.new()
	animals_title.text = "Animal Cards"
	draw_cards_tab_box.add_child(animals_title)

	var animals_scroll := ScrollContainer.new()
	animals_scroll.custom_minimum_size = Vector2(0, 280)
	animals_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	draw_cards_tab_box.add_child(animals_scroll)

	var animals_wrap := HFlowContainer.new()
	animals_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	animals_scroll.add_child(animals_wrap)
	var animal_ids: Array[int] = []
	for k in animal_system.animals_by_id.keys():
		animal_ids.append(int(k))
	animal_ids.sort()
	for id in animal_ids:
		var def: Dictionary = animal_system.animals_by_id[id]
		if not bool(def.get("enabled", true)):
			continue
		var b := Button.new()
		b.text = _animal_name(id)
		b.pressed.connect(_on_debug_draw_card_pressed.bind(CARD_KIND_ANIMAL, id))
		animals_wrap.add_child(b)

func _rebuild_globals_debug_menu() -> void:
	if globals_tab_box == null:
		return
	for child in globals_tab_box.get_children():
		child.queue_free()

	var max_hand_row := _debug_labeled_spinbox("Max Hand Cards", float(max_hand_size), 1, 20, 1)
	var max_hand_spin: SpinBox = max_hand_row["spinbox"]
	max_hand_spin.value_changed.connect(_on_global_max_hand_changed)
	globals_tab_box.add_child(max_hand_row["row"])

	var animal_base_row := _debug_labeled_spinbox("Animal Base Chance", animal_base_chance, 0.0, 1.0, 0.01)
	var animal_base_spin: SpinBox = animal_base_row["spinbox"]
	animal_base_spin.value_changed.connect(_on_global_animal_base_changed)
	globals_tab_box.add_child(animal_base_row["row"])

	var animal_current_row := _debug_labeled_spinbox("Animal Current Chance", animal_current_chance, 0.0, 1.0, 0.01)
	var animal_current_spin: SpinBox = animal_current_row["spinbox"]
	animal_current_spin.value_changed.connect(_on_global_animal_current_changed)
	globals_tab_box.add_child(animal_current_row["row"])

	var unlocked_rings_row := _debug_labeled_spinbox("Unlocked Rings", float(unlocked_ring_count), 0, ring_count, 1)
	var unlocked_rings_spin: SpinBox = unlocked_rings_row["spinbox"]
	unlocked_rings_spin.value_changed.connect(_on_global_unlocked_rings_changed)
	globals_tab_box.add_child(unlocked_rings_row["row"])

	var score_snapshot := score_engine.score_board_state(board, grid)
	var totals_label := Label.new()
	totals_label.text = "Element state total: %d" % int(score_snapshot.get("total_element_score", 0))
	globals_tab_box.add_child(totals_label)
	var delta_label := Label.new()
	delta_label.text = "Last element delta: %s" % last_element_delta_info
	globals_tab_box.add_child(delta_label)

func _on_debug_button_pressed() -> void:
	if debug_popup == null:
		return
	_rebuild_rules_debug_menu()
	_rebuild_draw_cards_debug_menu()
	_rebuild_globals_debug_menu()
	debug_popup.popup()

func _on_rule_picker_item_selected(index: int, element_key: String, picker: OptionButton) -> void:
	if index < 0 or index >= picker.item_count:
		return
	var chosen := picker.get_item_text(index)
	score_engine.set_rule_id(element_key, chosen)
	queue_redraw()

func _on_debug_draw_card_pressed(kind: String, id: int) -> void:
	_add_card(kind, id)
	_ensure_selected_card()
	queue_redraw()

func _debug_labeled_spinbox(label_text: String, value: float, min_value: float, max_value: float, step: float) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(180, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spin)
	return {"row": row, "spinbox": spin}

func _on_global_max_hand_changed(value: float) -> void:
	max_hand_size = maxi(1, int(round(value)))
	if _hand_slot_count() > max_hand_size:
		while _hand_slot_count() > max_hand_size and not hand_cards.is_empty():
			hand_cards.remove_at(hand_cards.size() - 1)
		_ensure_selected_card()
	queue_redraw()

func _on_global_animal_base_changed(value: float) -> void:
	animal_base_chance = clampf(value, 0.0, 1.0)
	if animal_current_chance < animal_base_chance:
		animal_current_chance = animal_base_chance
	queue_redraw()

func _on_global_animal_current_changed(value: float) -> void:
	animal_current_chance = clampf(value, 0.0, 1.0)
	queue_redraw()

func _on_global_unlocked_rings_changed(value: float) -> void:
	unlocked_ring_count = clampi(int(round(value)), 0, ring_count)
	queue_redraw()

func _process(delta: float) -> void:
	var moved := _update_camera_pan_from_keys(delta)
	if recent_group_highlight_ttl > 0.0:
		recent_group_highlight_ttl = maxf(0.0, recent_group_highlight_ttl - delta)
		moved = true
	var coord := grid.world_to_axial(get_viewport().get_mouse_position())
	hovered_hand_card_key = _hovered_hand_card_key(get_viewport().get_mouse_position())
	if coord != hovered_coord:
		hovered_coord = coord
		queue_redraw()
	elif moved or not hovered_hand_card_key.is_empty():
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if _is_final_infinite_stage():
				_finish_run()
				return
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drag_panning = true
				left_drag_start_pos = event.position
				left_drag_moved = false
				return
			if is_drag_panning:
				is_drag_panning = false
				if left_drag_moved:
					return
				if _try_select_card_from_hand(event.position):
					queue_redraw()
					return
				_try_place_at_mouse()
	elif event is InputEventMouseMotion and is_drag_panning:
		camera_offset += event.relative
		if event.position.distance_to(left_drag_start_pos) > 4.0:
			left_drag_moved = true
		_apply_camera_origin()
		queue_redraw()

func _try_place_at_mouse() -> void:
	if game_finished:
		return
	var coord := grid.world_to_axial(get_viewport().get_mouse_position())
	if not grid.has_coord(coord) or not _is_tile_unlocked(coord):
		return
	if selected_card_key.is_empty():
		_update_hud("Select a card from your hand first.")
		return

	var prev_score := total_score
	var turn_delta := 0
	if selected_mode == CARD_KIND_ELEMENT:
		var simulation := score_engine.simulate_action_delta(board, grid, {
			"kind": "element",
			"coord": coord,
			"element": selected_element
		})
		if not bool(simulation.get("valid", false)):
			_update_hud(String(simulation.get("reason", "Invalid move")))
			return
		board = (simulation["after_board"] as Dictionary)
		turn_delta += int(score_engine.placement_bonus) + int(simulation["delta"])
		last_element_delta_info = "%+d (state %+d + base +1)" % [int(score_engine.placement_bonus) + int(simulation["delta"]), int(simulation["delta"])]
		recent_group_highlight_tiles = (simulation.get("affected_group_tiles", []) as Array[Vector2i]).duplicate()
		recent_group_highlight_ttl = recent_group_highlight_duration
		if selected_element == TileState.Element.FOREST and not has_placed_first_forest:
			has_placed_first_forest = true
			spirit_system.maybe_spawn_first_forest_spirit(true, current_turn)
	else:
		if not animal_system.can_place_animal(board, coord, selected_animal):
			_update_hud("Invalid animal placement")
			return
		var a_score := animal_system.score_animal(board, grid, coord, selected_animal)
		var tile2: TileState = board[coord]
		tile2.animal = selected_animal
		animal_system.register_animal_goal(board, coord, selected_animal, current_turn)
		turn_delta += a_score + 1

	_consume_selected_card()

	var spirit_result := spirit_system.evaluate(board, grid, current_turn)
	turn_delta += spirit_result["delta"]
	turn_delta += animal_system.process_turn_penalties(board, current_turn)

	total_score += turn_delta
	var unlock_msg := _apply_progression_unlocks(total_score)
	var draw_msg := _draw_turn_cards()
	current_turn += 1
	if game_finished:
		_update_hud("Game over. Final score: %d" % total_score)
	elif unlock_msg.is_empty():
		_update_hud("Turn +1, gained %d points. %s" % [turn_delta, draw_msg])
	else:
		_update_hud("Turn +1, gained %d points. %s %s" % [turn_delta, unlock_msg, draw_msg])
	queue_redraw()

func _draw() -> void:
	for c in grid.coords:
		if not _is_tile_unlocked(c):
			continue
		_draw_hex(c, _tile_color(board[c]))
		_draw_tile_icon(c, board[c])
	_draw_animal_symbols()
	_draw_recent_group_highlight()
	_draw_hover_highlights()
	_draw_hover_preview()
	_draw_progress_circle()
	_draw_hand_ui()

func _draw_recent_group_highlight() -> void:
	if recent_group_highlight_ttl <= 0.0:
		return
	var alpha := clampf(recent_group_highlight_ttl / recent_group_highlight_duration, 0.0, 1.0)
	for c in recent_group_highlight_tiles:
		if _is_tile_unlocked(c):
			_draw_glow_border(c, Color(0.95, 0.75, 0.16, 0.85 * alpha), 4.0)

func _draw_animal_symbols() -> void:
	for c in grid.coords:
		if not _is_tile_unlocked(c):
			continue
		var tile: TileState = board[c]
		if tile.animal == 0:
			continue
		var center := grid.axial_to_world(c)
		var symbol := animal_system.animal_symbol_texture(tile.animal)
		if symbol != null:
			var size := Vector2(26, 26)
			var rect := Rect2(center - size * 0.5, size)
			draw_texture_rect(symbol, rect, false)
		else:
			var label := _animal_name(tile.animal).substr(0, 1).to_upper()
			draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, 16, 16, Color.BLACK)

func _draw_hex(coord: Vector2i, color: Color) -> void:
	var center := grid.axial_to_world(coord)
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := deg_to_rad(60 * i - 30)
		pts.append(center + Vector2(cos(ang), sin(ang)) * grid.tile_size * 0.92)
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 2.0)

func _draw_tile_icon(coord: Vector2i, tile: TileState) -> void:
	var tex := score_engine.icon_texture_for(tile.element, tile.stack_count)
	if tex == null:
		return
	var center := grid.axial_to_world(coord)
	var size := Vector2(30, 30)
	draw_texture_rect(tex, Rect2(center - size * 0.5, size), false)

func _tile_color(tile: TileState) -> Color:
	match tile.element:
		TileState.Element.NONE:
			return Color(0.36, 0.28, 0.22)
		TileState.Element.MOUNTAIN:
			if tile.stack_count >= 2:
				return Color(0.38, 0.38, 0.42)
			if tile.stack_count == 1:
				return Color(0.48, 0.48, 0.52)
			return Color(0.58, 0.48, 0.38)
		TileState.Element.FOREST:
			if tile.stack_count >= 2:
				return Color(0.10, 0.36, 0.14)
			if tile.stack_count == 1:
				return Color(0.16, 0.46, 0.20)
			return Color(0.22, 0.52, 0.22)
		TileState.Element.FIELD:
			if tile.stack_count >= 1:
				return Color(0.84, 0.74, 0.34)
			return Color(0.90, 0.82, 0.46)
		TileState.Element.RIVER:
			return Color(0.20, 0.40, 0.85)
		TileState.Element.WETLANDS:
			return Color(0.20, 0.58, 0.50)
		_:
			return Color(0.36, 0.28, 0.22)

func _draw_hover_preview() -> void:
	if not grid.has_coord(hovered_coord) or not _is_tile_unlocked(hovered_coord):
		return

	var center := grid.axial_to_world(hovered_coord)
	var preview := _preview_turn_points(hovered_coord)
	if selected_mode == CARD_KIND_ELEMENT and preview["valid"]:
		var overlay := Color(_tile_color(board[hovered_coord]))
		if preview["valid"]:
			match selected_element:
				TileState.Element.FOREST:
					overlay = Color(0.18, 0.60, 0.24, 0.55)
				TileState.Element.FIELD:
					overlay = Color(0.92, 0.84, 0.46, 0.55)
				TileState.Element.MOUNTAIN:
					overlay = Color(0.72, 0.72, 0.76, 0.55)
				TileState.Element.RIVER:
					overlay = Color(0.36, 0.58, 0.96, 0.55)
				TileState.Element.WETLANDS:
					overlay = Color(0.32, 0.72, 0.62, 0.55)
			_draw_hex(hovered_coord, overlay)
	elif selected_mode == CARD_KIND_ANIMAL:
		_draw_hover_animal_symbol(center)
	if preview["valid"]:
		var delta := int(preview["points"])
		var prefix := "+" if delta >= 0 else ""
		var text := "%s%d" % [prefix, delta]
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-24, -40),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			100,
			18,
			Color(0.95, 0.97, 1.0, 1.0)
		)

func _draw_hover_highlights() -> void:
	if not grid.has_coord(hovered_coord) or not _is_tile_unlocked(hovered_coord):
		return
	var info: Dictionary = _build_hover_highlight_info(hovered_coord)
	var radius_tiles: Array = info["radius"]
	for c in radius_tiles:
		_draw_glow_border(c as Vector2i, Color(1, 1, 1, 0.35), 2.0)
	_draw_glow_border(hovered_coord, info["border"] as Color, 4.0)
	var positive: Array = info["positive"]
	var negative: Array = info["negative"]
	for c in positive:
		_draw_glow_border(c as Vector2i, Color(1.0, 0.84, 0.2, 0.95), 3.0)
	for c in negative:
		_draw_glow_border(c as Vector2i, Color(1, 0.2, 0.2, 0.95), 3.0)

func _draw_glow_border(coord: Vector2i, color: Color, width: float) -> void:
	var center := grid.axial_to_world(coord)
	var pts := PackedVector2Array()
	for i in range(6):
		var ang := deg_to_rad(60 * i - 30)
		pts.append(center + Vector2(cos(ang), sin(ang)) * grid.tile_size * 0.97)
	draw_polyline(pts + PackedVector2Array([pts[0]]), color, width)

func _build_hover_highlight_info(coord: Vector2i) -> Dictionary:
	var positive: Array[Vector2i] = []
	var negative: Array[Vector2i] = []
	var radius_tiles: Array[Vector2i] = []
	var can_place := false

	if selected_mode == CARD_KIND_ELEMENT:
		var preview := score_engine.simulate_action_delta(board, grid, {
			"kind": "element",
			"coord": coord,
			"element": selected_element
		})
		can_place = bool(preview.get("valid", false))
		if can_place:
			var tiles: Array = preview.get("affected_group_tiles", [])
			var gained_rule_points := int(preview.get("delta", 0)) > 0
			for t in tiles:
				var tc := t as Vector2i
				if tc == coord or not _is_tile_unlocked(tc):
					continue
				if gained_rule_points:
					positive.append(tc)
				else:
					negative.append(tc)
	else:
		can_place = animal_system.can_place_animal(board, coord, selected_animal)
		if can_place and animal_system.animals_by_id.has(selected_animal):
			var def: Dictionary = animal_system.animals_by_id[selected_animal]
			var needed_counts: Dictionary = {}
			for t in def["required_specs"] as Array:
				var key := str(t)
				needed_counts[key] = int(needed_counts.get(key, 0)) + 1
			var found_counts: Dictionary = {}
			var check_range := int(def["range"])
			for c in board.keys():
				var c2 := c as Vector2i
				if not _is_tile_unlocked(c2):
					continue
				var dist := HexCoord.distance(coord, c2)
				if dist > check_range:
					continue
				radius_tiles.append(c2)
				if dist == 0:
					continue
				var tkey := animal_system.tile_spec_key(board[c2] as TileState)
				if needed_counts.has(tkey):
					found_counts[tkey] = int(found_counts.get(tkey, 0)) + 1
					positive.append(c2)
			for tkey in needed_counts.keys():
				if int(found_counts.get(tkey, 0)) < int(needed_counts[tkey]):
					for c in board.keys():
						var c2 := c as Vector2i
						if not _is_tile_unlocked(c2):
							continue
						var dist := HexCoord.distance(coord, c2)
						if dist == 0 or dist > check_range:
							continue
						var spec_key := animal_system.tile_spec_key(board[c2] as TileState)
						if spec_key == String(tkey) and not positive.has(c2):
							negative.append(c2)

	var border := Color(1, 1, 1, 0.95) if can_place else Color(1, 0.2, 0.2, 0.95)
	return {"border": border, "positive": positive, "negative": negative, "radius": radius_tiles}

func _collect_connected(source_board: Dictionary, start: Vector2i, element: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not source_board.has(start):
		return out
	if int((source_board[start] as TileState).element) != element:
		return out
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		out.append(c)
		for n in grid.neighbors(c):
			if seen.has(n):
				continue
			if int((source_board[n] as TileState).element) == element:
				seen[n] = true
				queue.append(n)
	return out

func _draw_hover_animal_symbol(center: Vector2) -> void:
	var symbol := animal_system.animal_symbol_texture(selected_animal)
	if symbol != null:
		var size := Vector2(30, 30)
		var rect := Rect2(center - size * 0.5, size)
		draw_texture_rect(symbol, rect, false, Color(1, 1, 1, 0.65))
	else:
		var label := _animal_name(selected_animal).substr(0, 1).to_upper()
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), label, HORIZONTAL_ALIGNMENT_LEFT, 16, 16, Color(1, 1, 1, 0.75))

func _draw_progress_circle() -> void:
	var stage := _current_stage_progress()
	var vp := get_viewport_rect().size
	var center := Vector2(92, vp.y - 92)
	var radius := 64.0
	var border_width := 8.0

	# Base dark circle
	draw_circle(center, radius, Color(0.08, 0.17, 0.26, 0.95))
	# Base border
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.88, 0.90, 0.93, 0.95), border_width, true)
	# Progress border from top clockwise
	var progress: float = float(stage["progress"])
	var start := -PI / 2.0
	var finish := start + TAU * progress
	if progress > 0.001:
		draw_arc(center, radius, start, finish, 96, Color(0.55, 0.90, 0.26, 1.0), border_width, true)
	
	var top_text := str(int(stage["current"]))
	var bottom_text := "∞" if bool(stage["needed_is_infinite"]) else str(int(stage["needed"]))
	draw_string(ThemeDB.fallback_font, center + Vector2(-40, -6), top_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color(0.55, 0.90, 0.26, 1.0))
	draw_line(center + Vector2(-24, 2), center + Vector2(24, 2), Color(0.92, 0.93, 0.95, 0.95), 3.0)
	draw_string(ThemeDB.fallback_font, center + Vector2(-40, 36), bottom_text, HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color(0.92, 0.93, 0.95, 1.0))

func _current_stage_progress() -> Dictionary:
	if progression_steps.is_empty():
		return {"current": 0, "needed": 0, "progress": 1.0, "needed_is_infinite": false}

	if progression_step_index >= progression_steps.size():
		return {"current": total_score, "needed": total_score, "progress": 1.0, "needed_is_infinite": false}

	var next_threshold: int = int((progression_steps[progression_step_index] as Dictionary)["threshold"])
	if next_threshold < 0:
		return {"current": total_score, "needed": -1, "progress": 1.0, "needed_is_infinite": true}

	var ratio := 1.0
	if next_threshold > 0:
		ratio = float(total_score) / float(next_threshold)
	return {"current": total_score, "needed": next_threshold, "progress": clampf(ratio, 0.0, 1.0), "needed_is_infinite": false}

func _preview_turn_points(coord: Vector2i) -> Dictionary:
	if not grid.has_coord(coord) or not _is_tile_unlocked(coord):
		return {"valid": false, "points": 0}
	if selected_card_key.is_empty():
		return {"valid": false, "points": 0}

	var sim_board: Dictionary = _clone_board(board)
	var turn_delta: int = 0
	var valid := false
	var temp_first_forest := has_placed_first_forest
	var temp_spirit: SpiritSystem = _clone_spirit_system()
	var temp_animals: AnimalSystem = _clone_animal_system()

	if selected_mode == CARD_KIND_ELEMENT:
		var element_preview := score_engine.simulate_action_delta(sim_board, grid, {
			"kind": "element",
			"coord": coord,
			"element": selected_element
		})
		if not bool(element_preview.get("valid", false)):
			return {"valid": false, "points": 0}
		valid = true
		sim_board = element_preview["after_board"] as Dictionary
		turn_delta += int(score_engine.placement_bonus) + int(element_preview["delta"])
		if selected_element == TileState.Element.FOREST and not temp_first_forest:
			temp_first_forest = true
			temp_spirit.maybe_spawn_first_forest_spirit(true, current_turn)
	else:
		if not temp_animals.can_place_animal(sim_board, coord, selected_animal):
			return {"valid": false, "points": 0}
		valid = true
		var a_score := temp_animals.score_animal(sim_board, grid, coord, selected_animal)
		var tile2: TileState = sim_board[coord]
		tile2.animal = selected_animal
		temp_animals.register_animal_goal(sim_board, coord, selected_animal, current_turn)
		turn_delta += a_score + 1

	var spirit_result := temp_spirit.evaluate(sim_board, grid, current_turn)
	turn_delta += int(spirit_result["delta"])
	turn_delta += temp_animals.process_turn_penalties(sim_board, current_turn)
	return {"valid": valid, "points": turn_delta}

func _clone_board(source_board: Dictionary) -> Dictionary:
	var clone: Dictionary = {}
	for c in source_board.keys():
		clone[c] = (source_board[c] as TileState).clone()
	return clone

func _clone_spirit_system() -> SpiritSystem:
	var cloned := SpiritSystem.new()
	cloned.active_quest = spirit_system.active_quest.duplicate(true)
	cloned.forest_modifier_delta = spirit_system.forest_modifier_delta
	return cloned

func _clone_animal_system() -> AnimalSystem:
	var cloned := AnimalSystem.new()
	cloned.penalties_enabled = animal_system.penalties_enabled
	cloned.animals_by_id = animal_system.animals_by_id.duplicate(true)
	cloned.pending_goals = animal_system.pending_goals.duplicate(true)
	return cloned

func _apply_difficulty_card_settings() -> void:
	match selected_difficulty:
		DIFFICULTY_BEGINNER:
			max_hand_size = 9
			animal_base_chance = 0.10
		DIFFICULTY_EASY:
			max_hand_size = 8
			animal_base_chance = 0.14
		DIFFICULTY_NORMAL:
			max_hand_size = 7
			animal_base_chance = 0.18
		DIFFICULTY_ADVANCED:
			max_hand_size = 6
			animal_base_chance = 0.22
		DIFFICULTY_CHALLENGE:
			max_hand_size = 5
			animal_base_chance = 0.26
		_:
			max_hand_size = 7
			animal_base_chance = 0.18
	animal_current_chance = animal_base_chance

func _draw_initial_hand() -> void:
	for _i in range(min(3, max_hand_size)):
		_draw_turn_cards()
	_ensure_selected_card()

func _draw_turn_cards() -> String:
	if _hand_slot_count() >= max_hand_size:
		return "Hand full."
	var element := _roll_element_draw()
	_add_card(CARD_KIND_ELEMENT, element)
	var msg := "Drew %s." % _element_name(element)
	if _hand_slot_count() >= max_hand_size:
		animal_current_chance = min(animal_current_chance + 0.33, 1.0)
		_ensure_selected_card()
		return msg

	if rng.randf() <= animal_current_chance:
		var animal := _roll_animal_for_element(element)
		if animal != 0:
			_add_card(CARD_KIND_ANIMAL, animal)
			msg += " + %s." % _animal_name(animal)
			animal_current_chance = animal_base_chance
		else:
			animal_current_chance = min(animal_current_chance + 0.33, 1.0)
	else:
		animal_current_chance = min(animal_current_chance + 0.33, 1.0)
	_ensure_selected_card()
	return msg

func _roll_element_draw() -> int:
	var order := score_engine.element_order()
	if order.is_empty():
		return TileState.Element.FOREST
	var total_weight := 0.0
	for e in order:
		total_weight += maxf(float(element_draw_weights.get(e, 0.0)), 0.0)
	var pick := rng.randf() * total_weight
	var chosen := TileState.Element.FOREST
	for e in order:
		pick -= maxf(float(element_draw_weights.get(e, 0.0)), 0.0)
		if pick <= 0.0:
			chosen = e
			break

	for e in order:
		if e == chosen:
			element_draw_weights[e] = maxf(
				float(element_draw_weights[e]) + score_engine.draw_self_delta_for(e),
				score_engine.min_draw_weight_for(e)
			)
		else:
			element_draw_weights[e] = float(element_draw_weights[e]) + score_engine.draw_other_delta_for(e)
	return chosen

func _roll_animal_for_element(element: int) -> int:
	var target_element := element
	var roll := rng.randf()
	if roll > 0.52:
		var others := []
		for e in [TileState.Element.FOREST, TileState.Element.FIELD, TileState.Element.MOUNTAIN, TileState.Element.RIVER, TileState.Element.WETLANDS]:
			if e != element:
				others.append(e)
		var idx := int(floor((roll - 0.52) / 0.12))
		idx = clampi(idx, 0, others.size() - 1)
		target_element = int(others[idx])

	var options := animal_system.animal_ids_for_element(target_element)
	if options.is_empty():
		return 0
	var total := 0.0
	for id in options:
		total += maxf(animal_system.animal_draw_chance(id), 0.0)
	if total <= 0.0:
		return int(options[0])
	var pick := rng.randf() * total
	for id in options:
		pick -= maxf(animal_system.animal_draw_chance(id), 0.0)
		if pick <= 0.0:
			return int(id)
	return int(options[0])

func _add_card(kind: String, id: int) -> void:
	var key := _card_key(kind, id)
	for card in hand_cards:
		if String(card["key"]) == key:
			card["count"] = int(card["count"]) + 1
			return
	if _hand_slot_count() >= max_hand_size:
		return
	hand_cards.append({
		"key": key,
		"kind": kind,
		"id": id,
		"count": 1
	})

func _consume_selected_card() -> void:
	if selected_card_key.is_empty():
		return
	for i in range(hand_cards.size()):
		if String(hand_cards[i]["key"]) == selected_card_key:
			hand_cards[i]["count"] = int(hand_cards[i]["count"]) - 1
			if int(hand_cards[i]["count"]) <= 0:
				hand_cards.remove_at(i)
				selected_card_key = ""
			break
	_ensure_selected_card()
	_apply_selected_card_state()

func _hand_total_count() -> int:
	var total := 0
	for card in hand_cards:
		total += int(card["count"])
	return total

func _hand_slot_count() -> int:
	return hand_cards.size()

func _card_key(kind: String, id: int) -> String:
	return "%s:%d" % [kind, id]

func _ensure_selected_card() -> void:
	if selected_card_key.is_empty() and not hand_cards.is_empty():
		selected_card_key = String(hand_cards[0]["key"])
	_apply_selected_card_state()

func _apply_selected_card_state() -> void:
	for card in hand_cards:
		if String(card["key"]) != selected_card_key:
			continue
		selected_mode = String(card["kind"])
		if selected_mode == CARD_KIND_ELEMENT:
			selected_element = int(card["id"])
		else:
			selected_animal = int(card["id"])
		return

func _draw_hand_ui() -> void:
	var vp := get_viewport_rect().size
	var card_w := 86.0
	var card_h := 120.0
	var gap := 12.0
	var start := Vector2((vp.x - ((card_w + gap) * max_hand_size - gap)) * 0.5, vp.y - card_h - 14)
	for i in range(hand_cards.size()):
		var card: Dictionary = hand_cards[i]
		var selected := String(card["key"]) == selected_card_key
		var hovered := String(card["key"]) == hovered_hand_card_key
		var rect := Rect2(start + Vector2(i * (card_w + gap), 0), Vector2(card_w, card_h))
		if selected:
			var lift := 14.0
			var scale := 1.10
			var new_size := rect.size * scale
			var new_pos := rect.position - Vector2((new_size.x - rect.size.x) * 0.5, lift + (new_size.y - rect.size.y))
			rect = Rect2(new_pos, new_size)
		elif hovered:
			var hover_lift := 8.0
			var hover_scale := 1.05
			var hover_size := rect.size * hover_scale
			var hover_pos := rect.position - Vector2((hover_size.x - rect.size.x) * 0.5, hover_lift + (hover_size.y - rect.size.y))
			rect = Rect2(hover_pos, hover_size)
		_draw_card(rect, card, selected)
	_draw_hovered_card_rule_tooltip()

func _draw_card(rect: Rect2, card: Dictionary, selected: bool) -> void:
	var kind := String(card["kind"])
	var id := int(card["id"])
	var count := int(card["count"])
	var frame := Color(0.92, 0.94, 0.97, 0.98) if selected else Color(0.82, 0.85, 0.9, 0.92)
	var fill := Color(0.10, 0.20, 0.32, 0.96)
	if kind == CARD_KIND_ELEMENT:
		fill = _tile_color(_tile_for_element_preview(id))
	elif kind == CARD_KIND_ANIMAL and animal_system.animals_by_id.has(id):
		var def: Dictionary = animal_system.animals_by_id[id]
		var place_specs: Array = def["place_specs"]
		if not place_specs.is_empty():
			fill = _color_for_spec(str(place_specs[0]))
	draw_rect(rect, fill, true)
	draw_rect(rect, frame, false, 3.0)
	if kind == CARD_KIND_ANIMAL:
		var symbol := animal_system.animal_symbol_texture(id)
		if symbol != null:
			draw_texture_rect(symbol, rect.grow(-18), false)
		else:
			var letter := _animal_name(id).substr(0, 1).to_upper()
			draw_string(ThemeDB.fallback_font, rect.position + Vector2(rect.size.x * 0.45, rect.size.y * 0.60), letter, HORIZONTAL_ALIGNMENT_LEFT, 16, 22, Color.WHITE)
		_draw_animal_placement_icons(rect, id)
		_draw_animal_requirement_dots(rect, id)
	elif kind == CARD_KIND_ELEMENT:
		_draw_element_placement_dots(rect, id)
	var count_text := str(count)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(8, rect.size.y - 8), count_text, HORIZONTAL_ALIGNMENT_LEFT, 30, 22, Color.WHITE)

func _tile_for_element_preview(element: int) -> TileState:
	var t := TileState.new()
	t.element = element
	return t

func _color_for_element(element: int) -> Color:
	return _tile_color(_tile_for_element_preview(element))

func _draw_animal_requirement_dots(rect: Rect2, animal_id: int) -> void:
	if not animal_system.animals_by_id.has(animal_id):
		return
	var def: Dictionary = animal_system.animals_by_id[animal_id]
	var required_specs: Array = def["required_specs"]
	if required_specs.is_empty():
		return

	var x := rect.position.x + rect.size.x - 22.0
	var start_y := rect.position.y + 10.0
	var step := 20.0
	for idx in range(required_specs.size()):
		var y := start_y + idx * step
		if y > rect.position.y + rect.size.y - 14.0:
			break
		var tex := _texture_for_spec(str(required_specs[idx]))
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x - 8.0, y - 8.0), Vector2(16, 16)), false)

func _draw_animal_placement_icons(rect: Rect2, animal_id: int) -> void:
	if not animal_system.animals_by_id.has(animal_id):
		return
	var def: Dictionary = animal_system.animals_by_id[animal_id]
	var place_specs: Array = def["place_specs"]
	if place_specs.is_empty():
		return
	var x := rect.position.x + 10.0
	var start_y := rect.position.y + 10.0
	var step := 20.0
	for idx in range(place_specs.size()):
		var y := start_y + idx * step
		if y > rect.position.y + rect.size.y - 14.0:
			break
		var tex := _texture_for_spec(String(place_specs[idx]))
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x - 8.0, y - 8.0), Vector2(16, 16)), false)

func _draw_element_placement_dots(rect: Rect2, element: int) -> void:
	var place_specs := score_engine.allowed_place_specs_for_element(element)
	if place_specs.is_empty():
		return
	var x := rect.position.x + 10.0
	var start_y := rect.position.y + 10.0
	var step := 20.0
	for idx in range(place_specs.size()):
		var y := start_y + idx * step
		if y > rect.position.y + rect.size.y - 14.0:
			break
		var tex := _texture_for_spec(String(place_specs[idx]))
		if tex != null:
			draw_texture_rect(tex, Rect2(Vector2(x - 8.0, y - 8.0), Vector2(16, 16)), false)

func _color_for_spec(spec: String) -> Color:
	var parsed := animal_system.parse_spec_key(spec)
	if parsed.is_empty():
		return Color.WHITE
	var element := int(parsed.get("element", TileState.Element.NONE))
	var stacks := int(parsed.get("stacks", 0))
	var t := TileState.new()
	t.element = element
	t.stack_count = stacks
	return _tile_color(t)

func _symbol_for_spec(spec: String) -> String:
	var parsed := animal_system.parse_spec_key(spec)
	if parsed.is_empty():
		return "?"
	var element := int(parsed.get("element", TileState.Element.NONE))
	var stacks := int(parsed.get("stacks", 0))
	if element == TileState.Element.NONE:
		return "N0"
	var icon := score_engine.icon_for(element, stacks)
	return icon if not icon.is_empty() else "%d:%d" % [element, stacks]

func _texture_for_spec(spec: String) -> Texture2D:
	var parsed := animal_system.parse_spec_key(spec)
	if parsed.is_empty():
		return null
	var element := int(parsed.get("element", TileState.Element.NONE))
	var stacks := int(parsed.get("stacks", 0))
	return score_engine.icon_texture_for(element, stacks)

func _sync_element_draw_weights() -> void:
	element_draw_weights.clear()
	for e in score_engine.element_order():
		element_draw_weights[e] = score_engine.base_draw_weight_for(e)

func _try_select_card_from_hand(click_pos: Vector2) -> bool:
	var vp := get_viewport_rect().size
	var card_w := 86.0
	var card_h := 120.0
	var gap := 12.0
	var start := Vector2((vp.x - ((card_w + gap) * max_hand_size - gap)) * 0.5, vp.y - card_h - 14)
	for i in range(hand_cards.size()):
		var rect := Rect2(start + Vector2(i * (card_w + gap), 0), Vector2(card_w, card_h))
		if rect.has_point(click_pos):
			selected_card_key = String(hand_cards[i]["key"])
			_apply_selected_card_state()
			_update_hud("Selected %s card." % (_element_name(selected_element) if selected_mode == CARD_KIND_ELEMENT else _animal_name(selected_animal)))
			return true
	return false

func _hovered_hand_card_key(mouse_pos: Vector2) -> String:
	var vp := get_viewport_rect().size
	var card_w := 86.0
	var card_h := 120.0
	var gap := 12.0
	var start := Vector2((vp.x - ((card_w + gap) * max_hand_size - gap)) * 0.5, vp.y - card_h - 14)
	for i in range(hand_cards.size()):
		var card: Dictionary = hand_cards[i]
		var selected := String(card["key"]) == selected_card_key
		var rect := Rect2(start + Vector2(i * (card_w + gap), 0), Vector2(card_w, card_h))
		if selected:
			var lift := 14.0
			var scale := 1.10
			var new_size := rect.size * scale
			var new_pos := rect.position - Vector2((new_size.x - rect.size.x) * 0.5, lift + (new_size.y - rect.size.y))
			rect = Rect2(new_pos, new_size)
		if rect.has_point(mouse_pos):
			return String(card["key"])
	return ""

func _update_hud(last_msg: String) -> void:
	return

func _draw_hovered_card_rule_tooltip() -> void:
	if hovered_hand_card_key.is_empty():
		return
	var card := _card_by_key(hovered_hand_card_key)
	if card.is_empty():
		return
	var tooltip := _hover_rule_text(card)
	if tooltip.is_empty():
		return
	var vp := get_viewport_rect().size
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, vp.y - 152),
		tooltip,
		HORIZONTAL_ALIGNMENT_LEFT,
		1000,
		18,
		Color(0.95, 0.97, 1.0, 1.0)
	)

func _hover_rule_text(card: Dictionary) -> String:
	var kind := String(card.get("kind", ""))
	var id := int(card.get("id", 0))
	if kind == CARD_KIND_ELEMENT:
		match id:
			TileState.Element.FOREST:
				return "Forest rule: %s" % score_engine.rule_id_for("forest")
			TileState.Element.FIELD:
				return "Field rule: %s" % score_engine.rule_id_for("field")
			TileState.Element.MOUNTAIN:
				return "Mountain rule: %s" % score_engine.rule_id_for("mountain")
			TileState.Element.RIVER:
				return "River rule: %s" % score_engine.rule_id_for("river")
			TileState.Element.WETLANDS:
				return "Wetlands rule: %s" % score_engine.rule_id_for("wetlands")
			_:
				return ""
	if kind == CARD_KIND_ANIMAL:
		return "Animal scoring is defined by animal CSV rules."
	return ""

func _card_by_key(key: String) -> Dictionary:
	for card in hand_cards:
		if String(card.get("key", "")) == key:
			return card
	return {}

func _element_name(element: int) -> String:
	match element:
		TileState.Element.FOREST:
			return "Forest"
		TileState.Element.FIELD:
			return "Field"
		TileState.Element.MOUNTAIN:
			return "Mountain"
		TileState.Element.RIVER:
			return "River"
		TileState.Element.WETLANDS:
			return "Wetlands"
		_:
			return "None"

func _animal_name(animal: int) -> String:
	return animal_system.animal_name(animal)

func _is_tile_unlocked(coord: Vector2i) -> bool:
	return HexCoord.distance(Vector2i.ZERO, coord) <= unlocked_ring_count

func _load_progression_csv(path: String) -> void:
	progression_steps.clear()
	progression_step_index = 0
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Progression CSV not found: %s" % path)
		return

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.to_lower().begins_with("map_size,"):
			continue
		var cols: PackedStringArray = line.split(",", false)
		if cols.size() < 4:
			continue
		var map_size := int(cols[0].strip_edges())
		var difficulty := int(cols[1].strip_edges())
		if map_size != selected_map_size or difficulty != selected_difficulty:
			continue

		ring_count = int(cols[2].strip_edges())
		var tuple_str := cols[3].strip_edges()
		var tuple_parts: PackedStringArray = tuple_str.split("|", false)
		for item in tuple_parts:
			var clean := item.strip_edges()
			var pair: PackedStringArray = clean.split(":", false)
			if pair.size() != 2:
				continue
			var threshold := _parse_threshold_value(pair[1].strip_edges())
			progression_steps.append({
				"ring_add": int(pair[0].strip_edges()),
				"threshold": threshold
			})
		break

	progression_steps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta := int(a["threshold"])
		var tb := int(b["threshold"])
		if ta < 0 and tb < 0:
			return false
		if ta < 0:
			return false
		if tb < 0:
			return true
		return ta < tb
	)
	grid = HexGrid.new(ring_count, 38.0, CAMERA_BASE_ORIGIN)
	_apply_camera_origin()
	unlocked_ring_count = clampi(unlocked_ring_count, 0, ring_count)

func _apply_progression_unlocks(current_score: int) -> String:
	if progression_steps.is_empty():
		return ""
	if progression_step_index >= progression_steps.size():
		return ""
	var unlocked_now := 0
	while progression_step_index < progression_steps.size():
		var step: Dictionary = progression_steps[progression_step_index]
		var threshold := int(step["threshold"])
		if threshold < 0:
			break
		if threshold > current_score:
			break
		unlocked_ring_count = min(unlocked_ring_count + int(step["ring_add"]), ring_count)
		unlocked_now += int(step["ring_add"])
		progression_step_index += 1
	if unlocked_now <= 0:
		return ""
	return "Unlocked %d ring(s)." % unlocked_now

func _parse_threshold_value(raw: String) -> int:
	var lowered := raw.to_lower()
	if lowered == "inf" or lowered == "infinity" or raw == "∞":
		return -1
	return int(raw)

func _is_final_infinite_stage() -> bool:
	if progression_steps.is_empty():
		return false
	if progression_step_index < 0 or progression_step_index >= progression_steps.size():
		return false
	return int((progression_steps[progression_step_index] as Dictionary)["threshold"]) < 0

func _update_camera_pan_from_keys(delta: float) -> bool:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x -= 1.0
	if dir == Vector2.ZERO:
		return false
	camera_offset += dir.normalized() * CAMERA_PAN_SPEED * delta
	_apply_camera_origin()
	return true

func _apply_camera_origin() -> void:
	grid.origin = CAMERA_BASE_ORIGIN + camera_offset

func _finish_run() -> void:
	if game_finished:
		return
	game_finished = true
	_update_hud("Game ended. Final score: %d" % total_score)
