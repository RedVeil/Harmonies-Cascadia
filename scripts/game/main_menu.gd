extends Control

const GAME_SCENE := "res://scenes/Refactored_Main.tscn"
const BG_PATH := "res://assets/ui/menu_bg.webp"

var COLOR_RIGHT := Color.html("#D2C2AD")

@onready var _bg_fallback: ColorRect = $BackgroundFallback
@onready var _bg_image: TextureRect = $BackgroundImage
@onready var _name_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/NameNav
@onready var _name_input: LineEdit = $Split/LeftColumn/Margin/NavStack/NameNav/NameInput
@onready var _root_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/RootNav
@onready var _play_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav
@onready var _tutorial_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/TutorialNav
@onready var _code_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/CodeNav
@onready var _settings_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/SettingsNav
@onready var _settings_panel: SettingsPanel = $Split/LeftColumn/Margin/NavStack/SettingsNav/SettingsScroll/SettingsPanel
@onready var _map_size_row: HBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow
@onready var _quick_session_desc: Label = $Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/QuickSessionDesc
@onready var _puzzle_button: Button = $Split/LeftColumn/Margin/NavStack/PlayNav/PuzzleBlock/PuzzleButton
@onready var _puzzle_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/PuzzleNav
@onready var _puzzle_list: VBoxContainer = $Split/LeftColumn/Margin/NavStack/PuzzleNav/PuzzleList
@onready var _code_input: LineEdit = $Split/LeftColumn/Margin/NavStack/CodeNav/CodeInput
@onready var _code_status: Label = $Split/LeftColumn/Margin/NavStack/CodeNav/CodeStatus

@onready var _daily_desc: Label = $Split/LeftColumn/Margin/NavStack/PlayNav/DailyBlock/DailyDesc
@onready var _daily_inline_buttons: HBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav/DailyBlock/DailyInlineButtons
@onready var _leaderboard: DailyLeaderboardOverlay = $Split/RightColumn/DailyLeaderboardOverlay

@onready var _quick_inline_buttons: HBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/QuickInlineButtons

@onready var _endless_desc: Label = $Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessDesc
@onready var _endless_inline_buttons: HBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons

var _puzzle_ids: Array[String] = []


func _ready() -> void:
	if not GameSettings.tutorial_played:
		GameSession.begin_tutorial_run()
		get_tree().change_scene_to_file(GAME_SCENE)
		return
	_setup_background()
	_setup_puzzle_ids()
	_setup_button_hover_sounds()
	_code_status.text = ""
	if _name_input:
		_name_input.max_length = GameSettings.PLAYER_NAME_MAX_LENGTH
	if _settings_panel:
		_settings_panel.apply_sidebar_style()
	_reset_mode_inline_ui()
	if GameSettings.tutorial_completed and GameSettings.player_name.strip_edges().is_empty():
		_show_name_nav()
	else:
		_show_root_nav()


