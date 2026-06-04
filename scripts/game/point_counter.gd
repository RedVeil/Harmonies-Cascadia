extends Node2D
class_name PointCounter

@export var orchestrator : Orchestrator
@export var checkpoint: int = 100
@export var checkpoint_multiplier : float = 2.0

var target : int = 0
var current: int = 0
var preview: int = 0

var is_hovered : bool = false
var timer : float = 0.5

var current_backup: int = 0
var target_backup: int = 0

var _reward_tweens: Dictionary = {}
var _gain_popup : Node2D
var _gain_label : Label

var score_label : Label
var progress_sprite : Sprite2D
var background_sprite : Sprite2D
var gain_popup : Node2D
var gain_label : Label

## ----- Initialisation ----- ##

func _ready() -> void:
	target = checkpoint
	$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value", 0.0)
	$ProgressBar.material.set_shader_parameter("third_value", 0.0)
	$Label.text = "%d" % current
	$Tooltip/Label.text = "This is you Point Score. Earn enough points to unlock additional tiles to play with.\n(0 / %d)" % target
	_setup_gain_label()
	score_label = $Label
	progress_sprite = $ProgressBar
	background_sprite = $Sprite2D
	gain_popup = _gain_popup
	gain_label = _gain_label
	call_deferred("ensure_score_label_pivot")

## ----- Down stream Logic ----- ##

func preview_progress(val:int) -> void:
	if val > target:
		preview = target
	else:
		preview = val
		
	if val == current:
		$ProgressBar.material.set_shader_parameter("third_value",  0.0)
		$ProgressBar.material.set_shader_parameter("current_value",  0.0)
	else:
		if val > current:
			$ProgressBar.material.set_shader_parameter("current_value",  0.0)
			$ProgressBar.material.set_shader_parameter("third_value",  float(preview) / float(target))
		else:
			$ProgressBar.material.set_shader_parameter("third_value",  0.0)
			$ProgressBar.material.set_shader_parameter("current_value",  float(preview) / float(target))
		
		$Label.text = "%d" % current
		$Tooltip/Label.text = "This is you Point Score. Earn enough points to unlock additional tiles to play with.\n(%d / %d)" % [preview, target]

func apply_preview(animate_reward: bool = false) -> void:
	current_backup = current
	target_backup = target
	var gained := preview - current_backup
	current = preview
	
	if current >= target:
		target = target * checkpoint_multiplier
		orchestrator.add_map_points(1)
	
	if animate_reward and gained != 0:
		GameFeedback.run_point_counter_reward(self, gained, current_backup, current)
	else:
		apply_current_style()

func reset_preview() -> void:
	preview = current
	apply_current_style()

func undo() -> void:
	current = current_backup
	preview = current_backup
	target = target_backup
	apply_current_style()

## ----- Tooltip Logic ----- ##

func _process(delta:float) -> void:
	if is_hovered:
		timer -= delta
		if timer <= 0.0:
			$Tooltip.show()

func _on_mouse_entered() -> void:
	is_hovered = true
	timer = 0.5

func _on_mouse_exited() -> void:
	is_hovered = false
	timer = 0.5
	$Tooltip.hide()

## ----- Reward feedback API (used by GameFeedback) ----- ##

func set_reward_tween(key: StringName, tween: Tween) -> void:
	if _reward_tweens.has(key):
		var existing: Tween = _reward_tweens[key]
		if existing.is_valid():
			existing.kill()
	_reward_tweens[key] = tween

func kill_reward_tweens() -> void:
	for key in _reward_tweens.keys():
		var tween: Tween = _reward_tweens[key]
		if tween.is_valid():
			tween.kill()
	_reward_tweens.clear()

func ensure_score_label_pivot() -> void:
	score_label.pivot_offset = score_label.size * 0.5

func setup_gain_popup_text(gained: int) -> void:
	if gained > 0:
		_gain_label.text = "+%d" % gained
		_gain_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.2, 1.0))
	else:
		_gain_label.text = "%d" % gained
		_gain_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35, 1.0))

func set_animated_score_display(value: float) -> void:
	var shown := int(round(value))
	$Label.text = "%d" % shown
	var progress := clampf(float(shown) / float(target), 0.0, 1.0)
	$ProgressBar.material.set_shader_parameter("third_value", 0.0)
	$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value", progress)
	$Tooltip/Label.text = "This is you Point Score. Earn enough points to unlock additional tiles to play with.\n(%d / %d)" % [shown, target]

func finish_reward_popup() -> void:
	_gain_label.visible = false
	_gain_popup.modulate = Color.WHITE
	_gain_popup.position = GameFeedback.settings.point_gain_popup_start
	_gain_popup.scale = Vector2.ONE

func _setup_gain_label() -> void:
	_gain_popup = Node2D.new()
	_gain_popup.name = "GainPopup"
	_gain_popup.z_index = 2
	add_child(_gain_popup)

	_gain_label = Label.new()
	_gain_label.visible = false
	_gain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gain_label.offset_left = -36.0
	_gain_label.offset_top = -16.0
	_gain_label.offset_right = 36.0
	_gain_label.offset_bottom = 16.0
	_gain_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 1))
	_gain_label.add_theme_constant_override("outline_size", 5)
	_gain_label.add_theme_font_size_override("font_size", 28)
	_gain_popup.add_child(_gain_label)

func _reset_reward_scales() -> void:
	var cfg : GameFeedbackSettings = GameFeedback.settings
	$Label.scale = Vector2.ONE
	$ProgressBar.scale = cfg.point_hex_base_scale
	$Sprite2D.scale = cfg.point_hex_base_scale

## ----- Utility Logic ----- ##

func apply_current_style() -> void:
	_reset_reward_scales()
	$ProgressBar.material.set_shader_parameter("third_value",  0.0)
	$ProgressBar.material.set_shader_parameter("current_value",  0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value",  float(current) / float(target))
	$Label.text = "%d" % current
	
	$Tooltip/Label.text = "This is you Point Score. Earn enough points to unlock additional tiles to play with.\n(%d / %d)" % [current, target]
