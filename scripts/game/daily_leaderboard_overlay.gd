extends Control
class_name DailyLeaderboardOverlay

@export var page_size: int = 25

var COLOR_PANEL := Color.html("#F4DFCA")
var COLOR_HEADER := Color.html("#918478")
var COLOR_ROW := Color(1, 1, 1, 0.35)
var COLOR_ROW_ME := Color.html("#E8C9A8")

@onready var _scroll: ScrollContainer = $Panel/Margin/Layout/Scroll
@onready var _row_list: VBoxContainer = $Panel/Margin/Layout/Scroll/RowList
@onready var _status: Label = $Panel/Margin/Layout/StatusLabel
@onready var _update: Button = $Panel/Margin/Layout/ButtonRow/UpdateButton
@onready var _show_me: Button = $Panel/Margin/Layout/ButtonRow/ShowMeButton
@onready var _show_top: Button = $Panel/Margin/Layout/ButtonRow/ShowTopButton
@onready var _close: Button = $Panel/Margin/Layout/ButtonRow/CloseButton
@onready var _panel: PanelContainer = $Panel

var _load_gen: int = 0
var _loading: bool = false
var _suspend_scroll_load: bool = false
var _has_more_below: bool = false
var _loaded_start: int = 0
var _loaded_end: int = 0
var _player_rank: int = 0
var _player_id: String = ""
var _date: String = ""
var _row_normal: StyleBoxFlat
var _row_me: StyleBoxFlat


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	COLOR_PANEL.a = 0.94
	_apply_panel_style()
	_row_normal = _make_row_style(COLOR_ROW)
	_row_me = _make_row_style(COLOR_ROW_ME)
	_update.pressed.connect(_on_update_pressed)
	_show_me.pressed.connect(_on_show_me_pressed)
	_show_top.pressed.connect(_on_show_top_pressed)
	_close.pressed.connect(_on_close_pressed)
	for button in [_update, _show_me, _show_top, _close]:
		if not button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.connect(_on_button_hover)
	var bar := _scroll.get_v_scroll_bar()
	if bar != null:
		bar.value_changed.connect(_on_scroll_value_changed)
	_scroll.resized.connect(_sync_row_list_width)
	_show_me.disabled = true


func is_open() -> bool:
	return visible


func open() -> void:
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_open_async()


func close() -> void:
	_load_gen += 1
	_set_busy(false)
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_rows()
	_status.text = ""
	_show_me.disabled = true


func _apply_panel_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = COLOR_PANEL
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_right = 12
	box.corner_radius_bottom_left = 12
	_panel.add_theme_stylebox_override("panel", box)


