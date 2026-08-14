extends Area2D
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
const TOUCH_LONG_PRESS_SEC := 0.45
var COLOR_BROWN := Color.html("#918478")

@onready var visuals : Node2D = $visuals
@onready var hit_area : Control = $HitArea
@onready var recycle_btn: Control = $HitArea/RecycleButton
@onready var recycle_circle: Sprite2D = $HitArea/RecycleButton/Circle
@onready var recycle_label: Label = $HitArea/RecycleButton/Label
@onready var placement_tooltip : PlacementTooltip = $PlacementTooltip
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
var _hit_area_base_position: Vector2 = Vector2.ZERO
var _hit_area_base_offset_top: float = 0.0
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
## Sticky hover for touch: survives mouse_exit until another card is hovered or selected.
var _touch_hover_sticky: bool = false
var _recycle_enabled: bool = false
var _recycle_hovered: bool = false
var _recycle_base_position: Vector2 = Vector2.ZERO
var _long_press_timer: Timer
var _touch_press_active: bool = false
var _long_press_fired: bool = false

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = false
	_hit_area_base_offset_top = hit_area.offset_top
	_shadow_base_offset_top = shadow.offset_top
	_hit_area_base_position = hit_area.position
	hit_area.pivot_offset = hit_area.size * 0.5
	hit_area.mouse_entered.connect(_on_mouse_entered)
	hit_area.mouse_exited.connect(_on_mouse_exited)
	hit_area.gui_input.connect(_on_gui_input)
	_recycle_base_position = recycle_btn.position
	# #region agent log
	_dbg_recycle("C", "card.gd:_ready", "captured recycle/hit bases", {
		"card_id": id,
		"recycle_pos": {"x": recycle_btn.position.x, "y": recycle_btn.position.y},
		"recycle_base": {"x": _recycle_base_position.x, "y": _recycle_base_position.y},
		"hit_offset_top": hit_area.offset_top,
		"hit_base_offset_top": _hit_area_base_offset_top,
		"hit_pos": {"x": hit_area.position.x, "y": hit_area.position.y},
	})
	# #endregion
	recycle_btn.visible = false
	recycle_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	recycle_btn.gui_input.connect(_on_recycle_gui_input)
	recycle_btn.mouse_entered.connect(_on_recycle_mouse_entered)
	recycle_btn.mouse_exited.connect(_on_recycle_mouse_exited)
	_long_press_timer = Timer.new()
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = TOUCH_LONG_PRESS_SEC
	_long_press_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_press_timer)
func init(cardData:CardData, parent:Node, idx:int) -> void:
	if parent is CardContainer:
		container = parent
	_interaction_host = parent
	id = idx
	
	stack_amount = cardData.amount
	
	element_id = cardData.element
	is_animal = cardData.type == 1

	_base_body_color = Color.html(ElementCatalog.elements[cardData.element].levels.back().color)
	var mat = $visuals/points/background.material.duplicate()
	mat.set_shader_parameter("unfilled_color", _base_body_color)
	$visuals/points/background.material = mat
	var frame_mat = frame.material.duplicate()
	frame_mat.set_shader_parameter("body_color", _base_body_color)
	frame_mat.set_shader_parameter("name_color", Color(0.16, 0.17, 0.253, 1))
	frame.material = frame_mat
	frame_2.material = frame_mat
	frame_3.material = frame_mat
	frame_4.material = frame_mat
	_desaturated = false
	
	placement_tooltip.init(cardData.type, cardData.placement, cardData.bonus)
	$visuals/points/Label.text = "%d" % cardData.point_score
	$visuals/CardLabel.text = cardData.name
	_apply_stack_visuals()
	
	$visuals/icon.texture = load(cardData.icon)
	$visuals/icon.show()

	if cardData.type == 1:
		$visuals/bonus_points/background.material = mat
		$visuals/bonus_points/Label.text = "+%d" % cardData.bonus_points
		$visuals/bonus_points.show()
		$visuals/points.show()

		var elem = ElementCatalog.elements[cardData.element]
		var symbol_path: String
		if cardData.placement.size() > 0:
			symbol_path = elem.levels[cardData.placement[0].level - 1].icon
		else:
			symbol_path = elem.levels.back().icon
		$visuals/elementicon.texture = load(symbol_path)
		$visuals/elementicon.show()
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

