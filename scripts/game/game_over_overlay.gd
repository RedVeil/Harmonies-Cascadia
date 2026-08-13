extends CanvasLayer
class_name GameOverOverlay

signal continue_pressed
signal end_pressed
signal leave_pressed
signal restart_pressed

var COLOR_BROWN := Color.html("#918478")

@onready var _title_label: Label = $PopupRoot/TitleLabel
@onready var _score_label: Label = $PopupRoot/ScoreLabel
@onready var _compare_label: Label = $PopupRoot/CompareLabel
@onready var _rating_label: Label = $PopupRoot/RatingLabel
@onready var _continue_button: Control = $PopupRoot/ContinueButton
@onready var _end_button: Control = $PopupRoot/EndButton
@onready var _leave_button: Control = $PopupRoot/LeaveButton
@onready var _restart_button: Control = $PopupRoot/RestartButton
@onready var _share_button: Control = $PopupRoot/ShareButton
@onready var _share_status: Label = $PopupRoot/ShareStatus
@onready var _popup_root: Node2D = $PopupRoot

var _final_score: int = 0


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_reset_button_hovers()
	_compare_label.hide()
	if _rating_label:
		_rating_label.hide()
	_share_status.text = ""
	_show_confirm_buttons()


func open_confirm(final_score: int) -> void:
	GameFeedback.play_open_popup()
	_final_score = final_score
	_title_label.text = "End Game?"
	_score_label.text = "Score: %d" % final_score
	_share_status.text = ""
	_compare_label.hide()
	if _rating_label:
		_rating_label.hide()
	_show_confirm_buttons()
	_reset_button_hovers()
	show()


func show_results(final_score: int) -> void:
	_final_score = final_score
	_title_label.text = "End Game?"
	_score_label.text = "Score: %d" % final_score
	_share_status.text = ""
	if GameSession.is_puzzle():
		_show_puzzle_rating(final_score)
		_compare_label.hide()
	elif GameSession.has_reference_score():
		if _rating_label:
			_rating_label.hide()
		var ref := GameSession.reference_score
		var delta := final_score - ref
		var result := "Tied"
		if delta > 0:
			result = "You win (+%d)" % delta
		elif delta < 0:
			result = "They win (%d)" % delta
		_compare_label.text = "Their score: %d\n%s" % [ref, result]
		_compare_label.show()
	else:
		if _rating_label:
			_rating_label.hide()
		_compare_label.hide()
	_show_results_buttons()
	_reset_button_hovers()
	show()


func _show_puzzle_rating(final_score: int) -> void:
	if _rating_label == null:
		return
	var ratings: Dictionary = GameSession.get_puzzle_ratings()
	var achieved: String = GameSession.rating_for_score(final_score)
	var lines: PackedStringArray = []
	if achieved.is_empty():
		lines.append("No medal")
	else:
		lines.append("%s!" % achieved.capitalize())
	if not ratings.is_empty():
		lines.append(
			"Bronze %d  ·  Silver %d  ·  Gold %d"
			% [
				int(ratings.get("bronze", 0)),
				int(ratings.get("silver", 0)),
				int(ratings.get("gold", 0)),
			]
		)
	var title := str(GameSession.puzzle_config.get("title", "Puzzle"))
	_rating_label.text = "%s\n%s" % [title, "\n".join(lines)]
	_rating_label.show()


func close() -> void:
	GameFeedback.play_close_popup()
	hide()


func _show_confirm_buttons() -> void:
	_continue_button.show()
	_end_button.show()
	_leave_button.hide()
	_restart_button.hide()
	_share_button.hide()


func _show_results_buttons() -> void:
	_continue_button.hide()
	_end_button.hide()
	_leave_button.show()
	_restart_button.show()
	_share_button.show()


func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0


func _on_continue_pressed() -> void:
	GameFeedback.play_click_button()
	continue_pressed.emit()


func _on_end_pressed() -> void:
	GameFeedback.play_click_button()
	end_pressed.emit()


func _on_leave_pressed() -> void:
	GameFeedback.play_click_button()
	leave_pressed.emit()


func _on_restart_pressed() -> void:
	GameFeedback.play_click_button()
	restart_pressed.emit()


func _on_share_pressed() -> void:
	GameFeedback.play_click_button()
	DisplayServer.clipboard_set(
		ShareCode.clipboard_message(GameSession.run_seed, GameSession.ring_count, _final_score)
	)
	_share_status.text = "Code copied"


func _reset_button_hovers() -> void:
	_set_button_hover(_continue_button, false)
	_set_button_hover(_end_button, false)
	_set_button_hover(_leave_button, false)
	_set_button_hover(_restart_button, false)
	_set_button_hover(_share_button, false)


func _set_button_hover(button: Control, hovered: bool) -> void:
	if button == null:
		return
	var background: ColorRect = button.get_node("Background")
	var label: Label = button.get_node("Label")
	if hovered:
		background.color = COLOR_BROWN
		label.add_theme_color_override("font_color", Color.WHITE)
	else:
		background.color = Color.WHITE
		label.add_theme_color_override("font_color", COLOR_BROWN)


func _handle_gui_click(event: InputEvent, callback: Callable) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			get_viewport().set_input_as_handled()
			callback.call()


func _on_continue_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_continue_pressed)


func _on_continue_mouse_entered() -> void:
	GameFeedback.play_hover_button()
	_set_button_hover(_continue_button, true)


func _on_continue_mouse_exited() -> void:
	_set_button_hover(_continue_button, false)


func _on_end_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_end_pressed)


func _on_end_mouse_entered() -> void:
	GameFeedback.play_hover_button()
	_set_button_hover(_end_button, true)


func _on_end_mouse_exited() -> void:
	_set_button_hover(_end_button, false)


func _on_leave_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_leave_pressed)


func _on_leave_mouse_entered() -> void:
	GameFeedback.play_hover_button()
	_set_button_hover(_leave_button, true)


func _on_leave_mouse_exited() -> void:
	_set_button_hover(_leave_button, false)


func _on_restart_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_restart_pressed)


func _on_restart_mouse_entered() -> void:
	GameFeedback.play_hover_button()
	_set_button_hover(_restart_button, true)


func _on_restart_mouse_exited() -> void:
	_set_button_hover(_restart_button, false)


func _on_share_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_share_pressed)


func _on_share_mouse_entered() -> void:
	GameFeedback.play_hover_button()
	_set_button_hover(_share_button, true)


func _on_share_mouse_exited() -> void:
	_set_button_hover(_share_button, false)


func _on_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