func _setup_button_hover_sounds() -> void:
	var buttons: Array[Control] = [
		$Split/LeftColumn/Margin/NavStack/NameNav/NameAcceptButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/PlayBlock/PlayButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/TutorialBlock/TutorialButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/SettingsBlock/SettingsButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/EnterCodeBlock/EnterCodeButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/ExitButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/BackButton,
		$Split/LeftColumn/Margin/NavStack/TutorialNav/LandscapesBlock/LandscapesButton,
		$Split/LeftColumn/Margin/NavStack/TutorialNav/ScoringBlock/ScoringButton,
		$Split/LeftColumn/Margin/NavStack/TutorialNav/AnimalsBlock/AnimalsButton,
		$Split/LeftColumn/Margin/NavStack/TutorialNav/QuestsBlock/QuestsButton,
		$Split/LeftColumn/Margin/NavStack/TutorialNav/TutorialBackButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/DailyBlock/DailyButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/DailyBlock/DailyInlineButtons/PlayButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/DailyBlock/DailyInlineButtons/LeaderboardsButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/QuickSessionButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/QuickInlineButtons/ContinueButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/QuickInlineButtons/NewButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow/SmallButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow/MediumButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/QuickSessionBlock/TitleDesc/MapSizeRow/LargeButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons/ContinueButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/EndlessBlock/EndlessInlineButtons/NewButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/PuzzleBlock/PuzzleButton,
		$Split/LeftColumn/Margin/NavStack/PuzzleNav/PuzzleBackButton,
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
	_rebuild_puzzle_list(puzzles)


func _rebuild_puzzle_list(puzzles: Array[Dictionary]) -> void:
	if _puzzle_list == null:
		return
	for child in _puzzle_list.get_children():
		child.queue_free()
	for puzzle in puzzles:
		var id := str(puzzle.get("id", ""))
		if id.is_empty():
			continue
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", -10)

		var button := Button.new()
		button.text = str(puzzle.get("title", id)).to_upper()
		button.flat = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_focus_color", Color(1, 1, 1, 1))
		button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.6))
		button.add_theme_color_override("font_hover_color", Color(0.5686275, 0.5176471, 0.47058824, 1))
		button.add_theme_font_size_override("font_size", 26)
		var empty := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("normal", empty)
		button.add_theme_stylebox_override("pressed", empty)
		button.add_theme_stylebox_override("hover", empty)
		button.add_theme_stylebox_override("disabled", empty)
		button.add_theme_stylebox_override("focus", empty)
		button.pressed.connect(_on_puzzle_selected.bind(id))
		if not button.mouse_entered.is_connected(_on_nav_button_mouse_entered):
			button.mouse_entered.connect(_on_nav_button_mouse_entered)

		var desc := Label.new()
		desc.text = str(puzzle.get("description", ""))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		desc.add_theme_constant_override("line_spacing", -5)
		desc.add_theme_font_size_override("font_size", 13)

		block.add_child(button)
		block.add_child(desc)
		_puzzle_list.add_child(block)


func _reset_mode_inline_ui() -> void:
	_close_leaderboard()
	if _daily_inline_buttons:
		_daily_inline_buttons.hide()
	if _daily_desc:
		_daily_desc.show()
	if _quick_inline_buttons:
		_quick_inline_buttons.hide()
	if _endless_inline_buttons:
		_endless_inline_buttons.hide()
	if _endless_desc:
		_endless_desc.show()
	_hide_map_size_row()


func _hide_map_size_row() -> void:
	_map_size_row.hide()
	_quick_session_desc.show()


func _sync_nav_input_filters(active: Control) -> void:
	for nav in [_name_nav, _root_nav, _play_nav, _tutorial_nav, _puzzle_nav, _code_nav, _settings_nav]:
		if nav == null:
			continue
		if nav == active:
			nav.mouse_filter = Control.MOUSE_FILTER_STOP
		else:
			nav.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _show_name_nav() -> void:
	_name_nav.show()
	_root_nav.hide()
	_play_nav.hide()
	_tutorial_nav.hide()
	_puzzle_nav.hide()
	_code_nav.hide()
	_settings_nav.hide()
	_reset_mode_inline_ui()
	_sync_nav_input_filters(_name_nav)
	_name_input.grab_focus()


func _show_root_nav() -> void:
	_name_nav.hide()
	_root_nav.show()
	_play_nav.hide()
	_tutorial_nav.hide()
	_puzzle_nav.hide()
	_code_nav.hide()
	_settings_nav.hide()
	_reset_mode_inline_ui()
	_sync_nav_input_filters(_root_nav)


func _show_play_nav() -> void:
	GameFeedback.play_open_popup()
	RunSave.clear_expired_daily_save()
	_name_nav.hide()
	_root_nav.hide()
	_play_nav.show()
	_tutorial_nav.hide()
	_puzzle_nav.hide()
	_code_nav.hide()
	_settings_nav.hide()
	_reset_mode_inline_ui()
	_sync_nav_input_filters(_play_nav)


func _show_tutorial_nav() -> void:
	GameFeedback.play_open_popup()
	_name_nav.hide()
	_root_nav.hide()
	_play_nav.hide()
	_tutorial_nav.show()
	_puzzle_nav.hide()
	_code_nav.hide()
	_settings_nav.hide()
	_reset_mode_inline_ui()
	_sync_nav_input_filters(_tutorial_nav)


