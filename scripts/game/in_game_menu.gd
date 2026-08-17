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


func _ready() -> void:
	hide()
	_share_status.text = ""
	_setup_hover_sounds()
	_show_view(View.ROOT)


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


func _on_button_mouse_entered() -> void:
	GameFeedback.play_hover_button()


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


func _sync_view_input_filters() -> void:
	_root_nav.mouse_filter = Control.MOUSE_FILTER_STOP if _view == View.ROOT else Control.MOUSE_FILTER_IGNORE
	_end_session_block.mouse_filter = Control.MOUSE_FILTER_STOP if _view == View.END_SESSION else Control.MOUSE_FILTER_IGNORE
	_settings_block.mouse_filter = Control.MOUSE_FILTER_STOP if _view == View.SETTINGS else Control.MOUSE_FILTER_IGNORE


func open(score: int, _results: bool = false) -> void:
	GameFeedback.play_open_popup()
	_score = score
	_share_status.text = ""
	_score_label.text = "You have %d Points!" % score
	_sub_label.text = "Take a break or wrap up your session."
	_show_view(View.ROOT)
	show()


func show_results(final_score: int) -> void:
	_score = final_score
	_score_label.text = "You earned %d Points!" % final_score
	_sub_label.text = "Well done!"
	_share_status.text = ""
	_show_view(View.END_SESSION)
	show()


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
	_share_status.text = ""
	_score_label.text = "You have %d Points!" % _score
	_sub_label.text = "Take a break or wrap up your session."
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
		_share_status.text = "Code copied"
	else:
		_share_status.text = "Press Ctrl+C to copy"
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
