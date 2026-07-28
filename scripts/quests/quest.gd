extends Area2D
class_name QuestItem

var quest_container: QuestContainer

@onready var placement_tooltip: PlacementTooltip = $PlacementTooltip

var target: int = 1
var current: int = 0
var preview: int = 0

var current_backup: int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	input_pickable = true

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	var original_mat := $ProgressBar.material as Material
	$ProgressBar.material = original_mat.duplicate()
	$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value", 0.0)
	$ProgressBar.material.set_shader_parameter("third_value", 0.0)

func init(container: QuestContainer, quest: Quest) -> void:
	quest_container = container
	target = 1
	current = 0
	preview = 0
	$PlacementTooltip.init(
		1,
		quest.placement,
		quest.bonus,
		"+%d" % quest.points,
		PlacementTooltip.ArrowSide.RIGHT
	)
	set_pattern_quest_visuals(quest)

## ----- Interactions Logic ----- ##

func _on_mouse_entered() -> void:
	placement_tooltip.show()

func _on_mouse_exited() -> void:
	placement_tooltip.hide()

## ----- Down stream Logic ----- ##

func preview_progress(val: int) -> void:
	if val > target:
		preview = target
	else:
		preview = val

	if val == current:
		$ProgressBar.material.set_shader_parameter("third_value", 0.0)
		$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	else:
		if val > current:
			$ProgressBar.material.set_shader_parameter("current_value", 0.0)
			$ProgressBar.material.set_shader_parameter("third_value", float(preview) / float(target))
		else:
			$ProgressBar.material.set_shader_parameter("third_value", 0.0)
			$ProgressBar.material.set_shader_parameter("current_value", float(preview) / float(target))

func apply_preview() -> void:
	current_backup = current
	current = preview
	set_current_style()

func reset_preview() -> void:
	preview = current
	set_current_style()

func undo() -> void:
	preview = current_backup
	current = current_backup
	set_current_style()

## ----- Other Logic ----- ##

func remove_quest() -> void:
	queue_free()

## ----- Utility Functions ----- ##

func set_pattern_quest_visuals(quest: Quest) -> void:
	if quest.placement.is_empty():
		return
	var center := quest.placement[0]
	var levels: Array = ElementCatalog.elements[center.element].levels
	var level_index := clampi(center.level - 1, 0, levels.size() - 1)
	var level = levels[level_index]
	$Background.self_modulate = Color.html(level.color)
	set_icon(level.icon, 300)

func set_icon(icon_path: String, width: float) -> void:
	var icon: Texture2D = load(icon_path)
	var texture_size := icon.get_size()
	var scale_factor = min(
		width / texture_size.x,
		width / texture_size.y
	)
	$Background/Icon.scale = Vector2.ONE * scale_factor
	$Background/Icon.texture = icon

func set_current_style() -> void:
	$ProgressBar.material.set_shader_parameter("third_value", 0.0)
	$ProgressBar.material.set_shader_parameter("current_value", 0.0)
	$ProgressBar.material.set_shader_parameter("lerp_value", float(current) / float(target))
