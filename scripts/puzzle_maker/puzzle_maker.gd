extends Node
class_name PuzzleMakerController

## HUD controller for the puzzle maker scene: overlays, draft dict, erase, save.

const PuzzleSetupScript := preload("res://scripts/game/puzzle_setup.gd")
const PuzzleCatalogWriterScript := preload("res://scripts/puzzle_maker/puzzle_catalog_writer.gd")
const PUZZLE_MAKER_SCENE := "res://scenes/puzzle_maker/puzzle_maker.tscn"

@export var orchestrator: Orchestrator
@export var animal_picker: AnimalPickerOverlay
@export var quest_picker: QuestPickerOverlay
@export var pack_builder: PackBuilderOverlay
@export var save_overlay: PuzzleSaveOverlay
@export var scoring_overlay: ScoringRulesOverlay
@export var load_overlay: PuzzleLoadOverlay

var draft: Dictionary = {}

## When true, next animal pick goes to pack market; else into maker hand.
var _animal_pick_for_market: bool = false
## When true, next quest pick goes to pack builder; else quest bar preview.
var _quest_pick_for_pack: bool = false
var _palette_seeded: bool = false


func _ready() -> void:
	# Allow F6-running this scene without going through the menu.
	if not GameSession.is_puzzle_maker():
		GameSession.begin_puzzle_maker(GameSession.puzzle_id)
	_init_draft_from_session()
	if animal_picker:
		animal_picker.animal_selected.connect(_on_animal_selected)
		animal_picker.closed.connect(_on_animal_picker_closed)
	if quest_picker:
		quest_picker.quest_selected.connect(_on_quest_selected)
		quest_picker.closed.connect(_on_quest_picker_closed)
	if pack_builder:
		pack_builder.changed.connect(_on_pack_changed)
		pack_builder.request_animal_pick.connect(_on_pack_request_animal)
		pack_builder.request_quest_pick.connect(_on_pack_request_quest)
	if save_overlay:
		save_overlay.save_requested.connect(_on_save_requested)
	if scoring_overlay:
		scoring_overlay.rules_changed.connect(set_scoring_rules)
	if load_overlay:
		load_overlay.puzzle_selected.connect(_on_load_requested)
	call_deferred("_bootstrap_maker_ui")


func _bootstrap_maker_ui() -> void:
	# Wait until HUD slots have sized so the hand lays out on-screen.
	await get_tree().process_frame
	await get_tree().process_frame
	_ensure_hand_palette()
	_seed_animals_from_draft()
	_ensure_scoring_rules_in_draft()
	_refresh_action_counter()
	_force_hand_layout()


func _ensure_hand_palette() -> void:
	if orchestrator == null or orchestrator.card_manager == null:
		return
	var cm := orchestrator.card_manager
	cm.maker_mode = true
	cm.show()
	cm.z_index = 10
	if cm.card_container:
		cm.card_container.show()
		cm.card_container.z_index = 10
	orchestrator._seed_maker_element_palette()
	_palette_seeded = true
	# Instant layout (skip spawn tween so cards can't get stuck invisible).
	var container := cm.card_container
	if container != null:
		for card in container.cards:
			if card != null and card.has_method("consume_spawn_layout"):
				card.consume_spawn_layout()
		if container.has_method("_layout_cards"):
			container._layout_cards()
	_force_hand_layout()


func _seed_animals_from_draft() -> void:
	if orchestrator == null:
		return
	var raw_animals = draft.get("hand_animal_ids", [])
	if typeof(raw_animals) != TYPE_ARRAY:
		return
	for animal_id in raw_animals:
		var card: CardData = null
		for animal in CardCatalog.animals:
			if animal != null and animal.id == int(animal_id):
				card = animal
				break
		if card != null:
			orchestrator.add_hand_card(card)


