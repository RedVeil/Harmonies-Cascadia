extends Control
class_name SessionReplay

## Plays the placement log on the live map, in the menu's right pane.

const TILE_VISUALS_SCENE := preload("res://scenes/hex/tile_visuals.tscn")
const BUBBLE_TEXTURE := preload("res://assets/icons/circle.png")
const GEAR_ICON := preload("res://assets/icons/settings.png")
const OUTLINE_TEXTURE := preload("res://assets/icons/hex_outline_thin2.png")
const BAR_HEIGHT := 64.0
const SPEEDS: Array[float] = [1.0, 2.0, 4.0]
const PLACED_LIFT := 0.42
const PLACED_SCALE := 1.085
const PLACED_RISE := 0.24
const PLACED_SETTLE := 0.3
const CONTRIBUTOR_LIFT := 0.16
const CONTRIBUTOR_SCALE := 1.045
const CONTRIBUTOR_RISE := 0.2
const CONTRIBUTOR_SETTLE := 0.26
const CONTRIBUTOR_STAGGER := 0.06
const SCORE_POP_BASE_Y := 19.0
const SCORE_POP_RISE := 1.35
const SCORE_POP_PEAK_SCALE := 1.5
const SCORE_POP_UP_DURATION := 0.18
const SCORE_POP_FLOAT_DURATION := 0.85
const SCORE_POP_FADE_DURATION := 0.55
const SCORE_POP_FADE_DELAY := 0.35
const STEP_INTERVAL := (
	SCORE_POP_UP_DURATION + SCORE_POP_FLOAT_DURATION + SCORE_POP_FADE_DELAY + SCORE_POP_FADE_DURATION
)
const OUTLINE_FLASH_FADE := 0.45
var OUTLINE_FLASH_COLOR := Color(1.0, 0.9, 0.45, 1.0)
var POINTS_BUBBLE_SCALE := Vector3(1.2, 1.2, 1.2)

var _tiles_root: Node3D
var _bar: PanelContainer
var _play_button: Button
var _speed_button: Button
var _options_button: Button
var _options_panel: PanelContainer
var _place_sound_button: CheckButton
var _point_sound_button: CheckButton
var _show_points_button: CheckButton
var _animate_animals_button: CheckButton
var _outline_button: CheckButton
var _slider: HSlider
var _fullscreen_button: Button
var _options_open: bool = false

var _orchestrator: Orchestrator
var _steps: Array[Dictionary] = []
var _cursor: int = 0
var _ring: int = 3
var _hex_size: float = 11.0
var _open: bool = false
var _playing: bool = false
var _fullscreen: bool = false
var _wait: float = 0.0
var _speed_index: int = 0
var _home: Node = null
var _live_hidden: bool = false
var _live_visible: bool = true
var _live_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _hud: CanvasLayer
var _hud_was_visible: bool = true
var _camera_node: Camera3D
var _camera_process_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _camera_home := Vector3.ZERO
var _camera_posed: bool = false
var _camera_frame_token: int = 0
var _menu_hidden: bool = false
var _reparenting: bool = false
var _pivots: Dictionary = {}
var _visuals: Dictionary = {}
var _state: Dictionary = {}
var _celebrate_tweens: Dictionary = {}
var _bar_fade: Tween
var _bar_hover_token: int = 0
var _place_sound: bool = true
var _point_sound: bool = true
var _show_points: bool = false
var _animate_animals: bool = false
var _show_outline: bool = false
var _bubbles: Dictionary = {}
var _bubble_tweens: Dictionary = {}
var _outlines: Dictionary = {}
var _outline_tweens: Dictionary = {}


func _ready() -> void:
	_home = get_parent()
	_build_bar()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	UiTheme.bind_node(self, _apply_theme)
	_apply_theme()
	_apply_locale()
	if GameSettings != null and not GameSettings.settings_changed.is_connected(_apply_locale):
		GameSettings.settings_changed.connect(_apply_locale)


func _exit_tree() -> void:
	if _reparenting:
		return
	# The scene root is already walking its children. ReplayTiles is a later
	# sibling, so freeing it here mutates that list and crashes.
	_playing = false
	_open = false
	_camera_frame_token += 1
	_bar_hover_token += 1
	_kill_owned_tweens()
	_pivots.clear()
	_visuals.clear()
	_state.clear()
	_bubbles.clear()
	_outlines.clear()
	_tiles_root = null
	_live_hidden = false
	_camera_node = null
	_camera_posed = false
	_hud = null
	_menu_hidden = false


