class_name WebInstantButton
extends RefCounted
## Web/mobile: fire BaseButton.pressed on first tap instead of hover-only first touch.

const META_WIRED := "_web_instant_wired"


static func is_needed() -> bool:
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


static func skip_hover() -> bool:
	return is_needed() and InputScheme.is_touch()


static func wire_many(buttons: Array) -> void:
	for button in buttons:
		if button is BaseButton:
			wire(button)


static func wire_tree(root: Node) -> void:
	if not is_needed() or root == null:
		return
	for node in root.find_children("*", "BaseButton", true, false):
		wire(node as BaseButton)


static func wire(button: BaseButton) -> void:
	if not is_needed() or button == null:
		return
	button.focus_mode = Control.FOCUS_NONE
	if button.has_meta(META_WIRED):
		return
	button.set_meta(META_WIRED, true)
	if not button.gui_input.is_connected(_on_gui_input):
		button.gui_input.connect(_on_gui_input.bind(button))


static func _on_gui_input(event: InputEvent, button: BaseButton) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	if button.disabled or not button.visible or not button.is_visible_in_tree():
		return
	var press_id := InputScheme.touch.press_id()
	if button.get_meta("_web_instant_press", -1) == press_id:
		button.get_viewport().set_input_as_handled()
		return
	button.set_meta("_web_instant_press", press_id)
	button.get_viewport().set_input_as_handled()
	if button is OptionButton:
		(button as OptionButton).show_popup()
	elif button is CheckBox or button is CheckButton or button.toggle_mode:
		button.button_pressed = not button.button_pressed
		if not (button is CheckBox or button is CheckButton):
			button.pressed.emit()
	else:
		button.pressed.emit()
	button.release_focus()
	# Wait until emulated mouse events from this tap have landed on the
	# new layout (Back and Exit occupy the same spot).
	InputScheme.clear_stuck_gui_hover_deferred()
