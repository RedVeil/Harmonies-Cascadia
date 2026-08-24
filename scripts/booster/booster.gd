extends Node2D
class_name Booster

const FRAME_MATERIAL := preload("res://assets/ui/sdf_card_frame.tres")
const STACK_SCALE := 0.75 # 75% of hand-card size
const HOVER_LIFT_PX := 14.0
const HOVER_TWEEN_SEC := 0.12
const STACK_STEP_PX := 12.0
const DESATURATE_AMOUNT := 0.45
var FALLBACK_COLOR := Color(0.5686275, 0.5176471, 0.47058824, 1.0)
var COLOR_BROWN := Color.html("#918478")

@export var id: int = 0

@onready var icon: Sprite2D = $icon
@onready var background: Sprite2D = $background
@onready var progress_sprite: Sprite2D = $ProgressBar
@onready var stack_visuals: Node2D = $StackVisuals
@onready var empty_area: Control = $StackVisuals/EmptyArea
@onready var card_area: Control = $StackVisuals/CardArea
@onready var recycle_btn: Control = $StackVisuals/RecycleButton
@onready var recycle_circle: TextureRect = $StackVisuals/RecycleButton/Circle
@onready var recycle_label: Label = $StackVisuals/RecycleButton/Label
@onready var frame: TextureRect = $StackVisuals/Frame
@onready var frame_2: TextureRect = $StackVisuals/Frame2
@onready var frame_3: TextureRect = $StackVisuals/Frame3
@onready var shadow: TextureRect = $StackVisuals/Shadow
@onready var element_icon: TextureRect = $StackVisuals/ElementIcon

var container: BoosterContainer
var enabled: bool = true
var is_hovered: bool = false
var _reroll_ready: bool = true
var _reroll_hovered: bool = false

var _stack_frames: Array[TextureRect] = []
var _base_body_colors: Array[Color] = []
var _hover_tween: Tween
var _stack_base_y: float = 0.0
var _stack_extra_px: float = 0.0
var _card_area_rest := Rect2()
var _empty_area_rest := Rect2()
var _recycle_rest_offset_top: float = 0.0
var _recycle_rest_offset_bottom: float = 0.0
var _shadow_base_offset_top: float = -78.0

## ----- Initialisation ----- ##

func _ready() -> void:
	_stack_frames = [frame, frame_2, frame_3]
	_stack_base_y = stack_visuals.position.y
	_card_area_rest = _area_rest_rect(card_area)
	_empty_area_rest = _area_rest_rect(empty_area)
	_recycle_rest_offset_top = recycle_btn.offset_top
	_recycle_rest_offset_bottom = recycle_btn.offset_bottom
	_shadow_base_offset_top = shadow.offset_top
	if progress_sprite and progress_sprite.material:
		progress_sprite.material = progress_sprite.material.duplicate()
	_wire_area(empty_area)
	_wire_area(card_area)
	card_area.gui_input.connect(_on_gui_input)
	recycle_btn.visible = false
	recycle_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recycle_btn.pivot_offset = Vector2(14, 14)
	recycle_btn.gui_input.connect(_on_recycle_gui_input)
	recycle_btn.mouse_entered.connect(_on_recycle_mouse_entered)
	recycle_btn.mouse_exited.connect(_on_recycle_mouse_exited)
	_configure_mode_chrome()
	_sync_areas_to_visuals()
	if id == 4:
		icon.texture = load("res://assets/icons/animal.png")

func init(parent: BoosterContainer) -> void:
	container = parent

func is_stack_mode() -> bool:
	return id < 3

func set_reroll_ready(ready: bool) -> void:
	_reroll_ready = ready
	_apply_hover_visuals()

func _configure_mode_chrome() -> void:
	if is_stack_mode():
		stack_visuals.visible = true
		background.visible = false
		icon.visible = false
		progress_sprite.visible = false
		stack_visuals.scale = Vector2(STACK_SCALE, STACK_SCALE)
	else:
		stack_visuals.visible = false
		background.visible = false
		icon.visible = false
		progress_sprite.visible = false
		recycle_btn.visible = false

