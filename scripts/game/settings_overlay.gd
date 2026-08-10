extends CanvasLayer
class_name SettingsOverlay

@onready var _popup_root: Node2D = $PopupRoot
@onready var _settings_panel: SettingsPanel = $PopupRoot/SettingsPanel
@onready var _close_button: Control = $PopupRoot/CloseButton


func _ready() -> void:
	hide()
	_center_popup_root()
	get_viewport().size_changed.connect(_center_popup_root)
	if _close_button != null:
		_close_button.mouse_entered.connect(_on_close_mouse_entered)


func _on_close_mouse_entered() -> void:
	GameFeedback.play_hover_button()


func open() -> void:
	GameFeedback.play_open_popup()
	if _settings_panel:
		_settings_panel.refresh()
	show()


func close() -> void:
	GameFeedback.play_close_popup()
	hide()


func _center_popup_root() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	_popup_root.position = vp_size / 2.0


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