func _on_mouse_entered() -> void:
	is_mouse_inside = true
	_sync_ui_pointer_block()
	# Touch uses tap-to-hover; skip enter-driven hover so single tap stays distinct.
	if TouchMode.is_touch():
		return
	if _interaction_host and _interaction_host.has_method("hover_card"):
		_interaction_host.hover_card(id)
	

func _on_mouse_exited() -> void:
	is_mouse_inside = false
	# #region agent log
	_agent_dbg("A", "card.gd:_on_mouse_exited", "mouse_exited fired", {
		"card_id": id,
		"card_in_tree": is_inside_tree(),
		"card_vp_null": get_viewport() == null,
		"hit_in_tree": hit_area != null and hit_area.is_inside_tree(),
		"hit_vp_null": hit_area != null and hit_area.get_viewport() == null,
		"recycle_in_tree": recycle_btn != null and recycle_btn.is_inside_tree(),
		"recycle_vp_null": recycle_btn != null and recycle_btn.get_viewport() == null,
		"recycle_visible": recycle_btn != null and recycle_btn.visible,
		"hit_visible": hit_area != null and hit_area.visible,
	})
	# #endregion
	# Child STOP X fires parent exit first; keep hover/block until recycle owns it.
	if _is_pointer_over_recycle():
		_sync_ui_pointer_block()
		return
	_sync_ui_pointer_block()
	if TouchMode.is_touch() and _touch_hover_sticky:
		return
	if _interaction_host and _interaction_host.has_method("exit_card"):
		_interaction_host.exit_card(id)
	

func _on_gui_input(event: InputEvent) -> void:
	if _recycle_hovered:
		return
	if TouchMode.is_touch():
		_handle_touch_gui_input(event)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			GameFeedback.play_click_card()
			if _interaction_host and _interaction_host.has_method("select_card"):
				_interaction_host.select_card(id)
			get_viewport().set_input_as_handled()


func _handle_touch_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and TouchMode.is_emulated_mouse_event(event):
		return
	var is_press := false
	var is_release := false
	if event is InputEventScreenTouch:
		is_press = event.pressed
		is_release = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
		is_release = not event.pressed
	if not is_press and not is_release:
		return
	if is_press:
		_touch_press_active = true
		_long_press_fired = false
		_long_press_timer.start()
		get_viewport().set_input_as_handled()
		return
	if not _touch_press_active:
		return
	_touch_press_active = false
	_long_press_timer.stop()
	if _long_press_fired:
		_long_press_fired = false
		get_viewport().set_input_as_handled()
		return
	GameFeedback.play_click_card()
	if _interaction_host and _interaction_host.has_method("select_card"):
		_interaction_host.select_card(id)
	get_viewport().set_input_as_handled()


func _on_long_press_timeout() -> void:
	if not _touch_press_active:
		return
	_long_press_fired = true
	_touch_hover_sticky = true
	if _interaction_host and _interaction_host.has_method("hover_card"):
		_interaction_host.hover_card(id)

## ----- Stack Logic ----- ##

