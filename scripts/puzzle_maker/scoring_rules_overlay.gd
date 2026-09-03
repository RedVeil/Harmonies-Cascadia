extends CanvasLayer
class_name ScoringRulesOverlay

## Per-element scoring rule picker. Emits rules_changed with puzzle scoring_rules dict.

signal rules_changed(scoring_rules: Dictionary)
signal closed

var COLOR_BROWN := Color.html("#918478")

const ELEMENT_TYPES := [1, 2, 3, 4, 5]

var _option_buttons: Dictionary = {} # element_type -> OptionButton
var _desc_labels: Dictionary = {} # element_type -> Label
var _rule_ids_by_element: Dictionary = {} # element_type -> Array[int]

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _title: Label = $PopupRoot/TitleLabel
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _content: VBoxContainer = $PopupRoot/Content
@onready var _hint: Label = $PopupRoot/HintLabel


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)


func open(current_rules: Dictionary = {}) -> void:
	GameFeedback.play_open_popup()
	_rebuild_ui(current_rules)
	show()
	OverlayFocus.enable_control(_close_button)
	OverlayFocus.grab_control(_close_button)


func close() -> void:
	GameFeedback.play_close_popup()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if OverlayFocus.is_cancel(event):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _rebuild_ui(current_rules: Dictionary) -> void:
	for child in _content.get_children():
		child.queue_free()
	_option_buttons.clear()
	_desc_labels.clear()
	_rule_ids_by_element.clear()

	for element_type in ELEMENT_TYPES:
		if element_type < 0 or element_type >= ElementCatalog.elements.size():
			continue
		var element = ElementCatalog.elements[element_type]
		if element == null:
			continue

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		var name_label := Label.new()
		name_label.text = str(element.name)
		name_label.custom_minimum_size = Vector2(90, 0)
		name_label.add_theme_color_override("font_color", COLOR_BROWN)
		name_label.add_theme_font_size_override("font_size", 15)
		header.add_child(name_label)

		var option := OptionButton.new()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pool: Array = element.scoring_rules
		var ids: Array[int] = []
		var selected_idx := 0
		var wanted := _rule_id_for_element(current_rules, element_type)
		for i in pool.size():
			var rule_id := int(pool[i])
			ids.append(rule_id)
			var rule_name := "Rule %d" % rule_id
			if rule_id >= 0 and rule_id < RuleCatalog.rules.size() and RuleCatalog.rules[rule_id] != null:
				rule_name = RuleCatalog.rules[rule_id].name
			option.add_item(rule_name, rule_id)
			if rule_id == wanted:
				selected_idx = i
		if option.item_count > 0:
			option.select(selected_idx)
		option.item_selected.connect(_on_rule_selected.bind(element_type))
		header.add_child(option)
		row.add_child(header)

		var desc := Label.new()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", COLOR_BROWN)
		desc.add_theme_font_size_override("font_size", 11)
		desc.text = _description_for(ids[selected_idx] if selected_idx < ids.size() else -1)
		row.add_child(desc)

		_content.add_child(row)
		_option_buttons[element_type] = option
		_desc_labels[element_type] = desc
		_rule_ids_by_element[element_type] = ids


func _rule_id_for_element(rules: Dictionary, element_type: int) -> int:
	var key := str(element_type)
	if rules.has(key):
		return int(rules[key])
	if rules.has(element_type):
		return int(rules[element_type])
	return -1


func _description_for(rule_id: int) -> String:
	if rule_id < 0 or rule_id >= RuleCatalog.rules.size():
		return ""
	var rule: ScoringRule = RuleCatalog.rules[rule_id]
	if rule == null:
		return ""
	return str(rule.description)


func _on_rule_selected(item_index: int, element_type: int) -> void:
	GameFeedback.play_click_button()
	var ids: Array = _rule_ids_by_element.get(element_type, [])
	if item_index < 0 or item_index >= ids.size():
		return
	var rule_id := int(ids[item_index])
	if _desc_labels.has(element_type):
		(_desc_labels[element_type] as Label).text = _description_for(rule_id)
	rules_changed.emit(_collect_rules())


func _collect_rules() -> Dictionary:
	var out := {}
	for element_type in ELEMENT_TYPES:
		if not _option_buttons.has(element_type):
			continue
		var option: OptionButton = _option_buttons[element_type]
		var ids: Array = _rule_ids_by_element.get(element_type, [])
		var idx := option.selected
		if idx < 0 or idx >= ids.size():
			continue
		out[str(element_type)] = int(ids[idx])
	return out


func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0


func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close()


func _on_close_gui_input(event: InputEvent) -> void:
	if OverlayFocus.is_activate(event) or InputScheme.is_left_click(event):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
