extends Node2D
## Standalone animal card grid. Open scenes/debug/animal_card_grid_demo.tscn and run (F6).

const CARD_SCENE := preload("res://scenes/card/card.tscn")
const CARD_EXTENT := Rect2(-50.0, -122.0, 100.0, 220.0)

@export var columns: int = 8
@export var cell_size: Vector2 = Vector2(130, 220)
@export var margin: float = 40.0

@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	await get_tree().process_frame
	_spawn_grid()
	_fit_camera()


func _spawn_grid() -> void:
	if CardCatalog.animals.is_empty():
		push_error("AnimalCardGridDemo: CardCatalog.animals is empty")
		return

	var cols := maxi(columns, 1)
	for i in CardCatalog.animals.size():
		var card_data: CardData = CardCatalog.animals[i].duplicate(true)
		var card := CARD_SCENE.instantiate() as Card
		add_child(card)
		card.init(card_data, self, i)
		var col := i % cols
		var row := floori(float(i) / float(cols))
		card.apply_layout(Vector2(float(col) * cell_size.x, float(row) * cell_size.y), 0.0, 0)


func _fit_camera() -> void:
	var count := CardCatalog.animals.size()
	if count == 0 or camera == null:
		return

	var cols := mini(maxi(columns, 1), count)
	var rows := ceili(float(count) / float(maxi(columns, 1)))
	var grid_size := Vector2(
		(cols - 1) * cell_size.x + CARD_EXTENT.size.x,
		(rows - 1) * cell_size.y + CARD_EXTENT.size.y,
	)
	camera.position = CARD_EXTENT.position + grid_size * 0.5

	var vp := get_viewport_rect().size
	var padded := grid_size + Vector2(margin, margin) * 2.0
	var zoom := minf(vp.x / padded.x, vp.y / padded.y)
	camera.zoom = Vector2(zoom, zoom)
	camera.make_current()
