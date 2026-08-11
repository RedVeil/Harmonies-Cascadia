extends Node
class_name EndlessRunSave

## Endless run persistence for the “Continue / New” flow.
##
## Design:
## - Saves are written to `user://endless_run_save.json` when the user ends an endless run.
## - The “Continue” button loads the save to an in-memory pending state, then swaps scenes.
## - After the game scene loads, Orchestrator consumes the pending state and applies it.

const SAVE_PATH := "user://endless_run_save.json"

# In-memory payload used between scene loads (main menu -> game scene).
static var _has_pending_state: bool = false
static var _pending_state: Dictionary = {}


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func clear_save() -> void:
	# FileAccess.remove returns an Error; ignore.
	if FileAccess.file_exists(SAVE_PATH):
		# DirAccess removal is an *instance* method in this Godot version.
		var dir := DirAccess.open("user://")
		if dir == null:
			return
		dir.remove(SAVE_PATH.get_file())


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


static func _coord_from_arr(a: Array) -> Vector2i:
	if a.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(a[0]), int(a[1]))


static func _tile_to_dict(t: Object) -> Dictionary:
	# HexTileData is a Resource; store only exported fields we need.
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


static func _tile_from_dict(d: Dictionary) -> Dictionary:
	# NOTE: We deserialize into a plain dict; the hex/tile apply logic will convert to HexTileData.
	# Keeping it as dict avoids early dependency on resource constructors in this module.
	return d


static func _serialize_board(hex_manager: Object) -> Dictionary:
	if hex_manager == null:
		return {}
	var tiles := {}
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
	# active_rules: Dictionary[int, ScoringRule]
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
	# card_manager.cards is an Array[CardData] (with nulls).
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
		# BoosterData.cards: Array[CardData]
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
	# _market_offers is used for animal market panel in non-puzzle mode.
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

	# _bought_animal_ids tracks which animals are already bought (Dictionary[int,bool]).
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

	# State is captured from current in-memory game components.

	var state := {
		"run_seed": int(GameSession.run_seed),
		"game_mode": int(GameSession.game_mode),
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
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("EndlessRunSave: failed to open save file: %s" % SAVE_PATH)
		return
	f.store_string(json)
	f.flush()
	f.close()


static func load_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


static func apply_state_to_orchestrator(orchestrator: Object, state: Dictionary) -> void:
	# This method is intentionally defensive and calls into helper methods
	# if they exist. The actual per-system “apply_saved_state” helpers are
	# added in later to-dos.
	if orchestrator == null or state.is_empty():
		return

	# Run config (must happen before gameplay randomness; main menu sets run_seed before scene load for Continue).
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

	# Core orchestration vars.
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