func _force_hand_layout() -> void:
	if orchestrator == null or orchestrator.card_manager == null:
		return
	var hud := get_tree().get_first_node_in_group("puzzle_maker_hud")
	if hud == null:
		# Fall back: find HUD sibling CanvasLayer with hud_layout.
		var root := get_parent()
		if root:
			hud = root.get_node_or_null("HUD")
	if hud != null and hud.has_method("_relayout"):
		hud._relayout()
	var container := orchestrator.card_manager.card_container
	if container != null and container.has_method("_layout_cards"):
		container._layout_cards()


func _on_animal_picker_closed() -> void:
	if not (pack_builder and pack_builder.visible and pack_builder.pending_animal_slot >= 0):
		_animal_pick_for_market = false


func _on_quest_picker_closed() -> void:
	if not (pack_builder and pack_builder.visible and pack_builder.pending_quest_pack >= 0):
		_quest_pick_for_pack = false


func _unhandled_input(event: InputEvent) -> void:
	if not GameSession.is_puzzle_maker():
		return
	if animal_picker and animal_picker.visible:
		return
	if quest_picker and quest_picker.visible:
		return
	if pack_builder and pack_builder.visible:
		return
	if save_overlay and save_overlay.visible:
		return
	if scoring_overlay and scoring_overlay.visible:
		return
	if load_overlay and load_overlay.visible:
		return
	if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_RIGHT \
		and event.pressed \
		and orchestrator \
		and orchestrator.tile_hovered:
		orchestrator.maker_erase_tile(orchestrator.selected_coord)
		get_viewport().set_input_as_handled()


func _init_draft_from_session() -> void:
	var puzzle := GameSession.puzzle_config
	if puzzle.is_empty():
		draft = {
			"id": "",
			"title": "",
			"description": "",
			"order": 0,
			"seed": 0,
			"ring_count": GameSession.ring_count,
			"map_growth": false,
			"max_pack_takes": 0,
			"max_plays": 3,
			"ratings": {"bronze": 10, "silver": 15, "gold": 20},
			"scoring_rules": {},
			"tiles": [],
			"hand_element_ids": [],
			"hand_animal_ids": [],
			"quest_ids": [],
			"boosters": [null, null, null],
			"animal_market": [-1, -1, -1],
		}
	else:
		draft = puzzle.duplicate(true)
		if not draft.has("boosters"):
			draft["boosters"] = [null, null, null]
		if not draft.has("animal_market"):
			draft["animal_market"] = [-1, -1, -1]
		if not draft.has("ratings"):
			draft["ratings"] = {"bronze": 10, "silver": 15, "gold": 20}
		if not draft.has("quest_ids"):
			draft["quest_ids"] = []


func get_ring_count() -> int:
	return int(draft.get("ring_count", GameSession.ring_count))


func get_max_plays() -> int:
	return int(draft.get("max_plays", 3))


func set_ring_count(rings: int) -> void:
	rings = clampi(rings, 1, 8)
	draft["ring_count"] = rings
	GameSession.ring_count = rings
	if orchestrator == null or orchestrator.hex_manager == null:
		return
	var tiles := orchestrator.serialize_filled_tiles()
	orchestrator.hex_manager.rebuild_with_ring_count(rings)
	# Re-apply kept tiles with full visual/score rebuild.
	var kept: Array = []
	for entry in tiles:
		var q := int(entry.get("q", 0))
		var r := int(entry.get("r", 0))
		if HexCoord.distance(Vector2i.ZERO, Vector2i(q, r)) <= rings:
			kept.append(entry)
	PuzzleSetupScript.apply(
		{"tiles": kept},
		orchestrator.hex_manager,
		orchestrator.score_engine,
		orchestrator.point_counter
	)


func set_max_plays(plays: int) -> void:
	plays = clampi(plays, -1, 99)
	draft["max_plays"] = plays
	# Keep session config in sync so save/export and HUD agree.
	if typeof(GameSession.puzzle_config) != TYPE_DICTIONARY:
		GameSession.puzzle_config = {}
	GameSession.puzzle_config["max_plays"] = plays
	_refresh_action_counter()


