extends CanvasLayer
class_name GameOverOverlay

signal continue_pressed
signal end_pressed
signal leave_pressed
signal restart_pressed
signal next_pressed

var COLOR_BROWN := Color.html("#918478")
var COLOR_STAR_EARNED := Color.html("#F2B05C")
var COLOR_STAR_EMPTY := Color.WHITE

@export var star_chime_sounds: Array[AudioStream] = []
@export var score_tick_sounds: Array[AudioStream] = []
@export var star_chime_volume_db: float = 7.0
@export var score_tick_volume_db: float = -5.0

@onready var _title_label: Label = $PopupRoot/TitleLabel
@onready var _score_label: Label = $PopupRoot/ScoreLabel
@onready var _compare_label: Label = $PopupRoot/CompareLabel
@onready var _rating_label: Label = $PopupRoot/RatingLabel
@onready var _stars_row: Node2D = $PopupRoot/StarsRow
@onready var _continue_button: Control = $PopupRoot/ContinueButton
@onready var _end_button: Control = $PopupRoot/EndButton
@onready var _leave_button: Control = $PopupRoot/LeaveButton
@onready var _restart_button: Control = $PopupRoot/RestartButton
@onready var _next_button: Control = $PopupRoot/NextButton
@onready var _share_button: Control = $PopupRoot/ShareButton
@onready var _share_status: Label = $PopupRoot/ShareStatus
@onready var _popup_root: Node2D = $PopupRoot
@onready var _leave_label: Label = $PopupRoot/LeaveButton/Label

var _final_score: int = 0
var _displayed_score: int = 0
var _puzzle_counting: bool = false
var _star_filled: Array[bool] = [false, false, false]
var _star_nodes: Array[Node2D] = []
var _star_base_scale: Array[Vector2] = []
var _star_thresholds: Array[int] = [0, 0, 0]
var _feedback_tweens: Dictionary = {}


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_setup_stars()
	_reset_button_hovers()
	_compare_label.hide()
	if _rating_label:
		_rating_label.hide()
	if _stars_row:
		_stars_row.hide()
	_share_status.text = ""
	_show_confirm_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if OverlayFocus.is_cancel(event):
		if _continue_button != null and _continue_button.visible:
			_on_continue_pressed()
		elif _leave_button != null and _leave_button.visible:
			_on_leave_pressed()
		get_viewport().set_input_as_handled()


func _grab_visible_button_focus() -> void:
	for button in [
		_continue_button,
		_end_button,
		_leave_button,
		_restart_button,
		_next_button,
		_share_button,
	]:
		if button == null:
			continue
		OverlayFocus.enable_control(button)
		if button.visible and button.is_visible_in_tree():
			OverlayFocus.grab_control(button)
			return


func _setup_stars() -> void:
	if _stars_row == null:
		return
	_star_nodes.clear()
	_star_base_scale.clear()
	for child in _stars_row.get_children():
		if not child is Node2D:
			continue
		var star := child as Node2D
		_star_nodes.append(star)
		_star_base_scale.append(star.scale)
		star.modulate = COLOR_STAR_EMPTY


