extends Control
class_name SettingsPanel

enum View { ROOT, PLAYER, GRAPHICS, AUDIO }

@onready var _root_view: VBoxContainer = $Content/RootView
@onready var _player_view: VBoxContainer = $Content/PlayerView
@onready var _graphics_scroll: ScrollContainer = $Content/GraphicsScroll
@onready var _graphics_view: VBoxContainer = $Content/GraphicsScroll/GraphicsView
@onready var _audio_view: VBoxContainer = $Content/AudioView
@onready var _player_button: Button = $Content/RootView/PlayerBlock/PlayerButton
@onready var _graphics_button: Button = $Content/RootView/GraphicsBlock/GraphicsButton
@onready var _audio_button: Button = $Content/RootView/AudioBlock/AudioButton
@onready var _player_desc: Label = $Content/RootView/PlayerBlock/PlayerDesc
@onready var _graphics_desc: Label = $Content/RootView/GraphicsBlock/GraphicsDesc
@onready var _audio_desc: Label = $Content/RootView/AudioBlock/AudioDesc
@onready var _name_label: Label = $Content/PlayerView/NameLabel
@onready var _name_input: LineEdit = $Content/PlayerView/NameInput
@onready var _theme_label: Label = $Content/PlayerView/ThemeLabel
@onready var _theme_option: OptionButton = $Content/PlayerView/ThemeOption
@onready var _language_label: Label = $Content/PlayerView/LanguageLabel
@onready var _language_option: OptionButton = $Content/PlayerView/LanguageOption
@onready var _master_label: Label = $Content/AudioView/MasterHeader/MasterLabel
@onready var _master_value: Label = $Content/AudioView/MasterHeader/MasterValue
@onready var _music_label: Label = $Content/AudioView/MusicHeader/MusicLabel
@onready var _music_value: Label = $Content/AudioView/MusicHeader/MusicValue
@onready var _effects_label: Label = $Content/AudioView/EffectsHeader/EffectsLabel
@onready var _effects_value: Label = $Content/AudioView/EffectsHeader/EffectsValue
@onready var _master_slider: HSlider = $Content/AudioView/MasterSlider
@onready var _music_slider: HSlider = $Content/AudioView/MusicSlider
@onready var _effects_slider: HSlider = $Content/AudioView/EffectsSlider
@onready var _desktop_block: VBoxContainer = $Content/GraphicsScroll/GraphicsView/DesktopBlock
@onready var _display_label: Label = $Content/GraphicsScroll/GraphicsView/DesktopBlock/DisplayLabel
@onready var _display_option: OptionButton = $Content/GraphicsScroll/GraphicsView/DesktopBlock/DisplayOption
@onready var _fps_label: Label = $Content/GraphicsScroll/GraphicsView/DesktopBlock/FpsLabel
@onready var _fps_option: OptionButton = $Content/GraphicsScroll/GraphicsView/DesktopBlock/FpsOption
@onready var _ui_scale_label: Label = $Content/GraphicsScroll/GraphicsView/UiScaleHeader/UiScaleLabel
@onready var _ui_scale_value: Label = $Content/GraphicsScroll/GraphicsView/UiScaleHeader/UiScaleValue
@onready var _ui_scale_slider: HSlider = $Content/GraphicsScroll/GraphicsView/UiScaleSlider
@onready var _preset_label: Label = $Content/GraphicsScroll/GraphicsView/PresetLabel
@onready var _animal_label: Label = $Content/GraphicsScroll/GraphicsView/AnimalLabel
@onready var _msaa_label: Label = $Content/GraphicsScroll/GraphicsView/MsaaLabel
@onready var _preset_low: Button = $Content/GraphicsScroll/GraphicsView/PresetRow/LowButton
@onready var _preset_medium: Button = $Content/GraphicsScroll/GraphicsView/PresetRow/MediumButton
@onready var _preset_high: Button = $Content/GraphicsScroll/GraphicsView/PresetRow/HighButton
@onready var _preset_custom: Button = $Content/GraphicsScroll/GraphicsView/PresetRow/CustomButton
@onready var _wind_check: CheckButton = $Content/GraphicsScroll/GraphicsView/WindCheck
@onready var _clouds_check: CheckButton = $Content/GraphicsScroll/GraphicsView/CloudsCheck
@onready var _animal_option: OptionButton = $Content/GraphicsScroll/GraphicsView/AnimalOption
@onready var _msaa_option: OptionButton = $Content/GraphicsScroll/GraphicsView/MsaaOption
@onready var _quality_divider: ColorRect = $Content/GraphicsScroll/GraphicsView/QualityDivider