func _make_row_style(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_right = 4
	box.corner_radius_bottom_left = 4
	return box


func _set_busy(busy: bool) -> void:
	_loading = busy
	if is_instance_valid(_update):
		_update.disabled = busy


func _open_async() -> void:
	_load_gen += 1
	var gen := _load_gen
	_set_busy(true)
	_clear_rows()
	_loaded_start = 0
	_loaded_end = 0
	_has_more_below = false
	_player_rank = 0
	_player_id = GameSettings.player_id
	_date = GameSession.get_utc_date_iso()
	_show_me.disabled = true
	_status.text = "Loading..."

	if not SupabaseClient.is_configured():
		_status.text = "Leaderboard is not configured."
		_set_busy(false)
		return

	var entry: Dictionary = await SupabaseClient.fetch_player_entry(_date, _player_id)
	if gen != _load_gen:
		return
	if not entry.is_empty():
		_player_rank = int(entry.get("rank", 0))
		_show_me.disabled = _player_rank <= 0

	var offset := 0
	if _player_rank > 0:
		offset = _centered_offset(_player_rank)
	var loaded := await _replace_with_page(offset, gen)
	if gen != _load_gen or not loaded:
		return
	if _player_rank > 0:
		await _center_on_player()
	else:
		_scroll.scroll_vertical = 0


func _centered_offset(rank: int) -> int:
	return maxi(0, rank - 1 - int(page_size / 2.0))


func _replace_with_page(offset: int, gen: int = _load_gen) -> bool:
	_set_busy(true)
	var rows: Array = await SupabaseClient.fetch_page(_date, offset, page_size)
	if gen != _load_gen:
		return false
	_set_busy(false)
	_clear_rows()
	_loaded_start = offset
	_append_rows(rows)
	_sync_loaded_range()
	_has_more_below = rows.size() >= page_size
	_sync_row_list_width()
	if rows.is_empty() and offset == 0:
		if not SupabaseClient.last_error.is_empty():
			_status.text = SupabaseClient.last_error
		else:
			_status.text = "No scores yet today."
	else:
		_status.text = ""
	return true


func _append_rows(rows: Array) -> void:
	for item in rows:
		if typeof(item) == TYPE_DICTIONARY:
			_row_list.add_child(_make_row(item))


func _prepend_rows(rows: Array) -> void:
	for i in range(rows.size() - 1, -1, -1):
		var item: Variant = rows[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := _make_row(item)
		_row_list.add_child(row)
		_row_list.move_child(row, 0)


func _make_row(entry: Dictionary) -> PanelContainer:
	var rank := int(entry.get("rank", 0))
	var player_id := str(entry.get("player_id", ""))
	var is_me := player_id == _player_id and not player_id.is_empty()
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", _row_me if is_me else _row_normal)
	row.set_meta("player_id", player_id)
	row.set_meta("rank", rank)
	row.custom_minimum_size = Vector2(0, 28)

	var cols := HBoxContainer.new()
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_theme_constant_override("separation", 12)
	row.add_child(cols)

	var rank_label := _make_cell("%d" % rank, 56)
	var name_label := _make_cell(str(entry.get("name", "")), 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var points_label := _make_cell("%d" % int(entry.get("points", 0)), 72)
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cols.add_child(rank_label)
	cols.add_child(name_label)
	cols.add_child(points_label)
	return row


func _make_cell(text: String, min_width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", COLOR_HEADER)
	label.add_theme_font_size_override("font_size", 16)
	if min_width > 0.0:
		label.custom_minimum_size = Vector2(min_width, 0)
	label.clip_text = true
	return label


func _clear_rows() -> void:
	for child in _row_list.get_children():
		_row_list.remove_child(child)
		child.queue_free()


func _sync_row_list_width() -> void:
	var width := _scroll.size.x
	var bar := _scroll.get_v_scroll_bar()
	if bar != null and bar.visible:
		width -= bar.size.x
	_row_list.custom_minimum_size.x = maxf(width, 0.0)


func _sync_loaded_range() -> void:
	var children := _row_list.get_children()
	if children.is_empty():
		_loaded_start = 0
		_loaded_end = 0
		return
	_loaded_start = maxi(int(children[0].get_meta("rank", 1)) - 1, 0)
	_loaded_end = int(children[children.size() - 1].get_meta("rank", 0))


func _find_player_row() -> Control:
	for child in _row_list.get_children():
		if str(child.get_meta("player_id", "")) == _player_id:
			return child as Control
	return null


func _center_on_player() -> void:
	var row := _find_player_row()
	if row == null:
		return
	await _center_row(row)


func _center_row(row: Control) -> void:
	_suspend_scroll_load = true
	await get_tree().process_frame
	if not is_inside_tree() or not is_instance_valid(row):
		_suspend_scroll_load = false
		return
	var view_h := _scroll.size.y
	var target := int(row.position.y + row.size.y * 0.5 - view_h * 0.5)
	_scroll.scroll_vertical = maxi(target, 0)
	await get_tree().process_frame
	_suspend_scroll_load = false


func _on_scroll_value_changed(_value: float) -> void:
	if _loading or _suspend_scroll_load or not visible:
		return
	var bar := _scroll.get_v_scroll_bar()
	if bar == null:
		return
	if _scroll.scroll_vertical <= 48 and _loaded_start > 0:
		_load_previous()
	elif _has_more_below and _scroll.scroll_vertical >= bar.max_value - bar.page - 48:
		_load_next()


func _load_next() -> void:
	if _loading:
		return
	var gen := _load_gen
	_set_busy(true)
	var rows: Array = await SupabaseClient.fetch_page(_date, _loaded_end, page_size)
	if gen != _load_gen:
		return
	_set_busy(false)
	_append_rows(rows)
	_sync_loaded_range()
	_has_more_below = rows.size() >= page_size
	_sync_row_list_width()


func _load_previous() -> void:
	if _loading or _loaded_start <= 0:
		return
	var gen := _load_gen
	var offset := maxi(_loaded_start - page_size, 0)
	var count := _loaded_start - offset
	_set_busy(true)
	_suspend_scroll_load = true
	var old_scroll := _scroll.scroll_vertical
	var old_height := _row_list.size.y
	var rows: Array = await SupabaseClient.fetch_page(_date, offset, count)
	if gen != _load_gen:
		_suspend_scroll_load = false
		return
	_set_busy(false)
	if rows.is_empty():
		_suspend_scroll_load = false
		return
	_prepend_rows(rows)
	_sync_loaded_range()
	await get_tree().process_frame
	_sync_row_list_width()
	var new_height := _row_list.size.y
	_scroll.scroll_vertical = old_scroll + int(new_height - old_height)
	await get_tree().process_frame
	_suspend_scroll_load = false


func _on_update_pressed() -> void:
	GameFeedback.play_click_button()
	if _loading:
		return
	if _row_list.get_child_count() == 0:
		_open_async()
		return
	await _update_merge_async()


func _update_merge_async() -> void:
	_load_gen += 1
	var gen := _load_gen
	_set_busy(true)
	_status.text = "Updating..."

	var entry: Dictionary = await SupabaseClient.fetch_player_entry(_date, _player_id)
	if gen != _load_gen:
		return
	if not entry.is_empty():
		_player_rank = int(entry.get("rank", 0))
		_show_me.disabled = _player_rank <= 0
	else:
		_player_rank = 0
		_show_me.disabled = true

	var offset := _loaded_start
	var count := maxi(_loaded_end - _loaded_start, page_size)
	var fetched: Array = []
	var remaining := count
	var page_offset := offset
	while remaining > 0:
		var take := mini(remaining, page_size)
		var page: Array = await SupabaseClient.fetch_page(_date, page_offset, take)
		if gen != _load_gen:
			return
		if page.is_empty():
			break
		fetched.append_array(page)
		if page.size() < take:
			break
		page_offset += page.size()
		remaining -= page.size()

	if gen != _load_gen:
		return
	_set_busy(false)

	if fetched.is_empty() and offset == 0:
		_merge_rows(fetched)
		if not SupabaseClient.last_error.is_empty():
			_status.text = SupabaseClient.last_error
		else:
			_status.text = "No scores yet today."
		return
	if fetched.is_empty() and not SupabaseClient.last_error.is_empty():
		_status.text = SupabaseClient.last_error
		return

	_has_more_below = fetched.size() >= count
	_merge_rows(fetched)
	_status.text = ""


func _merge_rows(fetched: Array) -> void:
	var by_id: Dictionary = {}
	for child in _row_list.get_children():
		var pid := str(child.get_meta("player_id", ""))
		if not pid.is_empty():
			by_id[pid] = child

	var seen: Dictionary = {}
	for item in fetched:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var pid := str(item.get("player_id", ""))
		if pid.is_empty():
			continue
		seen[pid] = true
		if by_id.has(pid):
			_update_row(by_id[pid], item)
		else:
			var row := _make_row(item)
			_row_list.add_child(row)
			by_id[pid] = row

	var to_remove: Array = []
	for child in _row_list.get_children():
		if not seen.has(str(child.get_meta("player_id", ""))):
			to_remove.append(child)
	for child in to_remove:
		_row_list.remove_child(child)
		child.queue_free()

	_sort_rows_by_rank()
	_sync_loaded_range()
	_sync_row_list_width()


func _update_row(row: PanelContainer, entry: Dictionary) -> void:
	var rank := int(entry.get("rank", 0))
	var player_id := str(entry.get("player_id", ""))
	var is_me := player_id == _player_id and not player_id.is_empty()
	row.add_theme_stylebox_override("panel", _row_me if is_me else _row_normal)
	row.set_meta("player_id", player_id)
	row.set_meta("rank", rank)
	if row.get_child_count() == 0:
		return
	var cols := row.get_child(0) as HBoxContainer
	if cols == null or cols.get_child_count() < 3:
		return
	(cols.get_child(0) as Label).text = "%d" % rank
	(cols.get_child(1) as Label).text = str(entry.get("name", ""))
	(cols.get_child(2) as Label).text = "%d" % int(entry.get("points", 0))


func _sort_rows_by_rank() -> void:
	var children := _row_list.get_children()
	children.sort_custom(func(a: Node, b: Node) -> bool:
		return int(a.get_meta("rank", 0)) < int(b.get_meta("rank", 0))
	)
	for i in children.size():
		_row_list.move_child(children[i], i)


func _on_show_me_pressed() -> void:
	GameFeedback.play_click_button()
	if _player_rank <= 0:
		return
	var row := _find_player_row()
	if row != null:
		await _center_row(row)
		return
	var gen := _load_gen
	var loaded := await _replace_with_page(_centered_offset(_player_rank), gen)
	if gen != _load_gen or not loaded:
		return
	await _center_on_player()


func _on_show_top_pressed() -> void:
	GameFeedback.play_click_button()
	if _loaded_start == 0:
		_scroll.scroll_vertical = 0
		return
	var gen := _load_gen
	var loaded := await _replace_with_page(0, gen)
	if gen != _load_gen or not loaded:
		return
	_scroll.scroll_vertical = 0


func _on_close_pressed() -> void:
	GameFeedback.play_click_button()
	close()


func _on_button_hover() -> void:
	GameFeedback.play_hover_button()
