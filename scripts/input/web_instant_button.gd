class_name WebInstantButton
extends RefCounted
## Web/mobile: fire BaseButton.pressed on first tap instead of hover-only first touch.

const META_WIRED := "_web_instant_wired"


static func skip_hover() -> bool:
	return OS.has_feature("web") and TouchMode.is_touch()


static func wire_many(buttons: Array) -> void:
	for button in buttons:
		if button is BaseButton:
			wire(button)


static func wire(button: BaseButton) -> void:
	if not OS.has_feature("web") or button == null:
		return
	if button.has_meta(META_WIRED):
		return
	button.set_meta(META_WIRED, true)
	button.focus_mode = Control.FOCUS_NONE
	if not button.gui_input.is_connected(_on_gui_input):
		button.gui_input.connect(_on_gui_input.bind(button))


static func _on_gui_input(event: InputEvent, button: BaseButton) -> void:
	if event is InputEventMouseButton and TouchMode.is_emulated_mouse_event(event):
		return
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	button.get_viewport().set_input_as_handled()
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
		button.toggled.emit(button.button_pressed)
	button.pressed.emit()
	button.release_focus()
	TouchMode.clear_stuck_gui_hover()