var _view: View = View.ROOT
var _web_text
var _committing_name: bool = false


func _ready() -> void:
	_setup_options()
	if _name_input:
		_name_input.max_length = GameSettings.PLAYER_NAME_MAX_LENGTH
	_setup_web_text()
	_build_theme_picker()
	_build_language_picker()
	_wire_signals()
	_apply_desktop_visibility()
	_show_view(View.ROOT)
	apply_sidebar_style()
	UiTheme.bind_node(self, apply_sidebar_style)
	refresh()
	apply_locale()
	_bind_scroll_fit()
	if GameSettings != null and not GameSettings.settings_changed.is_connected(apply_locale):
		GameSettings.settings_changed.connect(apply_locale)


func _bind_scroll_fit() -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return
	if not scroll.resized.is_connected(_fit_to_scroll_parent):
		scroll.resized.connect(_fit_to_scroll_parent)
	call_deferred("_fit_to_scroll_parent")


func _fit_to_scroll_parent() -> void:
	var scroll := get_parent() as ScrollContainer
	if scroll == null:
		return
	var target := maxf(scroll.size.y, 1.0)
	if not is_equal_approx(custom_minimum_size.y, target):
		custom_minimum_size.y = target


func refresh() -> void:
	_refresh_from_settings()


func apply_locale() -> void:
	if _player_button:
		_player_button.text = Loc.ui("settings.player")
	if _player_desc:
		_player_desc.text = Loc.ui("settings.player_desc")
	if _graphics_button:
		_graphics_button.text = Loc.ui("settings.graphics")
	if _graphics_desc:
		_graphics_desc.text = Loc.ui("settings.graphics_desc")
	if _audio_button:
		_audio_button.text = Loc.ui("settings.audio")
	if _audio_desc:
		_audio_desc.text = Loc.ui("settings.audio_desc")
	if _name_label:
		_name_label.text = Loc.ui("settings.player_name")
	if _name_input:
		_name_input.placeholder_text = Loc.ui("settings.your_name")
	if _theme_label:
		_theme_label.text = Loc.ui("settings.theme")
	if _language_label:
		_language_label.text = Loc.ui("settings.language")
	if _preset_label:
		_preset_label.text = Loc.ui("settings.quality")
	if _display_label:
		_display_label.text = Loc.ui("settings.display")
	if _fps_label:
		_fps_label.text = Loc.ui("settings.fps_cap")
	if _ui_scale_label:
		_ui_scale_label.text = Loc.ui("settings.ui_scale")
	if _preset_low:
		_preset_low.text = Loc.ui("settings.low")
	if _preset_medium:
		_preset_medium.text = Loc.ui("settings.medium")
	if _preset_high:
		_preset_high.text = Loc.ui("settings.high")
	if _preset_custom:
		_preset_custom.text = Loc.ui("settings.custom")
	if _wind_check:
		_wind_check.text = Loc.ui("settings.plant_sway")
	if _clouds_check:
		_clouds_check.text = Loc.ui("settings.cloud_shadows")
	if _animal_label:
		_animal_label.text = Loc.ui("settings.animal_motion")
	if _msaa_label:
		_msaa_label.text = Loc.ui("settings.msaa")
	if _master_label:
		_master_label.text = Loc.ui("settings.master")
	if _music_label:
		_music_label.text = Loc.ui("settings.music")
	if _effects_label:
		_effects_label.text = Loc.ui("settings.effects")
	GameSettings.begin_ui_sync()
	_setup_options()
	_build_theme_picker()
	GameSettings.end_ui_sync()
	_update_preset_buttons()