## ----- State Logic ----- ##

func enable() -> void:
	enabled = true
	if is_stack_mode():
		_apply_stack_saturation(false)
	_apply_hover_visuals()

func disable() -> void:
	enabled = false
	if is_stack_mode():
		_kill_hover_tween()
		stack_visuals.position.y = _stack_base_y
		recycle_btn.visible = false
		_apply_recycle_pickable()
		_apply_stack_saturation(true)
	else:
		background.self_modulate = Color.WHITE
		icon.self_modulate = Color.GRAY

func set_progress(value: float) -> void:
	if is_stack_mode():
		return
	if progress_sprite == null or progress_sprite.material == null:
		return
	var mat := progress_sprite.material as ShaderMaterial
	mat.set_shader_parameter("current_value", 0.0)
	mat.set_shader_parameter("lerp_value", clampf(value, 0.0, 1.0))
	mat.set_shader_parameter("third_value", 0.0)

## ----- Interactions Logic ----- ##

func _wire_area(area: Control) -> void:
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	_sync_ui_pointer_block()
	if is_hovered:
		return
	GameFeedback.play_hover_button()
	is_hovered = true
	_apply_hover_visuals()


func _on_mouse_exited() -> void:
	if _is_pointer_over_booster_ui():
		_sync_ui_pointer_block()
		return
	if _is_touch_sticky_booster():
		_clear_reroll_hover()
		_sync_ui_pointer_block()
		return
	_drop_hover()


func _drop_hover() -> void:
	is_hovered = false
	_clear_reroll_hover()
	_apply_hover_visuals()
	_sync_ui_pointer_block()


func _on_gui_input(event: InputEvent) -> void:
	if not InputScheme.is_left_click(event) or not enabled:
		return
	if InputScheme.uses_touch_confirm():
		if not InputScheme.touch.is_sticky("booster", id):
			var prev := InputScheme.touch.set_target("booster", id)
			if String(prev.get("kind", "")) == "booster" and prev.get("id", id) != id:
				_unhover_other_booster(int(prev["id"]))
			if not is_hovered:
				_on_mouse_entered()
			_clear_reroll_hover()
			card_area.accept_event()
			get_viewport().set_input_as_handled()
			return
	GameFeedback.play_click_button()
	container.select_booster(id)
	InputScheme.touch.clear()
	card_area.accept_event()
	get_viewport().set_input_as_handled()


func _apply_hover_visuals() -> void:
	if is_stack_mode():
		_apply_stack_hover_visuals()
		return
	if not enabled:
		background.self_modulate = Color.WHITE
		icon.self_modulate = Color.GRAY
		return
	if is_hovered:
		background.self_modulate = Color.html("#918478")
		icon.self_modulate = Color.WHITE
	else:
		background.self_modulate = Color.WHITE
		icon.self_modulate = Color.html("#918478")

func _apply_stack_hover_visuals() -> void:
	var show_x := enabled and _reroll_ready and (is_hovered or _reroll_hovered)
	recycle_btn.visible = show_x
	_apply_recycle_pickable()
	if not enabled or (not is_hovered and not _reroll_hovered):
		_tween_stack_y(_stack_base_y)
		return
	_tween_stack_y(_stack_base_y - HOVER_LIFT_PX)

