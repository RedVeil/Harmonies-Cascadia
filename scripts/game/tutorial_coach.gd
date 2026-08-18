extends CanvasLayer
class_name TutorialCoach
## Presentation-only coach: authored highlight frames and text bubble.

signal continue_pressed
signal skip_pressed

const COACH_LAYER_DEFAULT := 12
const COACH_LAYER_MENU := 20
const MENU_HIGHLIGHTS := ["end_session", "share"]

@export_group("Hex Highlight")
## Pixels to shift every hex spotlight up (positive = up). Tune on TutorialCoach.
@export var hex_highlight_up: float = 48.0
## Extra pixels around the projected tile.
@export var hex_highlight_pad: float = 10.0

@onready var _highlights: Control = $Highlights
@onready var _bubble: Panel = $Bubble
@onready var _title: Label = $Bubble/Margin/VBox/Title
@onready var _body: Label = $Bubble/Margin/VBox/Body
@onready var _continue_button: Button = $Bubble/Margin/VBox/ButtonRow/ContinueButton
@onready var _skip_button: Button = $Bubble/Margin/VBox/ButtonRow/SkipButton
@onready var _stars_row: HBoxContainer = $Bubble/Margin/VBox/StarsRow

var COLOR_STAR_BRONZE := Color.html("#C4783B")
var COLOR_STAR_SILVER := Color.html("#C8C8CC")
var COLOR_STAR_GOLD := Color.html("#F2B05C")

var _visible_highlight: Control = null
var _bubble_side: String = ""
var _track_hex: bool = false
var _tracked_hex_coord := Vector2i.ZERO
var _hex_container: HexTileContainer = null
var _modal_bubble_size := Vector2.ZERO


func _ready() -> void:
	layer = COACH_LAYER_DEFAULT
	hide()
	_hide_all_highlights()
	_continue_button.pressed.connect(_on_continue)
	_continue_button.mouse_entered.connect(_on_button_mouse_entered)
	_skip_button.pressed.connect(_on_skip)
	_skip_button.mouse_entered.connect(_on_button_mouse_entered)
	get_viewport().size_changed.connect(_on_viewport_resized)
	if _stars_row:
		_stars_row.hide()


func _process(_delta: float) -> void:
	if not visible or not _track_hex:
		return
	_sync_hex_highlight()


func _on_button_mouse_entered() -> void:
	GameFeedback.play_hover_button()


func show_centered_modal(title: String, body: String, button_label: String, ratings: Dictionary = {}) -> void:
	_modal_bubble_size = Vector2(380, 280)
	GameFeedback.play_open_popup()
	show_step({
		"title": title,
		"body": body,
		"complete": {"label": button_label},
	}, "none", true)
	_apply_rating_stars(ratings)


func show_step(step: Dictionary, highlight_name: String, show_continue: bool) -> void:
	_apply_rating_stars({})
	_title.text = str(step.get("title", ""))
	_body.text = str(step.get("body", ""))
	_continue_button.visible = show_continue
	var complete: Dictionary = step.get("complete", {})
	if typeof(complete) != TYPE_DICTIONARY:
		complete = {}
	_continue_button.text = str(complete.get("label", "Continue"))
	var skip_label := str(complete.get("skip_label", ""))
	_skip_button.visible = not skip_label.is_empty()
	if _skip_button.visible:
		_skip_button.text = skip_label
	_bubble_side = str(step.get("bubble_side", "")).to_lower()
	if highlight_name in MENU_HIGHLIGHTS:
		layer = COACH_LAYER_MENU
	else:
		layer = COACH_LAYER_DEFAULT
	_show_highlight(highlight_name)
	if _track_hex:
		_sync_hex_highlight()
	_place_bubble(_highlight_rect())
	show()
	# #region agent log
	call_deferred("_debug_log_menu_highlight", highlight_name, "post-fix")
	# #endregion


