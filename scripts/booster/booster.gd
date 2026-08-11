extends Area2D
class_name Booster

const FRAME_MATERIAL := preload("res://assets/ui/sdf_card_frame.tres")
const STACK_SCALE := 0.75 # 75% of hand-card size
const HOVER_LIFT_PX := 14.0
const HOVER_TWEEN_SEC := 0.12
const DESATURATE_AMOUNT := 0.45
var FALLBACK_COLOR := Color(0.5686275, 0.5176471, 0.47058824, 1.0)
var COLOR_BROWN := Color.html("#918478")

@export var id: int = 0

@onready var icon: Sprite2D = $icon
@onready var background: Sprite2D = $background
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var progress_sprite: Sprite2D = $ProgressBar
@onready var stack_visuals: Node2D = $StackVisuals
@onready var frame: TextureRect = $StackVisuals/Frame
@onready var frame_2: TextureRect = $StackVisuals/Frame2
@onready var frame_3: TextureRect = $StackVisuals/Frame3
@onready var shadow: TextureRect = $StackVisuals/Shadow
@onready var element_icon: TextureRect = $StackVisuals/ElementIcon
@onready var hover_button: Area2D = $StackVisuals/HoverButton
@onready var hover_button_circle: Sprite2D = $StackVisuals/HoverButton/Circle
@onready var hover_button_label: Label = $StackVisuals/HoverButton/Label

var container: BoosterContainer
var enabled: bool = true
var is_hovered: bool = false
var _reroll_ready: bool = true
var _reroll_hovered: bool = false

var _stack_frames: Array[TextureRect] = []
var _base_body_colors: Array[Color] = []
var _hover_tween: Tween
var _stack_base_y: float = 0.0

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = true
	_stack_frames = [frame, frame_2, frame_3]
	_stack_base_y = stack_visuals.position.y
	if progress_sprite and progress_sprite.material:
		progress_sprite.material = progress_sprite.material.duplicate()
	_configure_mode_chrome()
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
		var rect := RectangleShape2D.new()
		# Hand card is 100x174; packs are STACK_SCALE of that, plus peek.
		rect.size = Vector2(100.0 * STACK_SCALE + 3.0, 174.0 * STACK_SCALE + 20.0)
		collision.shape = rect
		# Origin at card center so the bottom half sits off-screen.
		collision.position = Vector2(0, -8)
	else:
		stack_visuals.visible = false
		background.visible = false
		icon.visible = false
		progress_sprite.visible = false
		hover_button.visible = false
		var circle := CircleShape2D.new()
		circle.radius = 20.0
		collision.shape = circle
		collision.position = Vector2.ZERO

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
		hover_button.visible = false
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

func _on_mouse_entered() -> void:
	UiPointerBlock.enter(self)
	GameFeedback.play_hover_button()
	is_hovered = true
	_apply_hover_visuals()

func _on_mouse_exited() -> void:
	UiPointerBlock.exit(self)
	is_hovered = false
	_apply_hover_visuals()

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
	hover_button.visible = show_x
	hover_button.input_pickable = show_x
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

func _on_input_event(
	viewport: Viewport,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and enabled:
			if _reroll_hovered:
				return
			GameFeedback.play_click_button()
			container.select_booster(id)
			viewport.set_input_as_handled()

func _on_reroll_input_event(
	viewport: Viewport,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not enabled or not _reroll_ready:
				return
			GameFeedback.play_click_button()
			container.reroll_booster(id)
			viewport.set_input_as_handled()

func _on_reroll_mouse_entered() -> void:
	_reroll_hovered = true
	UiPointerBlock.enter(hover_button)
	if _reroll_ready:
		GameFeedback.play_hover_button()
		hover_button_circle.self_modulate = COLOR_BROWN
		hover_button_label.add_theme_color_override("font_color", Color.WHITE)

func _on_reroll_mouse_exited() -> void:
	_reroll_hovered = false
	UiPointerBlock.exit(hover_button)
	hover_button_circle.self_modulate = Color.WHITE
	hover_button_label.add_theme_color_override("font_color", COLOR_BROWN)

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
	var extra := float(maxi(depth - 1, 0)) * 12.0
	shadow.offset_top = -78.0 - extra

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
