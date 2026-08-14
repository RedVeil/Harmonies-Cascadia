extends Control
class_name SettingsPanel

enum View { ROOT, GRAPHICS, AUDIO }

@onready var _root_view: VBoxContainer = $Content/RootView
@onready var _graphics_view: VBoxContainer = $Content/GraphicsView
@onready var _audio_view: VBoxContainer = $Content/AudioView
@onready var _graphics_button: Button = $Content/RootView/GraphicsButton
@onready var _audio_button: Button = $Content/RootView/AudioButton
@onready var _music_label: Label = $Content/AudioView/MusicHeader/MusicLabel
@onready var _music_value: Label = $Content/AudioView/MusicHeader/MusicValue
@onready var _effects_label: Label = $Content/AudioView/EffectsHeader/EffectsLabel
@onready var _effects_value: Label = $Content/AudioView/EffectsHeader/EffectsValue
@onready var _music_slider: HSlider = $Content/AudioView/MusicSlider
@onready var _effects_slider: HSlider = $Content/AudioView/EffectsSlider
@onready var _preset_label: Label = $Content/GraphicsView/PresetLabel
@onready var _animal_label: Label = $Content/GraphicsView/AnimalLabel
@onready var _msaa_label: Label = $Content/GraphicsView/MsaaLabel
@onready var _preset_low: Button = $Content/GraphicsView/PresetRow/LowButton
@onready var _preset_medium: Button = $Content/GraphicsView/PresetRow/MediumButton
@onready var _preset_high: Button = $Content/GraphicsView/PresetRow/HighButton
@onready var _preset_custom: Button = $Content/GraphicsView/PresetRow/CustomButton
@onready var _wind_check: CheckButton = $Content/GraphicsView/WindCheck
@onready var _clouds_check: CheckButton = $Content/GraphicsView/CloudsCheck
@onready var _animal_option: OptionButton = $Content/GraphicsView/AnimalOption
@onready var _msaa_option: OptionButton = $Content/GraphicsView/MsaaOption

var _view: View = View.ROOT
var _sidebar_styled: bool = false
var _chip_normal: StyleBoxFlat
var _chip_hover: StyleBoxFlat
var _chip_pressed: StyleBoxFlat
var _chip_disabled: StyleBoxFlat
var _nav_empty: StyleBoxEmpty


func _ready() -> void:
	_setup_options()
	_preset_custom.disabled = true
	_wire_signals()
	_show_view(View.ROOT)
	refresh()


func refresh() -> void:
	_refresh_from_settings()


func reset_to_root() -> void:
	_show_view(View.ROOT)


## Returns true if a submenu was closed (caller should stay on Settings).
func handle_back() -> bool:
	if _view == View.ROOT:
		return false
	GameFeedback.play_close_popup()
	_show_view(View.ROOT)
	return true


func apply_sidebar_style() -> void:
	if _sidebar_styled:
		return
	_sidebar_styled = true
	_build_chip_styles()
	_nav_empty = StyleBoxEmpty.new()

	var white := Color.WHITE
	var taupe := Color.html("#B4A594")
	var taupe_dark := Color.html("#918478")

	for label in [
		_music_label,
		_music_value,
		_effects_label,
		_effects_value,
		_preset_label,
		_animal_label,
		_msaa_label,
	]:
		if label:
			label.add_theme_color_override("font_color", white)

	_style_nav_button(_graphics_button)
	_style_nav_button(_audio_button)

	for button in [_preset_low, _preset_medium, _preset_high, _preset_custom]:
		_style_chip_button(button, taupe, taupe_dark)

	for option in [_animal_option, _msaa_option]:
		_style_chip_option(option, taupe, taupe_dark)

	for check in [_wind_check, _clouds_check]:
		if check == null:
			continue
		check.add_theme_color_override("font_color", white)
		check.add_theme_color_override("font_pressed_color", white)
		check.add_theme_color_override("font_hover_color", taupe_dark)
		check.add_theme_color_override("font_focus_color", white)
		check.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))

	_style_sidebar_slider(_music_slider, taupe, taupe_dark)
	_style_sidebar_slider(_effects_slider, taupe, taupe_dark)


func _style_nav_button(button: Button) -> void:
	if button == null:
		return
	var taupe_dark := Color.html("#918478")
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", taupe_dark)
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0.6))
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _nav_empty)


func _style_sidebar_slider(slider: HSlider, taupe: Color, taupe_dark: Color) -> void:
	if slider == null:
		return
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color.WHITE
	grabber.set_corner_radius_all(4)
	grabber.content_margin_left = 6.0
	grabber.content_margin_top = 6.0
	grabber.content_margin_right = 6.0
	grabber.content_margin_bottom = 6.0

	var grabber_hl := grabber.duplicate() as StyleBoxFlat
	grabber_hl.bg_color = taupe_dark

	var slider_style := StyleBoxFlat.new()
	slider_style.bg_color = Color(1, 1, 1, 0.35)
	slider_style.set_corner_radius_all(2)
	slider_style.content_margin_top = 4.0
	slider_style.content_margin_bottom = 4.0

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.WHITE
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 4.0
	fill.content_margin_bottom = 4.0

	slider.add_theme_stylebox_override("slider", slider_style)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	slider.add_theme_color_override("grabber_font_color", taupe)


func _build_chip_styles() -> void:
	_chip_normal = _make_chip_style(Color.WHITE)
	_chip_hover = _make_chip_style(Color.html("#918478"))
	_chip_pressed = _make_chip_style(Color.html("#918478"))
	_chip_disabled = _make_chip_style(Color(1, 1, 1, 0.45))


func _make_chip_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	return style