func _ensure_scoring_rules_in_draft() -> void:
	var rules = draft.get("scoring_rules", {})
	if typeof(rules) == TYPE_DICTIONARY and not rules.is_empty():
		set_scoring_rules(rules)
		return
	# Capture whatever ScoreEngine already rolled/applied.
	if orchestrator == null or orchestrator.score_engine == null:
		return
	var captured := {}
	for element_type in orchestrator.score_engine.active_rules.keys():
		var rule: ScoringRule = orchestrator.score_engine.active_rules[element_type]
		if rule != null:
			captured[str(element_type)] = rule.id
	if not captured.is_empty():
		draft["scoring_rules"] = captured


func set_scoring_rules(scoring_rules: Dictionary) -> void:
	var normalized := {}
	for key in scoring_rules.keys():
		normalized[str(key)] = int(scoring_rules[key])
	draft["scoring_rules"] = normalized
	if typeof(GameSession.puzzle_config) != TYPE_DICTIONARY:
		GameSession.puzzle_config = {}
	GameSession.puzzle_config["scoring_rules"] = normalized.duplicate()
	if orchestrator == null or orchestrator.score_engine == null:
		return
	orchestrator.score_engine.apply_forced_rules(normalized)
	_rescore_board()


func _rescore_board() -> void:
	if orchestrator == null or orchestrator.hex_manager == null:
		return
	var tiles := orchestrator.serialize_filled_tiles()
	PuzzleSetupScript.apply(
		{"tiles": tiles},
		orchestrator.hex_manager,
		orchestrator.score_engine,
		orchestrator.point_counter
	)


func _refresh_action_counter() -> void:
	if orchestrator == null or orchestrator.play_counter == null:
		return
	var plays := get_max_plays()
	orchestrator.play_counter.set_remaining(plays)


func open_animals() -> void:
	_animal_pick_for_market = false
	if animal_picker:
		animal_picker.open()


func open_quests() -> void:
	_quest_pick_for_pack = false
	if quest_picker:
		quest_picker.open()


func open_packs() -> void:
	if pack_builder:
		pack_builder.open(
			draft.get("boosters", [null, null, null]),
			draft.get("animal_market", [-1, -1, -1])
		)


func open_scoring() -> void:
	_ensure_scoring_rules_in_draft()
	if scoring_overlay:
		scoring_overlay.open(draft.get("scoring_rules", {}))


func open_save() -> void:
	_sync_board_and_hand_into_draft()
	var board_score := 0
	if orchestrator and orchestrator.score_engine:
		board_score = orchestrator.score_engine.total_score
	if save_overlay:
		save_overlay.open(draft, board_score)


func open_load() -> void:
	if load_overlay:
		load_overlay.open(str(draft.get("id", "")))


func _on_load_requested(id: String) -> void:
	if id.is_empty():
		return
	GameSession.begin_puzzle_maker(id)
	SceneLoader.goto(PUZZLE_MAKER_SCENE)


func leave_to_menu() -> void:
	GameSession.clear_puzzle()
	GameSession.game_mode = GameSession.GameMode.NORMAL
	SceneLoader.goto("res://scenes/main_menu.tscn")


func _on_animal_selected(animal_id: int) -> void:
	if _animal_pick_for_market:
		if pack_builder and pack_builder.visible:
			pack_builder.apply_animal(animal_id)
		_animal_pick_for_market = false
		return
	if orchestrator == null:
		return
	var card: CardData = null
	for animal in CardCatalog.animals:
		if animal != null and animal.id == animal_id:
			card = animal
			break
	if card == null:
		return
	orchestrator.add_hand_card(card)
	_force_hand_layout()


func _on_quest_selected(quest_id: int) -> void:
	if _quest_pick_for_pack:
		if pack_builder and pack_builder.visible:
			pack_builder.apply_quest(quest_id)
		_quest_pick_for_pack = false
		return
	if orchestrator:
		orchestrator.add_quest(quest_id)


func _on_pack_changed(boosters: Array, animal_market: Array) -> void:
	draft["boosters"] = boosters
	draft["animal_market"] = animal_market


func _on_pack_request_animal(_slot: int) -> void:
	_animal_pick_for_market = true
	if animal_picker:
		animal_picker.open()