func _kill_owned_tweens() -> void:
	var tweens: Array = []
	tweens.append_array(_celebrate_tweens.values())
	tweens.append_array(_bubble_tweens.values())
	tweens.append_array(_outline_tweens.values())
	if _bar_fade != null:
		tweens.append(_bar_fade)
	_celebrate_tweens.clear()
	_bubble_tweens.clear()
	_outline_tweens.clear()
	_bar_fade = null
	for tween in tweens:
		var anim := tween as Tween
		if anim == null or not anim.is_valid():
			continue
		for conn in anim.finished.get_connections():
			anim.finished.disconnect(conn["callable"])
		anim.kill()


func _process(delta: float) -> void:
	if not _open or not _playing:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if _cursor >= _steps.size():
		_playing = false
		_apply_locale()
		return
	_apply_forward(1, is_equal_approx(_speed(), 1.0), true)
	if _cursor >= _steps.size():
		_playing = false
	_apply_locale()
	if _playing:
		_wait = _interval()


func is_open() -> bool:
	return _open


func is_fullscreen() -> bool:
	return _fullscreen


func open_replay(host: Orchestrator) -> void:
	if host == null or host.replay_steps.is_empty():
		return
	if _open:
		close_replay()
	_orchestrator = host
	_steps.clear()
	for step in host.replay_steps:
		var copy: Dictionary = (step as Dictionary).duplicate()
		_steps.append(copy)
	_ring = maxi(GameSession.get_map_ring_count(), 1)
	_hex_size = 11.0
	if host.hex_manager != null and host.hex_manager.hex_container != null:
		_hex_size = host.hex_manager.hex_container.hex_size
	_speed_index = 0
	_reset_feedback_toggles()
	if not _ensure_tiles_root():
		_steps.clear()
		return
	_hide_live_board()
	_hide_scene_chrome()
	_rebuild_to(0)
	_open = true
	_playing = true
	_wait = _interval()
	_present_overlay()
	_apply_locale()


func close_replay() -> void:
	if _fullscreen:
		set_fullscreen(false)
	_playing = false
	_open = false
	_stop_celebrate()
	_clear_hexes()
	_free_tiles_root()
	_show_live_board()
	_show_scene_chrome()
	_return_home()


func set_fullscreen(enabled: bool) -> void:
	if enabled == _fullscreen:
		return
	_fullscreen = enabled
	if enabled:
		var host := _fullscreen_host()
		if host != null and get_parent() != host:
			_reparenting = true
			reparent(host)
			_reparenting = false
			set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			move_to_front()
		var split := _menu_split()
		if split != null:
			split.visible = false
			_menu_hidden = true
	else:
		if _menu_hidden:
			var split := _menu_split()
			if split != null:
				split.visible = true
			_menu_hidden = false
		if _home != null and get_parent() != _home:
			_reparenting = true
			reparent(_home)
			_reparenting = false
			set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = true
	_place_bar()
	if _options_open:
		_place_options_panel.call_deferred()
	if enabled:
		_restore_camera_home()
	else:
		_queue_camera_frame()
	_apply_locale()


func _present_overlay() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place_bar()
	_set_bar_alpha(0.0)
	_fullscreen = false
	visible = true
	_queue_camera_frame()


