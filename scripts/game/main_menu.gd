extends Control

const GAME_SCENE := "res://scenes/Refactored_Main.tscn"
const BG_PATH := "res://assets/ui/main_menu_bg.png"

var COLOR_CREAM := Color.html("#F4DFCA")

@onready var _bg_fallback: ColorRect = $BackgroundFallback
@onready var _bg_image: TextureRect = $BackgroundImage
@onready var _root_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/RootNav
@onready var _play_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/PlayNav
@onready var _code_nav: VBoxContainer = $Split/LeftColumn/Margin/NavStack/CodeNav
@onready var _settings_host: Control = $Split/RightColumn/SettingsHost
@onready var _settings_panel: SettingsPanel = $Split/RightColumn/SettingsHost/Margin/SettingsPanel
@onready var _map_size_option: OptionButton = $Split/LeftColumn/Margin/NavStack/PlayNav/NormalBlock/MapSizeOption
@onready var _puzzle_option: OptionButton = $Split/LeftColumn/Margin/NavStack/PlayNav/PuzzleBlock/PuzzleOption
@onready var _puzzle_button: Button = $Split/LeftColumn/Margin/NavStack/PlayNav/PuzzleBlock/PuzzleButton
@onready var _code_input: LineEdit = $Split/LeftColumn/Margin/NavStack/CodeNav/CodeInput
@onready var _code_status: Label = $Split/LeftColumn/Margin/NavStack/CodeNav/CodeStatus

var _puzzle_ids: Array[String] = []


func _ready() -> void:
	_setup_background()
	_setup_map_size_option()
	_setup_puzzle_option()
	_setup_button_hover_sounds()
	_show_root_nav()
	_settings_host.hide()
	_code_status.text = ""


func _setup_button_hover_sounds() -> void:
	var buttons: Array[Control] = [
		$Split/LeftColumn/Margin/NavStack/RootNav/PlayButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/TutorialButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/EnterCodeButton,
		$Split/LeftColumn/Margin/NavStack/RootNav/SettingsButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/BackButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/DailyButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/NormalBlock/NormalButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/EndlessButton,
		$Split/LeftColumn/Margin/NavStack/PlayNav/PuzzleBlock/PuzzleButton,
		$Split/LeftColumn/Margin/NavStack/CodeNav/CodeBackButton,
		$Split/LeftColumn/Margin/NavStack/CodeNav/StartCodeButton,
	]
	for button in buttons:
		if button != null and not button.mouse_entered.is_connected(_on_nav_button_mouse_entered):
			button.mouse_entered.connect(_on_nav_button_mouse_entered)


func _on_nav_button_mouse_entered() -> void:
	GameFeedback.play_hover_button()


func _setup_background() -> void:
	_bg_fallback.color = COLOR_CREAM
	if ResourceLoader.exists(BG_PATH):
		var tex := load(BG_PATH) as Texture2D
		if tex != null:
			_bg_image.texture = tex
			_bg_image.show()
			return
	_bg_image.hide()


func _setup_map_size_option() -> void:
	_map_size_option.clear()
	_map_size_option.add_item("Small", GameSession.MapSize.SMALL)
	_map_size_option.add_item("Medium", GameSession.MapSize.MEDIUM)
	_map_size_option.add_item("Large", GameSession.MapSize.LARGE)
	_map_size_option.select(1)


func _setup_puzzle_option() -> void:
	_puzzle_option.clear()
	_puzzle_ids.clear()
	var puzzles: Array[Dictionary] = GameSession.list_puzzles()
	for i in puzzles.size():
		var puzzle: Dictionary = puzzles[i]
		var id := str(puzzle.get("id", ""))
		var title := str(puzzle.get("title", id))
		_puzzle_ids.append(id)
		_puzzle_option.add_item(title, i)
	if _puzzle_ids.is_empty():
		_puzzle_button.disabled = true
		_puzzle_option.disabled = true
		_puzzle_option.add_item("No puzzles found", 0)
	else:
		_puzzle_button.disabled = false
		_puzzle_option.disabled = false
		_puzzle_option.select(0)


func _show_root_nav() -> void:
	_root_nav.show()
	_play_nav.hide()
	_code_nav.hide()


func _show_play_nav() -> void:
	GameFeedback.play_open_popup()
	_root_nav.hide()
	_play_nav.show()
	_code_nav.hide()
	_settings_host.hide()


func _show_code_nav() -> void:
	GameFeedback.play_open_popup()
	_root_nav.hide()
	_play_nav.hide()
	_code_nav.show()
	_settings_host.hide()
	_code_status.text = ""
	_code_input.grab_focus()


func _on_play_pressed() -> void:
	GameFeedback.play_click_button()
	_show_play_nav()


func _on_tutorial_pressed() -> void:
	GameFeedback.play_click_button()
	GameSession.begin_tutorial_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_settings_pressed() -> void:
	GameFeedback.play_click_button()
	_show_root_nav()
	_settings_panel.refresh()
	GameFeedback.play_open_popup()
	_settings_host.show()


func _on_enter_code_pressed() -> void:
	GameFeedback.play_click_button()
	_show_code_nav()


func _on_back_pressed() -> void:
	GameFeedback.play_click_button()
	GameFeedback.play_close_popup()
	_settings_host.hide()
	_show_root_nav()


func _on_daily_pressed() -> void:
	GameFeedback.play_click_button()
	if _start_tutorial_if_needed():
		return
	GameSession.begin_daily_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_normal_pressed() -> void:
	GameFeedback.play_click_button()
	if _start_tutorial_if_needed():
		return
	var size := _map_size_option.get_selected_id() as GameSession.MapSize
	GameSession.begin_normal_run(size)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_endless_pressed() -> void:
	GameFeedback.play_click_button()
	if _start_tutorial_if_needed():
		return
	GameSession.begin_endless_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_puzzle_pressed() -> void:
	GameFeedback.play_click_button()
	if _puzzle_ids.is_empty():
		return
	var idx := _puzzle_option.get_selected_id()
	if idx < 0 or idx >= _puzzle_ids.size():
		idx = _puzzle_option.selected
	if idx < 0 or idx >= _puzzle_ids.size():
		return
	if not GameSession.begin_puzzle_run(_puzzle_ids[idx]):
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