func set_stack_amount(amount: int, animate: bool = true) -> void:
	if stack_amount == amount:
		return
	# #region agent log
	_dbg_recycle("A", "card.gd:set_stack_amount", "stack amount changing", {
		"card_id": id,
		"is_animal": is_animal,
		"from": stack_amount,
		"to": amount,
		"is_active": is_active,
		"is_mouse_inside": is_mouse_inside,
		"visuals_pos_y": visuals.position.y,
		"target_visuals_y": target_visuals_position.y,
		"hit_offset_top": hit_area.offset_top,
		"recycle_pos_y": recycle_btn.position.y,
	})
	# #endregion
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

	var extra := float(depth - 1) * STACK_STEP_PX
	shadow.offset_top = _shadow_base_offset_top - extra
	hit_area.offset_top = _hit_area_base_offset_top - extra
	hit_area.pivot_offset = hit_area.size * 0.5
	_hit_area_base_position = hit_area.position
	# #region agent log
	_dbg_recycle("A", "card.gd:_apply_stack_visuals", "before hit/recycle sync", {
		"card_id": id,
		"is_animal": is_animal,
		"stack_amount": stack_amount,
		"depth": depth,
		"extra": extra,
		"is_active": is_active,
		"visuals_pos_y": visuals.position.y,
		"hit_offset_top_after_stack": hit_area.offset_top,
		"hit_base_offset_top": _hit_area_base_offset_top,
		"hit_base_pos_y": _hit_area_base_position.y,
		"recycle_pos_y_before": recycle_btn.position.y,
		"recycle_base_y": _recycle_base_position.y,
	})
	# #endregion
	_sync_hit_area_to_visuals()
	_sync_recycle_button_stack_offset()
	# #region agent log
	_dbg_recycle("D", "card.gd:_apply_stack_visuals", "after hit/recycle sync", {
		"card_id": id,
		"hit_offset_top": hit_area.offset_top,
		"hit_pos_y": hit_area.position.y,
		"visuals_pos_y": visuals.position.y,
		"recycle_pos_y": recycle_btn.position.y,
		"baked_delta_y": _hit_area_base_offset_top - hit_area.offset_top,
	})
	# #endregion

## ----- Other Logic ----- ##

func handle_hover() -> void:
	if is_animal:
		placement_tooltip.show()
	if !is_active:
		GameFeedback.play_hover_card()
		set_select_visuals()
	refresh_recycle_button(true)

func handle_exit() -> void:
	_touch_hover_sticky = false
	placement_tooltip.hide()
	if !is_active:
		reset_select_visuals()
	refresh_recycle_button(false)

func select() -> void:
	is_active = true
	_touch_hover_sticky = false
	self.z_index = base_z_index + 100
	if target_visuals_position == base_visuals_position:
		set_select_visuals()

func deselect() -> void:
	is_active = false
	_touch_hover_sticky = false
	self.z_index = base_z_index
	reset_select_visuals()
	placement_tooltip.hide()

func remove_card() -> void:
	# #region agent log
	_agent_dbg("A", "card.gd:remove_card", "remove_card called", {
		"card_id": id,
		"card_in_tree": is_inside_tree(),
		"is_mouse_inside": is_mouse_inside,
		"recycle_visible": recycle_btn != null and recycle_btn.visible,
	})
	# #endregion
	UiPointerBlock.exit(self)
	UiPointerBlock.exit(recycle_btn)
	kill_animations()
	queue_free()


func _exit_tree() -> void:
	# #region agent log
	_agent_dbg("E", "card.gd:_exit_tree", "card leaving tree", {
		"card_id": id,
		"is_mouse_inside": is_mouse_inside,
		"recycle_visible": recycle_btn != null and recycle_btn.visible,
		"vp_null": get_viewport() == null,
	})
	# #endregion
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
	var points_mat := $visuals/points/background.material as ShaderMaterial
	if points_mat != null:
		points_mat.set_shader_parameter("unfilled_color", color)
	if is_animal and $visuals/bonus_points.visible:
		var bonus_mat := $visuals/bonus_points/background.material as ShaderMaterial
		if bonus_mat != null:
			bonus_mat.set_shader_parameter("unfilled_color", color)
	var icon_mod := Color(0.7, 0.7, 0.7, 1.0) if desaturate else Color.WHITE
	$visuals/icon.modulate = icon_mod
	$visuals/CardLabel.modulate = icon_mod
	$visuals/points.modulate = icon_mod
	$visuals/bonus_points.modulate = icon_mod
	if $visuals/elementicon.visible:
		$visuals/elementicon.modulate = icon_mod


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
	_sync_hit_area_to_visuals()
	_sync_ui_pointer_block()