func _show_puzzle_nav() -> void:
	GameFeedback.play_open_popup()
	_name_nav.hide()
	_root_nav.hide()
	_play_nav.hide()
	_tutorial_nav.hide()
	_puzzle_nav.show()
	_code_nav.hide()
	_settings_nav.hide()
	_reset_mode_inline_ui()
	_sync_nav_input_filters(_puzzle_nav)


func _show_code_nav() -> void:
	GameFeedback.play_open_popup()
	_name_nav.hide()
	_root_nav.hide()
	_play_nav.hide()
	_tutorial_nav.hide()
	_puzzle_nav.hide()
	_code_nav.show()
	_settings_nav.hide()
	_reset_mode_inline_ui()
	_sync_nav_input_filters(_code_nav)
	_code_status.text = ""
	_code_input.grab_focus()


func _show_settings_nav() -> void:
	GameFeedback.play_open_popup()
	_name_nav.hide()
	_root_nav.hide()
	_play_nav.hide()
	_tutorial_nav.hide()
	_puzzle_nav.hide()
	_code_nav.hide()
	_settings_nav.show()
	_reset_mode_inline_ui()
	_sync_nav_input_filters(_settings_nav)
	if _settings_panel:
		_settings_panel.apply_sidebar_style()
		_settings_panel.reset_to_root()
		_settings_panel.refresh()


func _on_name_accept_pressed() -> void:
	GameFeedback.play_click_button()
	_try_accept_player_name(_name_input.text)


func _on_name_submitted(text: String) -> void:
	_try_accept_player_name(text)


func _try_accept_player_name(text: String) -> void:
	var new_name := text.strip_edges()
	if new_name.is_empty():
		_name_input.grab_focus()
		return
	GameSettings.set_player_name(new_name)
	_show_root_nav()


func _on_play_pressed() -> void:
	GameFeedback.play_click_button()
	_show_play_nav()


func _on_tutorial_pressed() -> void:
	GameFeedback.play_click_button()
	_show_tutorial_nav()


func _on_tutorial_landscapes_pressed() -> void:
	_start_tutorial_part("landscapes")


func _on_tutorial_scoring_pressed() -> void:
	_start_tutorial_part("boosters")


func _on_tutorial_animals_pressed() -> void:
	_start_tutorial_part("animals")


func _on_tutorial_quests_pressed() -> void:
	_start_tutorial_part("quests")


func _start_tutorial_part(part_id: String) -> void:
	GameFeedback.play_click_button()
	GameSession.begin_tutorial_run(part_id)
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
	if _puzzle_nav.visible:
		_show_play_nav()
		return
	GameFeedback.play_close_popup()
	_show_root_nav()


func _on_exit_pressed() -> void:
	GameFeedback.play_click_button()
	get_tree().quit()


func _close_leaderboard() -> void:
	if _leaderboard != null and _leaderboard.is_open():
		_leaderboard.close()


func _on_daily_pressed() -> void:
	GameFeedback.play_click_button()
	RunSave.clear_expired_daily_save()
	var showing := not _daily_inline_buttons.visible
	_daily_inline_buttons.visible = showing
	_daily_desc.visible = not showing
	if not showing:
		_close_leaderboard()


func _on_daily_play_pressed() -> void:
	GameFeedback.play_click_button()
	RunSave.clear_expired_daily_save()
	if RunSave.has_save(GameSession.GameMode.DAILY):
		var state := RunSave.load_save(GameSession.GameMode.DAILY)
		if not state.is_empty() and RunSave.is_daily_save_valid(state):
			_continue_from_state(state, GameSession.GameMode.DAILY)
			return
		RunSave.clear_save(GameSession.GameMode.DAILY)
	GameSession.begin_daily_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_daily_leaderboards_pressed() -> void:
	GameFeedback.play_click_button()
	if _leaderboard == null:
		return
	if _leaderboard.is_open():
		_leaderboard.close()
	else:
		_leaderboard.open()


