class_name AdaptiveNavGaps
extends RefCounted
## Three sidebar bands as fractions of the sidebar height: title, menu, footer.

const TITLE_PCT := 0.15
const FOOTER_PCT := 0.15


static func apply_bands(sidebar: Control) -> void:
	if sidebar == null:
		return
	var title := sidebar.get_node_or_null("TitleBand") as Control
	var menu := sidebar.get_node_or_null("MenuBand") as Control
	var footer := sidebar.get_node_or_null("FooterBand") as Control
	var title_end := TITLE_PCT
	var footer_start := 1.0 - FOOTER_PCT
	_band(title, 0.0, title_end)
	_band(menu, title_end, footer_start)
	_band(footer, footer_start, 1.0)


static func bind_sidebar(sidebar: Control) -> void:
	if sidebar == null:
		return
	var refresh := func() -> void:
		apply_bands(sidebar)
	if not sidebar.resized.is_connected(refresh):
		sidebar.resized.connect(refresh)
	apply_bands(sidebar)


static func _band(band: Control, top: float, bottom: float) -> void:
	if band == null:
		return
	band.set_anchors_preset(Control.PRESET_FULL_RECT)
	band.anchor_left = 0.0
	band.anchor_right = 1.0
	band.anchor_top = top
	band.anchor_bottom = bottom
	band.offset_left = 0.0
	band.offset_top = 0.0
	band.offset_right = 0.0
	band.offset_bottom = 0.0
