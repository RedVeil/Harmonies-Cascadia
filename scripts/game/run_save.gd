extends Node
class_name RunSave

## Mode-aware run persistence for the Continue / New flow (endless, daily, quick).
##
## Design:
## - Saves are written when the user ends a supported run from the in-game menu.
## - Continue loads the save to an in-memory pending state, then swaps scenes.
## - After the game scene loads, Orchestrator consumes the pending state and applies it.

const PATH_ENDLESS := "user://endless_run_save.json"
const PATH_DAILY := "user://daily_run_save.json"
const PATH_NORMAL := "user://normal_run_save.json"

# In-memory payload used between scene loads (main menu -> game scene).
static var _has_pending_state: bool = false
static var _pending_state: Dictionary = {}


static func path_for_mode(mode: int) -> String:
	match mode:
		GameSession.GameMode.DAILY:
			return PATH_DAILY
		GameSession.GameMode.NORMAL:
			return PATH_NORMAL
		GameSession.GameMode.ENDLESS:
			return PATH_ENDLESS
		_:
			return ""


static func supports_mode(mode: int) -> bool:
	return (
		mode == GameSession.GameMode.DAILY
		or mode == GameSession.GameMode.NORMAL
		or mode == GameSession.GameMode.ENDLESS
	)


static func has_save(mode: int) -> bool:
	var path := path_for_mode(mode)
	if path.is_empty():
		return false
	if not FileAccess.file_exists(path):
		return false
	if mode == GameSession.GameMode.DAILY:
		return is_daily_save_valid(load_save(mode))
	return true


static func is_daily_save_valid(state: Dictionary) -> bool:
	if state.is_empty():
		return false
	var saved_seed := int(state.get("run_seed", 0))
	return saved_seed != 0 and saved_seed == GameSession.get_daily_seed()


static func clear_expired_daily_save() -> void:
	if not FileAccess.file_exists(PATH_DAILY):
		return
	var state := load_save(GameSession.GameMode.DAILY)
	if not is_daily_save_valid(state):
		clear_save(GameSession.GameMode.DAILY)


static func clear_save(mode: int) -> void:
	var path := path_for_mode(mode)
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	dir.remove(path.get_file())


static func set_pending_state(state: Dictionary) -> void:
	_pending_state = state
	_has_pending_state = true


static func consume_pending_state() -> Variant:
	if not _has_pending_state:
		return null
	var out := _pending_state
	_pending_state = {}
	_has_pending_state = false
	return out


static func consume_pending_state_or_null() -> Variant:
	return consume_pending_state()


static func _coord_to_arr(c: Vector2i) -> Array[int]:
	return [c.x, c.y]


static func _tile_to_dict(t: Object) -> Dictionary:
	if t == null:
		return {}
	return {
		"element": int(t.element),
		"level": int(t.level),
		"animal_id": int(t.animal_id),
		"animal_amount": int(t.animal_amount),
		"group_id": int(t.group_id),
		"hex_map_id": int(t.hex_map_id),
		"orientation_steps": int(t.orientation_steps),
	}


static func _serialize_board(hex_manager: Object) -> Dictionary:
	if hex_manager == null:
		return {}
	var tiles_out: Array[Dictionary] = []
	for coord in hex_manager.tiles.keys():
		var tile_data = hex_manager.tiles[coord]
		var entry: Dictionary = _tile_to_dict(tile_data)
		entry["q"] = coord.x
		entry["r"] = coord.y
		tiles_out.append(entry)

	var groups_out: Array[Dictionary] = []
	for gid in hex_manager.groups.keys():
		var coords_arr: Array = hex_manager.groups[gid]
		var coords_out: Array[Array] = []
		for c in coords_arr:
			coords_out.append(_coord_to_arr(c))
		groups_out.append({
			"id": int(gid),
			"coords": coords_out,
		})

	var active_origins_out: Array[Array] = []
	for origin in hex_manager.hex_map_active:
		active_origins_out.append(_coord_to_arr(origin))

	return {
		"hex_map_active": active_origins_out,
		"tiles": tiles_out,
		"groups": groups_out,
		"next_group_id": int(hex_manager.next_group_id),
	}