func hide_coach() -> void:
	layer = COACH_LAYER_DEFAULT
	_modal_bubble_size = Vector2.ZERO
	_apply_rating_stars({})
	_hide_all_highlights()
	hide()


func _apply_rating_stars(ratings: Dictionary) -> void:
	if _stars_row == null:
		return
	if ratings.is_empty():
		_stars_row.hide()
		return
	var values: Array[int] = [
		int(ratings.get("bronze", 0)),
		int(ratings.get("silver", 0)),
		int(ratings.get("gold", 0)),
	]
	var colors: Array[Color] = [
		COLOR_STAR_BRONZE,
		COLOR_STAR_SILVER,
		COLOR_STAR_GOLD,
	]
	var cols := _stars_row.get_children()
	for i in mini(values.size(), cols.size()):
		var col := cols[i] as Control
		if col == null:
			continue
		var icon := col.get_node_or_null("Icon") as TextureRect
		var points := col.get_node_or_null("Points") as Label
		if icon:
			icon.custom_minimum_size = Vector2(32, 32)
			icon.modulate = colors[i]
		if points:
			points.text = str(values[i])
	_stars_row.show()


func _show_highlight(highlight_name: String) -> void:
	if _visible_highlight:
		_visible_highlight.hide()
		_visible_highlight = null
	_track_hex = false
	if highlight_name.is_empty() or highlight_name == "none":
		return
	var node := _highlights.get_node_or_null(NodePath(highlight_name)) as Control
	if node == null:
		push_warning("TutorialCoach: no highlight named '%s'" % highlight_name)
		return
	node.show()
	_visible_highlight = node
	_track_hex = _parse_hex_highlight(highlight_name)


func _hide_all_highlights() -> void:
	_visible_highlight = null
	_track_hex = false
	if _highlights == null:
		return
	for child in _highlights.get_children():
		if child is CanvasItem:
			(child as CanvasItem).hide()


func _parse_hex_highlight(highlight_name: String) -> bool:
	if not highlight_name.begins_with("hex_"):
		return false
	var parts := highlight_name.split("_")
	if parts.size() != 3 or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return false
	_tracked_hex_coord = Vector2i(int(parts[1]), int(parts[2]))
	return true


func _sync_hex_highlight() -> void:
	if _visible_highlight == null or not is_instance_valid(_visible_highlight):
		return
	var rect := _hex_screen_rect(_tracked_hex_coord)
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	_visible_highlight.anchor_left = 0.0
	_visible_highlight.anchor_top = 0.0
	_visible_highlight.anchor_right = 0.0
	_visible_highlight.anchor_bottom = 0.0
	_visible_highlight.offset_left = rect.position.x
	_visible_highlight.offset_top = rect.position.y
	_visible_highlight.offset_right = rect.end.x
	_visible_highlight.offset_bottom = rect.end.y


func _hex_screen_rect(coord: Vector2i) -> Rect2:
	var container := _resolve_hex_container()
	var camera := get_viewport().get_camera_3d()
	if container == null or camera == null:
		return Rect2()
	var center := Vector3.ZERO
	if container.tiles_by_coord.has(coord):
		center = container.tiles_by_coord[coord].global_position
	else:
		center = container.to_global(HexCoord.axial_to_world(coord, container.hex_size))
	var radius := container.hex_size
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for height in [0.0, radius * 0.45]:
		for i in 6:
			var angle := deg_to_rad(60.0 * float(i))
			var world := center + Vector3(cos(angle) * radius, height, sin(angle) * radius)
			var screen := camera.unproject_position(world)
			min_p.x = minf(min_p.x, screen.x)
			min_p.y = minf(min_p.y, screen.y)
			max_p.x = maxf(max_p.x, screen.x)
			max_p.y = maxf(max_p.y, screen.y)
	if not is_finite(min_p.x) or not is_finite(max_p.x):
		return Rect2()
	var origin := min_p - Vector2(hex_highlight_pad, hex_highlight_pad + hex_highlight_up)
	var size := (max_p - min_p) + Vector2(hex_highlight_pad * 2.0, hex_highlight_pad * 2.0)
	return Rect2(origin, size)


