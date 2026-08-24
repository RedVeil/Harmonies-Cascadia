extends Node2D
class_name Card

@export var scale_speed : float = 1.0
@export var hover_scale: float = 8.0
@export var hover_height: float = 12.0
@export var exit_tween_duration: float = 0.3

@export_group("Spawn Animation")
@export var spawn_duration: float = 0.35
@export var spawn_origin: Vector2 = Vector2.ZERO
@export var spawn_sounds: Array[AudioStream] = []
@export var spawn_sound_volume_db: float = -10.0

@export_group("Redraw Animation")
@export var redraw_duration: float = 0.22
@export var redraw_peak_scale: float = 1.12
@export var redraw_sounds: Array[AudioStream] = []
@export var redraw_sound_volume_db: float = -10.0

const STACK_STEP_PX := 10.0
const STACK_VISUAL_CAP := 4
const DESATURATE_AMOUNT := 0.45
var COLOR_BROWN := Color.html("#918478")

@onready var visuals : Node2D = $visuals
@onready var empty_area : Control = $EmptyArea
@onready var card_area : Control = $CardArea
@onready var recycle_btn: Control = $visuals/RecycleButton
@onready var recycle_circle: TextureRect = $visuals/RecycleButton/Circle
@onready var recycle_label: Label = $visuals/RecycleButton/Label
@onready var card_placement : CardPlacement = $visuals/CardPlacement
@onready var frame : TextureRect = $visuals/Frame
@onready var frame_2 : TextureRect = $visuals/Frame2
@onready var frame_3 : TextureRect = $visuals/Frame3
@onready var frame_4 : TextureRect = $visuals/Frame4
@onready var shadow : TextureRect = $visuals/Shadow

var container : CardContainer
var _interaction_host: Node = null
var id : int = 0

var is_mouse_inside : bool = false
var exit_tween : Tween

var is_active : bool = false
var base_scale: Vector2 = Vector2.ONE
var target_scale : Vector2 =  Vector2.ONE
var base_visuals_position : Vector2 = Vector2.ZERO
var target_visuals_position : Vector2 = Vector2.ZERO
var _card_area_rest := Rect2()
var _empty_area_rest := Rect2()
var _recycle_rest_offset_top: float = 0.0
var _recycle_rest_offset_bottom: float = 0.0
var _shadow_base_offset_top: float = 0.0
var stack_amount : int = 0
var background_color : Color
var base_z_index : int = 0

var element_id : int = 0
var is_animal:bool = false
var _base_body_color: Color = Color.WHITE
var _desaturated: bool = false

var _spawn_active : bool = false
var _redraw_active : bool = false
var _spawn_layout_pending : bool = false
var _feedback_tweens: Dictionary = {}
var _recycle_enabled: bool = false
var _recycle_hovered: bool = false

## ----- Initialisation ----- ##

func _ready() -> void:
	_card_area_rest = _area_rest_rect(card_area)
	_empty_area_rest = _area_rest_rect(empty_area)
	_recycle_rest_offset_top = recycle_btn.offset_top
	_recycle_rest_offset_bottom = recycle_btn.offset_bottom
	_shadow_base_offset_top = shadow.offset_top
	_wire_area(empty_area)
	_wire_area(card_area)
	card_area.gui_input.connect(_on_gui_input)
	recycle_btn.visible = false
	recycle_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recycle_btn.pivot_offset = Vector2(14, 14)
	recycle_btn.gui_input.connect(_on_recycle_gui_input)
	recycle_btn.mouse_entered.connect(_on_recycle_mouse_entered)
	recycle_btn.mouse_exited.connect(_on_recycle_mouse_exited)
	_sync_areas_to_visuals()

func init(cardData:CardData, parent:Node, idx:int) -> void:
	if parent is CardContainer:
		container = parent
	_interaction_host = parent
	id = idx
	
	stack_amount = cardData.amount
	
	element_id = cardData.element
	is_animal = cardData.type == 1

	_base_body_color = Color.html(ElementCatalog.elements[cardData.element].levels.back().color)
	
	var frame_mat = frame.material.duplicate()
	frame_mat.set_shader_parameter("body_color", _base_body_color)
	frame_mat.set_shader_parameter("name_color", Color(0.16, 0.17, 0.253, 1))
	frame.material = frame_mat
	frame_2.material = frame_mat
	frame_3.material = frame_mat
	frame_4.material = frame_mat
	_desaturated = false
	
	$visuals/points/Label.text = "%d" % cardData.point_score
	$visuals/CardLabel.text = cardData.name
	_apply_stack_visuals()
	
	$visuals/icon.texture = load(cardData.icon)
	$visuals/icon.show()

	card_placement.init(cardData)
	card_placement.show()

	if cardData.type == 1:
		$visuals/bonus_points/Label.text = "+%d" % cardData.bonus_points
		$visuals/bonus_points.show()
		$visuals/points.show()
		
		_recycle_enabled = (
			parent is CardContainer
			or (parent != null and parent.has_method("reroll_card"))
		)

