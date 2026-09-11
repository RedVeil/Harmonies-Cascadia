extends Node
## Central UI / world palette. Apply at boot and whenever the player picks a theme.

signal theme_changed

const TILE_SHADOW_PATH := "res://assets/tiles/materials/ground/TileShadow.tres"
const TITLE_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Dangrek-Regular.ttf")
const HINT_ALPHA := 0.7
const BUTTON_HOVER_ALPHA := 0.5
const CHIP_BORDER_WIDTH := 2
const SUBTITLE_FONT_SIZE := 20
const DEFAULT_ID := "ocean-dark"
const THEME_STRIP_WIDTH := 64
const THEME_STRIP_HEIGHT := 16
const TOGGLE_WIDTH := 48
const TOGGLE_HEIGHT := 24
const TOGGLE_BORDER := 2.0
const TOGGLE_THUMB_INSET := 2.0

var THEMES := {
	"ocean-dark": {
		"name": "Ocean Dark",
		"primary": Color.html("#6fb3bf"),
		"secondary": Color.html("#4d9fae"),
		"menu": Color.html("#4d9fae"),
		"text": Color.html("#FFFFFF"),
	},
	"ocean-light": {
		"name": "Ocean Light",
		"primary": Color.html("#6fb3bf"),
		"secondary": Color.html("#4d9fae"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#4d9fae"),
	},
	"orange-dark": {
		"name": "Orange Dark",
		"primary": Color.html("#e8b38b"),
		"secondary": Color.html("#e09760"),
		"menu": Color.html("#e09760"),
		"text": Color.html("#FFFFFF"),
	},
	"orange-light": {
		"name": "Orange Light",
		"primary": Color.html("#e8b38b"),
		"secondary": Color.html("#e09760"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#e09760"),
	},
	"forest-dark": {
		"name": "Forest Dark",
		"primary": Color.html("#6B8F71"),
		"secondary": Color.html("#2C3A30"),
		"menu": Color.html("#2C3A30"),
		"text": Color.html("#FFFFFF"),
	},
	"forest-light": {
		"name": "Forest Light",
		"primary": Color.html("#6B8F71"),
		"secondary": Color.html("#2C3A30"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#2C3A30"),
	},
	"beige-dark": {
		"name": "Beige Dark",
		"primary": Color.html("#d1bfab"),
		"secondary": Color.html("#8b4f3a"),
		"menu": Color.html("#786452"),
		"text": Color.html("#f4dfca"),
	},
	"beige-light": {
		"name": "Beige Light",
		"primary": Color.html("#d1bfab"),
		"secondary": Color.html("#8b4f3a"),
		"menu": Color.html("#f4dfca"),
		"text": Color.html("#786452"),
	},
	"yellow-pastel-dark": {
		"name": "Yellow Pastel Dark",
		"primary": Color.html("#f4c48c"),
		"secondary": Color.html("#f0ac5d"),
		"menu": Color.html("#f0ac5d"),
		"text": Color.html("#FFFFFF"),
	},
	"yellow-pastel-light": {
		"name": "Yellow Pastel Light",
		"primary": Color.html("#f4c48c"),
		"secondary": Color.html("#f0ac5d"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#f0ac5d"),
	},
	"orange-pastel-dark": {
		"name": "Orange Pastel Dark",
		"primary": Color.html("#e8b38b"),
		"secondary": Color.html("#e09760"),
		"menu": Color.html("#e09760"),
		"text": Color.html("#FFFFFF"),
	},
	"orange-pastel-light": {
		"name": "Orange Pastel Light",
		"primary": Color.html("#e8b38b"),
		"secondary": Color.html("#e09760"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#e09760"),
	},
	"blue-pastel-dark": {
		"name": "Blue Pastel Dark",
		"primary": Color.html("#c8daf3"),
		"secondary": Color.html("#9ebeea"),
		"menu": Color.html("#9ebeea"),
		"text": Color.html("#FFFFFF"),
	},
	"blue-pastel-light": {
		"name": "Blue Pastel Light",
		"primary": Color.html("#c8daf3"),
		"secondary": Color.html("#9ebeea"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#92b0d9"),
	},
	"green-pastel-dark": {
		"name": "Green Pastel Dark",
		"primary": Color.html("#aaecd0"),
		"secondary": Color.html("#68ab8e"),
		"menu": Color.html("#68ab8e"),
		"text": Color.html("#FFFFFF"),
	},
	"green-pastel-light": {
		"name": "Green Pastel Light",
		"primary": Color.html("#aaecd0"),
		"secondary": Color.html("#68ab8e"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#68ab8e"),
	},
	"pink-pastel-dark": {
		"name": "Pink Pastel Dark",
		"primary": Color.html("#f3c8da"),
		"secondary": Color.html("#ea9ebe"),
		"menu": Color.html("#ea9ebe"),
		"text": Color.html("#FFFFFF"),
	},
	"pink-pastel-light": {
		"name": "Pink Pastel Light",
		"primary": Color.html("#f3c8da"),
		"secondary": Color.html("#ea9ebe"),
		"menu": Color.html("#FFFFFF"),
		"text": Color.html("#ea9ebe"),
	},
}

var theme_id: String = DEFAULT_ID
var primary: Color = Color.html("#6FB3BF")
var secondary: Color = Color.html("#4D9FAE")
var menu: Color = Color.html("#B4A594")
var text: Color = Color.html("#FFFFFF")
var hud_background := Color.WHITE
var points_positive := Color.GOLD
var points_negative := Color.CRIMSON
var highlight := Color(1.0, 1.0, 0.6350498, 1.0)

var _tile_shadow: StandardMaterial3D
var _nav_empty := StyleBoxEmpty.new()
var _empty_icon: Texture2D
var _strip_icons: Dictionary = {}
var _toggle_icons: Dictionary = {}


func _ready() -> void:
	_add_latin_fallback(TITLE_FONT)
	_add_latin_fallback(BODY_FONT)
	_tile_shadow = load(TILE_SHADOW_PATH) as StandardMaterial3D
	var stored := DEFAULT_ID
	if GameSettings != null:
		stored = GameSettings.theme_id
	_apply_palette(stored)
	apply()
	call_deferred("_watch_tree")


func _watch_tree() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_world_environment(node as WorldEnvironment)
	elif node is MeshInstance3D or node is MultiMeshInstance3D:
		_patch_mesh_node.call_deferred(node)


func bind_node(node: Node, callback: Callable) -> void:
	if node == null or not callback.is_valid():
		return
	if not theme_changed.is_connected(callback):
		theme_changed.connect(callback)
	if not node.tree_exiting.is_connected(_unbind_callback):
		node.tree_exiting.connect(_unbind_callback.bind(callback), CONNECT_ONE_SHOT)


func _unbind_callback(callback: Callable) -> void:
	if theme_changed.is_connected(callback):
		theme_changed.disconnect(callback)


func theme_display_name(id: String) -> String:
	var fallback := id
	var data = THEMES.get(id, {})
	if typeof(data) == TYPE_DICTIONARY:
		fallback = str(data.get("name", id))
	return Loc.ui("theme.%s" % id, fallback)


func theme_colors(id: String) -> Dictionary:
	var data = THEMES.get(id, {})
	if typeof(data) == TYPE_DICTIONARY:
		return data
	return THEMES[DEFAULT_ID]


func theme_strip_icon(id: String) -> Texture2D:
	if not THEMES.has(id):
		id = DEFAULT_ID
	if _strip_icons.has(id):
		return _strip_icons[id]
	var colors := theme_colors(id)
	var keys := ["primary", "secondary", "menu", "text"]
	var img := Image.create(THEME_STRIP_WIDTH, THEME_STRIP_HEIGHT, false, Image.FORMAT_RGBA8)
	var band := int(float(THEME_STRIP_WIDTH) / float(keys.size()))
	for i in keys.size():
		var x0 := i * band
		var width := THEME_STRIP_WIDTH - x0 if i == keys.size() - 1 else band
		img.fill_rect(Rect2i(x0, 0, width, THEME_STRIP_HEIGHT), colors[keys[i]])
	var texture := ImageTexture.create_from_image(img)
	_strip_icons[id] = texture
	return texture


func set_theme_id(id: String) -> void:
	if not THEMES.has(id):
		id = DEFAULT_ID
	_apply_palette(id)
	if GameSettings != null:
		GameSettings.theme_id = theme_id
		GameSettings.save_to_disk()
	apply()


func apply() -> void:
	_apply_tile_shadow()
	_apply_world_environments()
	theme_changed.emit()


func hint_color() -> Color:
	return with_alpha(text, HINT_ALPHA)


func placeholder_color() -> Color:
	return with_alpha(text, 0.55)


func with_alpha(color: Color, alpha: float) -> Color:
	var c := color
	c.a = alpha
	return c


func apply_hud_circle(background: CanvasItem, icon: CanvasItem, hovered: bool, enabled: bool = true) -> void:
	if background == null or icon == null:
		return
	background.self_modulate = hud_background
	if not enabled:
		icon.self_modulate = Color.GRAY
		return
	if hovered:
		background.self_modulate = secondary
		icon.self_modulate = hud_background
	else:
		background.self_modulate = hud_background
		icon.self_modulate = secondary


func apply_rect_button(background: ColorRect, label: Label, hovered: bool, enabled: bool = true) -> void:
	if background == null or label == null:
		return
	if not enabled:
		background.color = Color(0.85, 0.85, 0.85, 1.0)
		label.add_theme_color_override("font_color", Color.GRAY)
		return
	if hovered:
		background.color = with_alpha(text, BUTTON_HOVER_ALPHA)
		label.add_theme_color_override("font_color", hud_background)
	else:
		background.color = text
		label.add_theme_color_override("font_color", menu)


func make_chip_style(bg: Color, h_margin: float = 12.0, v_margin: float = 2.0, corner_radius: int = 0, border_color: Variant = null) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.content_margin_left = h_margin
	style.content_margin_top = v_margin
	style.content_margin_right = h_margin
	style.content_margin_bottom = v_margin
	style.set_border_width_all(CHIP_BORDER_WIDTH)
	style.border_color = text if border_color == null else (border_color as Color)
	if corner_radius > 0:
		style.set_corner_radius_all(corner_radius)
	return style


func style_chip_button(button: BaseButton, h_margin: float = 12.0, v_margin: float = 2.0, corner_radius: int = 0) -> void:
	if button == null:
		return
	var fill_idle := make_chip_style(text, h_margin, v_margin, corner_radius)
	var fill_invert := make_chip_style(menu, h_margin, v_margin, corner_radius)
	var faded := with_alpha(text, 0.45)
	var fill_disabled := make_chip_style(faded, h_margin, v_margin, corner_radius, faded)
	button.add_theme_color_override("font_color", menu)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_hover_pressed_color", text)
	button.add_theme_color_override("font_focus_color", menu)
	button.add_theme_color_override("font_disabled_color", with_alpha(menu, 0.45))
	button.add_theme_color_override("icon_normal_color", menu)
	button.add_theme_color_override("icon_hover_color", text)
	button.add_theme_color_override("icon_pressed_color", text)
	button.add_theme_color_override("icon_hover_pressed_color", text)
	button.add_theme_color_override("icon_focus_color", menu)
	button.add_theme_color_override("icon_disabled_color", with_alpha(menu, 0.45))
	button.add_theme_stylebox_override("normal", fill_idle)
	button.add_theme_stylebox_override("hover", fill_invert)
	button.add_theme_stylebox_override("pressed", fill_invert)
	button.add_theme_stylebox_override("hover_pressed", fill_invert)
	button.add_theme_stylebox_override("focus", _nav_empty)
	button.add_theme_stylebox_override("disabled", fill_disabled)


func apply_title_font(control: Control) -> void:
	if control == null:
		return
	control.add_theme_font_override("font", TITLE_FONT)


func _add_latin_fallback(font: Font) -> void:
	if font == null:
		return
	for existing in font.fallbacks:
		if existing is SystemFont:
			return
	var fallback := SystemFont.new()
	fallback.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "DejaVu Sans", "Arial"])
	var next: Array[Font] = []
	next.assign(font.fallbacks)
	next.append(fallback)
	font.fallbacks = next


func style_title_label(label: Label) -> void:
	if label == null:
		return
	apply_title_font(label)
	style_label(label)


func style_nav_button(button: Button, font_size: int = -1) -> void:
	if button == null:
		return
	button.flat = true
	apply_title_font(button)
	if font_size > 0:
		button.add_theme_font_size_override("font_size", font_size)
	var font_hover := with_alpha(text, BUTTON_HOVER_ALPHA)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", font_hover)
	button.add_theme_color_override("font_pressed_color", font_hover)
	button.add_theme_color_override("font_focus_color", font_hover)
	button.add_theme_color_override("font_disabled_color", with_alpha(text, 0.4))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _nav_empty)


func style_label(label: Label, hint: bool = false) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color", hint_color() if hint else text)


func style_subtitle_label(label: Label) -> void:
	if label == null:
		return
	style_label(label)
	label.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)


func style_check_button(button: CheckButton, font_size: int = -1) -> void:
	if button == null:
		return
	if font_size > 0:
		button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_pressed_color", text)
	button.add_theme_color_override("font_hover_color", with_alpha(text, BUTTON_HOVER_ALPHA))
	button.add_theme_color_override("font_focus_color", with_alpha(text, BUTTON_HOVER_ALPHA))
	button.add_theme_color_override("font_disabled_color", with_alpha(text, 0.4))
	var off_icon := _toggle_icon(false)
	var on_icon := _toggle_icon(true)
	for icon_name in [
		"unchecked",
		"unchecked_mirrored",
		"unchecked_disabled",
		"unchecked_disabled_mirrored",
	]:
		button.add_theme_icon_override(icon_name, off_icon)
	for icon_name in [
		"checked",
		"checked_mirrored",
		"checked_disabled",
		"checked_disabled_mirrored",
	]:
		button.add_theme_icon_override(icon_name, on_icon)
	for color_name in [
		"icon_normal_color",
		"icon_pressed_color",
		"icon_hover_color",
		"icon_hover_pressed_color",
		"icon_focus_color",
		"icon_disabled_color",
	]:
		button.add_theme_color_override(color_name, Color.WHITE)


func style_line_edit(line_edit: LineEdit) -> void:
	if line_edit == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = with_alpha(text, 0.22)
	box.set_border_width_all(1)
	box.border_color = with_alpha(text, 0.7)
	box.content_margin_left = 12.0
	box.content_margin_top = 8.0
	box.content_margin_right = 12.0
	box.content_margin_bottom = 8.0
	line_edit.add_theme_color_override("font_color", text)
	line_edit.add_theme_color_override("font_placeholder_color", placeholder_color())
	line_edit.add_theme_color_override("caret_color", text)
	line_edit.add_theme_stylebox_override("normal", box)
	line_edit.add_theme_stylebox_override("read_only", box)
	line_edit.add_theme_stylebox_override("focus", box)


func style_text_edit(edit: TextEdit) -> void:
	if edit == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = with_alpha(text, 0.22)
	box.set_border_width_all(1)
	box.border_color = with_alpha(text, 0.7)
	box.content_margin_left = 8.0
	box.content_margin_top = 8.0
	box.content_margin_right = 8.0
	box.content_margin_bottom = 8.0
	edit.add_theme_color_override("font_color", text)
	edit.add_theme_color_override("caret_color", text)
	edit.add_theme_stylebox_override("normal", box)
	edit.add_theme_stylebox_override("focus", box)
	edit.add_theme_stylebox_override("read_only", box)


func style_slider(slider: HSlider) -> void:
	if slider == null:
		return
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = text
	grabber.set_corner_radius_all(4)
	grabber.content_margin_left = 6.0
	grabber.content_margin_top = 6.0
	grabber.content_margin_right = 6.0
	grabber.content_margin_bottom = 6.0
	var grabber_hl := grabber.duplicate() as StyleBoxFlat
	grabber_hl.bg_color = menu
	var track := StyleBoxFlat.new()
	track.bg_color = with_alpha(text, 0.35)
	track.set_corner_radius_all(2)
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = text
	fill.set_corner_radius_all(2)
	fill.content_margin_top = 4.0
	fill.content_margin_bottom = 4.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_stylebox_override("grabber", grabber)
	slider.add_theme_stylebox_override("grabber_highlight", grabber_hl)


func style_option_button(option: OptionButton, h_margin: float = 12.0, v_margin: float = 6.0, item_icon_width: int = 0) -> void:
	if option == null:
		return
	style_chip_button(option, h_margin, v_margin)
	var popup := option.get_popup()
	var popup_panel := make_chip_style(text, 8.0, 6.0)
	popup.add_theme_stylebox_override("panel", popup_panel)
	popup.add_theme_stylebox_override("hover", make_chip_style(menu, 8.0, 6.0))
	popup.add_theme_color_override("font_color", menu)
	popup.add_theme_color_override("font_hover_color", text)
	popup.add_theme_color_override("font_separator_color", with_alpha(menu, 0.35))
	popup.add_theme_color_override("font_accelerator_color", menu)
	_hide_popup_radio_icons(popup)
	_hide_popup_radio_checks(popup)
	if item_icon_width > 0:
		option.add_theme_constant_override("h_separation", 8)
		option.add_theme_constant_override("icon_max_width", item_icon_width)
		popup.add_theme_constant_override("h_separation", 8)
		popup.add_theme_constant_override("icon_max_width", item_icon_width)
	if not popup.has_meta("_ui_theme_hide_checks"):
		popup.set_meta("_ui_theme_hide_checks", true)
		popup.about_to_popup.connect(_hide_popup_radio_checks.bind(popup))


func _toggle_icon(on: bool) -> Texture2D:
	var key := "%s-%s" % [theme_id, "on" if on else "off"]
	if _toggle_icons.has(key):
		return _toggle_icons[key]
	var light_theme := text.get_luminance() < menu.get_luminance()
	var off_track: Color
	var on_track: Color
	var off_thumb: Color
	var on_thumb: Color
	if light_theme:
		off_track = text
		on_track = hud_background
		off_thumb = text.lerp(hud_background, 0.55)
		on_thumb = text
	else:
		off_track = menu
		on_track = text
		off_thumb = menu.lerp(text, 0.55)
		on_thumb = menu
	var img := Image.create(TOGGLE_WIDTH, TOGGLE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var outer := Rect2(0.0, 0.0, float(TOGGLE_WIDTH), float(TOGGLE_HEIGHT))
	_fill_pill(img, outer, hud_background)
	var inner := outer.grow(-TOGGLE_BORDER)
	_fill_pill(img, inner, on_track if on else off_track)
	var thumb_radius := inner.size.y * 0.5 - TOGGLE_THUMB_INSET
	var thumb_cy := inner.position.y + inner.size.y * 0.5
	var thumb_cx := inner.position.x + TOGGLE_THUMB_INSET + thumb_radius
	if on:
		thumb_cx = inner.position.x + inner.size.x - TOGGLE_THUMB_INSET - thumb_radius
	_fill_circle(img, thumb_cx, thumb_cy, thumb_radius, on_thumb if on else off_thumb)
	var texture := ImageTexture.create_from_image(img)
	_toggle_icons[key] = texture
	return texture


func _fill_pill(img: Image, rect: Rect2, color: Color) -> void:
	var radius := rect.size.y * 0.5
	var left := rect.position.x + radius
	var right := rect.position.x + rect.size.x - radius
	img.fill_rect(Rect2i(int(left), int(rect.position.y), int(right - left), int(rect.size.y)), color)
	_fill_circle(img, left, rect.position.y + radius, radius, color)
	_fill_circle(img, right, rect.position.y + radius, radius, color)


func _fill_circle(img: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	var radius_sq := radius * radius
	var x0 := maxi(0, int(floor(cx - radius)))
	var y0 := maxi(0, int(floor(cy - radius)))
	var x1 := mini(img.get_width() - 1, int(ceil(cx + radius)))
	var y1 := mini(img.get_height() - 1, int(ceil(cy + radius)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - cx
			var dy := float(y) + 0.5 - cy
			if dx * dx + dy * dy <= radius_sq:
				img.set_pixel(x, y, color)


func _empty_theme_icon() -> Texture2D:
	if _empty_icon == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_empty_icon = ImageTexture.create_from_image(img)
	return _empty_icon


func _hide_popup_radio_icons(popup: PopupMenu) -> void:
	if popup == null:
		return
	var empty := _empty_theme_icon()
	for icon_name in [
		"checked",
		"unchecked",
		"radio_checked",
		"radio_unchecked",
		"checked_disabled",
		"unchecked_disabled",
		"radio_checked_disabled",
		"radio_unchecked_disabled",
	]:
		popup.add_theme_icon_override(icon_name, empty)
	popup.add_theme_constant_override("h_separation", 0)


func _hide_popup_radio_checks(popup: PopupMenu) -> void:
	if popup == null:
		return
	for i in popup.item_count:
		popup.set_item_as_radio_checkable(i, false)
		popup.set_item_as_checkable(i, false)
		popup.set_item_checked(i, false)


func style_panel(control: Control, corner_radius: int = -1, alpha: float = 1.0) -> void:
	if control == null:
		return
	var existing := control.get_theme_stylebox("panel") if control.has_theme_stylebox_override("panel") else null
	if existing == null:
		existing = control.get_theme_stylebox("panel")
	var box := StyleBoxFlat.new()
	box.bg_color = with_alpha(menu, alpha)
	var radius := corner_radius
	if radius < 0:
		if existing is StyleBoxFlat:
			radius = (existing as StyleBoxFlat).corner_radius_top_left
		else:
			radius = 0
	box.set_corner_radius_all(radius)
	if existing is StyleBoxFlat:
		var src := existing as StyleBoxFlat
		box.shadow_color = src.shadow_color
		box.shadow_size = src.shadow_size
		box.shadow_offset = src.shadow_offset
		box.content_margin_left = src.content_margin_left
		box.content_margin_top = src.content_margin_top
		box.content_margin_right = src.content_margin_right
		box.content_margin_bottom = src.content_margin_bottom
		box.border_width_left = src.border_width_left
		box.border_width_top = src.border_width_top
		box.border_width_right = src.border_width_right
		box.border_width_bottom = src.border_width_bottom
		box.border_color = text
	control.add_theme_stylebox_override("panel", box)


func apply_menu_tree(root: Node) -> void:
	if root == null:
		return
	_apply_menu_node(root)


func _apply_menu_node(node: Node) -> void:
	if node is SettingsPanel or node is DailyLeaderboardOverlay or node is TutorialCoach:
		return
	if node is Panel or node is PanelContainer:
		style_panel(node as Control)
	elif node is Label:
		var label := node as Label
		if label.name == "TitleLabel":
			style_title_label(label)
		else:
			var hint := _label_is_hint(label)
			style_label(label, hint)
	elif node is CheckButton:
		style_check_button(node as CheckButton)
	elif node is OptionButton:
		style_option_button(node as OptionButton)
	elif node is Button:
		var button := node as Button
		if _is_chip_button(button):
			style_chip_button(button)
		else:
			style_nav_button(button)
	elif node is LineEdit:
		style_line_edit(node as LineEdit)
	elif node is TextEdit:
		style_text_edit(node as TextEdit)
	elif node is HSlider:
		style_slider(node as HSlider)
	for child in node.get_children():
		_apply_menu_node(child)


func _label_is_hint(label: Label) -> bool:
	var n := label.name.to_lower()
	if n.contains("hint") or n.contains("desc") or n.contains("status") or n.contains("sub"):
		return true
	if label.has_theme_color_override("font_color"):
		return label.get_theme_color("font_color").a < 0.95
	return false


func _is_chip_button(button: BaseButton) -> bool:
	if button.flat:
		return false
	var sb := button.get_theme_stylebox("normal")
	if sb is StyleBoxEmpty:
		return false
	if sb is StyleBoxFlat:
		return (sb as StyleBoxFlat).bg_color.a > 0.05
	return true


func _apply_palette(id: String) -> void:
	if not THEMES.has(id):
		id = DEFAULT_ID
	theme_id = id
	var data: Dictionary = THEMES[id]
	primary = data["primary"]
	secondary = data["secondary"]
	menu = data["menu"]
	text = data["text"]
	_toggle_icons.clear()


func _apply_tile_shadow() -> void:
	if _tile_shadow == null:
		_tile_shadow = load(TILE_SHADOW_PATH) as StandardMaterial3D
	_configure_rim_material(_tile_shadow)
	var tree := get_tree()
	if tree != null and tree.root != null:
		_patch_tile_meshes(tree.root)


func _configure_rim_material(mat: StandardMaterial3D) -> void:
	if mat == null:
		return
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = false
	mat.emission_enabled = false
	mat.albedo_color = secondary


func _patch_tile_meshes(node: Node) -> void:
	_patch_mesh_node(node)
	for child in node.get_children():
		_patch_tile_meshes(child)


func _patch_mesh_node(node: Node) -> void:
	if _tile_shadow == null:
		return
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if _is_rim_material(mesh_instance.material_override):
			mesh_instance.material_override = _tile_shadow
		var mesh := mesh_instance.mesh
		if mesh == null:
			return
		for surface_i in mesh.get_surface_count():
			if _is_rim_material(mesh_instance.get_active_material(surface_i)):
				mesh_instance.set_surface_override_material(surface_i, _tile_shadow)
	elif node is MultiMeshInstance3D:
		var multi := node as MultiMeshInstance3D
		if _is_rim_material(multi.material_override):
			multi.material_override = _tile_shadow


func _is_rim_material(mat: Material) -> bool:
	if mat == null or mat == _tile_shadow:
		return false
	if not (mat is StandardMaterial3D):
		return false
	var standard := mat as StandardMaterial3D
	var material_name := standard.resource_name
	if material_name == "BrownDark" or material_name == "TileShadow":
		return true
	return standard.resource_path.ends_with("TileShadow.tres")


func _apply_world_environments() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	_apply_world_in(tree.root)


func _apply_world_in(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_world_environment(node as WorldEnvironment)
	for child in node.get_children():
		_apply_world_in(child)


func _apply_world_environment(world: WorldEnvironment) -> void:
	if world == null or world.environment == null:
		return
	world.environment.background_color = primary
