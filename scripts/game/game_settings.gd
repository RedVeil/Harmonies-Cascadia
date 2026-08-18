extends Node
## Persistent configuration: player identity, tutorial flags, graphics/audio. Apply at boot and from SettingsPanel.

signal settings_changed

enum Preset { LOW, MEDIUM, HIGH, CUSTOM }
enum AnimalMotion { FROZEN, IDLE_SPECIAL, FULL_ROAM }
enum MsaaMode { OFF, X2, X4 }

const SAVE_PATH := "user://configuration.json"
const LEGACY_SAVE_PATH := "user://graphics_settings.cfg"
const SECTION := "graphics"
const AUDIO_SECTION := "audio"
const PLAYER_NAME_MAX_LENGTH := 12

var player_id: String = ""
var player_name: String = ""
var tutorial_played: bool = false
var tutorial_completed: bool = false

var preset: Preset = Preset.HIGH
var wind_enabled: bool = true
var clouds_enabled: bool = true
var animal_motion: AnimalMotion = AnimalMotion.FULL_ROAM
var msaa_mode: MsaaMode = MsaaMode.X4

var music_volume: float = 0.5
var sfx_volume: float = 0.5

var _applying_ui_sync: bool = false


func _ready() -> void:
	load_from_disk()
	# Defer so the root viewport / GameFeedback exist.
	call_deferred("apply")


func load_from_disk() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		_load_from_json()
	elif FileAccess.file_exists(LEGACY_SAVE_PATH):
		_load_from_legacy_cfg()
	else:
		apply_preset(Preset.HIGH, false)

	var identity_dirty := false
	if player_id.is_empty():
		player_id = _generate_player_id()
		identity_dirty = true
	var sanitized_name := _sanitize_player_name(player_name)
	if sanitized_name != player_name:
		player_name = sanitized_name
		identity_dirty = true
	var tutorial_dirty := _migrate_player_progress()
	if identity_dirty or tutorial_dirty or not FileAccess.file_exists(SAVE_PATH):
		save_to_disk()


func _load_from_json() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		apply_preset(Preset.HIGH, false)
		return

	var data: Dictionary = parsed
	player_id = str(data.get("player_id", ""))
	player_name = str(data.get("player_name", ""))
	tutorial_played = bool(data.get("tutorial_played", false))
	tutorial_completed = bool(data.get("tutorial_completed", false))

	var graphics: Dictionary = data.get("graphics", {})
	if typeof(graphics) != TYPE_DICTIONARY:
		graphics = {}
	preset = int(graphics.get("preset", Preset.HIGH)) as Preset
	wind_enabled = bool(graphics.get("wind_enabled", true))
	clouds_enabled = bool(graphics.get("clouds_enabled", true))
	animal_motion = int(graphics.get("animal_motion", AnimalMotion.FULL_ROAM)) as AnimalMotion
	msaa_mode = int(graphics.get("msaa_mode", MsaaMode.X4)) as MsaaMode

	var audio: Dictionary = data.get("audio", {})
	if typeof(audio) != TYPE_DICTIONARY:
		audio = {}
	music_volume = clampf(float(audio.get("music_volume", 0.5)), 0.0, 1.0)
	sfx_volume = clampf(float(audio.get("sfx_volume", 0.5)), 0.0, 1.0)


func _load_from_legacy_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_SAVE_PATH) != OK:
		apply_preset(Preset.HIGH, false)
		return
	preset = int(cfg.get_value(SECTION, "preset", Preset.HIGH)) as Preset
	wind_enabled = bool(cfg.get_value(SECTION, "wind_enabled", true))
	clouds_enabled = bool(cfg.get_value(SECTION, "clouds_enabled", true))
	animal_motion = int(cfg.get_value(SECTION, "animal_motion", AnimalMotion.FULL_ROAM)) as AnimalMotion
	msaa_mode = int(cfg.get_value(SECTION, "msaa_mode", MsaaMode.X4)) as MsaaMode
	music_volume = clampf(float(cfg.get_value(AUDIO_SECTION, "music_volume", 0.5)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(AUDIO_SECTION, "sfx_volume", 0.5)), 0.0, 1.0)


func save_to_disk() -> void:
	var data := {
		"player_id": player_id,
		"player_name": player_name,
		"tutorial_played": tutorial_played,
		"tutorial_completed": tutorial_completed,
		"graphics": {
			"preset": int(preset),
			"wind_enabled": wind_enabled,
			"clouds_enabled": clouds_enabled,
			"animal_motion": int(animal_motion),
			"msaa_mode": int(msaa_mode),
		},
		"audio": {
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
		},
	}
	var json := JSON.stringify(data)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("GameSettings: failed to open configuration file: %s" % SAVE_PATH)
		return
	f.store_string(json)
	f.flush()
	f.close()


func set_player_name(new_name: String) -> void:
	var sanitized := _sanitize_player_name(new_name)
	if player_name == sanitized:
		return
	player_name = sanitized
	save_to_disk()