## ----- Layout Logic ----- ##

func mark_spawn_layout() -> void:
	_spawn_layout_pending = true

func consume_spawn_layout() -> bool:
	var pending := _spawn_layout_pending
	_spawn_layout_pending = false
	return pending

## ----- Interactions Logic ----- ##

func _wire_area(area: Control) -> void:
	area.scale = Vector2.ONE
	area.mouse_filter = Control.MOUSE_FILTER_STOP
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	is_mouse_inside = true
	_sync_ui_pointer_block()
	if _interaction_host and _interaction_host.has_method("hover_card"):
		_interaction_host.hover_card(id)


func _on_mouse_exited() -> void:
	# Moving between CardArea, EmptyArea, and the X must not drop hover.
	if _is_pointer_over_card_ui():
		_sync_ui_pointer_block()
		return
	is_mouse_inside = false
	if _is_touch_sticky_market():
		# Finger-up: keep the preview. X lives in EmptyArea so it cannot
		# steal the next CardArea tap.
		_clear_recycle_hover()
		_sync_ui_pointer_block()
		return
	_sync_ui_pointer_block()
	if _interaction_host and _interaction_host.has_method("exit_card"):
		_interaction_host.exit_card(id)


func _on_gui_input(event: InputEvent) -> void:
	if not InputScheme.is_left_click(event):
		return
	GameFeedback.play_click_card()
	if _interaction_host and _interaction_host.has_method("select_card"):
		_interaction_host.select_card(id)
	if _is_touch_sticky_market():
		_clear_recycle_hover()
	card_area.accept_event()
	get_viewport().set_input_as_handled()

## ----- Stack Logic ----- ##

func set_stack_amount(amount: int, animate: bool = true) -> void:
	if stack_amount == amount:
		return
	stack_amount = amount
	_apply_stack_visuals()
	if animate:
		play_redraw_animation()

func increment() -> void:
	set_stack_amount(stack_amount + 1)

func decrement() -> void:
	if stack_amount > 0:
		set_stack_amount(stack_amount - 1, false)

func _apply_stack_visuals() -> void:
	var depth := mini(maxi(stack_amount, 1), STACK_VISUAL_CAP)
	frame_2.visible = depth >= 2
	frame_3.visible = depth >= 3
	frame_4.visible = depth >= 4

	var extra := _stack_extra_px()
	shadow.offset_top = _shadow_base_offset_top - extra
	_sync_areas_to_visuals()

## ----- Other Logic ----- ##

func handle_hover() -> void:
	if !is_active:
		GameFeedback.play_hover_card()
		set_select_visuals()
	refresh_recycle_button(true)

func handle_exit() -> void:
	if !is_active:
		reset_select_visuals()
	refresh_recycle_button(false)

func select() -> void:
	is_active = true
	self.z_index = base_z_index + 100
	if target_visuals_position == base_visuals_position:
		set_select_visuals()

func deselect() -> void:
	is_active = false
	self.z_index = base_z_index
	reset_select_visuals()

func remove_card() -> void:
	UiPointerBlock.exit(self)
	UiPointerBlock.exit(recycle_btn)
	kill_animations()
	queue_free()


func _exit_tree() -> void:
	UiPointerBlock.exit(self)
	if recycle_btn != null:
		UiPointerBlock.exit(recycle_btn)

func set_select_visuals() -> void:
	self.z_index = base_z_index + 20
	target_scale = base_scale * hover_scale
	target_visuals_position = base_visuals_position - Vector2(0.0, hover_height)

func reset_select_visuals() -> void:
	self.z_index = base_z_index
	target_scale = base_scale
	target_visuals_position = base_visuals_position

func set_z(z:int) -> void:
	base_z_index = z
	self.z_index = base_z_index