static func _serialize_scoring(score_engine: Object) -> Dictionary:
	if score_engine == null:
		return {}

	var rules_out: Dictionary = {}
	for element_type in score_engine.active_rules.keys():
		var rule: Object = score_engine.active_rules[element_type]
		if rule == null:
			continue
		rules_out[str(element_type)] = int(rule.id)

	return {
		"active_rules": rules_out,
		"points_per_element_group": score_engine.points_per_element_group.duplicate(true),
		"placed_animals": score_engine.placed_animals.duplicate(true),
		"element_score": int(score_engine.element_score),
		"animal_score": int(score_engine.animal_score),
		"quest_score": int(score_engine.quest_score),
		"total_score": int(score_engine.total_score),
	}


static func _serialize_progress(point_counter: Object) -> Dictionary:
	if point_counter == null:
		return {}
	return {
		"current": int(point_counter.current),
		"target": int(point_counter.target),
		"preview": int(point_counter.preview),
	}


static func _serialize_quests(quest_manager: Object) -> Dictionary:
	if quest_manager == null:
		return {}
	return {
		"active_quests": quest_manager.active_quests.duplicate(true),
		"completed_quests": quest_manager.completed_quests.duplicate(true),
	}


static func _serialize_hand(card_manager: Object) -> Dictionary:
	if card_manager == null:
		return {}
	var hand_out: Array[Variant] = []
	for i in range(card_manager.cards.size()):
		var c = card_manager.cards[i]
		if c == null:
			hand_out.append(null)
			continue
		hand_out.append({
			"type": int(c.type),
			"id": int(c.id),
			"amount": int(c.amount),
		})

	return {
		"cards": hand_out,
		"card_amount": int(card_manager.card_amount),
		"animal_amount": int(card_manager.animal_amount),
	}


static func _serialize_boosters(booster_manager: Object) -> Dictionary:
	if booster_manager == null:
		return {}

	var boosters_out: Array[Variant] = []
	for i in range(booster_manager.boosters.size()):
		var b = booster_manager.boosters[i]
		if b == null:
			boosters_out.append(null)
			continue
		var booster_entry := {
			"type": int(b.type),
			"booster_points": int(b.booster_points),
			"map_points": int(b.map_points),
			"quest_ids": b.quest_ids.duplicate(true),
			"cards": [],
		}
		for c in b.cards:
			if c == null:
				continue
			booster_entry["cards"].append({
				"type": int(c.type),
				"id": int(c.id),
				"amount": int(c.amount),
			})
		boosters_out.append(booster_entry)

	var market_offers_out: Array[Variant] = []
	var market_offers: Array = booster_manager._market_offers if booster_manager != null else []

	for o in market_offers:
		if o == null:
			market_offers_out.append(null)
		else:
			market_offers_out.append({
				"type": int(o.type),
				"id": int(o.id),
				"amount": int(o.amount),
			})

	var bought_ids_out: Dictionary = {}
	for k in booster_manager._bought_animal_ids.keys():
		bought_ids_out[str(k)] = true

	return {
		"paused": bool(booster_manager.paused),
		"booster_reroll_progress": booster_manager.booster_reroll_progress.duplicate(true),
		"market_reroll_progress": booster_manager.market_reroll_progress.duplicate(true),
		"market_buys_remaining": int(booster_manager.market_buys_remaining),
		"options_ready": bool(booster_manager.options_ready),
		"pending_elements": int(booster_manager.pending_elements),
		"elements_played": int(booster_manager.elements_played),
		"booster_limit": int(booster_manager.booster_limit),
		"animal_market_offer_count": int(booster_manager.animal_market_offer_count),
		"boosters": boosters_out,
		"market_offers": market_offers_out,
		"bought_animal_ids": bought_ids_out,
	}