func _return_home() -> void:
	if _home != null and get_parent() != _home:
		_reparenting = true
		reparent(_home)
		_reparenting = false
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_bar_alpha(0.0)
	_fullscreen = false


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.name = "Bar"
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -BAR_HEIGHT
	_bar.offset_bottom = 0.0
	_bar.mouse_entered.connect(_on_bar_mouse_entered)
	_bar.mouse_exited.connect(_on_bar_mouse_exited)
	add_child(_bar)
	_set_bar_alpha(0.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_bar.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	_play_button = _make_bar_button("PlayButton")
	_play_button.pressed.connect(_on_play_pressed)
	row.add_child(_play_button)

	_speed_button = _make_bar_button("SpeedButton")
	_speed_button.custom_minimum_size = Vector2(56, 28)
	_speed_button.pressed.connect(_on_speed_pressed)
	row.add_child(_speed_button)

	_options_button = _make_bar_button("OptionsButton")
	_options_button.custom_minimum_size = Vector2(36, 28)
	_options_button.icon = GEAR_ICON
	_options_button.expand_icon = true
	_options_button.add_theme_constant_override("icon_max_width", 18)
	_options_button.toggle_mode = true
	_options_button.toggled.connect(_on_options_toggled)
	row.add_child(_options_button)

	_slider = HSlider.new()
	_slider.name = "Timeline"
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 1.0
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.drag_started.connect(_on_slider_drag_started)
	_slider.drag_ended.connect(_on_slider_drag_ended)
	row.add_child(_slider)

	_fullscreen_button = _make_bar_button("FullscreenButton")
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	row.add_child(_fullscreen_button)

	_build_options_panel()
	WebInstantButton.wire_tree(_bar)
	WebInstantButton.wire_tree(_options_panel)


func _make_bar_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(0, 28)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_entered.connect(_on_button_mouse_entered)
	return button


func _build_options_panel() -> void:
	_options_panel = PanelContainer.new()
	_options_panel.name = "Options"
	_options_panel.visible = false
	_options_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_options_panel.z_index = 2
	_options_panel.mouse_entered.connect(_on_bar_mouse_entered)
	_options_panel.mouse_exited.connect(_on_bar_mouse_exited)
	add_child(_options_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_options_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	margin.add_child(column)

	_place_sound_button = _make_check("PlaceSoundButton", true)
	_place_sound_button.toggled.connect(_on_place_sound_toggled)
	column.add_child(_place_sound_button)

	_point_sound_button = _make_check("PointSoundButton", true)
	_point_sound_button.toggled.connect(_on_point_sound_toggled)
	column.add_child(_point_sound_button)

	_show_points_button = _make_check("ShowPointsButton", false)
	_show_points_button.toggled.connect(_on_show_points_toggled)
	column.add_child(_show_points_button)

	_animate_animals_button = _make_check("AnimateAnimalsButton", false)
	_animate_animals_button.toggled.connect(_on_animate_animals_toggled)
	column.add_child(_animate_animals_button)

	_outline_button = _make_check("OutlineButton", false)
	_outline_button.toggled.connect(_on_outline_toggled)
	column.add_child(_outline_button)


func _make_check(node_name: String, pressed: bool) -> CheckButton:
	var button := CheckButton.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_entered.connect(_on_button_mouse_entered)
	button.set_pressed_no_signal(pressed)
	return button


func _reset_feedback_toggles() -> void:
	_place_sound = true
	_point_sound = true
	_show_points = false
	_animate_animals = false
	_show_outline = false
	if _place_sound_button:
		_place_sound_button.set_pressed_no_signal(true)
	if _point_sound_button:
		_point_sound_button.set_pressed_no_signal(true)
	if _show_points_button:
		_show_points_button.set_pressed_no_signal(false)
	if _animate_animals_button:
		_animate_animals_button.set_pressed_no_signal(false)
	if _outline_button:
		_outline_button.set_pressed_no_signal(false)


func _on_button_mouse_entered() -> void:
	if WebInstantButton.skip_hover():
		return
	GameFeedback.play_hover_button()


func _apply_theme() -> void:
	if _bar:
		UiTheme.style_panel(_bar)
	if _play_button:
		UiTheme.style_chip_button(_play_button)
		_play_button.add_theme_font_size_override("font_size", 16)
	if _speed_button:
		UiTheme.style_chip_button(_speed_button)
		_speed_button.add_theme_font_size_override("font_size", 16)
	if _options_button:
		UiTheme.style_chip_button(_options_button)
	if _options_panel:
		UiTheme.style_panel(_options_panel)
	for toggle in [_place_sound_button, _point_sound_button, _show_points_button, _animate_animals_button, _outline_button]:
		if toggle:
			UiTheme.style_check_button(toggle, 16)
	if _fullscreen_button:
		UiTheme.style_chip_button(_fullscreen_button)
		_fullscreen_button.add_theme_font_size_override("font_size", 16)
	if _slider:
		UiTheme.style_slider(_slider)


func _apply_locale() -> void:
	if _play_button:
		_play_button.text = Loc.ui("pause.pause") if _playing else Loc.ui("pause.play")
	if _speed_button:
		_speed_button.text = "%dx" % int(_speed())
	if _place_sound_button:
		_place_sound_button.text = Loc.ui("pause.replay_place_sound")
	if _point_sound_button:
		_point_sound_button.text = Loc.ui("pause.replay_point_sound")
	if _show_points_button:
		_show_points_button.text = Loc.ui("pause.replay_show_points")
	if _animate_animals_button:
		_animate_animals_button.text = Loc.ui("pause.replay_animate_animals")
	if _outline_button:
		_outline_button.text = Loc.ui("pause.replay_outline")
	if _fullscreen_button:
		_fullscreen_button.text = Loc.ui("pause.windowed") if _fullscreen else Loc.ui("pause.fullscreen")


func _on_play_pressed() -> void:
	GameFeedback.play_click_button()
	if _playing:
		_playing = false
		_apply_locale()
		return
	if _cursor >= _steps.size():
		_rebuild_to(0)
	_playing = true
	_wait = _interval()
	_apply_locale()


func _on_options_toggled(pressed: bool) -> void:
	GameFeedback.play_click_button()
	_set_options_open(pressed)


func _set_options_open(open: bool) -> void:
	_options_open = open
	if _options_button and _options_button.button_pressed != open:
		_options_button.set_pressed_no_signal(open)
	if _options_panel == null:
		return
	_options_panel.visible = open
	if not open:
		return
	_options_panel.modulate.a = _bar.modulate.a if _bar else 1.0
	_place_options_panel.call_deferred()


func _place_options_panel() -> void:
	if not _options_open or _options_panel == null or _options_button == null or _bar == null:
		return
	var panel_size := _options_panel.get_combined_minimum_size()
	_options_panel.size = panel_size
	var button_rect := _options_button.get_global_rect()
	var bounds := get_global_rect()
	var x := button_rect.position.x
	var y := _bar.get_global_rect().position.y - panel_size.y
	if x + panel_size.x > bounds.end.x:
		x = bounds.end.x - panel_size.x
	if x < bounds.position.x:
		x = bounds.position.x
	_options_panel.global_position = Vector2(x, y)


func _on_place_sound_toggled(pressed: bool) -> void:
	_place_sound = pressed
	GameFeedback.play_click_button()


func _on_point_sound_toggled(pressed: bool) -> void:
	_point_sound = pressed
	GameFeedback.play_click_button()


func _on_show_points_toggled(pressed: bool) -> void:
	_show_points = pressed
	GameFeedback.play_click_button()


func _on_outline_toggled(pressed: bool) -> void:
	_show_outline = pressed
	GameFeedback.play_click_button()


func _on_animate_animals_toggled(pressed: bool) -> void:
	_animate_animals = pressed
	GameFeedback.play_click_button()
	for visuals in _visuals.values():
		var tile := visuals as TileVisuals
		if tile == null:
			continue
		if pressed:
			tile.start_animal_roam()
		else:
			tile.place_animals_on_paths()


func _on_speed_pressed() -> void:
	GameFeedback.play_click_button()
	var previous := _speed()
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	if previous > 0.0:
		_wait = _wait * previous / _speed()
	_apply_locale()


func _on_fullscreen_pressed() -> void:
	GameFeedback.play_click_button()
	set_fullscreen(not _fullscreen)


func _on_slider_drag_started() -> void:
	_playing = false
	_apply_locale()


func _on_slider_drag_ended(_value_changed: bool) -> void:
	_seek(int(_slider.value))


func _speed() -> float:
	return SPEEDS[_speed_index]


func _interval() -> float:
	return STEP_INTERVAL / _speed()


func _fullscreen_host() -> Control:
	if _home == null or _home.get_parent() == null:
		return null
	var split := _home.get_parent()
	return split.get_parent() as Control


func _menu_split() -> Control:
	if _home == null:
		return null
	return _home.get_parent() as Control


func _world_root() -> Node3D:
	if _orchestrator == null or _orchestrator.hex_manager == null:
		return null
	return _orchestrator.hex_manager.get_parent() as Node3D


func _ensure_tiles_root() -> bool:
	if _tiles_root != null and is_instance_valid(_tiles_root):
		return true
	var world := _world_root()
	if world == null:
		return false
	_tiles_root = Node3D.new()
	_tiles_root.name = "ReplayTiles"
	world.add_child(_tiles_root)
	return true


func _free_tiles_root() -> void:
	if _tiles_root != null and is_instance_valid(_tiles_root):
		_tiles_root.free()
	_tiles_root = null


func _place_bar() -> void:
	if _bar == null:
		return
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bar.offset_top = -BAR_HEIGHT
	_bar.offset_bottom = 0.0


func _set_bar_alpha(alpha: float) -> void:
	if _bar == null:
		return
	if _bar_fade != null and _bar_fade.is_valid():
		_bar_fade.kill()
	_bar.modulate.a = alpha
	if alpha <= 0.0:
		_set_options_open(false)
	elif _options_panel != null:
		_options_panel.modulate.a = alpha


func _fade_bar(alpha: float) -> void:
	if _bar == null:
		return
	if alpha <= 0.0:
		_set_options_open(false)
	if _bar_fade != null and _bar_fade.is_valid():
		_bar_fade.kill()
	_bar_fade = create_tween()
	_bar_fade.tween_property(_bar, "modulate:a", alpha, 0.15)
	if _options_open and _options_panel != null:
		_bar_fade.parallel().tween_property(_options_panel, "modulate:a", alpha, 0.15)


func _on_bar_mouse_entered() -> void:
	_bar_hover_token += 1
	_fade_bar(1.0)


func _on_bar_mouse_exited() -> void:
	_bar_hover_token += 1
	var token := _bar_hover_token
	await get_tree().process_frame
	if token != _bar_hover_token or _bar == null:
		return
	if _pointer_over_chrome():
		return
	_fade_bar(0.0)


func _pointer_over_chrome() -> bool:
	var point := get_global_mouse_position()
	if _bar != null and _bar.get_global_rect().has_point(point):
		return true
	return (
		_options_open
		and _options_panel != null
		and _options_panel.visible
		and _options_panel.get_global_rect().has_point(point)
	)


func _hide_scene_chrome() -> void:
	var world := _world_root()
	if world == null:
		return
	_hud = world.get_node_or_null("HUD") as CanvasLayer
	if _hud != null:
		_hud_was_visible = _hud.visible
		_hud.visible = false
	_camera_node = world.get_node_or_null("Camera3D") as Camera3D
	if _camera_node != null:
		_camera_process_mode = _camera_node.process_mode
		_camera_node.process_mode = Node.PROCESS_MODE_DISABLED
		_camera_home = _camera_node.global_position
		_camera_posed = true


func _queue_camera_frame() -> void:
	_camera_frame_token += 1
	var token := _camera_frame_token
	_apply_camera_frame.call_deferred(token)


func _apply_camera_frame(token: int) -> void:
	if token != _camera_frame_token or not _open or not _camera_posed:
		return
	if _camera_node == null or not is_instance_valid(_camera_node):
		return
	if _fullscreen:
		_camera_node.global_position = _camera_home
		return
	var pane := _home as Control
	if pane == null:
		return
	var rect := pane.get_global_rect()
	var view := get_viewport().get_visible_rect()
	if rect.size.x < 1.0 or view.size.x < 1.0 or view.size.y < 1.0:
		return
	var delta := rect.get_center() - view.get_center()
	var horizontal := _camera_node.size * (view.size.x / view.size.y)
	var shift_x := (delta.x / view.size.x) * horizontal
	var shift_y := -(delta.y / view.size.y) * _camera_node.size
	var right := _camera_node.global_basis.x
	var up := _camera_node.global_basis.y
	_camera_node.global_position = _camera_home - right * shift_x - up * shift_y


func _restore_camera_home() -> void:
	_camera_frame_token += 1
	if not _camera_posed or _camera_node == null or not is_instance_valid(_camera_node):
		return
	_camera_node.global_position = _camera_home


func _show_scene_chrome() -> void:
	if _menu_hidden:
		var split := _menu_split()
		if split != null:
			split.visible = true
		_menu_hidden = false
	if _hud != null and is_instance_valid(_hud):
		_hud.visible = _hud_was_visible
	_hud = null
	_restore_camera_home()
	if _camera_node != null and is_instance_valid(_camera_node):
		_camera_node.process_mode = _camera_process_mode
	_camera_node = null
	_camera_posed = false


func _seek(target: int) -> void:
	target = clampi(target, 0, _steps.size())
	if target == _cursor:
		_sync_slider()
		return
	_clear_score_bubbles()
	_clear_outlines()
	if target > _cursor:
		_apply_forward(target - _cursor, false)
		return
	_rebuild_to(target)


func _rebuild_to(target: int) -> void:
	_stop_celebrate()
	_clear_hexes()
	_create_patch(Vector2i.ZERO)
	_cursor = 0
	target = clampi(target, 0, _steps.size())
	while _cursor < target:
		_apply_step(_steps[_cursor], false)
		_cursor += 1
	_sync_slider()


func _apply_forward(count: int, animate: bool, feedback: bool = false) -> void:
	var target := mini(_cursor + count, _steps.size())
	while _cursor < target:
		var last := _cursor == target - 1
		_apply_step(_steps[_cursor], animate and last, feedback and last)
		_cursor += 1
	_sync_slider()


func _sync_slider() -> void:
	if _slider == null:
		return
	_slider.max_value = float(_steps.size())
	_slider.set_value_no_signal(float(_cursor))


func _apply_step(step: Dictionary, animate: bool, feedback: bool = false) -> void:
	var kind := str(step.get("kind", ""))
	if kind == "map":
		_create_patch(Vector2i(int(step.get("q", 0)), int(step.get("r", 0))))
		return
	if kind != "place":
		return
	var coord := Vector2i(int(step.get("q", 0)), int(step.get("r", 0)))
	if not _pivots.has(coord):
		_create_hex(coord)
	var previous_element := int(_state[coord]["element"]) if _state.has(coord) else GameEnums.ELEMENT.NONE
	_state[coord] = {
		"element": int(step.get("element", GameEnums.ELEMENT.NONE)),
		"level": int(step.get("level", GameEnums.LEVEL.ANY)),
		"animal_id": int(step.get("animal_id", -1)),
		"animal_amount": int(step.get("animal_amount", 0)),
	}
	_commit(coord)
	var placed_element := int(_state[coord]["element"])
	if previous_element == GameEnums.ELEMENT.RIVER or placed_element == GameEnums.ELEMENT.RIVER:
		for neighbor in HexCoord.neighbors(coord):
			if neighbor == coord or not _state.has(neighbor):
				continue
			if int(_state[neighbor]["element"]) != GameEnums.ELEMENT.RIVER:
				continue
			_commit(neighbor)
	var points := int(step.get("points", 0))
	if animate:
		_play_group_celebrate(coord, points)
	if feedback:
		_play_step_feedback(coord, points)


func _create_patch(origin: Vector2i) -> void:
	for q in range(-_ring, _ring + 1):
		for r in range(-_ring, _ring + 1):
			var coord := origin + Vector2i(q, r)
			if HexCoord.distance(origin, coord) > _ring:
				continue
			if _pivots.has(coord):
				continue
			_create_hex(coord)


func _create_hex(coord: Vector2i) -> void:
	if _tiles_root == null:
		return
	var pivot := Node3D.new()
	pivot.position = HexCoord.axial_to_world(coord, _hex_size)
	_tiles_root.add_child(pivot)
	var visuals := TILE_VISUALS_SCENE.instantiate() as TileVisuals
	pivot.add_child(visuals)
	_pivots[coord] = pivot
	_visuals[coord] = visuals
	_state[coord] = {
		"element": GameEnums.ELEMENT.NONE,
		"level": GameEnums.LEVEL.ANY,
		"animal_id": -1,
		"animal_amount": 0,
	}
	_commit(coord)


func _commit(coord: Vector2i) -> void:
	if not _pivots.has(coord) or not _state.has(coord):
		return
	var state: Dictionary = _state[coord]
	var element := int(state["element"])
	var orientation_steps := 0
	var river_index := -1
	if element == GameEnums.ELEMENT.RIVER:
		var river_data := RiverPreviewLogic.get_river_index_and_rotation(coord, _river_neighbors(coord))
		orientation_steps = river_data.x
		river_index = river_data.y
	elif element != GameEnums.ELEMENT.NONE:
		orientation_steps = HexCoord.pick_orientation_steps(coord)
	var pivot := _pivots[coord] as Node3D
	pivot.rotation_degrees.y = HexCoord.direction_to_yaw_degrees(orientation_steps)
	var visuals := _visuals[coord] as TileVisuals
	var rotations: Array[float] = []
	visuals.apply(
		element,
		int(state["level"]),
		coord,
		int(state["animal_id"]),
		int(state["animal_amount"]),
		rotations,
		river_index,
		true,
		_animate_animals
	)


func _river_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for neighbor in HexCoord.neighbors(coord):
		if not _state.has(neighbor):
			continue
		if int(_state[neighbor]["element"]) != GameEnums.ELEMENT.RIVER:
			continue
		out.append(neighbor)
	return out


func _play_group_celebrate(origin: Vector2i, points: int) -> void:
	if not _state.has(origin):
		return
	var element := int(_state[origin]["element"])
	if element != GameEnums.ELEMENT.NONE:
		_play_celebrate(origin, true, 0.0)
	if points == 0:
		return
	var delay := 0.0
	for coord in _group_targets(origin):
		if coord == origin:
			continue
		if not _state.has(coord) or int(_state[coord]["element"]) == GameEnums.ELEMENT.NONE:
			continue
		_play_celebrate(coord, false, delay)
		delay += CONTRIBUTOR_STAGGER


func _play_celebrate(coord: Vector2i, strong: bool, delay: float) -> void:
	if not _visuals.has(coord):
		return
	_reset_celebrate_visual(coord)
	var visuals := _visuals[coord] as Node3D
	if visuals == null:
		return
	var lift := PLACED_LIFT if strong else CONTRIBUTOR_LIFT
	var peak := Vector3.ONE * (PLACED_SCALE if strong else CONTRIBUTOR_SCALE)
	var rise := PLACED_RISE if strong else CONTRIBUTOR_RISE
	var settle := PLACED_SETTLE if strong else CONTRIBUTOR_SETTLE
	var tween := create_tween()
	_celebrate_tweens[coord] = tween
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(visuals, "position:y", lift, rise)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", peak, rise)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(visuals, "position:y", 0.0, settle)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visuals, "scale", Vector3.ONE, settle)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_celebrate_finished.bind(coord))


func _on_celebrate_finished(coord: Vector2i) -> void:
	_reset_celebrate_visual(coord)


func _reset_celebrate_visual(coord: Vector2i) -> void:
	if _celebrate_tweens.has(coord):
		var tween: Tween = _celebrate_tweens[coord]
		_celebrate_tweens.erase(coord)
		if tween != null and tween.is_valid():
			tween.kill()
	if not _visuals.has(coord):
		return
	var visuals := _visuals[coord] as Node3D
	if visuals == null or not is_instance_valid(visuals):
		return
	visuals.position.y = 0.0
	visuals.scale = Vector3.ONE


func _stop_celebrate() -> void:
	for coord in _celebrate_tweens.keys():
		_reset_celebrate_visual(coord)


func _play_step_feedback(coord: Vector2i, points: int) -> void:
	var element := GameEnums.ELEMENT.NONE
	if _state.has(coord):
		element = int(_state[coord]["element"]) as GameEnums.ELEMENT
	if _place_sound and element != GameEnums.ELEMENT.NONE:
		_play_place_sound()
	if _show_outline:
		_flash_group_outline(coord)
	if points == 0:
		return
	if _point_sound:
		_play_point_sound()
	if _show_points:
		_show_score_bubble(coord, points)


func _play_place_sound() -> void:
	if _orchestrator == null or _orchestrator.hex_manager == null:
		return
	var container := _orchestrator.hex_manager.hex_container
	if container == null or container.tiles_by_coord.is_empty():
		return
	var tile: HexTile = container.tiles_by_coord.values()[0]
	FeedbackAnimHelper.play_sounds(tile.place_celebrate_sounds)


func _play_point_sound() -> void:
	if _orchestrator == null or _orchestrator.point_counter == null:
		return
	FeedbackAnimHelper.play_sounds(_orchestrator.point_counter.score_reward_sounds)


func _show_score_bubble(coord: Vector2i, points: int) -> void:
	if not _pivots.has(coord):
		return
	_clear_score_bubble(coord)
	var pivot := _pivots[coord] as Node3D
	var sprite := Sprite3D.new()
	sprite.name = "ScoreBubble"
	sprite.texture = BUBBLE_TEXTURE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = 2
	sprite.position = Vector3(0.0, SCORE_POP_BASE_Y, 0.0)
	sprite.scale = POINTS_BUBBLE_SCALE
	sprite.modulate = UiTheme.points_positive if points > 0 else UiTheme.points_negative
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.render_priority = 3
	label.modulate = Color(0, 0, 0, 1)
	label.font_size = 200
	label.scale = Vector3(1.8, 1.8, 1.8)
	label.text = "+%d" % points if points > 0 else "%d" % points
	sprite.add_child(label)
	pivot.add_child(sprite)
	_bubbles[coord] = sprite
	var tween := create_tween()
	_bubble_tweens[coord] = tween
	tween.tween_property(sprite, "scale", Vector3.ONE * SCORE_POP_PEAK_SCALE, SCORE_POP_UP_DURATION)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position:y", SCORE_POP_BASE_Y + SCORE_POP_RISE, SCORE_POP_FLOAT_DURATION)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "modulate:a", 0.0, SCORE_POP_FADE_DURATION)\
		.set_delay(SCORE_POP_FADE_DELAY).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_score_bubble_finished.bind(coord))


func _on_score_bubble_finished(coord: Vector2i) -> void:
	_clear_score_bubble(coord)


func _clear_score_bubble(coord: Vector2i) -> void:
	if _bubble_tweens.has(coord):
		var tween: Tween = _bubble_tweens[coord]
		_bubble_tweens.erase(coord)
		if tween != null and tween.is_valid():
			tween.kill()
	if not _bubbles.has(coord):
		return
	var sprite: Node = _bubbles[coord]
	_bubbles.erase(coord)
	if is_instance_valid(sprite):
		sprite.free()


func _clear_score_bubbles() -> void:
	for coord in _bubbles.keys():
		_clear_score_bubble(coord)


func _flash_group_outline(origin: Vector2i) -> void:
	if not _state.has(origin):
		return
	var delay := 0.0
	for coord in _group_targets(origin):
		if coord == origin:
			_flash_outline(coord, 0.0)
			continue
		_flash_outline(coord, delay)
		delay += CONTRIBUTOR_STAGGER


func _group_targets(origin: Vector2i) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	if not _state.has(origin):
		return targets
	var element := int(_state[origin]["element"])
	var group := _connected_group(origin, element)
	targets.assign(group)
	if not _outlines_neighbors(element):
		return targets
	for member in group:
		for neighbor in HexCoord.neighbors(member):
			if targets.has(neighbor) or not _state.has(neighbor):
				continue
			if int(_state[neighbor]["element"]) == GameEnums.ELEMENT.NONE:
				continue
			targets.append(neighbor)
	return targets


func _connected_group(origin: Vector2i, element: int) -> Array[Vector2i]:
	var group: Array[Vector2i] = []
	if element == GameEnums.ELEMENT.NONE or not _state.has(origin):
		if _state.has(origin):
			group.append(origin)
		return group
	var seen := {}
	var stack: Array[Vector2i] = [origin]
	seen[origin] = true
	while not stack.is_empty():
		var current: Vector2i = stack.pop_back()
		group.append(current)
		for neighbor in HexCoord.neighbors(current):
			if seen.has(neighbor) or not _state.has(neighbor):
				continue
			if int(_state[neighbor]["element"]) != element:
				continue
			seen[neighbor] = true
			stack.append(neighbor)
	return group


func _outlines_neighbors(element: int) -> bool:
	if _orchestrator == null or _orchestrator.score_engine == null:
		return element == GameEnums.ELEMENT.WETLAND
	if not _orchestrator.score_engine.active_rules.has(element):
		return false
	var rule: ScoringRule = _orchestrator.score_engine.active_rules[element]
	return rule != null and rule.special_rule == ScoringRule.SpecialRule.NEIGHBORS


func _flash_outline(coord: Vector2i, delay: float) -> void:
	if not _pivots.has(coord):
		return
	_clear_outline(coord)
	var pivot := _pivots[coord] as Node3D
	var outline := Sprite3D.new()
	outline.name = "Outline"
	outline.texture = OUTLINE_TEXTURE
	outline.axis = Vector3.AXIS_Y
	outline.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline.position = Vector3(0.0, 10.0, 0.0)
	outline.scale = Vector3(5.5, 5.5, 5.5)
	outline.modulate = OUTLINE_FLASH_COLOR
	pivot.add_child(outline)
	_outlines[coord] = outline
	var tween := create_tween()
	_outline_tweens[coord] = tween
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(outline, "modulate:a", 0.0, OUTLINE_FLASH_FADE)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(_on_outline_finished.bind(coord))


func _on_outline_finished(coord: Vector2i) -> void:
	_clear_outline(coord)


func _clear_outline(coord: Vector2i) -> void:
	if _outline_tweens.has(coord):
		var tween: Tween = _outline_tweens[coord]
		_outline_tweens.erase(coord)
		if tween != null and tween.is_valid():
			tween.kill()
	if not _outlines.has(coord):
		return
	var outline: Node = _outlines[coord]
	_outlines.erase(coord)
	if is_instance_valid(outline):
		outline.free()


func _clear_outlines() -> void:
	for coord in _outlines.keys():
		_clear_outline(coord)


func _clear_hexes() -> void:
	_stop_celebrate()
	_clear_score_bubbles()
	_clear_outlines()
	for pivot in _pivots.values():
		var node := pivot as Node
		if is_instance_valid(node):
			node.free()
	_pivots.clear()
	_visuals.clear()
	_state.clear()


func _hide_live_board() -> void:
	if _live_hidden or _orchestrator == null or _orchestrator.hex_manager == null:
		return
	var hex := _orchestrator.hex_manager
	_live_visible = hex.visible
	_live_process_mode = hex.process_mode
	hex.visible = false
	hex.process_mode = Node.PROCESS_MODE_DISABLED
	_live_hidden = true


func _show_live_board() -> void:
	if not _live_hidden:
		return
	if _orchestrator != null and is_instance_valid(_orchestrator) and _orchestrator.hex_manager != null:
		var hex := _orchestrator.hex_manager
		hex.visible = _live_visible
		hex.process_mode = _live_process_mode
	_live_hidden = false