## Match booster pack disable: muted frame + dimmed icons.
func set_desaturated(desaturate: bool) -> void:
	_desaturated = desaturate
	var color := _base_body_color
	if desaturate:
		var lum := color.get_luminance()
		color = _base_body_color.lerp(Color(lum, lum, lum, color.a), DESATURATE_AMOUNT)
	var frame_mat := frame.material as ShaderMaterial
	if frame_mat != null:
		frame_mat.set_shader_parameter("body_color", color)
	var icon_mod := Color(0.7, 0.7, 0.7, 1.0) if desaturate else Color.WHITE
	$visuals/icon.modulate = icon_mod
	$visuals/CardLabel.modulate = icon_mod
	$visuals/points.modulate = icon_mod
	$visuals/bonus_points.modulate = icon_mod
	if card_placement.visible:
		card_placement.modulate = icon_mod


## ----- Animations ----- ##

func play_spawn_animation(target_pos: Vector2, target_angle: float, z: int) -> void:
	play_animation(&"spawn", {
		"target_pos": target_pos,
		"target_angle": target_angle,
		"z": z,
	})

func play_redraw_animation() -> void:
	if _spawn_active:
		return
	play_animation(&"redraw", {})

func play_animation(name: StringName, params: Dictionary) -> void:
	match name:
		&"spawn":
			_animate_spawn(
				params.get("target_pos", position),
				params.get("target_angle", rotation_degrees),
				params.get("z", base_z_index)
			)
		&"redraw":
			_animate_redraw()

func kill_animations() -> void:
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	_spawn_active = false
	_redraw_active = false

func is_spawn_feedback_active() -> bool:
	return _spawn_active

func apply_layout(target_pos: Vector2, target_angle: float, z: int) -> void:
	set_z(z)
	position = target_pos
	rotation_degrees = target_angle

func _process(delta: float) -> void:
	if not (_spawn_active or _redraw_active):
		if visuals.scale.distance_squared_to(target_scale) >= 0.001 * 0.001:
			visuals.scale = visuals.scale.lerp(target_scale, delta * scale_speed)
			visuals.position = visuals.position.lerp(target_visuals_position, delta * scale_speed)
		elif visuals.position.distance_squared_to(target_visuals_position) >= 0.01 * 0.01:
			visuals.position = visuals.position.lerp(target_visuals_position, delta * scale_speed)
	_sync_areas_to_visuals()
	_sync_ui_pointer_block()


func _stack_extra_px() -> float:
	var depth := mini(maxi(stack_amount, 1), STACK_VISUAL_CAP)
	return float(depth - 1) * STACK_STEP_PX


func _area_rest_rect(area: Control) -> Rect2:
	return Rect2(
		area.offset_left,
		area.offset_top,
		area.offset_right - area.offset_left,
		area.offset_bottom - area.offset_top
	)


## Rest + stack extra + current visuals transform. Always computed from stored
## rest offsets so a place-while-selected cannot bake hover into the hit box.
## EmptyArea.bottom stays glued to CardArea.top.
func _sync_areas_to_visuals() -> void:
	var extra := _stack_extra_px()
	var dx := visuals.position.x
	var dy := visuals.position.y
	_apply_area_transform(card_area, _card_area_rest, extra, dx, dy, false)
	_apply_area_transform(empty_area, _empty_area_rest, extra, dx, dy, true)
	recycle_btn.offset_top = _recycle_rest_offset_top - extra
	recycle_btn.offset_bottom = _recycle_rest_offset_bottom - extra


func _apply_area_transform(
	area: Control,
	rest: Rect2,
	extra: float,
	dx: float,
	dy: float,
	move_bottom: bool
) -> void:
	var top := rest.position.y - extra + dy
	var bottom := rest.position.y + rest.size.y + dy
	if move_bottom:
		bottom -= extra
	area.offset_left = rest.position.x + dx
	area.offset_top = top
	area.offset_right = rest.position.x + rest.size.x + dx
	area.offset_bottom = bottom
	area.scale = visuals.scale
	area.pivot_offset = Vector2(-rest.position.x, -(rest.position.y - extra))


func _control_has_mouse(control: Control) -> bool:
	if control == null or not control.visible:
		return false
	if not control.is_inside_tree() or control.get_viewport() == null:
		return false
	return control.get_global_rect().has_point(control.get_global_mouse_position())


func _is_pointer_over_recycle() -> bool:
	return recycle_btn.visible and _control_has_mouse(recycle_btn)


func _is_pointer_over_card_ui() -> bool:
	return _control_has_mouse(empty_area) \
		or _control_has_mouse(card_area) \
		or _is_pointer_over_recycle()


