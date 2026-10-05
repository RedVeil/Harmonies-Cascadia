extends Node
## Central UI / world palette. Apply at boot and whenever the player picks a theme.

signal theme_changed

const TILE_SHADOW_PATH := "res://assets/tiles/materials/ground/TileShadow.tres"
const TITLE_FONT := preload("res://assets/fonts/LuckiestGuy-Regular.ttf")
const BODY_FONT := preload("res://assets/fonts/Dangrek-Regular.ttf")
const HINT_ALPHA := 0.7
const BUTTON_HOVER_ALPHA := 0.5
const CHIP_BORDER_WIDTH := 2
const CHIP_CORNER_RADIUS := 2
const RECT_BUTTON_RADIUS := 2
const SUBTITLE_FONT_SIZE := 20
const DEFAULT_ID := "ocean-dark"
const THEME_STRIP_WIDTH := 64
const THEME_STRIP_HEIGHT := 16
const TOGGLE_WIDTH := 48
const TOGGLE_HEIGHT := 24
const TOGGLE_BORDER := 2.0
const TOGGLE_THUMB_INSET := 2.0
const BACKDROP_LAYER := -1
const BACKDROP_NODE_NAME := "ThemeBackdrop"
const BACKDROP_SHADER_CODE := "shader_type canvas_item;\nuniform vec4 color_top : source_color = vec4(1.0);\nuniform vec4 color_bottom : source_color = vec4(1.0);\nvoid fragment() {\n\tCOLOR = mix(color_top, color_bottom, UV.y);\n}\n"

const THEME_ALIASES := {
	"orange-pastel-dark": "orange-dark",
	"orange-pastel-light": "orange-light",
}

var THEMES := _build_themes()

var theme_id: String = DEFAULT_ID
var primary: Color = Color.html("#6FB3BF")
var secondary: Color = Color.html("#4D9FAE")
var menu: Color = Color.html("#B4A594")
var text: Color = Color.html("#FFFFFF")
var hud_background := Color.WHITE
var points_positive := Color.GOLD
var points_negative := Color.CRIMSON
var highlight := Color(1.0, 1.0, 0.6350498, 1.0)

var title_font: Font
var body_font: Font

var _backdrop_shader: Shader
var _tile_shadow: StandardMaterial3D
var _worlds: Array[WorldEnvironment] = []
var _nav_empty := StyleBoxEmpty.new()
var _empty_icon: Texture2D
var _strip_icons: Dictionary = {}
var _toggle_icons: Dictionary = {}
var _toggle_mask_outer: Image
var _toggle_mask_inner: Image
var _toggle_mask_thumb_off: Image
var _toggle_mask_thumb_on: Image


static func _build_themes() -> Dictionary:
	var themes := {}
	_add_theme_pair(themes, "ocean", "Ocean", Color.html("#6fb3bf"), Color.html("#4d9fae"))
	_add_theme_pair(themes, "orange", "Orange", Color.html("#e8b38b"), Color.html("#e09760"))
	_add_theme_pair(themes, "forest", "Forest", Color.html("#6B8F71"), Color.html("#2C3A30"))
	_add_theme_pair_colors(
		themes,
		"beige",
		"Beige",
		Color.html("#d1bfab"),
		Color.html("#8b4f3a"),
		Color.html("#786452"),
		Color.html("#f4dfca"),
		Color.html("#f4dfca"),
		Color.html("#786452")
	)
	_add_theme_pair(themes, "yellow-pastel", "Yellow Pastel", Color.html("#f4c48c"), Color.html("#f0ac5d"))
	_add_theme_pair_colors(
		themes,
		"blue-pastel",
		"Blue Pastel",
		Color.html("#c8daf3"),
		Color.html("#9ebeea"),
		Color.html("#9ebeea"),
		Color.WHITE,
		Color.WHITE,
		Color.html("#92b0d9")
	)
	_add_theme_pair(themes, "green-pastel", "Green Pastel", Color.html("#aaecd0"), Color.html("#68ab8e"))
	_add_theme_pair(themes, "pink-pastel", "Pink Pastel", Color.html("#f3c8da"), Color.html("#ea9ebe"))
	return themes


static func _add_theme_pair(
	themes: Dictionary,
	id: String,
	display: String,
	primary_color: Color,
	secondary_color: Color
) -> void:
	_add_theme_pair_colors(themes, id, display, primary_color, secondary_color, secondary_color, Color.WHITE, Color.WHITE, secondary_color)


static func _add_theme_pair_colors(
	themes: Dictionary,
	id: String,
	display: String,
	primary_color: Color,
	secondary_color: Color,
	dark_menu: Color,
	dark_text: Color,
	light_menu: Color,
	light_text: Color
) -> void:
	themes["%s-dark" % id] = {
		"name": "%s Dark" % display,
		"primary": primary_color,
		"secondary": secondary_color,
		"menu": dark_menu,
		"text": dark_text,
	}
	themes["%s-light" % id] = {
		"name": "%s Light" % display,
		"primary": primary_color,
		"secondary": secondary_color,
		"menu": light_menu,
		"text": light_text,
	}


