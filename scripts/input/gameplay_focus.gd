extends Node
class_name GameplayFocus
## Discrete gamepad focus over hand, board, boosters, quests, and HUD.

enum Region { HAND, BOARD, BOOSTERS, QUESTS, HUD }

const STICK_DEADZONE := 0.55
const MOVE_REPEAT_DELAY := 0.28
const MOVE_REPEAT_RATE := 0.14
const SCREEN_MARGIN := 96.0

var orchestrator: Orchestrator

var _region: Region = Region.HAND
var _index: int = 0
var _active: bool = false
var _repeat_dir := Vector2.ZERO
var _repeat_elapsed: float = 0.0
var _repeat_started: bool = false
var _board_is_map: bool = false
var _board_coord := Vector2i.ZERO
var _map_origin := Vector2i.ZERO
var _modal_was_open: bool = false


func setup(host: Orchestrator) -> void:
	orchestrator = host
	set_process(true)
	set_process_unhandled_input(true)
	if not InputScheme.scheme_changed.is_connected(_on_scheme_changed):
		InputScheme.scheme_changed.connect(_on_scheme_changed)
	# HUD managers (@onready card_container, etc.) are siblings that become
	# ready after Orchestrator, so wait a frame before focusing.
	call_deferred("_on_scheme_changed", InputScheme.current)


func _on_scheme_changed(scheme: InputScheme.Scheme) -> void:
	if scheme == InputScheme.Scheme.GAMEPAD:
		_activate()
	else:
		_deactivate()


func _activate() -> void:
	if orchestrator == null:
		return
	_active = true
	if get_viewport():
		get_viewport().gui_release_focus()
	_region = Region.HAND
	_index = 0
	if _region_targets().is_empty():
		_region = Region.BOARD
	_apply_focus(true)


func _deactivate() -> void:
	if _active:
		_release_focus()
	_active = false
	_repeat_dir = Vector2.ZERO