func _sync_hit_area_to_visuals() -> void:
	hit_area.scale = visuals.scale
	hit_area.position = _hit_area_base_position + visuals.position


func _control_has_mouse(control: Control) -> bool:
	if control == null or not control.visible:
		return false
	var in_tree := control.is_inside_tree()
	var vp_null := control.get_viewport() == null
	if not in_tree or vp_null:
		# #region agent log
		_agent_dbg("A", "card.gd:_control_has_mouse", "unsafe mouse query", {
			"card_id": id,
			"control_name": str(control.name),
			"in_tree": in_tree,
			"vp_null": vp_null,
			"card_in_tree": is_inside_tree(),
			"visible": control.visible,
			"runId": "post-fix",
		})
		# #endregion
		return false
	return control.get_global_rect().has_point(control.get_global_mouse_position())


func _is_pointer_over_recycle() -> bool:
	return recycle_btn.visible and _control_has_mouse(recycle_btn)


func _is_pointer_over_card_ui() -> bool:
	return _control_has_mouse(hit_area) or _is_pointer_over_recycle()


func _sync_ui_pointer_block() -> void:
	UiPointerBlock.set_hovering(self, _is_pointer_over_card_ui())
	if not _is_pointer_over_recycle():
		UiPointerBlock.exit(recycle_btn)


## ----- Recycle X (animals only; node in card.tscn → HitArea/RecycleButton) ----- ##

## Keeps editor X/Y; only shifts Y when HitArea grows for stacked cards.
## Uses stack depth, not live offset_top — hover sync overwrites offset_top.
func _sync_recycle_button_stack_offset() -> void:
	var depth := mini(maxi(stack_amount, 1), STACK_VISUAL_CAP)
	var delta_y := float(depth - 1) * STACK_STEP_PX
	# #region agent log
	_dbg_recycle("B", "card.gd:_sync_recycle_button_stack_offset", "reposition recycle", {
		"card_id": id,
		"recycle_base_y": _recycle_base_position.y,
		"delta_y": delta_y,
		"new_recycle_y": _recycle_base_position.y + delta_y,
		"hit_offset_top": hit_area.offset_top,
		"hit_base_offset_top": _hit_area_base_offset_top,
		"visuals_pos_y": visuals.position.y,
		"stack_amount": stack_amount,
		"contaminated_delta_y": _hit_area_base_offset_top - hit_area.offset_top,
	})
	# #endregion
	recycle_btn.position = _recycle_base_position + Vector2(0.0, delta_y)


func refresh_recycle_button(show: bool) -> void:
	var visible := show and _recycle_enabled and is_animal
	# #region agent log
	if recycle_btn.visible and not visible:
		_agent_dbg("B", "card.gd:refresh_recycle_button", "hiding recycle button", {
			"card_id": id,
			"card_in_tree": is_inside_tree(),
			"vp_null": get_viewport() == null,
			"is_mouse_inside": is_mouse_inside,
		})
	# #endregion
	recycle_btn.visible = visible
	# #region agent log
	if visible:
		_dbg_recycle("E", "card.gd:refresh_recycle_button", "showing recycle button", {
			"card_id": id,
			"recycle_pos_y": recycle_btn.position.y,
			"recycle_base_y": _recycle_base_position.y,
			"hit_offset_top": hit_area.offset_top,
			"hit_pos_y": hit_area.position.y,
			"visuals_pos_y": visuals.position.y,
			"stack_amount": stack_amount,
			"is_active": is_active,
		})
	# #endregion
	recycle_btn.mouse_filter = (
		Control.MOUSE_FILTER_STOP if visible else Control.MOUSE_FILTER_IGNORE
	)
	if not visible:
		_recycle_hovered = false
		_reset_recycle_button_colors()
		UiPointerBlock.exit(recycle_btn)
	_sync_ui_pointer_block()