func _ready() -> void:
	title_font = TITLE_FONT.duplicate() as Font
	body_font = BODY_FONT.duplicate() as Font
	_add_latin_fallback(title_font)
	_add_latin_fallback(body_font)
	var loaded := load(TILE_SHADOW_PATH) as StandardMaterial3D
	if loaded != null:
		_tile_shadow = loaded.duplicate() as StandardMaterial3D
	var stored := DEFAULT_ID
	if GameSettings != null:
		stored = GameSettings.theme_id
	_apply_palette(_canonical_theme_id(stored))
	if GameSettings != null and THEME_ALIASES.has(stored):
		GameSettings.theme_id = theme_id
		GameSettings.save_to_disk()
	_watch_tree()
	apply()


func _watch_tree() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	if tree.root != null:
		_seed_existing(tree.root)


func _seed_existing(node: Node) -> void:
	if node is WorldEnvironment:
		_register_world(node as WorldEnvironment)
	elif node is MeshInstance3D or node is MultiMeshInstance3D:
		_patch_mesh_node(node)
	for child in node.get_children():
		_seed_existing(child)


func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_register_world_deferred.call_deferred(node)
	elif node is MeshInstance3D or node is MultiMeshInstance3D:
		_patch_mesh_node.call_deferred(node)


func _register_world_deferred(node: Node) -> void:
	if not is_instance_valid(node) or not (node is WorldEnvironment):
		return
	var world := node as WorldEnvironment
	_register_world(world)
	_apply_world_environment(world)


func _register_world(world: WorldEnvironment) -> void:
	if world == null:
		return
	if not _worlds.has(world):
		_worlds.append(world)
	var forget := _forget_world.bind(world)
	if not world.tree_exiting.is_connected(forget):
		world.tree_exiting.connect(forget, CONNECT_ONE_SHOT)


func _forget_world(world: WorldEnvironment) -> void:
	_worlds.erase(world)


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
	var canonical := _canonical_theme_id(id)
	var data: Dictionary = THEMES[canonical]
	var fallback := str(data.get("name", canonical))
	return Loc.ui("theme.%s" % canonical, fallback)


func theme_colors(id: String) -> Dictionary:
	return THEMES[_canonical_theme_id(id)]


func theme_strip_icon(id: String) -> Texture2D:
	id = _canonical_theme_id(id)
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
	_apply_palette(_canonical_theme_id(id))
	if GameSettings != null:
		GameSettings.theme_id = theme_id
		GameSettings.save_to_disk()
	apply()


func apply() -> void:
	_configure_rim_material(_tile_shadow)
	_apply_world_environments()
	theme_changed.emit()


func substitute_rim(mat: Material) -> Material:
	if _tile_shadow != null and _is_rim_material(mat):
		return _tile_shadow
	return mat


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


func paint_panel_fill(panel: Panel, color: Color, corner_radius: int = RECT_BUTTON_RADIUS) -> void:
	if panel == null:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(corner_radius)
	panel.add_theme_stylebox_override("panel", box)


func apply_rect_button(background: Panel, label: Label, hovered: bool, enabled: bool = true) -> void:
	if background == null or label == null:
		return
	if not enabled:
		paint_panel_fill(background, Color(0.85, 0.85, 0.85, 1.0))
		label.add_theme_color_override("font_color", Color.GRAY)
		return
	if hovered:
		paint_panel_fill(background, with_alpha(text, BUTTON_HOVER_ALPHA))
		label.add_theme_color_override("font_color", hud_background)
	else:
		paint_panel_fill(background, text)
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


func style_chip_button(button: BaseButton, h_margin: float = 12.0, v_margin: float = 2.0, corner_radius: int = CHIP_CORNER_RADIUS) -> void:
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
	control.add_theme_font_override("font", title_font if title_font != null else TITLE_FONT)


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
	_ensure_toggle_masks()
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
	var img := _blank_toggle_image()
	_blit_mask(img, _toggle_mask_outer, hud_background)
	_blit_mask(img, _toggle_mask_inner, on_track if on else off_track)
	var thumb_mask := _toggle_mask_thumb_on if on else _toggle_mask_thumb_off
	_blit_mask(img, thumb_mask, on_thumb if on else off_thumb)
	var texture := ImageTexture.create_from_image(img)
	_toggle_icons[key] = texture
	return texture