func reset_to_root() -> void:
	_show_view(View.ROOT)


## Returns true if a submenu was closed (caller should stay on Settings).
func handle_back() -> bool:
	if _view == View.ROOT:
		return false
	if _view == View.PLAYER:
		_commit_player_name()
	GameFeedback.play_close_popup()
	_show_view(View.ROOT)
	OverlayFocus.grab_first_button(_root_view)
	return true


func apply_sidebar_style() -> void:
	for label in [
		_master_label,
		_master_value,
		_music_label,
		_music_value,
		_effects_label,
		_effects_value,
		_display_label,
		_fps_label,
		_ui_scale_label,
		_ui_scale_value,
		_preset_label,
		_animal_label,
		_msaa_label,
		_name_label,
		_theme_label,
		_language_label,
	]:
		UiTheme.style_subtitle_label(label)

	UiTheme.style_nav_button(_player_button, 26)
	UiTheme.style_nav_button(_graphics_button, 26)
	UiTheme.style_nav_button(_audio_button, 26)
	if _player_button:
		_player_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _graphics_button:
		_graphics_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _audio_button:
		_audio_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for desc in [_player_desc, _graphics_desc, _audio_desc]:
		UiTheme.style_label(desc, true)
	UiTheme.style_line_edit(_name_input)

	for button in [_preset_low, _preset_medium, _preset_high, _preset_custom]:
		if button:
			button.custom_minimum_size = Vector2(0, 28)
		UiTheme.style_chip_button(button, 12.0, 6.0)

	for option in [_animal_option, _msaa_option, _language_option, _display_option, _fps_option]:
		if option:
			option.custom_minimum_size = Vector2(0, 28)
		UiTheme.style_option_button(option, 12.0, 6.0)

	UiTheme.style_check_button(_wind_check, UiTheme.SUBTITLE_FONT_SIZE)
	UiTheme.style_check_button(_clouds_check, UiTheme.SUBTITLE_FONT_SIZE)
	UiTheme.style_slider(_master_slider)
	UiTheme.style_slider(_music_slider)
	UiTheme.style_slider(_effects_slider)
	UiTheme.style_slider(_ui_scale_slider)
	if _quality_divider:
		_quality_divider.color = UiTheme.text
	_style_theme_option()


func _build_theme_picker() -> void:
	if _theme_option == null:
		return
	_theme_option.clear()
	_theme_option.fit_to_longest_item = true
	_theme_option.expand_icon = false
	_theme_option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for id in UiTheme.THEMES:
		var theme_id := str(id)
		_theme_option.add_icon_item(UiTheme.theme_strip_icon(theme_id), UiTheme.theme_display_name(theme_id))
		_theme_option.set_item_metadata(_theme_option.item_count - 1, theme_id)
	_select_theme_option(UiTheme.theme_id)


func _build_language_picker() -> void:
	if _language_option == null:
		return
	_language_option.clear()
	_language_option.fit_to_longest_item = true
	_language_option.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_language_option.add_item("English", 0)
	_language_option.set_item_metadata(0, Loc.ENG)
	_language_option.add_item("Deutsch", 1)
	_language_option.set_item_metadata(1, Loc.GER)
	_select_language_option(GameSettings.content_locale)


func _select_language_option(locale: String) -> void:
	if _language_option == null:
		return
	var wanted: String = Loc.normalize_locale(locale)
	for i in _language_option.item_count:
		if str(_language_option.get_item_metadata(i)) == wanted:
			_language_option.select(i)
			return
	if _language_option.item_count > 0:
		_language_option.select(0)


func _on_language_option_selected(index: int) -> void:
	if GameSettings.is_ui_syncing() or _language_option == null:
		return
	var locale := str(_language_option.get_item_metadata(index))
	if locale.is_empty() or locale == GameSettings.content_locale:
		return
	GameFeedback.play_click_button()
	GameSettings.set_content_locale(locale)