func _resolve_hex_container() -> HexTileContainer:
	if _hex_container != null and is_instance_valid(_hex_container):
		return _hex_container
	var node := get_tree().root.find_child("HexTileContainer", true, false)
	_hex_container = node as HexTileContainer
	return _hex_container


func _highlight_rect() -> Rect2:
	if _visible_highlight == null or not is_instance_valid(_visible_highlight):
		return Rect2()
	return _visible_highlight.get_global_rect()


func _place_bubble(highlight_rect: Rect2) -> void:
	var vp := get_viewport().get_visible_rect().size
	var bubble_size := _modal_bubble_size if _modal_bubble_size != Vector2.ZERO else Vector2(360, 200)
	_bubble.custom_minimum_size = bubble_size
	var pos := Vector2((vp.x - bubble_size.x) * 0.5, (vp.y - bubble_size.y) * 0.5)
	if highlight_rect.size.x > 1.0:
		match _bubble_side:
			"left":
				pos = Vector2(
					clampf(highlight_rect.position.x - bubble_size.x - 16.0, 16.0, vp.x - bubble_size.x - 16.0),
					clampf(highlight_rect.get_center().y - bubble_size.y * 0.5, 16.0, vp.y - bubble_size.y - 16.0)
				)
			"right":
				pos = Vector2(
					clampf(highlight_rect.end.x + 16.0, 16.0, vp.x - bubble_size.x - 16.0),
					clampf(highlight_rect.get_center().y - bubble_size.y * 0.5, 16.0, vp.y - bubble_size.y - 16.0)
				)
			"above":
				pos = Vector2(
					clampf(highlight_rect.get_center().x - bubble_size.x * 0.5, 16.0, vp.x - bubble_size.x - 16.0),
					clampf(highlight_rect.position.y - bubble_size.y - 16.0, 16.0, vp.y - bubble_size.y - 16.0)
				)
			"above_left":
				pos = Vector2(
					clampf(highlight_rect.position.x - bubble_size.x - 16.0, 16.0, vp.x - bubble_size.x - 16.0),
					clampf(highlight_rect.position.y - bubble_size.y - 16.0, 16.0, vp.y - bubble_size.y - 16.0)
				)
			"above_right":
				pos = Vector2(
					clampf(highlight_rect.end.x + 16.0, 16.0, vp.x - bubble_size.x - 16.0),
					clampf(highlight_rect.position.y - bubble_size.y - 16.0, 16.0, vp.y - bubble_size.y - 16.0)
				)
			"below":
				pos = Vector2(
					clampf(highlight_rect.get_center().x - bubble_size.x * 0.5, 16.0, vp.x - bubble_size.x - 16.0),
					clampf(highlight_rect.end.y + 16.0, 16.0, vp.y - bubble_size.y - 16.0)
				)
			_:
				var above := highlight_rect.position.y - bubble_size.y - 16.0
				if above > 16.0:
					pos = Vector2(
						clampf(highlight_rect.get_center().x - bubble_size.x * 0.5, 16.0, vp.x - bubble_size.x - 16.0),
						above
					)
				else:
					var below := highlight_rect.end.y + 16.0
					if below + bubble_size.y < vp.y - 16.0:
						pos = Vector2(
							clampf(highlight_rect.get_center().x - bubble_size.x * 0.5, 16.0, vp.x - bubble_size.x - 16.0),
							below
						)
	_bubble.position = pos
	_bubble.size = bubble_size


func _on_viewport_resized() -> void:
	if not visible:
		return
	_place_bubble(_highlight_rect())
	# #region agent log
	if _visible_highlight:
		_debug_log_menu_highlight(_visible_highlight.name, "post-fix")
	# #endregion


func _on_continue() -> void:
	GameFeedback.play_click_button()
	continue_pressed.emit()


