extends Node2D
class_name PointCounter

@export var orchestrator : Orchestrator
@export var checkpoint: int = 100

var target : int = 0
var current: int = 0
var preview: int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	target = checkpoint
	$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value", 0.0)
	$ProgressBar.material.set_shader_parameter("third_value", 0.0)
	$CurrentLabel.text = "%d" % current
	$TargetLabel.text  = "%d" % target

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
			$CurrentLabel.text = "%d + %d" % [current, preview]
		else:
			$ProgressBar.material.set_shader_parameter("third_value",  0.0)
			$ProgressBar.material.set_shader_parameter("current_value",  float(preview) / float(target))
			$CurrentLabel.text = "%d - %d" % [current, preview]

func apply_preview() -> void:
	current = preview
	$ProgressBar.material.set_shader_parameter("third_value",  0.0)
	$ProgressBar.material.set_shader_parameter("current_value",  0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value",  float(current) / float(target))
	$CurrentLabel.text = "%d" % current
	
	if current >= target:
		target += checkpoint
		orchestrator.add_map_point()

func reset_preview() -> void:
	preview = current
	apply_preview()