func _style_theme_option() -> void:
	if _theme_option == null:
		return
	_theme_option.custom_minimum_size = Vector2(0, 28)
	UiTheme.style_option_button(_theme_option, 12.0, 6.0, UiTheme.THEME_STRIP_WIDTH)
	_select_theme_option(UiTheme.theme_id)


func _select_theme_option(id: String) -> void:
	if _theme_option == null:
		return
	for i in _theme_option.item_count:
		if str(_theme_option.get_item_metadata(i)) == id:
			_theme_option.select(i)
			return
	if _theme_option.item_count > 0:
		_theme_option.select(0)


func _on_theme_option_selected(index: int) -> void:
	if GameSettings.is_ui_syncing() or _theme_option == null:
		return
	var id := str(_theme_option.get_item_metadata(index))
	if id.is_empty() or id == UiTheme.theme_id:
		return
	GameFeedback.play_click_button()
	UiTheme.set_theme_id(id)


func _setup_options() -> void:
	var animal_id := _animal_option.get_selected_id() if _animal_option.item_count > 0 else int(GameSettings.animal_motion)
	var msaa_id := _msaa_option.get_selected_id() if _msaa_option.item_count > 0 else int(GameSettings.msaa_mode)
	var display_id := _display_option.get_selected_id() if _display_option.item_count > 0 else int(GameSettings.window_mode)
	var fps_id := _fps_option.get_selected_id() if _fps_option.item_count > 0 else GameSettings.fps_cap
	_animal_option.clear()
	_animal_option.add_item(Loc.ui("settings.frozen"), GameSettings.AnimalMotion.FROZEN)
	_animal_option.add_item(Loc.ui("settings.idle_special"), GameSettings.AnimalMotion.IDLE_SPECIAL)
	_animal_option.add_item(Loc.ui("settings.full_roam"), GameSettings.AnimalMotion.FULL_ROAM)
	_select_option_by_id(_animal_option, animal_id)

	_msaa_option.clear()
	_msaa_option.add_item(Loc.ui("settings.off"), GameSettings.MsaaMode.OFF)
	_msaa_option.add_item("2×", GameSettings.MsaaMode.X2)
	_msaa_option.add_item("4×", GameSettings.MsaaMode.X4)
	_select_option_by_id(_msaa_option, msaa_id)

	_display_option.clear()
	_display_option.add_item(Loc.ui("settings.fullscreen"), GameSettings.WindowMode.FULLSCREEN)
	_display_option.add_item(Loc.ui("settings.windowed"), GameSettings.WindowMode.WINDOWED)
	_display_option.add_item(Loc.ui("settings.fullscreen_windowed"), GameSettings.WindowMode.FULLSCREEN_WINDOWED)
	_select_option_by_id(_display_option, display_id)

	_fps_option.clear()
	for cap in GameSettings.FPS_CAP_OPTIONS:
		var label := Loc.ui("settings.uncapped") if cap == 0 else str(cap)
		_fps_option.add_item(label, cap)
	_select_option_by_id(_fps_option, fps_id)