func _pop_star(index: int) -> void:
	if index < 0 or index >= _star_nodes.size():
		return
	_star_filled[index] = true
	var star := _star_nodes[index]
	var base := _star_base_scale[index] if index < _star_base_scale.size() else Vector2.ONE
	star.modulate = COLOR_STAR_EARNED
	star.scale = base * 0.2
	var pop := FeedbackAnimHelper.create_tween(self, _feedback_tweens, StringName("star_%d" % index))
	pop.tween_property(star, "scale", base * 1.65, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(star, "scale", base, 0.16)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	FeedbackAnimHelper.play_sounds(star_chime_sounds, star_chime_volume_db)


func _reset_stars() -> void:
	_star_filled = [false, false, false]
	for i in _star_nodes.size():
		var star := _star_nodes[i]
		var base := _star_base_scale[i] if i < _star_base_scale.size() else Vector2.ONE
		star.scale = base * 0.85
		star.modulate = COLOR_STAR_EMPTY


func _fill_star_instant(index: int) -> void:
	if index < 0 or index >= _star_nodes.size():
		return
	if _star_filled[index]:
		return
	_star_filled[index] = true
	var star := _star_nodes[index]
	var base := _star_base_scale[index] if index < _star_base_scale.size() else Vector2.ONE
	star.scale = base
	star.modulate = COLOR_STAR_EARNED


func open_confirm(final_score: int) -> void:
	_stop_puzzle_reveal()
	GameFeedback.play_open_popup()
	_final_score = final_score
	_apply_default_layout()
	_title_label.text = "End Game?"
	_score_label.text = "Score: %d" % final_score
	_share_status.text = ""
	_compare_label.hide()
	if _rating_label:
		_rating_label.hide()
	if _stars_row:
		_stars_row.hide()
	if _leave_label:
		_leave_label.text = "Leave"
	_show_confirm_buttons()
	_reset_button_hovers()
	show()
	_grab_visible_button_focus()


func show_results(final_score: int) -> void:
	_stop_puzzle_reveal()
	_final_score = final_score
	_share_status.text = ""
	if GameSession.is_puzzle():
		_show_puzzle_results(final_score)
		show()
		GameFeedback.play_open_popup()
		_grab_visible_button_focus()
		return
	GameFeedback.play_open_popup()
	_apply_default_layout()
	_title_label.text = "End Game?"
	_score_label.text = "Score: %d" % final_score
	if _stars_row:
		_stars_row.hide()
	if _leave_label:
		_leave_label.text = "Leave"
	if GameSession.has_reference_score():
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
	_grab_visible_button_focus()


func _show_puzzle_results(final_score: int) -> void:
	_apply_puzzle_layout()
	_title_label.text = "Puzzle Complete"
	_compare_label.hide()
	if _rating_label:
		_rating_label.hide()
	if _leave_label:
		_leave_label.text = "End"
	_hide_all_action_buttons()
	_reset_stars()
	if _stars_row:
		_stars_row.show()
	var ratings := GameSession.get_puzzle_ratings()
	_star_thresholds = [
		int(ratings.get("bronze", 0)),
		int(ratings.get("silver", 0)),
		int(ratings.get("gold", 0)),
	]
	_displayed_score = 0
	_set_score_display(0)
	_puzzle_counting = true
	_reset_button_hovers()
	var duration := clampf(1.5 + float(final_score) / 180.0, 1.5, 2.1)
	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"count")
	tween.tween_method(_on_count_tick, 0.0, float(final_score), duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_finish_puzzle_reveal, CONNECT_ONE_SHOT)


func _on_count_tick(value: float) -> void:
	var shown := int(round(value))
	if shown != _displayed_score:
		_displayed_score = shown
		_set_score_display(shown)
		if shown > 0:
			FeedbackAnimHelper.play_sounds(score_tick_sounds, score_tick_volume_db)
	_try_pop_stars(shown)


func _try_pop_stars(shown: int) -> void:
	for i in mini(_star_thresholds.size(), _star_nodes.size()):
		if _star_filled[i]:
			continue
		var threshold := _star_thresholds[i]
		if threshold <= 0 or shown < threshold:
			continue
		_pop_star(i)


func _apply_puzzle_layout() -> void:
	_title_label.offset_top = -122.0
	_title_label.offset_bottom = -88.0
	_title_label.add_theme_font_size_override("font_size", 22)
	_score_label.offset_top = -8.0
	_score_label.offset_bottom = 32.0
	_score_label.add_theme_font_size_override("font_size", 32)
	_place_action_button(_leave_button, -130.0, -10.0, 72.0, 104.0)
	_place_action_button(_restart_button, 10.0, 130.0, 72.0, 104.0)
	_place_action_button(_next_button, 64.0, 174.0, 72.0, 104.0)
	if _stars_row:
		_stars_row.position = Vector2(0, -48)


func _apply_default_layout() -> void:
	_title_label.offset_top = -120.0
	_title_label.offset_bottom = -84.0
	_title_label.add_theme_font_size_override("font_size", 28)
	_score_label.offset_top = -70.0
	_score_label.offset_bottom = -38.0
	_score_label.add_theme_font_size_override("font_size", 20)
	_place_action_button(_leave_button, -130.0, -10.0, 40.0, 72.0)
	_place_action_button(_restart_button, 10.0, 130.0, 40.0, 72.0)
	if _next_button:
		_next_button.hide()


func _set_score_display(score: int) -> void:
	_score_label.text = "%d" % score


func _finish_puzzle_reveal() -> void:
	if not _puzzle_counting:
		return
	_puzzle_counting = false
	_displayed_score = _final_score
	_set_score_display(_final_score)
	var newly_filled := 0
	for i in mini(_star_thresholds.size(), _star_nodes.size()):
		var threshold := _star_thresholds[i]
		if threshold > 0 and _final_score >= threshold and not _star_filled[i]:
			_fill_star_instant(i)
			newly_filled += 1
	if newly_filled > 0:
		FeedbackAnimHelper.play_sounds(star_chime_sounds, star_chime_volume_db)
	_show_puzzle_result_buttons()
	_reset_button_hovers()


