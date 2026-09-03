extends CanvasLayer
class_name PackBuilderOverlay

## Edits 3 booster slots (elements + quest_ids) and 3 animal market slots.

signal changed(boosters: Array, animal_market: Array)
signal request_animal_pick(slot_index: int)
signal request_element_pick(pack_index: int)
signal request_quest_pick(pack_index: int)
signal closed

const PACK_SLOTS := 3
const MARKET_SLOTS := 3
const MAX_PACK_ELEMENTS := 4

var COLOR_BROWN := Color.html("#918478")

var boosters: Array = [null, null, null]
var animal_market: Array = [-1, -1, -1]

var pending_animal_slot: int = -1
var pending_element_pack: int = -1
var pending_quest_pack: int = -1

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _title: Label = $PopupRoot/TitleLabel
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _content: VBoxContainer = $PopupRoot/Content
@onready var _status: Label = $PopupRoot/StatusLabel


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)


func open(initial_boosters: Array = [], initial_market: Array = []) -> void:
	GameFeedback.play_open_popup()
	_load_state(initial_boosters, initial_market)
	_rebuild_ui()
	show()
	OverlayFocus.enable_control(_close_button)
	OverlayFocus.grab_control(_close_button)


func close() -> void:
	GameFeedback.play_close_popup()
	hide()
	closed.emit()


func apply_animal(animal_id: int) -> void:
	if pending_animal_slot < 0 or pending_animal_slot >= MARKET_SLOTS:
		return
	animal_market[pending_animal_slot] = animal_id
	pending_animal_slot = -1
	_rebuild_ui()
	_emit_changed()


func apply_element(element_id: int) -> void:
	if pending_element_pack < 0 or pending_element_pack >= PACK_SLOTS:
		return
	var pack = boosters[pending_element_pack]
	if pack == null or typeof(pack) != TYPE_DICTIONARY:
		pack = {"elements": [], "quest_ids": []}
		boosters[pending_element_pack] = pack
	var elements: Array = pack.get("elements", [])
	if elements.size() >= MAX_PACK_ELEMENTS:
		_status.text = "Pack already has %d elements." % MAX_PACK_ELEMENTS
		pending_element_pack = -1
		return
	elements.append(element_id)
	pack["elements"] = elements
	pending_element_pack = -1
	_rebuild_ui()
	_emit_changed()


func apply_quest(quest_id: int) -> void:
	if pending_quest_pack < 0 or pending_quest_pack >= PACK_SLOTS:
		return
	var pack = boosters[pending_quest_pack]
	if pack == null or typeof(pack) != TYPE_DICTIONARY:
		pack = {"elements": [], "quest_ids": []}
		boosters[pending_quest_pack] = pack
	var quest_ids: Array = pack.get("quest_ids", [])
	if not quest_ids.has(quest_id):
		quest_ids.append(quest_id)
	pack["quest_ids"] = quest_ids
	pending_quest_pack = -1
	_rebuild_ui()
	_emit_changed()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if OverlayFocus.is_cancel(event):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _load_state(initial_boosters: Array, initial_market: Array) -> void:
	boosters = [null, null, null]
	for i in mini(PACK_SLOTS, initial_boosters.size()):
		var entry = initial_boosters[i]
		if entry == null:
			boosters[i] = null
		elif typeof(entry) == TYPE_DICTIONARY:
			boosters[i] = {
				"elements": (entry.get("elements", []) as Array).duplicate(),
				"quest_ids": (entry.get("quest_ids", []) as Array).duplicate(),
				"map_points": int(entry.get("map_points", 0)),
			}
	animal_market = [-1, -1, -1]
	for i in mini(MARKET_SLOTS, initial_market.size()):
		animal_market[i] = int(initial_market[i])