func _wire_signals() -> void:
	_player_button.pressed.connect(_on_player_pressed)
	_graphics_button.pressed.connect(_on_graphics_pressed)
	_audio_button.pressed.connect(_on_audio_pressed)
	_name_input.text_submitted.connect(_on_name_submitted)
	_name_input.focus_exited.connect(_on_name_focus_exited)
	_preset_low.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.LOW))
	_preset_medium.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.MEDIUM))
	_preset_high.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.HIGH))
	_preset_custom.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.CUSTOM))
	_wind_check.toggled.connect(_on_wind_toggled)
	_clouds_check.toggled.connect(_on_clouds_toggled)
	_animal_option.item_selected.connect(_on_animal_selected)
	_msaa_option.item_selected.connect(_on_msaa_selected)
	_display_option.item_selected.connect(_on_display_selected)
	_fps_option.item_selected.connect(_on_fps_selected)
	_theme_option.item_selected.connect(_on_theme_option_selected)
	_language_option.item_selected.connect(_on_language_option_selected)
	_master_slider.value_changed.connect(_on_master_volume_changed)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_effects_slider.value_changed.connect(_on_sfx_volume_changed)
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	for control in [
		_player_button,
		_graphics_button,
		_audio_button,
		_preset_low,
		_preset_medium,
		_preset_high,
		_preset_custom,
		_wind_check,
		_clouds_check,
		_animal_option,
		_msaa_option,
		_display_option,
		_fps_option,
		_theme_option,
		_language_option,
		_master_slider,
		_music_slider,
		_effects_slider,
		_ui_scale_slider,
	]:
		if control != null and not control.mouse_entered.is_connected(_on_control_mouse_entered):
			control.mouse_entered.connect(_on_control_mouse_entered)
	WebInstantButton.wire_many([
		_player_button,
		_graphics_button,
		_audio_button,
		_preset_low,
		_preset_medium,
		_preset_high,
		_preset_custom,
		_wind_check,
		_clouds_check,
		_animal_option,
		_msaa_option,
		_display_option,
		_fps_option,
		_theme_option,
		_language_option,
	])


func _on_control_mouse_entered() -> void:
	if WebInstantButton.skip_hover():
		return
	GameFeedback.play_hover_button()


func _show_view(view: View) -> void:
	_view = view
	_root_view.visible = view == View.ROOT
	_player_view.visible = view == View.PLAYER
	_graphics_scroll.visible = view == View.GRAPHICS
	_audio_view.visible = view == View.AUDIO
	# Title label is intentionally hidden.
	InputScheme.clear_stuck_gui_hover_deferred(self)


func _apply_desktop_visibility() -> void:
	if _desktop_block == null:
		return
	_desktop_block.visible = GameSettings.is_native_desktop()


func _refresh_from_settings() -> void:
	GameSettings.begin_ui_sync()
	_fill_name_input()
	_master_slider.value = GameSettings.master_volume
	_music_slider.value = GameSettings.music_volume
	_effects_slider.value = GameSettings.sfx_volume
	_ui_scale_slider.value = GameSettings.ui_scale
	_update_volume_labels()
	_update_scale_label()
	_wind_check.button_pressed = GameSettings.wind_enabled
	_clouds_check.button_pressed = GameSettings.clouds_enabled
	_select_option_by_id(_animal_option, int(GameSettings.animal_motion))
	_select_option_by_id(_msaa_option, int(GameSettings.msaa_mode))
	_select_option_by_id(_display_option, int(GameSettings.window_mode))
	_select_option_by_id(_fps_option, GameSettings.fps_cap)
	_select_theme_option(UiTheme.theme_id)
	_select_language_option(GameSettings.content_locale)
	GameSettings.end_ui_sync()
	_update_preset_buttons()
	_apply_desktop_visibility()


func _volume_display(linear: float) -> String:
	return str(roundi(clampf(linear, 0.0, 1.0) * 100.0))


func _update_volume_labels() -> void:
	_master_value.text = _volume_display(_master_slider.value)
	_music_value.text = _volume_display(_music_slider.value)
	_effects_value.text = _volume_display(_effects_slider.value)


func _update_scale_label() -> void:
	if _ui_scale_value:
		_ui_scale_value.text = str(roundi(clampf(_ui_scale_slider.value, GameSettings.UI_SCALE_MIN, GameSettings.UI_SCALE_MAX) * 100.0))


func _select_option_by_id(option: OptionButton, id: int) -> void:
	if option == null:
		return
	for i in option.item_count:
		if option.get_item_id(i) == id:
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)


func _update_preset_buttons() -> void:
	_preset_low.button_pressed = GameSettings.preset == GameSettings.Preset.LOW
	_preset_medium.button_pressed = GameSettings.preset == GameSettings.Preset.MEDIUM
	_preset_high.button_pressed = GameSettings.preset == GameSettings.Preset.HIGH
	_preset_custom.button_pressed = GameSettings.preset == GameSettings.Preset.CUSTOM


