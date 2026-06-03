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

## ----- Initialisation ----- ##

func _ready() -> void:
	target = checkpoint
	$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value", 0.0)
	$ProgressBar.material.set_shader_parameter("third_value", 0.0)
	$Label.text = "%d" % current
	$Tooltip/Label.text = "This is you Point Score. Earn enough points to unlock additional tiles to play with.\n(0 / %d)" % target

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


func apply_preview() -> void:
	current = preview
	$ProgressBar.material.set_shader_parameter("third_value",  0.0)
	$ProgressBar.material.set_shader_parameter("current_value",  0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value",  float(current) / float(target))
	$Label.text = "%d" % current
	
	if current >= target:
		target = target * checkpoint_multiplier 
		orchestrator.add_map_points(1)
	
	$Tooltip/Label.text = "This is you Point Score. Earn enough points to unlock additional tiles to play with.\n(%d / %d)" % [current, target]


func reset_preview() -> void:
	preview = current
	apply_preview()


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
