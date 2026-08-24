class_name OverlayFocus
extends RefCounted
## Helpers so Control-based menus work with a gamepad.


static func is_activate(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	return event.is_action("ui_accept") or event.is_action("confirm")


static func try_activate_event(viewport: Viewport, event: InputEvent) -> bool:
	if not is_activate(event):
		return false
	return activate_focused(viewport)


static func activate_focused(viewport: Viewport) -> bool:
	if viewport == null:
		return false
	var focused := viewport.gui_get_focus_owner()
	if focused == null or not (focused is BaseButton):
		return false
	var button := focused as BaseButton
	if button.disabled or not button.visible or not button.is_visible_in_tree():
		return false
	if button is CheckBox or button is CheckButton:
		button.button_pressed = not button.button_pressed
		return true
	if button is OptionButton:
		(button as OptionButton).show_popup()
		return true
	button.pressed.emit()
	return true


static func is_cancel(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	return event.is_action("ui_cancel") or event.is_action("cancel")


static func enable_buttons(root: Node) -> void:
	if root == null:
		return
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		style_button_for_focus(button)


static func grab_first_button(root: Node) -> void:
	if not InputScheme.is_gamepad() or root == null:
		return
	enable_buttons(root)
	var button := _first_visible_button(root)
	if button != null:
		_queue_grab(button)


static func grab_button_row(row: Node, parent_button: Control = null) -> void:
	if not InputScheme.is_gamepad() or row == null:
		return
	wire_horizontal_row(row, parent_button)
	var button := _first_visible_button(row)
	if button != null:
		_queue_grab(button)


static func wire_horizontal_row(row: Node, parent_button: Control = null) -> void:
	if row == null:
		return
	enable_buttons(row)
	var buttons := visible_buttons(row)
	if buttons.is_empty():
		return
	var last_i := buttons.size() - 1
	for i in buttons.size():
		var button := buttons[i]
		var left := buttons[last_i] if i == 0 else buttons[i - 1]
		var right := buttons[0] if i == last_i else buttons[i + 1]
		button.focus_neighbor_left = button.get_path_to(left)
		button.focus_neighbor_right = button.get_path_to(right)
		button.focus_previous = button.get_path_to(left)
		button.focus_next = button.get_path_to(right)
		if parent_button != null:
			button.focus_neighbor_top = button.get_path_to(parent_button)
	if parent_button != null:
		parent_button.focus_neighbor_bottom = parent_button.get_path_to(buttons[0])


static func restore_parent_focus(parent_button: Control) -> void:
	if parent_button == null:
		return
	parent_button.focus_neighbor_bottom = NodePath()
	grab_control(parent_button)


static func style_button_for_focus(button: BaseButton) -> void:
	if button == null:
		return
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_color_override(
		"font_focus_color",
		button.get_theme_color("font_hover_color")
	)
	var hover_style := button.get_theme_stylebox("hover")
	if hover_style != null:
		button.add_theme_stylebox_override("focus", hover_style)
	if not button.focus_entered.is_connected(_on_button_focus_entered):
		button.focus_entered.connect(_on_button_focus_entered)


static func _on_button_focus_entered() -> void:
	GameFeedback.play_hover_button()


static func enable_control(control: Control) -> void:
	if control == null:
		return
	control.focus_mode = Control.FOCUS_ALL
	if control is BaseButton:
		style_button_for_focus(control as BaseButton)


static func grab_control(control: Control) -> void:
	if not InputScheme.is_gamepad() or control == null:
		return
	if not control.visible or not control.is_visible_in_tree():
		return
	control.focus_mode = Control.FOCUS_ALL
	if control is BaseButton:
		style_button_for_focus(control as BaseButton)
	_queue_grab(control)


static func visible_buttons(root: Node) -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	if root == null:
		return out
	for node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button == null:
			continue
		if not button.visible or not button.is_visible_in_tree():
			continue
		if button.disabled:
			continue
		out.append(button)
	return out


static func _first_visible_button(root: Node) -> BaseButton:
	var buttons := visible_buttons(root)
	if buttons.is_empty():
		return null
	return buttons[0]


static func _queue_grab(control: Control) -> void:
	if control == null:
		return
	(func() -> void:
		if is_instance_valid(control):
			control.grab_focus()
	).call_deferred()