func _on_player_pressed() -> void:
	GameFeedback.play_click_button()
	GameFeedback.play_open_popup()
	_fill_name_input()
	_show_view(View.PLAYER)
	OverlayFocus.grab_control(_name_input)


func _fill_name_input() -> void:
	if _name_input == null:
		return
	_name_input.text = GameSettings.player_name


func _commit_player_name() -> void:
	if _name_input == null or _committing_name:
		return
	_committing_name = true
	var new_name := _name_input.text.strip_edges()
	if new_name.is_empty():
		_name_input.text = GameSettings.player_name
		_committing_name = false
		return
	GameSettings.set_player_name(new_name)
	_name_input.text = GameSettings.player_name
	_committing_name = false


func _on_name_submitted(_text: String) -> void:
	_commit_player_name()


func _on_name_focus_exited() -> void:
	_commit_player_name()


func _setup_web_text() -> void:
	if not WebTextPrompt.is_needed():
		return
	_web_text = WebTextPrompt.new()
	_web_text.setup()
	_web_text.bind_line_edit(_name_input, Loc.ui("settings.your_name"))


func _on_graphics_pressed() -> void:
	GameFeedback.play_click_button()
	GameFeedback.play_open_popup()
	_show_view(View.GRAPHICS)
	OverlayFocus.grab_button_row(_preset_low.get_parent() if _preset_low else null)


func _on_audio_pressed() -> void:
	GameFeedback.play_click_button()
	GameFeedback.play_open_popup()
	_show_view(View.AUDIO)
	OverlayFocus.grab_first_button(_audio_view)


func _on_preset_pressed(preset: GameSettings.Preset) -> void:
	GameFeedback.play_click_button()
	GameSettings.apply_preset(preset)
	_refresh_from_settings()


func _on_wind_toggled(pressed: bool) -> void:
	if GameSettings.is_ui_syncing():
		return
	GameFeedback.play_click_button()
	GameSettings.set_wind_enabled(pressed)
	_update_preset_buttons()


func _on_clouds_toggled(pressed: bool) -> void:
	if GameSettings.is_ui_syncing():
		return
	GameFeedback.play_click_button()
	GameSettings.set_clouds_enabled(pressed)
	_update_preset_buttons()


func _on_animal_selected(index: int) -> void:
	if GameSettings.is_ui_syncing():
		return
	GameFeedback.play_click_button()
	var id := _animal_option.get_item_id(index)
	GameSettings.set_animal_motion(id as GameSettings.AnimalMotion)
	_update_preset_buttons()


func _on_msaa_selected(index: int) -> void:
	if GameSettings.is_ui_syncing():
		return
	GameFeedback.play_click_button()
	var id := _msaa_option.get_item_id(index)
	GameSettings.set_msaa_mode(id as GameSettings.MsaaMode)
	_update_preset_buttons()


func _on_display_selected(index: int) -> void:
	if GameSettings.is_ui_syncing():
		return
	GameFeedback.play_click_button()
	var id := _display_option.get_item_id(index)
	GameSettings.set_window_mode(id as GameSettings.WindowMode)


func _on_fps_selected(index: int) -> void:
	if GameSettings.is_ui_syncing():
		return
	GameFeedback.play_click_button()
	GameSettings.set_fps_cap(_fps_option.get_item_id(index))


func _on_master_volume_changed(value: float) -> void:
	_master_value.text = _volume_display(value)
	if GameSettings.is_ui_syncing():
		return
	GameSettings.set_master_volume(value)


func _on_music_volume_changed(value: float) -> void:
	_music_value.text = _volume_display(value)
	if GameSettings.is_ui_syncing():
		return
	GameSettings.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	_effects_value.text = _volume_display(value)
	if GameSettings.is_ui_syncing():
		return
	GameSettings.set_sfx_volume(value)


func _on_ui_scale_changed(value: float) -> void:
	_update_scale_label()
	if GameSettings.is_ui_syncing():
		return
	GameSettings.set_ui_scale(value)
