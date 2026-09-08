extends CanvasLayer
class_name PuzzleSaveOverlay

## Meta + ratings form; emits save_requested with field values.

signal save_requested(payload: Dictionary)
signal closed

@onready var _popup_root: Node2D = $PopupRoot
@onready var _popup_panel: Panel = $PopupRoot/PopupPanel
@onready var _title: Label = $PopupRoot/TitleLabel
@onready var _close_button: Control = $PopupRoot/CloseButton
@onready var _form: VBoxContainer = $PopupRoot/Form
@onready var _id_edit: LineEdit = $PopupRoot/Form/IdRow/IdEdit
@onready var _title_edit: LineEdit = $PopupRoot/Form/TitleRow/TitleEdit
@onready var _desc_edit: TextEdit = $PopupRoot/Form/DescEdit
@onready var _max_plays: SpinBox = $PopupRoot/Form/PlaysRow/MaxPlays
@onready var _max_packs: SpinBox = $PopupRoot/Form/PacksRow/MaxPacks
@onready var _rings: SpinBox = $PopupRoot/Form/RingsRow/Rings
@onready var _bronze: SpinBox = $PopupRoot/Form/RatingsRow/Bronze
@onready var _silver: SpinBox = $PopupRoot/Form/RatingsRow/Silver
@onready var _gold: SpinBox = $PopupRoot/Form/RatingsRow/Gold
@onready var _board_score: Label = $PopupRoot/Form/BoardScoreLabel
@onready var _save_button: Button = $PopupRoot/Form/SaveButton
@onready var _status: Label = $PopupRoot/Form/StatusLabel


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_save_button.pressed.connect(_on_save_pressed)
	_apply_theme()
	UiTheme.bind_node(self, _apply_theme)


func _apply_theme() -> void:
	if _popup_panel:
		UiTheme.style_panel(_popup_panel)
	UiTheme.style_label(_title)
	UiTheme.style_label(_board_score)
	UiTheme.style_label(_status, true)
	UiTheme.style_line_edit(_id_edit)
	UiTheme.style_line_edit(_title_edit)
	UiTheme.style_text_edit(_desc_edit)
	UiTheme.style_chip_button(_save_button)
	if _close_button:
		var close_label := _close_button.get_node_or_null("Label") as Label
		if close_label:
			UiTheme.style_label(close_label)
	if _form:
		for child in _form.find_children("*", "Label", true, false):
			if child is Label:
				var hint := (child as Label).name.to_lower().contains("status")
				UiTheme.style_label(child as Label, hint)


func open(draft: Dictionary, board_score: int = 0) -> void:
	GameFeedback.play_open_popup()
	_id_edit.text = str(draft.get("id", ""))
	_title_edit.text = str(draft.get("title", ""))
	_desc_edit.text = str(draft.get("description", ""))
	_max_plays.value = int(draft.get("max_plays", 3))
	_max_packs.value = int(draft.get("max_pack_takes", 0))
	_rings.value = int(draft.get("ring_count", 3))
	var ratings = draft.get("ratings", {})
	if typeof(ratings) != TYPE_DICTIONARY:
		ratings = {}
	_bronze.value = int(ratings.get("bronze", board_score))
	_silver.value = int(ratings.get("silver", board_score + 5))
	_gold.value = int(ratings.get("gold", board_score + 10))
	_board_score.text = "Current board score: %d" % board_score
	_status.text = ""
	show()
	OverlayFocus.enable_control(_close_button)
	if InputScheme.is_gamepad():
		OverlayFocus.grab_control(_close_button)
	else:
		_id_edit.grab_focus()


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


func _on_save_pressed() -> void:
	GameFeedback.play_click_button()
	var id := _id_edit.text.strip_edges()
	if id.is_empty():
		_status.text = "Id is required."
		return
	var payload := {
		"id": id,
		"title": _title_edit.text.strip_edges(),
		"description": _desc_edit.text.strip_edges(),
		"max_plays": int(_max_plays.value),
		"max_pack_takes": int(_max_packs.value),
		"ring_count": int(_rings.value),
		"ratings": {
			"bronze": int(_bronze.value),
			"silver": int(_silver.value),
			"gold": int(_gold.value),
		},
	}
	save_requested.emit(payload)


func set_status(text: String) -> void:
	_status.text = text


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