func _on_quick_session_pressed() -> void:
	GameFeedback.play_click_button()
	if RunSave.has_save(GameSession.GameMode.NORMAL):
		var showing := not _quick_inline_buttons.visible
		_quick_inline_buttons.visible = showing
		_map_size_row.hide()
		_quick_session_desc.visible = not showing
		return

	_quick_inline_buttons.hide()
	_map_size_row.visible = not _map_size_row.visible
	_quick_session_desc.visible = not _map_size_row.visible


func _on_quick_continue_pressed() -> void:
	GameFeedback.play_click_button()
	var state := RunSave.load_save(GameSession.GameMode.NORMAL)
	if state.is_empty():
		GameSession.begin_normal_run(GameSession.MapSize.MEDIUM)
		get_tree().change_scene_to_file(GAME_SCENE)
		return
	_continue_from_state(state, GameSession.GameMode.NORMAL)
	if _quick_inline_buttons:
		_quick_inline_buttons.hide()


func _on_quick_new_pressed() -> void:
	GameFeedback.play_click_button()
	RunSave.clear_save(GameSession.GameMode.NORMAL)
	if _quick_inline_buttons:
		_quick_inline_buttons.hide()
	_map_size_row.show()
	_quick_session_desc.hide()


func _on_map_size_small_pressed() -> void:
	_start_normal_run(GameSession.MapSize.SMALL)


func _on_map_size_medium_pressed() -> void:
	_start_normal_run(GameSession.MapSize.MEDIUM)


func _on_map_size_large_pressed() -> void:
	_start_normal_run(GameSession.MapSize.LARGE)


func _start_normal_run(size: GameSession.MapSize) -> void:
	GameFeedback.play_click_button()
	RunSave.clear_save(GameSession.GameMode.NORMAL)
	GameSession.begin_normal_run(size)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_endless_pressed() -> void:
	GameFeedback.play_click_button()
	if RunSave.has_save(GameSession.GameMode.ENDLESS):
		_endless_inline_buttons.visible = not _endless_inline_buttons.visible
		_endless_desc.visible = not _endless_inline_buttons.visible
		return

	GameSession.begin_endless_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_endless_continue_pressed() -> void:
	GameFeedback.play_click_button()
	var state := RunSave.load_save(GameSession.GameMode.ENDLESS)
	if state.is_empty():
		GameSession.begin_endless_run()
		get_tree().change_scene_to_file(GAME_SCENE)
		return
	_continue_from_state(state, GameSession.GameMode.ENDLESS)
	if _endless_inline_buttons:
		_endless_inline_buttons.hide()


func _on_endless_new_pressed() -> void:
	GameFeedback.play_click_button()
	RunSave.clear_save(GameSession.GameMode.ENDLESS)
	if _endless_inline_buttons:
		_endless_inline_buttons.hide()
	if _endless_desc:
		_endless_desc.show()
	GameSession.begin_endless_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _continue_from_state(state: Dictionary, mode: GameSession.GameMode) -> void:
	RunSave.set_pending_state(state)

	GameSession.game_mode = mode
	GameSession.map_size = int(state.get("map_size", GameSession.MapSize.MEDIUM)) as GameSession.MapSize
	GameSession.ring_count = int(state.get("ring_count", GameSession.ring_count))
	GameSession.checkpoint = int(state.get("checkpoint", GameSession.checkpoint))
	GameSession.checkpoint_multiplier = float(state.get("checkpoint_multiplier", GameSession.checkpoint_multiplier))
	GameSession.checkpoint_flat_increase = int(state.get("checkpoint_flat_increase", GameSession.checkpoint_flat_increase))
	GameSession.map_growth_enabled = bool(state.get("map_growth_enabled", GameSession.map_growth_enabled))
	GameSession.checkpoint_targets.clear()
	GameSession.clear_challenge()
	GameSession.clear_puzzle()

	var run_seed_value := int(state.get("run_seed", 1))
	GameSession.begin_run(run_seed_value, true)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_puzzle_pressed() -> void:
	GameFeedback.play_click_button()
	if _puzzle_ids.is_empty():
		return
	_show_puzzle_nav()


func _on_puzzle_selected(id: String) -> void:
	GameFeedback.play_click_button()
	if id.is_empty():
		return
	if not GameSession.begin_puzzle_run(id):
		return
	get_tree().change_scene_to_file(GAME_SCENE)


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