func _sanitize_player_name(value: String) -> String:
	var n := value.strip_edges()
	if n.length() > PLAYER_NAME_MAX_LENGTH:
		return n.substr(0, PLAYER_NAME_MAX_LENGTH)
	return n


func mark_tutorial_played() -> void:
	if tutorial_played:
		return
	tutorial_played = true
	save_to_disk()


func mark_tutorial_completed() -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	tutorial_played = true
	save_to_disk()


func _migrate_player_progress() -> bool:
	const LEGACY_PROGRESS_PATH := "user://player_progress.cfg"
	if not FileAccess.file_exists(LEGACY_PROGRESS_PATH):
		return false
	var cfg := ConfigFile.new()
	var dirty := false
	if cfg.load(LEGACY_PROGRESS_PATH) == OK:
		var completed := bool(cfg.get_value("progress", "tutorial_completed", false))
		if completed and not tutorial_completed:
			tutorial_completed = true
			dirty = true
		if completed and not tutorial_played:
			tutorial_played = true
			dirty = true
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove("player_progress.cfg")
	return dirty


func _platform_tag() -> String:
	if OS.has_feature("web"):
		return "web"
	return "desktop"


func _random_token() -> String:
	return "%08x%08x%08x%08x" % [randi(), randi(), randi(), randi()]


func _generate_player_id() -> String:
	var platform := _platform_tag()
	var device := OS.get_unique_id()
	if device.is_empty():
		device = _random_token()
	var token := _random_token()
	var ctx := "%s|%s|%s" % [platform, device, token]
	return ctx.sha256_text()


func apply_preset(new_preset: Preset, do_save: bool = true) -> void:
	if new_preset == Preset.CUSTOM:
		preset = Preset.CUSTOM
		if do_save:
			save_to_disk()
		return

	preset = new_preset
	match new_preset:
		Preset.LOW:
			wind_enabled = false
			clouds_enabled = false
			animal_motion = AnimalMotion.FROZEN
			msaa_mode = MsaaMode.OFF
		Preset.MEDIUM:
			wind_enabled = false
			clouds_enabled = true
			animal_motion = AnimalMotion.IDLE_SPECIAL
			msaa_mode = MsaaMode.X2
		Preset.HIGH:
			wind_enabled = true
			clouds_enabled = true
			animal_motion = AnimalMotion.FULL_ROAM
			msaa_mode = MsaaMode.X4
	apply()
	if do_save:
		save_to_disk()


func set_wind_enabled(value: bool) -> void:
	if _applying_ui_sync:
		wind_enabled = value
		return
	if wind_enabled == value:
		return
	wind_enabled = value
	_mark_custom_and_apply()


func set_clouds_enabled(value: bool) -> void:
	if _applying_ui_sync:
		clouds_enabled = value
		return
	if clouds_enabled == value:
		return
	clouds_enabled = value
	_mark_custom_and_apply()


func set_animal_motion(value: AnimalMotion) -> void:
	if _applying_ui_sync:
		animal_motion = value
		return
	if animal_motion == value:
		return
	animal_motion = value
	_mark_custom_and_apply()


func set_msaa_mode(value: MsaaMode) -> void:
	if _applying_ui_sync:
		msaa_mode = value
		return
	if msaa_mode == value:
		return
	msaa_mode = value
	_mark_custom_and_apply()


func set_music_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if _applying_ui_sync:
		music_volume = clamped
		return
	if is_equal_approx(music_volume, clamped):
		return
	music_volume = clamped
	apply_audio()
	save_to_disk()


func set_sfx_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if _applying_ui_sync:
		sfx_volume = clamped
		return
	if is_equal_approx(sfx_volume, clamped):
		return
	sfx_volume = clamped
	apply_audio()
	save_to_disk()


## Used by SettingsOverlay when refreshing controls from stored state.
func begin_ui_sync() -> void:
	_applying_ui_sync = true


func end_ui_sync() -> void:
	_applying_ui_sync = false


func is_ui_syncing() -> bool:
	return _applying_ui_sync


func _mark_custom_and_apply() -> void:
	preset = Preset.CUSTOM
	apply()
	save_to_disk()


func apply() -> void:
	WindControl.set_wind_enabled(wind_enabled)
	WindControl.set_cloud_enabled(clouds_enabled)
	_apply_msaa()
	apply_audio()
	settings_changed.emit()


func apply_audio() -> void:
	if GameFeedback != null and GameFeedback.has_method("apply_user_volumes"):
		GameFeedback.apply_user_volumes()


func _apply_msaa() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var vp := tree.root.get_viewport()
	if vp == null:
		return
	match msaa_mode:
		MsaaMode.OFF:
			vp.msaa_3d = Viewport.MSAA_DISABLED
		MsaaMode.X2:
			vp.msaa_3d = Viewport.MSAA_2X
		MsaaMode.X4:
			vp.msaa_3d = Viewport.MSAA_4X
