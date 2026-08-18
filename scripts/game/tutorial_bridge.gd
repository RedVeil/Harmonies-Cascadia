class_name TutorialBridge
extends RefCounted
## Generic action gates + event bus for the interactive tutorial.
## Orchestrator must not know step ids — only allow/deny and emit.

signal action_performed(action: String, payload: Dictionary)

var active: bool = false
var allow_actions: Array = []
var allow_booster_ids: Array = []
var allow_card_filter: String = ""
var allow_element_ids: Array[int] = []
var allow_animal_ids: Array[int] = []
var allow_coords_mode: String = ""
var allow_coords: Array[Vector2i] = []


func set_gates(gates: Dictionary) -> void:
	active = true
	allow_actions = gates.get("allow_actions", [])
	if typeof(allow_actions) != TYPE_ARRAY:
		allow_actions = []
	allow_booster_ids = gates.get("allow_booster_ids", [])
	if typeof(allow_booster_ids) != TYPE_ARRAY:
		allow_booster_ids = []
	allow_card_filter = str(gates.get("allow_card_filter", ""))
	allow_element_ids.assign(gates.get("allow_element_ids", []))
	if typeof(allow_element_ids) != TYPE_ARRAY:
		allow_element_ids = []
	allow_animal_ids.assign(gates.get("allow_animal_ids", []))
	if typeof(allow_animal_ids) != TYPE_ARRAY:
		allow_animal_ids = []
	allow_coords.clear()
	allow_coords_mode = str(gates.get("allow_coords_mode", ""))
	# Back-compat: older configs use `allow_coords: "any_empty"` etc.
	var coords_raw = gates.get("allow_coords", null)
	if typeof(coords_raw) == TYPE_STRING:
		allow_coords_mode = str(coords_raw)
	elif typeof(coords_raw) == TYPE_ARRAY:
		for item in coords_raw:
			if typeof(item) == TYPE_ARRAY and item.size() >= 2:
				allow_coords.append(Vector2i(int(item[0]), int(item[1])))
			elif item is Vector2i:
				allow_coords.append(item)


func clear_gates() -> void:
	active = false
	allow_actions = []
	allow_booster_ids = []
	allow_card_filter = ""
	allow_element_ids.clear()
	allow_animal_ids.clear()
	allow_coords_mode = ""
	allow_coords.clear()


func allows_action(action: String) -> bool:
	if not active:
		return true
	return allow_actions.has(action)


func allows_animal_buy(animal_id: int) -> bool:
	if not active:
		return true
	if allow_animal_ids.is_empty():
		return true
	return allow_animal_ids.has(animal_id)


func allows_booster(id: int) -> bool:
	if not active:
		return true
	if id == 4:
		# Opening the animal market.
		if allows_action("open_animal_market"):
			return _booster_id_allowed(id)
		if allows_action("buy_animal"):
			return _booster_id_allowed(id)
		if allows_action("take_booster"):
			return _booster_id_allowed(id)
		return false
	if not allows_action("take_booster"):
		return false
	return _booster_id_allowed(id)


func _booster_id_allowed(id: int) -> bool:
	if allow_booster_ids.is_empty():
		return true
	for bid in allow_booster_ids:
		if int(bid) == id:
			return true
	return false


func allows_card(card: CardData) -> bool:
	if not active:
		return true
	if not allows_action("select_card"):
		return false
	if allow_card_filter.is_empty():
		return true
	match allow_card_filter:
		"any_element":
			if card == null or card.type != CardData.CARD_TYPE.ELEMENT:
				return false
			return allow_element_ids.is_empty() or allow_element_ids.has(int(card.id))
		"any_animal":
			return card != null and card.type == CardData.CARD_TYPE.ANIMAL
		_:
			if card == null:
				return false
			if allow_element_ids.is_empty():
				return true
			# Best-effort: only element cards have meaningful `id` filtering.
			return card.type == CardData.CARD_TYPE.ELEMENT and allow_element_ids.has(int(card.id))


func allows_place_coord(coord: Vector2i, tile_data: HexTileData, placement_valid: bool) -> bool:
	if not active:
		return true
	if not allows_action("place"):
		return false
	if not allow_coords.is_empty() and not allow_coords.has(coord):
		return false
	match allow_coords_mode:
		"any_empty":
			return tile_data != null and int(tile_data.element) == 0
		"any_valid":
			return placement_valid
		"":
			return true
		_:
			return true


func notify(action: String, payload: Dictionary = {}) -> void:
	action_performed.emit(action, payload)