func _on_skip() -> void:
	GameFeedback.play_click_button()
	skip_pressed.emit()


# #region agent log
func _debug_log_menu_highlight(highlight_name: String, run_id: String) -> void:
	if highlight_name != "share" and highlight_name != "end_session":
		return
	var vp := get_viewport().get_visible_rect()
	var win := DisplayServer.window_get_size()
	var hl_rect := Rect2()
	var hl_off := {}
	if _visible_highlight:
		hl_rect = _visible_highlight.get_global_rect()
		hl_off = {
			"off_l": _visible_highlight.offset_left,
			"off_t": _visible_highlight.offset_top,
			"off_r": _visible_highlight.offset_right,
			"off_b": _visible_highlight.offset_bottom,
			"anchor_l": _visible_highlight.anchor_left,
			"anchor_r": _visible_highlight.anchor_right,
			"clip": _visible_highlight.clip_contents,
		}
	var menu_data := {}
	var menu := get_tree().root.find_child("InGameMenu", true, false)
	if menu:
		var left_col: Control = menu.get_node_or_null("Root/Split/LeftColumn")
		var action_row: Control = menu.get_node_or_null("Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow")
		var share_btn: Control = menu.get_node_or_null("Root/Split/LeftColumn/Margin/NavStack/EndSessionBlock/ActionRow/ShareButton")
		var end_btn: Control = menu.get_node_or_null("Root/Split/LeftColumn/Margin/NavStack/RootNav/EndSessionButton")
		if left_col:
			menu_data["left_col"] = {"x": left_col.get_global_rect().position.x, "y": left_col.get_global_rect().position.y, "w": left_col.get_global_rect().size.x, "h": left_col.get_global_rect().size.y}
		if action_row:
			menu_data["action_row"] = {"x": action_row.get_global_rect().position.x, "y": action_row.get_global_rect().position.y, "w": action_row.get_global_rect().size.x, "h": action_row.get_global_rect().size.y}
		if share_btn:
			menu_data["share_btn"] = {"x": share_btn.get_global_rect().position.x, "y": share_btn.get_global_rect().position.y, "w": share_btn.get_global_rect().size.x, "h": share_btn.get_global_rect().size.y, "visible": share_btn.visible}
		if end_btn:
			menu_data["end_session_btn"] = {"x": end_btn.get_global_rect().position.x, "y": end_btn.get_global_rect().position.y, "w": end_btn.get_global_rect().size.x, "h": end_btn.get_global_rect().size.y, "visible": end_btn.visible}
		if left_col and hl_rect.size.x > 0.0:
			menu_data["overflow_right"] = hl_rect.end.x - left_col.get_global_rect().end.x
	var data := {
		"highlight": highlight_name,
		"vp_w": vp.size.x,
		"vp_h": vp.size.y,
		"win_w": win.x,
		"win_h": win.y,
		"hl_x": hl_rect.position.x,
		"hl_y": hl_rect.position.y,
		"hl_w": hl_rect.size.x,
		"hl_h": hl_rect.size.y,
		"hl_end_x": hl_rect.end.x,
		"highlights_clip": _highlights.clip_contents,
		"highlights_w": _highlights.size.x,
		"offsets": hl_off,
		"menu": menu_data,
	}
	_agent_log("A,B,C,D,E", "tutorial_coach.gd:_debug_log_menu_highlight", "menu highlight vs sidebar", data, run_id)


func _agent_log(hypothesis_id: String, location: String, message: String, data: Dictionary, run_id: String) -> void:
	var payload := {
		"sessionId": "901c2e",
		"hypothesisId": hypothesis_id,
		"location": location,
		"message": message,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
		"runId": run_id,
	}
	var path := ProjectSettings.globalize_path("res://debug-901c2e.log")
	var f: FileAccess
	if FileAccess.file_exists(path):
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		if f:
			f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_line(JSON.stringify(payload))
		f.close()
# #endregion
