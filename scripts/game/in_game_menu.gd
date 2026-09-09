extends CanvasLayer
class_name InGameMenu

enum View { ROOT, END_SESSION, SETTINGS }

signal restart_pressed
signal end_pressed
signal back_pressed

@export var orchestrator: Orchestrator

@onready var _root_nav: VBoxContainer = $Root/Split/LeftColumn/Margin/NavStack/RootNav
@onready var _end_session_block: VBoxContainer = $Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock
@onready var _settings_block: ScrollContainer = $Root/Split/LeftColumn/Margin/NavStack/SettingsBlock
@onready var _footer_spacer: Control = $Root/Split/LeftColumn/Margin/NavStack/FooterSpacer
@onready var _score_label: Label = $Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ScoreLabel
@onready var _sub_label: Label = $Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/SubLabel
@onready var _share_status: Label = $Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ShareStatus
@onready var _settings_panel: SettingsPanel = $Root/Split/LeftColumn/Margin/NavStack/SettingsBlock/SettingsPanel

var _score: int = 0
var _view: View = View.ROOT
var _showing_results: bool = false
var _share_kind: String = ""


func _ready() -> void:
	hide()
	_share_status.text = ""
	_setup_hover_sounds()
	_show_view(View.ROOT)
	_apply_theme()
	UiTheme.bind_node(self, _apply_theme)
	_apply_locale()
	if GameSettings != null and not GameSettings.settings_changed.is_connected(_apply_locale):
		GameSettings.settings_changed.connect(_apply_locale)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if OverlayFocus.is_cancel(event):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _setup_hover_sounds() -> void:
	var buttons: Array[Control] = [
		$Root/Split/LeftColumn/Margin/NavStack/RootNav/SettingsButton,
		$Root/Split/LeftColumn/Margin/NavStack/RootNav/EndSessionButton,
		$Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow/RestartButton,
		$Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow/EndButton,
		$Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow/ShareButton,
		$Root/Split/LeftColumn/Margin/NavStack/BackButton,
	]
	for button in buttons:
		if button != null and not button.mouse_entered.is_connected(_on_button_mouse_entered):
			button.mouse_entered.connect(_on_button_mouse_entered)
	WebInstantButton.wire_many(buttons)


func _on_button_mouse_entered() -> void:
	if WebInstantButton.skip_hover():
		return
	GameFeedback.play_hover_button()


func _apply_theme() -> void:
	var left := $Root/Split/LeftColumn as Control
	if left:
		UiTheme.apply_menu_tree(left)
	if _settings_panel:
		_settings_panel.apply_sidebar_style()
	if _sub_label:
		UiTheme.style_label(_sub_label, true)
	if _share_status:
		UiTheme.style_label(_share_status, true)


func _apply_locale() -> void:
	var end_session := $Root/Split/LeftColumn/Margin/NavStack/RootNav/EndSessionButton as Button
	if end_session:
		end_session.text = Loc.ui("pause.end_session")
	var settings_btn := $Root/Split/LeftColumn/Margin/NavStack/RootNav/SettingsButton as Button
	if settings_btn:
		settings_btn.text = Loc.ui("pause.settings")
	var restart := $Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow/RestartButton as Button
	if restart:
		restart.text = Loc.ui("pause.restart")
	var end_btn := $Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow/EndButton as Button
	if end_btn:
		end_btn.text = Loc.ui("pause.end")
	var share := $Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow/ShareButton as Button
	if share:
		share.text = Loc.ui("pause.share")
	var back := $Root/Split/LeftColumn/Margin/NavStack/BackButton as Button
	if back:
		back.text = Loc.ui("pause.back")
	_refresh_end_session_copy()
	_refresh_share_status()


func _refresh_end_session_copy() -> void:
	if _score_label == null or _sub_label == null:
		return
	if _showing_results:
		_score_label.text = Loc.ui("pause.you_earned_points") % _score
		_sub_label.text = Loc.ui("pause.well_done")
	else:
		_score_label.text = Loc.ui("pause.you_have_points") % _score
		_sub_label.text = Loc.ui("pause.take_a_break")


func _refresh_share_status() -> void:
	if _share_status == null:
		return
	if _share_kind == "copied":
		_share_status.text = Loc.ui("pause.code_copied")
	elif _share_kind == "press_copy":
		_share_status.text = Loc.ui("pause.press_copy")
	else:
		_share_status.text = ""