func _tween_stack_y(target_y: float) -> void:
	_kill_hover_tween()
	_hover_tween = create_tween()
	_hover_tween.tween_property(stack_visuals, "position:y", target_y, HOVER_TWEEN_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _kill_hover_tween() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null

func set_focus_hover(on: bool) -> void:
	if on:
		if not is_hovered:
			_on_mouse_entered()
	elif is_hovered:
		_drop_hover()


func _unhover_other_booster(other_id: int) -> void:
	if container == null:
		return
	for booster in container.boosters:
		if booster != null and booster.id == other_id:
			InputScheme.touch.clear()
			booster._drop_hover()
			InputScheme.touch.set_target("booster", id)
			return


func _on_recycle_gui_input(event: InputEvent) -> void:
	if not InputScheme.is_left_click(event):
		return
	if not enabled or not _reroll_ready:
		return
	GameFeedback.play_click_button()
	container.reroll_booster(id)
	if InputScheme.uses_touch_confirm():
		InputScheme.touch.set_target("booster", id)
	recycle_btn.accept_event()
	get_viewport().set_input_as_handled()


func _on_recycle_mouse_entered() -> void:
	if recycle_btn.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	_reroll_hovered = true
	UiPointerBlock.enter(recycle_btn)
	_sync_ui_pointer_block()
	if _reroll_ready:
		GameFeedback.play_hover_button()
		recycle_circle.self_modulate = COLOR_BROWN
		recycle_label.add_theme_color_override("font_color", Color.WHITE)


func _on_recycle_mouse_exited() -> void:
	if _is_touch_sticky_booster():
		_clear_reroll_hover()
		_sync_ui_pointer_block()
		return
	_clear_reroll_hover()
	_sync_ui_pointer_block()
	if _is_pointer_over_booster_ui():
		return
	_drop_hover()


func _clear_reroll_hover() -> void:
	if not _reroll_hovered:
		UiPointerBlock.exit(recycle_btn)
		_reset_recycle_button_colors()
		return
	_reroll_hovered = false
	UiPointerBlock.exit(recycle_btn)
	_reset_recycle_button_colors()


func _reset_recycle_button_colors() -> void:
	recycle_circle.self_modulate = Color.WHITE
	recycle_label.add_theme_color_override("font_color", COLOR_BROWN)


func _apply_recycle_pickable() -> void:
	recycle_btn.mouse_filter = (
		Control.MOUSE_FILTER_STOP if recycle_btn.visible else Control.MOUSE_FILTER_IGNORE
	)


func _area_rest_rect(area: Control) -> Rect2:
	return Rect2(
		area.offset_left,
		area.offset_top,
		area.offset_right - area.offset_left,
		area.offset_bottom - area.offset_top
	)


func _sync_areas_to_visuals() -> void:
	var extra := _stack_extra_px
	_apply_area_transform(card_area, _card_area_rest, extra, false)
	_apply_area_transform(empty_area, _empty_area_rest, extra, true)
	recycle_btn.offset_top = _recycle_rest_offset_top - extra
	recycle_btn.offset_bottom = _recycle_rest_offset_bottom - extra


func _apply_area_transform(area: Control, rest: Rect2, extra: float, move_bottom: bool) -> void:
	var top := rest.position.y - extra
	var bottom := rest.position.y + rest.size.y
	if move_bottom:
		bottom -= extra
	area.offset_left = rest.position.x
	area.offset_top = top
	area.offset_right = rest.position.x + rest.size.x
	area.offset_bottom = bottom
	area.pivot_offset = Vector2(-rest.position.x, -(rest.position.y - extra))


func _control_has_mouse(control: Control) -> bool:
	if control == null or not control.visible:
		return false
	if not control.is_inside_tree() or control.get_viewport() == null:
		return false
	return control.get_global_rect().has_point(control.get_global_mouse_position())


func _is_pointer_over_recycle() -> bool:
	return recycle_btn.visible and _control_has_mouse(recycle_btn)


func _is_pointer_over_booster_ui() -> bool:
	return _control_has_mouse(empty_area) \
		or _control_has_mouse(card_area) \
		or _is_pointer_over_recycle()


func _sync_ui_pointer_block() -> void:
	UiPointerBlock.set_hovering(self, _is_pointer_over_booster_ui())
	if not _is_pointer_over_recycle():
		UiPointerBlock.exit(recycle_btn)


func _is_touch_sticky_booster() -> bool:
	return InputScheme.uses_touch_confirm() and InputScheme.touch.is_sticky("booster", id)


func _process(_delta: float) -> void:
	_sync_ui_pointer_block()


func _exit_tree() -> void:
	UiPointerBlock.exit(self)
	if recycle_btn != null:
		UiPointerBlock.exit(recycle_btn)

## ----- Booster Visual Logic ----- ##

func set_booster_visuals(boosterData: BoosterData) -> void:
	if not is_stack_mode():
		if boosterData.type == 7:
			icon.visible = true
			icon.texture = load("res://assets/icons/animal.png")
		return

	var element_ids := _collect_element_ids(boosterData)
	_apply_stack_colors(element_ids)
	if not enabled:
		_apply_stack_saturation(true)

func _collect_element_ids(boosterData: BoosterData) -> Array[int]:
	var element_ids: Array[int] = []
	if boosterData == null:
		return element_ids
	if boosterData.type > 0 and boosterData.type < 6 and boosterData.cards.is_empty():
		element_ids.append(boosterData.type)
		return element_ids
	for c in boosterData.cards:
		if c.type == 0:
			element_ids.append(c.id)
		else:
			element_ids.append(c.element)
	return element_ids

func _apply_stack_colors(element_ids: Array[int]) -> void:
	_base_body_colors.clear()
	var depth := mini(element_ids.size(), _stack_frames.size())
	if depth <= 0:
		# Empty pack: single muted frame.
		_base_body_colors.append(FALLBACK_COLOR)
		depth = 1
		_set_frame_color(frame, FALLBACK_COLOR)
		frame.visible = true
		frame_2.visible = false
		frame_3.visible = false
		_set_front_element_icon(-1)
		_update_shadow_for_depth(1)
		return

	# Front frame = first element; Frame2/Frame3 peek behind (later pack cards).
	for i in _stack_frames.size():
		var layer: TextureRect = _stack_frames[i]
		if i >= depth:
			layer.visible = false
			continue
		var color := _color_for_element(element_ids[i])
		_base_body_colors.append(color)
		_set_frame_color(layer, color)
		layer.visible = true
	_set_front_element_icon(element_ids[0])
	_update_shadow_for_depth(depth)

func _set_front_element_icon(element_id: int) -> void:
	if element_id < 0 or element_id >= ElementCatalog.elements.size():
		element_icon.visible = false
		element_icon.texture = null
		return
	var element: Element = ElementCatalog.elements[element_id]
	if element.levels.is_empty():
		element_icon.visible = false
		element_icon.texture = null
		return
	element_icon.texture = load(element.levels.back().icon)
	element_icon.visible = true
	element_icon.modulate = Color.WHITE if enabled else Color(0.7, 0.7, 0.7, 1.0)

func _color_for_element(element_id: int) -> Color:
	if element_id >= 0 and element_id < ElementCatalog.elements.size():
		var element: Element = ElementCatalog.elements[element_id]
		if element.levels.size() > 0:
			return Color.html(element.levels.back().color)
	return FALLBACK_COLOR

func _set_frame_color(layer: TextureRect, color: Color) -> void:
	var mat := FRAME_MATERIAL.duplicate() as ShaderMaterial
	mat.set_shader_parameter("body_color", color)
	# Flatten name plate so mini stacks read as solid colored cards.
	mat.set_shader_parameter("name_color", color)
	layer.material = mat

func _update_shadow_for_depth(depth: int) -> void:
	# Match card stack: extra top peek shifts shadow upward.
	_stack_extra_px = float(maxi(depth - 1, 0)) * STACK_STEP_PX
	shadow.offset_top = _shadow_base_offset_top - _stack_extra_px
	_sync_areas_to_visuals()

func _apply_stack_saturation(desaturate: bool) -> void:
	for i in _stack_frames.size():
		var layer: TextureRect = _stack_frames[i]
		if not layer.visible:
			continue
		var mat := layer.material as ShaderMaterial
		if mat == null:
			continue
		var base := FALLBACK_COLOR
		if i < _base_body_colors.size():
			base = _base_body_colors[i]
		var color := base
		if desaturate:
			var gray := Color(base.get_luminance(), base.get_luminance(), base.get_luminance(), base.a)
			color = base.lerp(gray, DESATURATE_AMOUNT)
		mat.set_shader_parameter("body_color", color)
		mat.set_shader_parameter("name_color", color)
	if element_icon.visible:
		element_icon.modulate = Color(0.7, 0.7, 0.7, 1.0) if desaturate else Color.WHITE