func _style_chip_button(button: Button, taupe: Color, taupe_dark: Color) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(0, 28)
	button.add_theme_color_override("font_color", taupe)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", taupe)
	button.add_theme_color_override("font_disabled_color", Color(taupe.r, taupe.g, taupe.b, 0.45))
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _chip_normal)
	button.add_theme_stylebox_override("hover", _chip_hover)
	button.add_theme_stylebox_override("pressed", _chip_pressed)
	button.add_theme_stylebox_override("hover_pressed", _chip_pressed)
	button.add_theme_stylebox_override("focus", _chip_normal)
	button.add_theme_stylebox_override("disabled", _chip_disabled)


func _style_chip_option(option: OptionButton, taupe: Color, taupe_dark: Color) -> void:
	if option == null:
		return
	option.custom_minimum_size = Vector2(0, 28)
	option.add_theme_color_override("font_color", taupe)
	option.add_theme_color_override("font_hover_color", Color.WHITE)
	option.add_theme_color_override("font_pressed_color", Color.WHITE)
	option.add_theme_color_override("font_focus_color", taupe)
	option.add_theme_color_override("font_disabled_color", Color(taupe.r, taupe.g, taupe.b, 0.45))
	option.add_theme_stylebox_override("normal", _chip_normal)
	option.add_theme_stylebox_override("hover", _chip_hover)
	option.add_theme_stylebox_override("pressed", _chip_hover)
	option.add_theme_stylebox_override("focus", _chip_normal)
	option.add_theme_stylebox_override("disabled", _chip_disabled)

	var popup := option.get_popup()
	var popup_panel := _make_chip_style(Color.WHITE)
	popup_panel.content_margin_left = 8.0
	popup_panel.content_margin_top = 6.0
	popup_panel.content_margin_right = 8.0
	popup_panel.content_margin_bottom = 6.0
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override("hover", _make_chip_style(Color.html("#918478")))
	popup.add_theme_color_override("font_color", taupe)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_separator_color", Color(taupe.r, taupe.g, taupe.b, 0.35))
	popup.add_theme_color_override("font_accelerator_color", taupe_dark)


func _setup_options() -> void:
	_animal_option.clear()
	_animal_option.add_item("Frozen", GameSettings.AnimalMotion.FROZEN)
	_animal_option.add_item("Idle / Special", GameSettings.AnimalMotion.IDLE_SPECIAL)
	_animal_option.add_item("Full Roam", GameSettings.AnimalMotion.FULL_ROAM)

	_msaa_option.clear()
	_msaa_option.add_item("Off", GameSettings.MsaaMode.OFF)
	_msaa_option.add_item("2×", GameSettings.MsaaMode.X2)
	_msaa_option.add_item("4×", GameSettings.MsaaMode.X4)


func _wire_signals() -> void:
	_graphics_button.pressed.connect(_on_graphics_pressed)
	_audio_button.pressed.connect(_on_audio_pressed)
	_preset_low.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.LOW))
	_preset_medium.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.MEDIUM))
	_preset_high.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.HIGH))
	_wind_check.toggled.connect(_on_wind_toggled)
	_clouds_check.toggled.connect(_on_clouds_toggled)
	_animal_option.item_selected.connect(_on_animal_selected)
	_msaa_option.item_selected.connect(_on_msaa_selected)
	_music_slider.value_changed.connect(_on_music_volume_changed)
	_effects_slider.value_changed.connect(_on_sfx_volume_changed)
	for control in [
		_graphics_button,
		_audio_button,
		_preset_low,
		_preset_medium,
		_preset_high,
		_wind_check,
		_clouds_check,
		_animal_option,
		_msaa_option,
		_music_slider,
		_effects_slider,
	]:
		if control != null and not control.mouse_entered.is_connected(_on_control_mouse_entered):
			control.mouse_entered.connect(_on_control_mouse_entered)
	WebInstantButton.wire_many([
		_graphics_button,
		_audio_button,
		_preset_low,
		_preset_medium,
		_preset_high,
		_wind_check,
		_clouds_check,
		_animal_option,
		_msaa_option,
	])


func _on_control_mouse_entered() -> void:
	if WebInstantButton.skip_hover():
		return
	GameFeedback.play_hover_button()


func _show_view(view: View) -> void:
	_view = view
	_root_view.visible = view == View.ROOT
	_graphics_view.visible = view == View.GRAPHICS
	_audio_view.visible = view == View.AUDIO
	# Title label is intentionally hidden.


func _refresh_from_settings() -> void:
	GameSettings.begin_ui_sync()
	_music_slider.value = GameSettings.music_volume
	_effects_slider.value = GameSettings.sfx_volume
	_update_volume_labels()
	_wind_check.button_pressed = GameSettings.wind_enabled
	_clouds_check.button_pressed = GameSettings.clouds_enabled
	_select_option_by_id(_animal_option, int(GameSettings.animal_motion))
	_select_option_by_id(_msaa_option, int(GameSettings.msaa_mode))
	GameSettings.end_ui_sync()
	_update_preset_buttons()


func _volume_display(linear: float) -> String:
	return str(roundi(clampf(linear, 0.0, 1.0) * 100.0))


func _update_volume_labels() -> void:
	_music_value.text = _volume_display(_music_slider.value)
	_effects_value.text = _volume_display(_effects_slider.value)


func _select_option_by_id(option: OptionButton, id: int) -> void:
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


func _on_graphics_pressed() -> void:
	GameFeedback.play_click_button()
	GameFeedback.play_open_popup()
	_show_view(View.GRAPHICS)


func _on_audio_pressed() -> void:
	GameFeedback.play_click_button()
	GameFeedback.play_open_popup()
	_show_view(View.AUDIO)


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
