extends Control

const GAME_SCENE := "res://scenes/Refactored_Main.tscn"
const BG_PATH := "res://assets/ui/menu_bg.webp"

var COLOR_RIGHT := Color.html("#D2C2AD")

@onready var _bg_fallback: ColorRect = $BackgroundFallback
@onready var _bg_image: TextureRect = $BackgroundImage
@onready var _root_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/RootNav
@onready var _play_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav
@onready var _code_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/CodeNav
@onready var _settings_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/SettingsNav
@onready var _settings_panel: SettingsPanel = $Split/LeftColumn/Margin/NavStack/SettingsNav/SettingsScroll/SettingsPanel
@onready var _map_size_row: HBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow
@onready var _quick_session_desc: Label = $Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/QuickSessionDesc
@onready var _puzzle_button: Button = $Split/LeftColumn/Margin/NavStack/PlayNav/PuzzleBlock/PuzzleButton
@onready var _code_input: LineEdit = $Split/LeftColumn/Margin/NavStack/CodeNav/CodeInput
@onready var _code_status: Label = $Split/LeftColumn/Margin/NavStack/CodeNav/CodeStatus

@onready var _endless_desc: Label = $Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessDesc
@onready var _endless_inline_buttons: HBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons

@onready var _endless_continue_button: Button = $Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons/ContinueButton
@onready var _endless_new_button: Button = $Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons/NewButton

var _puzzle_ids: Array[String] = []


func _ready() -> void:
	_setup_background()
	_setup_puzzle_ids()
	_setup_button_hover_sounds()
	_show_root_nav()
	_code_status.text = ""
	if _settings_panel:
		_settings_panel.apply_sidebar_style()
	if _endless_inline_buttons:
		_endless_inline_buttons.hide()
	if _endless_desc:
		_endless_desc.show()


func _setup_button_hover_sounds() -> void:
	var buttons: Array[Control] = [
		$Split/LeftColumn/Margin/NavStack/RootNav/PlayBlock/PlayButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/TutorialBlock/TutorialButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/SettingsBlock/SettingsButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/EnterCodeBlock/EnterCodeButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/ExitButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/BackButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/DailyBlock/DailyButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/QuickSessionButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow/SmallButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow/MediumButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow/LargeButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons/ContinueButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons/NewButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/PuzzleBlock/PuzzleButton,
		$Split/LeftColumn/Margin/NavStack/CodeNav/CodeBackButton,
		$Split/LeftColumn/Margin/NavStack/CodeNav/StartCodeButton,
		$Split/LeftColumn/Margin/NavStack/SettingsNav/SettingsBackButton,
	]
	for button in buttons:
		if button != null and not button.mouse_entered.is_connected(_on_nav_button_mouse_entered):
			button.mouse_entered.connect(_on_nav_button_mouse_entered)


func _on_nav_button_mouse_entered() -> void:
	GameFeedback.play_hover_button()


func _setup_background() -> void:
	_bg_fallback.color = COLOR_RIGHT
	if ResourceLoader.exists(BG_PATH):
		var tex := load(BG_PATH) as Texture2D
		if tex != null:
			_bg_image.texture = tex
			_bg_image.show()
			return
	_bg_image.hide()


func _setup_puzzle_ids() -> void:
	_puzzle_ids.clear()
	var puzzles: Array[Dictionary] = GameSession.list_puzzles()
	for puzzle in puzzles:
		var id := str(puzzle.get("id", ""))
		if not id.is_empty():
			_puzzle_ids.append(id)
	_puzzle_button.disabled = _puzzle_ids.is_empty()


func _hide_map_size_row() -> void:
	_map_size_row.hide()
	_quick_session_desc.show()


func _show_root_nav() -> void:
	_root_nav.show()
	_play_nav.hide()
	_code_nav.hide()
	_settings_nav.hide()
	_hide_map_size_row()


func _show_play_nav() -> void:
	GameFeedback.play_open_popup()
	_root_nav.hide()
	_play_nav.show()
	_code_nav.hide()
	_settings_nav.hide()
	_hide_map_size_row()


func _show_code_nav() -> void:
	GameFeedback.play_open_popup()
	_root_nav.hide()
	_play_nav.hide()
	_code_nav.show()
	_settings_nav.hide()
	_hide_map_size_row()
	_code_status.text = ""
	_code_input.grab_focus()


func _show_settings_nav() -> void:
	GameFeedback.play_open_popup()
	_root_nav.hide()
	_play_nav.hide()
	_code_nav.hide()
	_settings_nav.show()
	_hide_map_size_row()
	if _settings_panel:
		_settings_panel.apply_sidebar_style()
		_settings_panel.reset_to_root()
		_settings_panel.refresh()