func _sync_ui_pointer_block() -> void:
	UiPointerBlock.set_hovering(self, _is_pointer_over_card_ui())
	if not _is_pointer_over_recycle():
		UiPointerBlock.exit(recycle_btn)


func refresh_recycle_button(show: bool) -> void:
	var visible := show and _recycle_enabled and is_animal
	recycle_btn.visible = visible
	if not visible:
		_recycle_hovered = false
		_reset_recycle_button_colors()
		UiPointerBlock.exit(recycle_btn)
	_apply_recycle_pickable()
	_sync_ui_pointer_block()


func _apply_recycle_pickable() -> void:
	recycle_btn.mouse_filter = (
		Control.MOUSE_FILTER_STOP if recycle_btn.visible else Control.MOUSE_FILTER_IGNORE
	)


func _on_recycle_gui_input(event: InputEvent) -> void:
	if not InputScheme.is_left_click(event):
		return
	if not _recycle_enabled:
		return
	GameFeedback.play_click_button()
	if container != null and container.has_method("recycle_card"):
		container.recycle_card(id)
	elif _interaction_host != null and _interaction_host.has_method("reroll_card"):
		_interaction_host.reroll_card(id)
	elif _interaction_host != null and _interaction_host.has_method("recycle_card"):
		_interaction_host.recycle_card(id)
	recycle_btn.accept_event()
	get_viewport().set_input_as_handled()


func _on_recycle_mouse_entered() -> void:
	if not _recycle_enabled:
		return
	if recycle_btn.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	_recycle_hovered = true
	UiPointerBlock.enter(recycle_btn)
	_sync_ui_pointer_block()
	GameFeedback.play_hover_button()
	recycle_circle.self_modulate = COLOR_BROWN
	recycle_label.add_theme_color_override("font_color", Color.WHITE)
	if _interaction_host != null and _interaction_host.has_method("set_recycle_hover"):
		_interaction_host.set_recycle_hover(id, true)


func _on_recycle_mouse_exited() -> void:
	if _is_touch_sticky_market():
		_clear_recycle_hover()
		_sync_ui_pointer_block()
		return
	_clear_recycle_hover()
	_sync_ui_pointer_block()
	if _is_pointer_over_card_ui():
		return
	is_mouse_inside = false
	if is_queued_for_deletion():
		return
	if _interaction_host != null and _interaction_host.has_method("exit_card"):
		_interaction_host.exit_card(id)


func _reset_recycle_button_colors() -> void:
	recycle_circle.self_modulate = Color.WHITE
	recycle_label.add_theme_color_override("font_color", COLOR_BROWN)


func _clear_recycle_hover() -> void:
	if not _recycle_hovered:
		UiPointerBlock.exit(recycle_btn)
		_reset_recycle_button_colors()
		return
	_recycle_hovered = false
	UiPointerBlock.exit(recycle_btn)
	_reset_recycle_button_colors()
	if _interaction_host != null and _interaction_host.has_method("set_recycle_hover"):
		_interaction_host.set_recycle_hover(id, false)


func _is_market_host() -> bool:
	return _interaction_host is AnimalMarketPanel \
		or _interaction_host is AnimalMarketOverlay


func _is_touch_sticky_market() -> bool:
	if not _is_market_host():
		return false
	if _interaction_host is AnimalMarketOverlay:
		return InputScheme.touch.is_sticky("market_overlay", id)
	return InputScheme.touch.is_sticky("market", id)


func _animate_spawn(target_pos: Vector2, target_angle: float, z: int) -> void:
	FeedbackAnimHelper.play_sounds(spawn_sounds, spawn_sound_volume_db)

	_spawn_active = true
	set_z(z)
	position = spawn_origin
	rotation_degrees = 0.0
	visuals.scale = Vector2.ZERO
	visuals.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"spawn", true)
	tween.tween_property(visuals, "scale", base_scale, spawn_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "modulate", Color.WHITE, spawn_duration * 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, spawn_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", target_angle, spawn_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func() -> void:
		_spawn_active = false
		position = target_pos
		rotation_degrees = target_angle
		visuals.scale = target_scale
	)

func _animate_redraw() -> void:
	FeedbackAnimHelper.play_sounds(redraw_sounds, redraw_sound_volume_db)

	_redraw_active = true
	var peak_scale := base_scale * redraw_peak_scale
	var tween := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"redraw")
	tween.tween_property(visuals, "scale", peak_scale, redraw_duration * 0.35)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", target_scale, redraw_duration * 0.65)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(func() -> void:
		_redraw_active = false
	)