func _skip_puzzle_reveal() -> void:
	if not _puzzle_counting:
		return
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	_finish_puzzle_reveal()


func _stop_puzzle_reveal() -> void:
	_puzzle_counting = false
	FeedbackAnimHelper.kill_all(_feedback_tweens)


func close() -> void:
	_stop_puzzle_reveal()
	GameFeedback.play_close_popup()
	hide()


func _hide_all_action_buttons() -> void:
	_continue_button.hide()
	_end_button.hide()
	_leave_button.hide()
	_restart_button.hide()
	_next_button.hide()
	_share_button.hide()


func _show_confirm_buttons() -> void:
	_continue_button.show()
	_end_button.show()
	_leave_button.hide()
	_restart_button.hide()
	_next_button.hide()
	_share_button.hide()


func _show_results_buttons() -> void:
	_continue_button.hide()
	_end_button.hide()
	_leave_button.show()
	_restart_button.show()
	_next_button.hide()
	_share_button.show()


func _show_puzzle_result_buttons() -> void:
	_continue_button.hide()
	_end_button.hide()
	_share_button.hide()
	_leave_button.show()
	_restart_button.show()
	var show_next := _can_show_next_puzzle()
	_layout_puzzle_result_buttons(show_next)
	if show_next:
		_next_button.show()
	else:
		_next_button.hide()


func _can_show_next_puzzle() -> bool:
	if not GameSession.is_puzzle():
		return false
	if GameSession.rating_for_score(_final_score).is_empty():
		return false
	return not GameSession.get_next_puzzle_id().is_empty()


func _layout_puzzle_result_buttons(include_next: bool) -> void:
	var top := 72.0
	var bottom := 104.0
	if include_next:
		_place_action_button(_leave_button, -174.0, -64.0, top, bottom)
		_place_action_button(_restart_button, -55.0, 55.0, top, bottom)
		_place_action_button(_next_button, 64.0, 174.0, top, bottom)
	else:
		_place_action_button(_leave_button, -130.0, -10.0, top, bottom)
		_place_action_button(_restart_button, 10.0, 130.0, top, bottom)


func _place_action_button(button: Control, left: float, right: float, top: float, bottom: float) -> void:
	if button == null:
		return
	button.offset_left = left
	button.offset_right = right
	button.offset_top = top
	button.offset_bottom = bottom


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
	if _puzzle_counting:
		_skip_puzzle_reveal()
		return
	GameFeedback.play_click_button()
	leave_pressed.emit()


func _on_restart_pressed() -> void:
	if _puzzle_counting:
		_skip_puzzle_reveal()
		return
	GameFeedback.play_click_button()
	restart_pressed.emit()


func _on_next_pressed() -> void:
	if _puzzle_counting:
		_skip_puzzle_reveal()
		return
	GameFeedback.play_click_button()
	next_pressed.emit()


func _on_share_pressed() -> void:
	GameFeedback.play_click_button()
	var msg := ShareCode.clipboard_message(GameSession.run_seed, GameSession.ring_count, _final_score)
	if ShareCode.copy_to_clipboard(msg):
		_share_status.text = "Code copied"
	else:
		_share_status.text = "Press Ctrl+C to copy"


func _reset_button_hovers() -> void:
	_set_button_hover(_continue_button, false)
	_set_button_hover(_end_button, false)
	_set_button_hover(_leave_button, false)
	_set_button_hover(_restart_button, false)
	_set_button_hover(_next_button, false)
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
	if OverlayFocus.is_activate(event) or InputScheme.is_left_click(event):
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
	if _puzzle_counting:
		return
	GameFeedback.play_hover_button()
	_set_button_hover(_leave_button, true)


func _on_leave_mouse_exited() -> void:
	_set_button_hover(_leave_button, false)


func _on_restart_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_restart_pressed)


func _on_restart_mouse_entered() -> void:
	if _puzzle_counting:
		return
	GameFeedback.play_hover_button()
	_set_button_hover(_restart_button, true)


func _on_restart_mouse_exited() -> void:
	_set_button_hover(_restart_button, false)


func _on_next_gui_input(event: InputEvent) -> void:
	_handle_gui_click(event, _on_next_pressed)


func _on_next_mouse_entered() -> void:
	if _puzzle_counting:
		return
	GameFeedback.play_hover_button()
	_set_button_hover(_next_button, true)


func _on_next_mouse_exited() -> void:
	_set_button_hover(_next_button, false)


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
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _puzzle_counting:
			_skip_puzzle_reveal()