func _tutorial_active() -> bool:
	return orchestrator != null and orchestrator.tutorial_bridge != null and orchestrator.tutorial_bridge.active


func _allows(action: String) -> bool:
	if not _tutorial_active():
		return true
	return orchestrator.tutorial_bridge.allows_action(action)


func _notify(action: String, payload: Dictionary = {}) -> void:
	if orchestrator == null:
		return
	orchestrator.tutorial_bridge.notify(action, payload)


func _show_view(view: View) -> void:
	_view = view
	_root_nav.visible = view == View.ROOT
	_end_session_block.visible = view == View.END_SESSION
	_settings_block.visible = view == View.SETTINGS
	# Settings scroll takes the expand space; otherwise footer spacer pushes BACK down.
	_footer_spacer.visible = view != View.SETTINGS
	_settings_block.size_flags_vertical = Control.SIZE_EXPAND_FILL if view == View.SETTINGS else 0
	_sync_view_input_filters()
	_grab_view_focus()


func _grab_view_focus() -> void:
	OverlayFocus.grab_first_button($Root/Split/LeftColumn/Margin/NavStack)


func _sync_view_input_filters() -> void:
	_root_nav.mouse_filter = Control.MOUSE_FILTER_STOP if _view == View.ROOT else Control.MOUSE_FILTER_IGNORE
	_end_session_block.mouse_filter = Control.MOUSE_FILTER_STOP if _view == View.END_SESSION else Control.MOUSE_FILTER_IGNORE
	_settings_block.mouse_filter = Control.MOUSE_FILTER_STOP if _view == View.SETTINGS else Control.MOUSE_FILTER_IGNORE
	InputScheme.clear_stuck_gui_hover_deferred(self)


func open(score: int, _results: bool = false) -> void:
	GameFeedback.play_open_popup()
	_score = score
	_showing_results = false
	_share_kind = ""
	_share_status.text = ""
	_refresh_end_session_copy()
	_show_view(View.ROOT)
	show()
	OverlayFocus.grab_first_button(_root_nav)


func show_results(final_score: int) -> void:
	GameFeedback.play_open_popup()
	_score = final_score
	_showing_results = true
	_share_kind = ""
	_refresh_end_session_copy()
	_share_status.text = ""
	_show_view(View.END_SESSION)
	show()
	OverlayFocus.grab_first_button(_end_session_block)


func close() -> void:
	GameFeedback.play_close_popup()
	_show_view(View.ROOT)
	hide()


func open_settings_panel() -> void:
	if _settings_panel:
		_settings_panel.apply_sidebar_style()
		_settings_panel.reset_to_root()
		_settings_panel.refresh()
	_show_view(View.SETTINGS)


func _on_settings_pressed() -> void:
	if _tutorial_active():
		return
	GameFeedback.play_click_button()
	if _settings_panel:
		_settings_panel.apply_sidebar_style()
		_settings_panel.reset_to_root()
		_settings_panel.refresh()
	GameFeedback.play_open_popup()
	_show_view(View.SETTINGS)


func _on_end_session_pressed() -> void:
	if not _allows("open_end_session"):
		return
	GameFeedback.play_click_button()
	GameFeedback.play_open_popup()
	_showing_results = false
	_share_kind = ""
	_share_status.text = ""
	_refresh_end_session_copy()
	_show_view(View.END_SESSION)
	_notify("end_session_opened")


func _on_restart_pressed() -> void:
	if _tutorial_active():
		return
	GameFeedback.play_click_button()
	restart_pressed.emit()


func _on_end_pressed() -> void:
	if _tutorial_active() and not _allows("end_game"):
		return
	GameFeedback.play_click_button()
	end_pressed.emit()


func _on_share_pressed() -> void:
	if not _allows("share_code"):
		return
	GameFeedback.play_click_button()
	var msg := ShareCode.clipboard_message(GameSession.run_seed, GameSession.ring_count, _score)
	if ShareCode.copy_to_clipboard(msg):
		_share_kind = "copied"
	else:
		_share_kind = "press_copy"
	_refresh_share_status()
	_notify("code_shared")


func _on_back_pressed() -> void:
	if _tutorial_active():
		return
	GameFeedback.play_click_button()
	if _view == View.SETTINGS and _settings_panel != null and _settings_panel.handle_back():
		return
	if _view != View.ROOT:
		GameFeedback.play_close_popup()
		_show_view(View.ROOT)
		return
	back_pressed.emit()