func _rebuild_ui() -> void:
	for child in _content.get_children():
		child.queue_free()
	_status.text = "Build packs and the animal market for this puzzle."

	var packs_label := Label.new()
	packs_label.text = "Packs"
	packs_label.add_theme_color_override("font_color", COLOR_BROWN)
	packs_label.add_theme_font_size_override("font_size", 18)
	_content.add_child(packs_label)

	for i in PACK_SLOTS:
		_content.add_child(_make_pack_row(i))

	var market_label := Label.new()
	market_label.text = "Animal Market"
	market_label.add_theme_color_override("font_color", COLOR_BROWN)
	market_label.add_theme_font_size_override("font_size", 18)
	_content.add_child(market_label)

	for i in MARKET_SLOTS:
		_content.add_child(_make_market_row(i))


func _make_pack_row(index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var pack = boosters[index]
	var summary := Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_color_override("font_color", COLOR_BROWN)
	summary.add_theme_font_size_override("font_size", 13)
	if pack == null:
		summary.text = "Pack %d: (empty)" % (index + 1)
	else:
		var elements: Array = pack.get("elements", [])
		var quest_ids: Array = pack.get("quest_ids", [])
		summary.text = "Pack %d: els %s  quests %s" % [index + 1, str(elements), str(quest_ids)]
	row.add_child(summary)

	row.add_child(_btn("Elements", _on_add_element.bind(index)))
	row.add_child(_btn("Quest", _on_add_quest.bind(index)))
	row.add_child(_btn("Clear", _on_clear_pack.bind(index)))
	return row


func _make_market_row(index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var summary := Label.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_color_override("font_color", COLOR_BROWN)
	summary.add_theme_font_size_override("font_size", 13)
	var animal_id := int(animal_market[index])
	if animal_id < 0:
		summary.text = "Slot %d: (empty)" % (index + 1)
	else:
		var name := str(animal_id)
		for animal in CardCatalog.animals:
			if animal != null and animal.id == animal_id:
				name = animal.name
				break
		summary.text = "Slot %d: %s (#%d)" % [index + 1, name, animal_id]
	row.add_child(summary)
	row.add_child(_btn("Pick", _on_pick_animal.bind(index)))
	row.add_child(_btn("Clear", _on_clear_animal.bind(index)))
	return row


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(72, 28)
	b.pressed.connect(cb)
	return b


func _on_add_element(pack_index: int) -> void:
	GameFeedback.play_click_button()
	pending_element_pack = pack_index
	pending_quest_pack = -1
	pending_animal_slot = -1
	# Cycle element ids 1-5 via a simple chooser built into status/actions.
	_show_element_chooser(pack_index)


func _show_element_chooser(pack_index: int) -> void:
	# Inline chooser row under status.
	for child in _content.get_children():
		if child.has_meta("element_chooser"):
			child.queue_free()
	var row := HBoxContainer.new()
	row.set_meta("element_chooser", true)
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = "Add element to pack %d:" % (pack_index + 1)
	label.add_theme_color_override("font_color", COLOR_BROWN)
	row.add_child(label)
	for element in CardCatalog.elements:
		if element == null or element.id <= 0:
			continue
		var b := _btn(element.name.substr(0, 3), func() -> void:
			pending_element_pack = pack_index
			apply_element(element.id)
		)
		row.add_child(b)
	_content.add_child(row)
	request_element_pick.emit(pack_index)


func _on_add_quest(pack_index: int) -> void:
	GameFeedback.play_click_button()
	pending_quest_pack = pack_index
	pending_element_pack = -1
	pending_animal_slot = -1
	request_quest_pick.emit(pack_index)


func _on_clear_pack(pack_index: int) -> void:
	GameFeedback.play_click_button()
	boosters[pack_index] = null
	_rebuild_ui()
	_emit_changed()


func _on_pick_animal(slot_index: int) -> void:
	GameFeedback.play_click_button()
	pending_animal_slot = slot_index
	pending_element_pack = -1
	pending_quest_pack = -1
	request_animal_pick.emit(slot_index)


func _on_clear_animal(slot_index: int) -> void:
	GameFeedback.play_click_button()
	animal_market[slot_index] = -1
	_rebuild_ui()
	_emit_changed()


func _emit_changed() -> void:
	changed.emit(boosters.duplicate(true), animal_market.duplicate())


func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0


func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	_emit_changed()
	close()


func _on_close_gui_input(event: InputEvent) -> void:
	if OverlayFocus.is_activate(event) or InputScheme.is_left_click(event):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