func _modal_open() -> bool:
	if orchestrator == null:
		return true
	if orchestrator.game_over or orchestrator.is_intro_locked():
		return true
	if orchestrator.in_game_menu != null and orchestrator.in_game_menu.visible:
		return true
	if orchestrator.settings_overlay != null and orchestrator.settings_overlay.visible:
		return true
	if orchestrator.game_over_overlay != null and orchestrator.game_over_overlay.visible:
		return true
	if orchestrator.tutorial_overlay != null and orchestrator.tutorial_overlay.visible:
		return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not _active or _modal_open() or not InputScheme.is_gamepad():
		return
	if event.is_action_pressed("focus_region_next"):
		_cycle_region(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("focus_region_prev"):
		_cycle_region(-1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("confirm") or event.is_action_pressed("ui_accept"):
		_confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		_cancel()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("alt_action"):
		_alt()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("undo_action"):
		if orchestrator.undo_button != null and orchestrator.undo_button.enabled:
			orchestrator.undo()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("open_menu"):
		orchestrator.open_in_game_menu()
		get_viewport().set_input_as_handled()
		return
	var tap_dir := _digital_dir_from_event(event)
	if tap_dir != Vector2.ZERO:
		_move(tap_dir)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _active or not InputScheme.is_gamepad():
		return
	var modal := _modal_open()
	if _modal_was_open and not modal:
		if get_viewport():
			get_viewport().gui_release_focus()
		_apply_focus(true)
	_modal_was_open = modal
	if modal:
		return
	var stick := Input.get_vector("focus_left", "focus_right", "focus_up", "focus_down")
	if stick.length() < STICK_DEADZONE:
		_repeat_dir = Vector2.ZERO
		_repeat_elapsed = 0.0
		_repeat_started = false
		return
	var dir := _quantize_dir(stick)
	if dir != _repeat_dir:
		_repeat_dir = dir
		_repeat_elapsed = 0.0
		_repeat_started = false
		_move(dir)
		return
	_repeat_elapsed += delta
	var threshold := MOVE_REPEAT_DELAY if not _repeat_started else MOVE_REPEAT_RATE
	if _repeat_elapsed >= threshold:
		_repeat_elapsed = 0.0
		_repeat_started = true
		_move(dir)


func _digital_dir_from_event(event: InputEvent) -> Vector2:
	if not event.is_pressed() or event.is_echo():
		return Vector2.ZERO
	if event.is_action("focus_left"):
		return Vector2.LEFT
	if event.is_action("focus_right"):
		return Vector2.RIGHT
	if event.is_action("focus_up"):
		return Vector2.UP
	if event.is_action("focus_down"):
		return Vector2.DOWN
	return Vector2.ZERO


func _quantize_dir(stick: Vector2) -> Vector2:
	if absf(stick.x) >= absf(stick.y):
		return Vector2.RIGHT if stick.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if stick.y > 0.0 else Vector2.UP


func _cycle_region(step: int) -> void:
	_release_focus()
	var region_count := 5
	var next := wrapi(int(_region) + step, 0, region_count)
	for _i in region_count:
		_region = next
		if not _region_targets().is_empty() or _region == Region.BOARD:
			break
		next = wrapi(next + step, 0, region_count)
	_index = 0
	_board_is_map = false
	_apply_focus(true)


func _move(dir: Vector2) -> void:
	if _region == Region.BOARD:
		_move_board(dir)
		return
	var targets := _region_targets()
	if targets.is_empty():
		return
	var best_i := _index
	var best_score := 1e9
	var from := _target_screen(targets[_index]) if _index >= 0 and _index < targets.size() else Vector2.ZERO
	for i in targets.size():
		if i == _index:
			continue
		var to: Vector2 = _target_screen(targets[i])
		var delta := to - from
		var aligned := delta.normalized().dot(dir)
		if aligned < 0.25:
			continue
		var score := delta.length() / aligned
		if score < best_score:
			best_score = score
			best_i = i
	if best_i == _index:
		var fallback := clampi(_index + int(dir.x) + int(dir.y), 0, targets.size() - 1)
		best_i = fallback
	if best_i != _index:
		_release_focus()
		_index = best_i
		_apply_focus(true)


func _move_board(dir: Vector2) -> void:
	if orchestrator == null or orchestrator.hex_manager == null:
		return
	var container := orchestrator.hex_manager.hex_container
	if container == null:
		return
	var from_world := _board_world_pos()
	var move_world := _screen_dir_to_world_xz(dir)
	if move_world == Vector2.ZERO:
		return
	var best_kind := ""
	var best_coord := Vector2i.ZERO
	var best_score := 1e9
	var hex_size := _hex_size()
	for coord in container.tiles_by_coord.keys():
		if not _board_is_map and coord == _board_coord:
			continue
		var world: Vector3 = HexCoord.axial_to_world(coord, hex_size)
		var delta := Vector2(world.x - from_world.x, world.z - from_world.z)
		var aligned := delta.normalized().dot(move_world)
		if aligned < 0.2:
			continue
		var score := delta.length() / aligned
		if score < best_score:
			best_score = score
			best_kind = "tile"
			best_coord = coord
	for map_btn in orchestrator.hex_manager.map_buttons:
		if map_btn == null:
			continue
		if _board_is_map and map_btn.my_coord == _map_origin:
			continue
		var world: Vector3 = HexCoord.axial_to_world(map_btn.my_coord, hex_size)
		var delta := Vector2(world.x - from_world.x, world.z - from_world.z)
		var aligned := delta.normalized().dot(move_world)
		if aligned < 0.2:
			continue
		var score := delta.length() / aligned
		if score < best_score:
			best_score = score
			best_kind = "map"
			best_coord = map_btn.my_coord
	if best_kind.is_empty():
		return
	_release_focus()
	_board_is_map = best_kind == "map"
	if _board_is_map:
		_map_origin = best_coord
	else:
		_board_coord = best_coord
	_apply_focus(true)


func _screen_dir_to_world_xz(dir: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return dir
	var right := cam.global_basis.x
	var forward := -cam.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	if right.length_squared() == 0.0 or forward.length_squared() == 0.0:
		return dir
	right = right.normalized()
	forward = forward.normalized()
	var world: Vector3 = right * dir.x + forward * -dir.y
	var xz := Vector2(world.x, world.z)
	if xz == Vector2.ZERO:
		return Vector2.ZERO
	return xz.normalized()


func _board_world_pos() -> Vector3:
	var hex_size := _hex_size()
	if _board_is_map:
		return HexCoord.axial_to_world(_map_origin, hex_size)
	return HexCoord.axial_to_world(_board_coord, hex_size)


func _hex_size() -> float:
	if orchestrator == null or orchestrator.hex_manager == null:
		return 11.0
	var container := orchestrator.hex_manager.hex_container
	if container == null:
		return 11.0
	return container.hex_size


func _apply_focus(play_hover: bool) -> void:
	if _region == Region.BOARD:
		_focus_board(play_hover)
		_keep_board_visible()
		return
	var targets := _region_targets()
	if targets.is_empty():
		return
	_index = clampi(_index, 0, targets.size() - 1)
	_hover_target(targets[_index], true, play_hover)


func _release_focus() -> void:
	if _region == Region.BOARD:
		_unfocus_board()
		return
	var targets := _region_targets()
	if _index >= 0 and _index < targets.size():
		_hover_target(targets[_index], false, false)


func _focus_board(play_hover: bool) -> void:
	if orchestrator == null or orchestrator.hex_manager == null:
		return
	var container := orchestrator.hex_manager.hex_container
	if container == null:
		return
	if _board_is_map:
		var map_btn := _map_button_at(_map_origin)
		if map_btn != null:
			map_btn._set_highlight(true)
			if play_hover:
				GameFeedback.play_hover_button()
		return
	if not container.tiles_by_coord.has(_board_coord):
		if container.tiles_by_coord.has(Vector2i.ZERO):
			_board_coord = Vector2i.ZERO
		elif not container.tiles_by_coord.is_empty():
			_board_coord = container.tiles_by_coord.keys()[0]
		else:
			return
	var tile: HexTile = container.tiles_by_coord[_board_coord]
	container.handle_hover(_board_coord)
	tile.show_outline(Color.WHITE)
	if play_hover:
		pass


func _unfocus_board() -> void:
	if orchestrator == null or orchestrator.hex_manager == null:
		return
	var container := orchestrator.hex_manager.hex_container
	if container == null:
		return
	if _board_is_map:
		var map_btn := _map_button_at(_map_origin)
		if map_btn != null:
			map_btn.clear_hover_for_ui()
		return
	if container.tiles_by_coord.has(_board_coord):
		container.handle_exit(_board_coord)
		container.tiles_by_coord[_board_coord].hide_outline()


func _keep_board_visible() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not cam.has_method("ensure_world_visible"):
		return
	cam.ensure_world_visible(_board_world_pos(), SCREEN_MARGIN)


func _confirm() -> void:
	match _region:
		Region.HAND:
			var targets := _region_targets()
			if _index < 0 or _index >= targets.size():
				return
			orchestrator.select_hand_card(int(targets[_index]["id"]))
		Region.BOARD:
			if _board_is_map:
				orchestrator.handle_map_button_click(_map_origin)
			else:
				orchestrator.handle_tile_click(_board_coord)
			_apply_focus(false)
		Region.BOOSTERS:
			_confirm_booster()
		Region.QUESTS:
			pass
		Region.HUD:
			_confirm_hud()


func _confirm_booster() -> void:
	var targets := _region_targets()
	if _index < 0 or _index >= targets.size():
		return
	var target: Dictionary = targets[_index]
	var kind := String(target.get("kind", ""))
	if kind == "booster":
		orchestrator.booster_manager.select_booster(int(target["id"]))
	elif kind == "market_arrow":
		orchestrator.booster_manager.toggle_animal_market()
	elif kind == "market_offer":
		orchestrator.booster_manager.buy_market_animal(int(target["id"]))
	_apply_focus(false)


func _confirm_hud() -> void:
	var targets := _region_targets()
	if _index < 0 or _index >= targets.size():
		return
	var kind := String(targets[_index].get("kind", ""))
	match kind:
		"undo":
			if orchestrator.undo_button != null and orchestrator.undo_button.enabled:
				orchestrator.undo()
		"menu":
			orchestrator.open_in_game_menu()
		"score":
			orchestrator.show_score_help()
		"recycle":
			if orchestrator.card_recycling != null and orchestrator.card_recycling.enabled:
				orchestrator.apply_recycle_card(-1, orchestrator.card_recycling.recycling_value, false)
		"end_game":
			orchestrator.end_game()


func _cancel() -> void:
	if orchestrator.selected_card_id != -1:
		orchestrator.select_hand_card(-1)
		if _region == Region.BOARD:
			_apply_focus(false)
		return
	if _region == Region.BOOSTERS and orchestrator.booster_manager != null:
		var market := orchestrator.booster_manager.animal_market
		if market != null and market.is_open():
			orchestrator.booster_manager.close_animal_market()
			_apply_focus(true)


func _alt() -> void:
	match _region:
		Region.HAND:
			var targets := _region_targets()
			if _index < 0 or _index >= targets.size():
				return
			var card_id := int(targets[_index]["id"])
			if orchestrator.card_manager == null:
				return
			if card_id >= 0 and card_id < orchestrator.card_manager.cards.size():
				var card: CardData = orchestrator.card_manager.cards[card_id]
				if card != null and card.type == CardData.CARD_TYPE.ANIMAL:
					orchestrator.recycle_hand_animal(card_id)
		Region.BOOSTERS:
			var targets := _region_targets()
			if _index < 0 or _index >= targets.size():
				return
			var target: Dictionary = targets[_index]
			var kind := String(target.get("kind", ""))
			if kind == "booster":
				orchestrator.booster_manager.reroll_booster_slot(int(target["id"]))
			elif kind == "market_offer":
				orchestrator.booster_manager.reroll_market_slot(int(target["id"]))
			_apply_focus(false)


func _region_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if orchestrator == null:
		return out
	match _region:
		Region.HAND:
			var container := _card_container()
			if container == null:
				return out
			var cards := container.cards
			for i in cards.size():
				if cards[i] != null:
					out.append({"kind": "card", "id": i, "node": cards[i]})
		Region.BOOSTERS:
			out.append_array(_booster_targets())
		Region.QUESTS:
			if orchestrator.quest_manager == null or orchestrator.quest_manager.quest_container == null:
				return out
			var quests := orchestrator.quest_manager.quest_container.quests
			for i in quests.size():
				if quests[i] != null:
					out.append({"kind": "quest", "id": i, "node": quests[i]})
		Region.HUD:
			out.append_array(_hud_targets())
		Region.BOARD:
			pass
	return out


func _card_container() -> CardContainer:
	if orchestrator == null or orchestrator.card_manager == null:
		return null
	return orchestrator.card_manager.card_container


func _booster_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if orchestrator == null or orchestrator.booster_manager == null:
		return out
	var booster_container := orchestrator.booster_manager.booster_container
	if booster_container != null:
		for booster in booster_container.boosters:
			if booster != null:
				out.append({"kind": "booster", "id": booster.id, "node": booster})
	var market := orchestrator.booster_manager.animal_market
	if market == null:
		return out
	if market.is_open():
		out.append({"kind": "market_arrow", "id": 1, "node": market._collapse_arrow})
		for i in market._cards.size():
			if market._cards[i] != null:
				out.append({"kind": "market_offer", "id": i, "node": market._cards[i]})
	else:
		out.append({"kind": "market_arrow", "id": 0, "node": market._expand_arrow})
	return out


func _hud_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if orchestrator.undo_button != null:
		out.append({"kind": "undo", "node": orchestrator.undo_button})
	if orchestrator.menu_button != null:
		out.append({"kind": "menu", "node": orchestrator.menu_button})
	var hud := orchestrator.get_parent().get_node_or_null("HUD")
	if hud != null:
		var score := hud.get_node_or_null("ScoreTooltip")
		if score != null:
			out.append({"kind": "score", "node": score})
	if orchestrator.card_recycling != null:
		out.append({"kind": "recycle", "node": orchestrator.card_recycling})
	return out


func _target_screen(target: Dictionary) -> Vector2:
	var node: Node = target.get("node", null)
	if node is Node2D:
		return (node as Node2D).global_position
	if node is Control:
		return (node as Control).global_position
	return Vector2.ZERO


func _hover_target(target: Dictionary, on: bool, play_hover: bool) -> void:
	var kind := String(target.get("kind", ""))
	match kind:
		"card":
			var container := _card_container()
			if container == null:
				return
			var card_id := int(target["id"])
			if on:
				container.hover_card(card_id)
			else:
				container.exit_card(card_id)
		"booster":
			var booster: Booster = target.get("node", null)
			if booster != null:
				booster.set_focus_hover(on)
		"market_arrow":
			var arrow: Area2D = target.get("node", null)
			if arrow != null:
				if on:
					if play_hover:
						GameFeedback.play_hover_button()
					var icon := arrow.get_node_or_null("Icon") as Sprite2D
					if icon:
						icon.modulate = Color.html("#918478")
					UiPointerBlock.enter(arrow)
				else:
					UiPointerBlock.exit(arrow)
					var icon := arrow.get_node_or_null("Icon") as Sprite2D
					if icon:
						icon.modulate = Color.WHITE
		"market_offer":
			if orchestrator == null or orchestrator.booster_manager == null:
				return
			var market := orchestrator.booster_manager.animal_market
			var offer_id := int(target["id"])
			if market == null:
				return
			if on:
				market.hover_card(offer_id)
			else:
				market.exit_card(offer_id)
		"quest":
			var quest: QuestItem = target.get("node", null)
			if quest != null:
				if on:
					quest._on_mouse_entered()
				else:
					quest._on_mouse_exited()
		"undo", "menu", "score", "recycle":
			var node: Node = target.get("node", null)
			if node != null and node.has_method("set_focus_hover"):
				node.set_focus_hover(on)
			elif node != null:
				if on and node.has_method("_on_mouse_entered"):
					node._on_mouse_entered()
				elif not on and node.has_method("_on_mouse_exited"):
					node._on_mouse_exited()
				elif on and node.has_method("_on_button_mouse_entered"):
					node._on_button_mouse_entered()
				elif not on and node.has_method("_on_button_mouse_exited"):
					node._on_button_mouse_exited()


func _map_button_at(origin: Vector2i) -> MapButton:
	if orchestrator == null or orchestrator.hex_manager == null:
		return null
	for map_btn in orchestrator.hex_manager.map_buttons:
		if map_btn != null and map_btn.my_coord == origin:
			return map_btn
	return null