func _on_play_pressed() -> void:
	GameFeedback.play_click_button()
	_show_play_nav()


func _on_tutorial_pressed() -> void:
	GameFeedback.play_click_button()
	GameSession.begin_tutorial_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	GameFeedback.play_click_button()
	_show_settings_nav()


func _on_enter_code_pressed() -> void:
	GameFeedback.play_click_button()
	_show_code_nav()


func _on_back_pressed() -> void:
	GameFeedback.play_click_button()
	if _settings_nav.visible and _settings_panel != null and _settings_panel.handle_back():
		return
	GameFeedback.play_close_popup()
	_show_root_nav()


func _on_exit_pressed() -> void:
	GameFeedback.play_click_button()
	get_tree().quit()


func _on_daily_pressed() -> void:
	GameFeedback.play_click_button()
	if _start_tutorial_if_needed():
		return
	GameSession.begin_daily_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_quick_session_pressed() -> void:
	GameFeedback.play_click_button()
	_map_size_row.visible = not _map_size_row.visible
	_quick_session_desc.visible = not _map_size_row.visible


func _on_map_size_small_pressed() -> void:
	_start_normal_run(GameSession.MapSize.SMALL)


func _on_map_size_medium_pressed() -> void:
	_start_normal_run(GameSession.MapSize.MEDIUM)


func _on_map_size_large_pressed() -> void:
	_start_normal_run(GameSession.MapSize.LARGE)


func _start_normal_run(size: GameSession.MapSize) -> void:
	GameFeedback.play_click_button()
	if _start_tutorial_if_needed():
		return
	GameSession.begin_normal_run(size)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_endless_pressed() -> void:
	GameFeedback.play_click_button()
	if _start_tutorial_if_needed():
		return
	if EndlessRunSave.has_save():
		_endless_inline_buttons.visible = not _endless_inline_buttons.visible
		_endless_desc.visible = not _endless_inline_buttons.visible
		return

	GameSession.begin_endless_run()
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_endless_continue_pressed() -> void:
	GameFeedback.play_click_button()
	var state := EndlessRunSave.load_save()
	if state.is_empty():
		# Save vanished; fall back to a fresh run.
		GameSession.begin_endless_run()
		get_tree().change_scene_to_file(GAME_SCENE)
		return

	EndlessRunSave.set_pending_state(state)

	# Set run config before the game scene loads (ScoreEngine picks rules in _ready()).
	GameSession.game_mode = GameSession.GameMode.ENDLESS
	GameSession.map_size = GameSession.MapSize.MEDIUM
	GameSession.ring_count = int(state.get("ring_count", GameSession.ring_count))
	GameSession.checkpoint = int(state.get("checkpoint", GameSession.checkpoint))
	GameSession.checkpoint_multiplier = float(state.get("checkpoint_multiplier", GameSession.checkpoint_multiplier))
	GameSession.checkpoint_flat_increase = int(state.get("checkpoint_flat_increase", GameSession.checkpoint_flat_increase))
	GameSession.map_growth_enabled = bool(state.get("map_growth_enabled", GameSession.map_growth_enabled))
	GameSession.checkpoint_targets.clear()

	var seed := int(state.get("run_seed", 1))
	GameSession.begin_run(seed, true)

	if _endless_inline_buttons:
		_endless_inline_buttons.hide()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_endless_new_pressed() -> void:
	GameFeedback.play_click_button()
	EndlessRunSave.clear_save()
	if _endless_inline_buttons:
		_endless_inline_buttons.hide()
	if _endless_desc:
		_endless_desc.show()
	GameSession.begin_endless_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_puzzle_pressed() -> void:
	GameFeedback.play_click_button()
	if _puzzle_ids.is_empty():
		return
	if not GameSession.begin_puzzle_run(_puzzle_ids[0]):
		return
	get_tree().change_scene_to_file(GAME_SCENE)


func _start_tutorial_if_needed() -> bool:
	if PlayerProgress.tutorial_completed:
		return false
	GameSession.begin_tutorial_run()
	get_tree().change_scene_to_file(GAME_SCENE)
	return true


func _on_start_code_pressed() -> void:
	GameFeedback.play_click_button()
	_try_start_from_code(_code_input.text)


func _on_code_submitted(text: String) -> void:
	_try_start_from_code(text)


func _try_start_from_code(text: String) -> void:
	var decoded := ShareCode.decode(text)
	if not decoded.get("ok", false):
		_code_status.text = str(decoded.get("error", "Invalid code."))
		return
	GameSession.begin_challenge_run(
		int(decoded["seed"]),
		int(decoded["ring_count"]),
		int(decoded["score"])
	)
	get_tree().change_scene_to_file(GAME_SCENE)