func _on_recycle_gui_input(event: InputEvent) -> void:
	if not _recycle_enabled:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			GameFeedback.play_click_button()
			# #region agent log
			_dbg87("A", "card.gd:_on_recycle_gui_input", "recycle X clicked", {
				"card_id": id,
				"is_animal": is_animal,
				"in_tree": is_inside_tree(),
				"queued_free": is_queued_for_deletion(),
				"recycle_visible": recycle_btn != null and recycle_btn.visible,
			})
			# #endregion
			if container != null and container.has_method("recycle_card"):
				container.recycle_card(id)
			elif _interaction_host != null and _interaction_host.has_method("reroll_card"):
				_interaction_host.reroll_card(id)
			elif _interaction_host != null and _interaction_host.has_method("recycle_card"):
				_interaction_host.recycle_card(id)
			get_viewport().set_input_as_handled()


func _on_recycle_mouse_entered() -> void:
	if not _recycle_enabled:
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
	# #region agent log
	_dbg87("A", "card.gd:_on_recycle_mouse_exited", "recycle mouse exited", {
		"card_id": id,
		"is_animal": is_animal,
		"in_tree": is_inside_tree(),
		"queued_free": is_queued_for_deletion(),
		"recycle_visible": recycle_btn != null and recycle_btn.visible,
		"hit_has_mouse": _control_has_mouse(hit_area),
		"host_valid": _interaction_host != null and is_instance_valid(_interaction_host),
	})
	# #endregion
	_recycle_hovered = false
	UiPointerBlock.exit(recycle_btn)
	_reset_recycle_button_colors()
	if _interaction_host != null and _interaction_host.has_method("set_recycle_hover"):
		_interaction_host.set_recycle_hover(id, false)
	_sync_ui_pointer_block()
	# Left X into empty space (not back onto the card body).
	if not _control_has_mouse(hit_area):
		is_mouse_inside = false
		if TouchMode.is_touch() and _touch_hover_sticky:
			return
		# Recycle already removed this card; skip hover-exit on a freed slot.
		if is_queued_for_deletion():
			return
		if _interaction_host != null and _interaction_host.has_method("exit_card"):
			_interaction_host.exit_card(id)


func _reset_recycle_button_colors() -> void:
	recycle_circle.self_modulate = Color.WHITE
	recycle_label.add_theme_color_override("font_color", COLOR_BROWN)

# #region agent log
func _dbg_recycle(hyp: String, loc: String, msg: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "3fc6cd",
		"runId": "post-fix",
		"hypothesisId": hyp,
		"location": loc,
		"message": msg,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
	}
	var path := "c:/Users/leonn/Documents/Harmonies-Cascadia/debug-3fc6cd.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f.seek_end()
	if f != null:
		f.store_line(JSON.stringify(payload))
		f.close()

func _dbg87(hyp: String, loc: String, msg: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "87ce77",
		"hypothesisId": hyp,
		"location": loc,
		"message": msg,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
	}
	var path := "c:/Users/leonn/Documents/Harmonies-Cascadia/debug-87ce77.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f.seek_end()
	if f != null:
		f.store_line(JSON.stringify(payload))
		f.close()

func _agent_dbg(hyp: String, loc: String, msg: String, data: Dictionary) -> void:
	var payload := {
		"sessionId": "22fdc4",
		"hypothesisId": hyp,
		"location": loc,
		"message": msg,
		"data": data,
		"timestamp": int(Time.get_unix_time_from_system() * 1000.0),
	}
	var path := "c:/Users/leonn/Documents/Harmonies-Cascadia/debug-22fdc4.log"
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(path, FileAccess.WRITE)
	else:
		f.seek_end()
	if f != null:
		f.store_line(JSON.stringify(payload))
		f.close()
# #endregion

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