func _ensure_toggle_masks() -> void:
	if _toggle_mask_outer != null:
		return
	var outer := Rect2(0.0, 0.0, float(TOGGLE_WIDTH), float(TOGGLE_HEIGHT))
	var inner := outer.grow(-TOGGLE_BORDER)
	_toggle_mask_outer = _make_pill_mask(outer)
	_toggle_mask_inner = _make_pill_mask(inner)
	var thumb_radius := inner.size.y * 0.5 - TOGGLE_THUMB_INSET
	var thumb_cy := inner.position.y + inner.size.y * 0.5
	var thumb_off_cx := inner.position.x + TOGGLE_THUMB_INSET + thumb_radius
	var thumb_on_cx := inner.position.x + inner.size.x - TOGGLE_THUMB_INSET - thumb_radius
	_toggle_mask_thumb_off = _make_circle_mask(thumb_off_cx, thumb_cy, thumb_radius)
	_toggle_mask_thumb_on = _make_circle_mask(thumb_on_cx, thumb_cy, thumb_radius)


func _blank_toggle_image() -> Image:
	var img := Image.create(TOGGLE_WIDTH, TOGGLE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


func _make_pill_mask(rect: Rect2) -> Image:
	var img := _blank_toggle_image()
	_fill_pill(img, rect, Color.WHITE)
	return img


func _make_circle_mask(cx: float, cy: float, radius: float) -> Image:
	var img := _blank_toggle_image()
	_fill_circle(img, cx, cy, radius, Color.WHITE)
	return img


func _blit_mask(dst: Image, mask: Image, color: Color) -> void:
	for y in TOGGLE_HEIGHT:
		for x in TOGGLE_WIDTH:
			if mask.get_pixel(x, y).a <= 0.0:
				continue
			dst.set_pixel(x, y, color)


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
	if label.has_meta("ui_hint"):
		return bool(label.get_meta("ui_hint"))
	var n := String(label.name)
	if n == "SubLabel":
		return true
	return n.ends_with("Hint") or n.ends_with("Desc") or n.ends_with("Status")


func _is_chip_button(button: BaseButton) -> bool:
	if button.flat:
		return false
	var sb := button.get_theme_stylebox("normal")
	if sb is StyleBoxEmpty:
		return false
	if sb is StyleBoxFlat:
		return (sb as StyleBoxFlat).bg_color.a > 0.05
	return true


func _canonical_theme_id(id: String) -> String:
	if THEME_ALIASES.has(id):
		id = str(THEME_ALIASES[id])
	if not THEMES.has(id):
		return DEFAULT_ID
	return id


func _apply_palette(id: String) -> void:
	theme_id = _canonical_theme_id(id)
	var data: Dictionary = THEMES[theme_id]
	primary = data["primary"]
	secondary = data["secondary"]
	menu = data["menu"]
	text = data["text"]
	_toggle_icons.clear()


func _configure_rim_material(mat: StandardMaterial3D) -> void:
	if mat == null:
		return
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = false
	mat.emission_enabled = false
	mat.albedo_color = secondary


func _patch_mesh_node(node: Node) -> void:
	if not is_instance_valid(node) or _tile_shadow == null:
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
	if standard.resource_name == "TileShadow":
		return true
	return standard.resource_path.ends_with("TileShadow.tres")


func _apply_world_environments() -> void:
	var live: Array[WorldEnvironment] = []
	for world in _worlds:
		if not is_instance_valid(world):
			continue
		_apply_world_environment(world)
		live.append(world)
	_worlds = live


func _apply_world_environment(world: WorldEnvironment) -> void:
	if not is_instance_valid(world) or world.environment == null:
		return
	var env := world.environment
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = BACKDROP_LAYER
	env.background_color = primary
	_apply_theme_backdrop(world)


func _apply_theme_backdrop(world: WorldEnvironment) -> void:
	var root := world.get_parent()
	if root == null:
		return
	var layer := root.get_node_or_null(BACKDROP_NODE_NAME) as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = BACKDROP_NODE_NAME
		layer.layer = BACKDROP_LAYER
		root.add_child(layer)
	var existing := layer.get_node_or_null("Gradient")
	if existing != null and not (existing is ColorRect):
		existing.name = "GradientOld"
		existing.queue_free()
		existing = null
	var rect := existing as ColorRect
	if rect == null:
		rect = ColorRect.new()
		rect.name = "Gradient"
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(rect)
		_fit_backdrop.call_deferred(rect)
	var material := rect.material as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = _get_backdrop_shader()
		rect.material = material
	material.set_shader_parameter("color_top", primary)
	material.set_shader_parameter("color_bottom", secondary)
	_fit_backdrop(rect)


func _get_backdrop_shader() -> Shader:
	if _backdrop_shader == null:
		_backdrop_shader = Shader.new()
		_backdrop_shader.code = BACKDROP_SHADER_CODE
	return _backdrop_shader


func _fit_backdrop(rect: Control) -> void:
	if not is_instance_valid(rect) or not rect.is_inside_tree():
		return
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