static func save_from_orchestrator(orchestrator: Object) -> void:
	if orchestrator == null:
		return
	if not supports_mode(GameSession.game_mode):
		return

	var path := path_for_mode(GameSession.game_mode)
	if path.is_empty():
		return

	var state := {
		"run_seed": int(GameSession.run_seed),
		"game_mode": int(GameSession.game_mode),
		"map_size": int(GameSession.map_size),
		"ring_count": int(GameSession.ring_count),
		"checkpoint": int(GameSession.checkpoint),
		"checkpoint_multiplier": float(GameSession.checkpoint_multiplier),
		"checkpoint_flat_increase": int(GameSession.checkpoint_flat_increase),
		"map_growth_enabled": bool(GameSession.map_growth_enabled),
		"map_points": int(orchestrator.map_points),
		"placed_tile_count": int(orchestrator._placed_tile_count),
		"cards_paused": bool(orchestrator.cards_paused),
		"board": _serialize_board(orchestrator.hex_manager),
		"scoring": _serialize_scoring(orchestrator.score_engine),
		"progress": _serialize_progress(orchestrator.point_counter),
		"quests": _serialize_quests(orchestrator.quest_manager),
		"hand": _serialize_hand(orchestrator.card_manager),
		"boosters": _serialize_boosters(orchestrator.booster_manager),
	}

	var json := JSON.stringify(state)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("RunSave: failed to open save file: %s" % path)
		return
	f.store_string(json)
	f.flush()
	f.close()


static func load_save(mode: int) -> Dictionary:
	var path := path_for_mode(mode)
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func apply_state_to_orchestrator(orchestrator: Object, state: Dictionary) -> void:
	if orchestrator == null or state.is_empty():
		return

	if state.has("map_size"):
		GameSession.map_size = int(state["map_size"]) as GameSession.MapSize
	if state.has("ring_count"):
		GameSession.ring_count = int(state["ring_count"])
	if state.has("checkpoint"):
		GameSession.checkpoint = int(state["checkpoint"])
	if state.has("checkpoint_multiplier"):
		GameSession.checkpoint_multiplier = float(state["checkpoint_multiplier"])
	if state.has("checkpoint_flat_increase"):
		GameSession.checkpoint_flat_increase = int(state["checkpoint_flat_increase"])
	if state.has("map_growth_enabled"):
		GameSession.map_growth_enabled = bool(state["map_growth_enabled"])

	if state.has("map_points"):
		orchestrator.map_points = int(state["map_points"])
	if state.has("placed_tile_count"):
		orchestrator._placed_tile_count = int(state["placed_tile_count"])
	if state.has("cards_paused"):
		orchestrator.cards_paused = bool(state["cards_paused"])

	var board = state.get("board", {})
	if orchestrator.hex_manager and orchestrator.hex_manager.has_method("apply_saved_state"):
		orchestrator.hex_manager.apply_saved_state(board)

	var scoring = state.get("scoring", {})
	if orchestrator.score_engine and orchestrator.score_engine.has_method("apply_saved_state"):
		orchestrator.score_engine.apply_saved_state(scoring)

	var progress = state.get("progress", {})
	if orchestrator.point_counter and orchestrator.point_counter.has_method("apply_saved_state"):
		orchestrator.point_counter.apply_saved_state(progress)

	var quests = state.get("quests", {})
	if orchestrator.quest_manager and orchestrator.quest_manager.has_method("apply_saved_state"):
		orchestrator.quest_manager.apply_saved_state(quests)

	var hand = state.get("hand", {})
	if orchestrator.card_manager and orchestrator.card_manager.has_method("apply_saved_state"):
		orchestrator.card_manager.apply_saved_state(hand)
	elif orchestrator.card_manager and orchestrator.card_manager.has_method("reset_hand_from_state"):
		orchestrator.card_manager.reset_hand_from_state(hand)

	var boosters = state.get("boosters", {})
	if orchestrator.booster_manager and orchestrator.booster_manager.has_method("apply_saved_state"):
		orchestrator.booster_manager.apply_saved_state(boosters)
