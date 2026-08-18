extends Node2D
## Standalone quest tooltip grid. Open scenes/debug/quest_tooltip_grid_demo.tscn and run (F6).

const TOOLTIP_SCENE := preload("res://scenes/game/placement_tooltip.tscn")
const TOOLTIP_EXTENT := Rect2(0.0, 0.0, 100.0, 130.0)

@export var columns: int = 6
@export var cell_size: Vector2 = Vector2(120, 150)
@export var margin: float = 40.0
@export var arrow_side: PlacementTooltip.ArrowSide = PlacementTooltip.ArrowSide.BELOW

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	await get_tree().process_frame
	_spawn_grid()
	_fit_camera()


func _spawn_grid() -> void:
	if QuestCatalog.quest_options.is_empty():
		push_error("QuestTooltipGridDemo: QuestCatalog.quest_options is empty")
		return

	var cols := maxi(columns, 1)
	for i in QuestCatalog.quest_options.size():
		var quest: Quest = QuestCatalog.quest_options[i].duplicate(true)
		var tip := TOOLTIP_SCENE.instantiate() as PlacementTooltip
		add_child(tip)
		tip.init(1, quest.placement, quest.bonus, "=%d" % quest.points, arrow_side)
		var col := i % cols
		var row := floori(float(i) / float(cols))
		tip.position = Vector2(float(col) * cell_size.x, float(row) * cell_size.y)


func _fit_camera() -> void:
	var count := QuestCatalog.quest_options.size()
	if count == 0 or camera == null:
		return

	var cols := mini(maxi(columns, 1), count)
	var rows := ceili(float(count) / float(maxi(columns, 1)))
	var grid_size := Vector2(
		(cols - 1) * cell_size.x + TOOLTIP_EXTENT.size.x,
		(rows - 1) * cell_size.y + TOOLTIP_EXTENT.size.y,
	)
	camera.position = TOOLTIP_EXTENT.position + grid_size * 0.5

	var vp := get_viewport_rect().size
	var padded := grid_size + Vector2(margin, margin) * 2.0
	var zoom := minf(vp.x / padded.x, vp.y / padded.y)
	camera.zoom = Vector2(zoom, zoom)
	camera.make_current()