func _on_pack_request_quest(_pack: int) -> void:
	_quest_pick_for_pack = true
	if quest_picker:
		quest_picker.open()


func _sync_board_and_hand_into_draft() -> void:
	if orchestrator:
		draft["tiles"] = orchestrator.serialize_filled_tiles()
		draft["hand_animal_ids"] = _collect_hand_animal_ids()
		draft["quest_ids"] = _collect_active_quest_ids()
	draft["ring_count"] = GameSession.ring_count
	_ensure_scoring_rules_in_draft()
	if int(draft.get("seed", 0)) == 0 and str(draft.get("id", "")) != "":
		draft["seed"] = hash(str(draft["id"]))


func _collect_hand_animal_ids() -> Array:
	var ids: Array = []
	if orchestrator == null or orchestrator.card_manager == null:
		return ids
	for card in orchestrator.card_manager.cards:
		if card == null or card.type != CardData.CARD_TYPE.ANIMAL:
			continue
		for _i in maxi(card.amount, 1):
			ids.append(card.id)
	return ids


func _collect_active_quest_ids() -> Array:
	var ids: Array = []
	if orchestrator == null or orchestrator.quest_manager == null:
		return ids
	for quest_id in orchestrator.quest_manager.active_quests:
		var qid := int(quest_id)
		if qid < 0:
			continue
		ids.append(qid)
	return ids


func _on_save_requested(payload: Dictionary) -> void:
	_sync_board_and_hand_into_draft()
	for key in payload.keys():
		draft[key] = payload[key]
	if payload.has("ring_count"):
		set_ring_count(int(payload["ring_count"]))
	if payload.has("max_plays"):
		set_max_plays(int(payload["max_plays"]))
	if not draft.has("scoring_rules") or typeof(draft["scoring_rules"]) != TYPE_DICTIONARY:
		draft["scoring_rules"] = {}
	_ensure_scoring_rules_in_draft()
	if int(draft.get("seed", 0)) == 0:
		draft["seed"] = hash(str(draft.get("id", "puzzle")))
	draft["map_growth"] = false
	draft["ring_count"] = GameSession.ring_count

	# Normalize boosters: empty dicts with no elements become null.
	var normalized_boosters: Array = []
	var raw_boosters = draft.get("boosters", [null, null, null])
	for i in 3:
		var entry = raw_boosters[i] if i < raw_boosters.size() else null
		if entry == null or typeof(entry) != TYPE_DICTIONARY:
			normalized_boosters.append(null)
			continue
		var elements: Array = entry.get("elements", [])
		if elements.is_empty():
			normalized_boosters.append(null)
			continue
		var out_pack := {"elements": elements.duplicate()}
		var quest_ids: Array = entry.get("quest_ids", [])
		if not quest_ids.is_empty():
			out_pack["quest_ids"] = quest_ids.duplicate()
		var map_points := int(entry.get("map_points", 0))
		if map_points != 0:
			out_pack["map_points"] = map_points
		normalized_boosters.append(out_pack)
	draft["boosters"] = normalized_boosters

	var market: Array = []
	var raw_market = draft.get("animal_market", [-1, -1, -1])
	for i in 3:
		market.append(int(raw_market[i]) if i < raw_market.size() else -1)
	draft["animal_market"] = market

	var starting_quests: Array = []
	var raw_quests = draft.get("quest_ids", [])
	if typeof(raw_quests) == TYPE_ARRAY:
		for quest_id in raw_quests:
			var qid := int(quest_id)
			if qid < 0:
				continue
			starting_quests.append(qid)
	draft["quest_ids"] = starting_quests

	if PuzzleCatalogWriterScript.upsert(draft):
		GameSession.puzzle_id = str(draft.get("id", ""))
		GameSession.puzzle_config = draft.duplicate(true)
		if save_overlay:
			save_overlay.set_status("Saved to puzzles.json.")
			await get_tree().create_timer(0.6).timeout
			save_overlay.close()
	else:
		if save_overlay:
			save_overlay.set_status("Save failed — is res:// writable?")
