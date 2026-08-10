extends Node
## Persistent player flags (tutorial completion, etc.).

const SAVE_PATH := "user://player_progress.cfg"
const SECTION := "progress"

var tutorial_completed: bool = false


func _ready() -> void:
	load_from_disk()


func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		tutorial_completed = false
		return
	tutorial_completed = bool(cfg.get_value(SECTION, "tutorial_completed", false))


func save_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "tutorial_completed", tutorial_completed)
	cfg.save(SAVE_PATH)


func mark_tutorial_completed() -> void:
	tutorial_completed = true
	save_to_disk()
