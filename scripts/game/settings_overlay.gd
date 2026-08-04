extends CanvasLayer
class_name SettingsOverlay

var COLOR_BROWN := Color.html("#918478")

@onready var _popup_root: Node2D = $PopupRoot
@onready var _preset_low: Button = $PopupRoot/PresetRow/LowButton
@onready var _preset_medium: Button = $PopupRoot/PresetRow/MediumButton
@onready var _preset_high: Button = $PopupRoot/PresetRow/HighButton
@onready var _preset_custom: Button = $PopupRoot/PresetRow/CustomButton
@onready var _wind_check: CheckButton = $PopupRoot/WindCheck
@onready var _clouds_check: CheckButton = $PopupRoot/CloudsCheck
@onready var _animal_option: OptionButton = $PopupRoot/AnimalOption
@onready var _msaa_option: OptionButton = $PopupRoot/MsaaOption


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	_setup_options()
	_preset_custom.disabled = true
	_wire_signals()


func open() -> void:
	_refresh_from_settings()
	show()


func close() -> void:
	hide()


func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0


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
	_preset_low.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.LOW))
	_preset_medium.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.MEDIUM))
	_preset_high.pressed.connect(_on_preset_pressed.bind(GameSettings.Preset.HIGH))
	_wind_check.toggled.connect(_on_wind_toggled)
	_clouds_check.toggled.connect(_on_clouds_toggled)
	_animal_option.item_selected.connect(_on_animal_selected)
	_msaa_option.item_selected.connect(_on_msaa_selected)


func _refresh_from_settings() -> void:
	GameSettings.begin_ui_sync()
	_wind_check.button_pressed = GameSettings.wind_enabled
	_clouds_check.button_pressed = GameSettings.clouds_enabled
	_select_option_by_id(_animal_option, int(GameSettings.animal_motion))
	_select_option_by_id(_msaa_option, int(GameSettings.msaa_mode))
	GameSettings.end_ui_sync()
	_update_preset_buttons()


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


func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close()


func _on_close_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_close_pressed()
			get_viewport().set_input_as_handled()


func _on_dimmer_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_close_pressed()
			get_viewport().set_input_as_handled()
