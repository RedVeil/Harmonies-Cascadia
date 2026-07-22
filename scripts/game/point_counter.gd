extends Node2D
class_name PointCounter

@export var orchestrator : Orchestrator
@export var checkpoint: int = 100
@export var checkpoint_multiplier : float = 2.0

@export_group("Score Punch Animation")
@export var punch_scale: float = 1.14
@export var punch_up_duration: float = 0.12
@export var punch_settle_duration: float = 0.2
@export var hex_base_scale: Vector2 = Vector2(0.3, 0.3)
@export var hex_peak_scale: Vector2 = Vector2(0.34, 0.34)

@export_group("Score Count Animation")
@export var count_duration: float = 0.55
@export var score_reward_sounds: Array[AudioStream] = []

@export_group("Score Gain Popup Animation")
@export var gain_popup_start: Vector2 = Vector2(72.0, 0.0)
@export var gain_popup_end: Vector2 = Vector2(90.0, -14.0)
@export var gain_popup_scale_in_duration: float = 0.2
@export var gain_popup_float_duration: float = 0.75
@export var gain_popup_fade_duration: float = 0.45
@export var gain_popup_fade_delay: float = 0.35

var target : int = 0
var current: int = 0
var preview: int = 0

var is_hovered : bool = false
var timer : float = 0.5

var current_backup: int = 0
var target_backup: int = 0

var _feedback_tweens: Dictionary = {}
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

## ----- Score Logic ----- ##

func preview_progress(val:int) -> void:
	if val > target:
		preview = target
	else:
		preview = val

	# Keep logical preview updated, but don't fight an in-flight score reward.
	if _is_score_reward_playing():
		return
		
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
		play_animation(&"score_reward", {
			"gained": gained,
			"from_score": current_backup,
			"to_score": current,
		})
	elif not _is_score_reward_playing():
		apply_current_style()

func reset_preview() -> void:
	preview = current
	# Never cut a score reward short; only the next score_reward may replace it.
	if _is_score_reward_playing():
		return
	kill_animations()
	apply_current_style()

func undo() -> void:
	kill_animations()
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

## ----- Animations ----- ##

func play_animation(name: StringName, params: Dictionary) -> void:
	match name:
		&"score_reward":
			_animate_score_reward(
				params.get("gained", 0),
				params.get("from_score", current),
				params.get("to_score", current)
			)

func kill_animations() -> void:
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	_finish_gain_popup()
	apply_current_style()

func _is_score_reward_playing() -> bool:
	for key in [&"reward", &"punch"]:
		var tw: Variant = _feedback_tweens.get(key)
		if tw is Tween and tw.is_valid():
			return true
	return false

func ensure_score_label_pivot() -> void:
	score_label.pivot_offset = score_label.size * 0.5

func _animate_score_reward(gained: int, from_score: int, to_score: int) -> void:
	# Allowed interrupt: replacing the previous score reward with the next one.
	FeedbackAnimHelper.kill_all(_feedback_tweens)
	_finish_gain_popup()
	FeedbackAnimHelper.play_sounds(score_reward_sounds)

	ensure_score_label_pivot()
	_setup_gain_popup_text(gained)

	score_label.scale = Vector2.ONE
	progress_sprite.scale = hex_base_scale
	background_sprite.scale = hex_base_scale

	var punch := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"punch")
	punch.set_parallel(true)
	punch.tween_property(score_label, "scale", Vector2(punch_scale, punch_scale), punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(progress_sprite, "scale", hex_peak_scale, punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(background_sprite, "scale", hex_peak_scale, punch_up_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.chain().tween_property(score_label, "scale", Vector2.ONE, punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	punch.parallel().tween_property(progress_sprite, "scale", hex_base_scale, punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	punch.parallel().tween_property(background_sprite, "scale", hex_base_scale, punch_settle_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	gain_popup.position = gain_popup_start
	gain_popup.scale = Vector2(0.6, 0.6)
	gain_popup.modulate = Color(1, 1, 1, 1)
	gain_label.visible = true

	var reward := FeedbackAnimHelper.create_tween(self, _feedback_tweens, &"reward", true)
	reward.tween_method(
		_set_animated_score_display,
		float(from_score),
		float(to_score),
		count_duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reward.tween_property(gain_popup, "scale", Vector2.ONE, gain_popup_scale_in_duration)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reward.tween_property(gain_popup, "position", gain_popup_end, gain_popup_float_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reward.tween_property(gain_popup, "modulate:a", 0.0, gain_popup_fade_duration)\
		.set_delay(gain_popup_fade_delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	reward.chain().tween_callback(func() -> void:
		_finish_gain_popup()
		apply_current_style()
	)

func _setup_gain_popup_text(gained: int) -> void:
	if gained > 0:
		_gain_label.text = "+%d" % gained
		_gain_label.add_theme_color_override("font_color", Color(0.95, 0.72, 0.2, 1.0))
	else:
		_gain_label.text = "%d" % gained
		_gain_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35, 1.0))

func _set_animated_score_display(value: float) -> void:
	var shown := int(round(value))
	$Label.text = "%d" % shown
	var progress := clampf(float(shown) / float(target), 0.0, 1.0)
	$ProgressBar.material.set_shader_parameter("third_value", 0.0)
	$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value", progress)
	$Tooltip/Label.text = "This is you score. Earn enough points to unlock additional tiles to play with.\n(%d / %d)" % [shown, target]

func _finish_gain_popup() -> void:
	gain_label.visible = false
	gain_popup.modulate = Color.WHITE
	gain_popup.position = gain_popup_start
	gain_popup.scale = Vector2.ONE

## ----- Utility Logic ----- ##

func apply_current_style() -> void:
	$Label.scale = Vector2.ONE
	$ProgressBar.scale = hex_base_scale
	$Sprite2D.scale = hex_base_scale
	$ProgressBar.material.set_shader_parameter("third_value",  0.0)
	$ProgressBar.material.set_shader_parameter("current_value",  0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value",  float(current) / float(target))
	$Label.text = "%d" % current
	
	$Tooltip/Label.text = "This is you score. Earn enough points to unlock additional tiles to play with.\n(%d / %d)" % [current, target]
