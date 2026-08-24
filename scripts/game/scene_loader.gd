extends CanvasLayer
## Autoload overlay for scene changes. Blocks input and keeps a spinner
## visible until the destination scene (including HexManager warmup) is ready.

const SPIN_RAD_PER_SEC := 1.6

var COLOR_DIM := Color(0.8235294, 0.7607843, 0.6784314, 0.55)
var COLOR_HEX := Color.html("#918478")

@onready var _dimmer: ColorRect = $Dimmer
@onready var _hex: TextureRect = $Hex

var _busy: bool = false
var _pending_path: String = ""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dimmer.color = COLOR_DIM
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_hex.modulate = COLOR_HEX
	_hex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	set_process(false)


func _process(delta: float) -> void:
	_hex.rotation += SPIN_RAD_PER_SEC * delta


func goto(path: String) -> void:
	if path.is_empty():
		return
	if _busy:
		_pending_path = path
		return
	_busy = true
	_show_overlay()
	await _transition(path)


func reload() -> void:
	if _busy:
		return
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene != null else ""
	if path.is_empty():
		path = "res://scenes/Refactored_Main.tscn"
	_pending_path = ""
	_busy = true
	_show_overlay()
	await _transition(path)


func _show_overlay() -> void:
	_hex.rotation = 0.0
	show()
	set_process(true)


func _hide_overlay() -> void:
	hide()
	set_process(false)
	_hex.rotation = 0.0


func _transition(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var err := ResourceLoader.load_threaded_request(path)
	if err != OK:
		push_warning("SceneLoader: could not request %s (%s)" % [path, error_string(err)])
		_abort()
		return

	while true:
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED \
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("SceneLoader: failed to load %s" % path)
			_abort()
			return
		await get_tree().process_frame

	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	if packed == null:
		push_warning("SceneLoader: missing PackedScene for %s" % path)
		_abort()
		return

	err = get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_warning("SceneLoader: change_scene_to_packed failed (%s)" % error_string(err))
		_abort()
		return

	await get_tree().process_frame
	var current := get_tree().current_scene
	if current != null and not current.is_node_ready():
		await current.ready

	var next := _pending_path
	_pending_path = ""
	var current_path := current.scene_file_path if current != null else ""
	if not next.is_empty() and next != current_path:
		await _transition(next)
		return

	_hide_overlay()
	_busy = false


func _abort() -> void:
	_pending_path = ""
	_hide_overlay()
	_busy = false
