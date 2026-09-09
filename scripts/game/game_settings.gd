extends Node
## Persistent configuration: player identity, tutorial flags, graphics/audio/theme. Apply at boot and from SettingsPanel.

signal settings_changed

enum Preset { LOW, MEDIUM, HIGH, CUSTOM }
enum AnimalMotion { FROZEN, IDLE_SPECIAL, FULL_ROAM }
enum MsaaMode { OFF, X2, X4 }
enum WindowMode { FULLSCREEN, WINDOWED, FULLSCREEN_WINDOWED }

const SAVE_PATH := "user://configuration.json"
const LEGACY_SAVE_PATH := "user://graphics_settings.cfg"
const SECTION := "graphics"
const AUDIO_SECTION := "audio"
const PLAYER_NAME_MAX_LENGTH := 12
const WINDOWED_SIZE := Vector2i(1280, 720)
const UI_SCALE_MIN := 0.75
const UI_SCALE_MAX := 1.5
const FPS_CAP_DEFAULT := 60
const FPS_CAP_OPTIONS: Array[int] = [30, 60, 120, 0]

var player_id: String = ""
var player_name: String = ""
var tutorial_played: bool = false
var tutorial_completed: bool = false
var first_puzzle_intro_shown: bool = false

var preset: Preset = Preset.LOW
var wind_enabled: bool = false
var clouds_enabled: bool = true
var animal_motion: AnimalMotion = AnimalMotion.FROZEN
var msaa_mode: MsaaMode = MsaaMode.OFF
var window_mode: WindowMode = WindowMode.FULLSCREEN
var fps_cap: int = FPS_CAP_DEFAULT

var music_volume: float = 0.5
var sfx_volume: float = 0.5
var master_volume: float = 1.0
var ui_scale: float = 1.0
var theme_id: String = "cascadia"
## "eng" or "ger". JSON catalog copy is resolved from this.
var content_locale: String = "eng"
## puzzle_id -> { "best_score": int }
var puzzle_progress: Dictionary = {}

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
		apply_preset(_default_preset(), false)
		content_locale = Loc.ENG

	var identity_dirty := false
	if player_id.is_empty():
		player_id = _generate_player_id()
		identity_dirty = true
	var sanitized_name := _sanitize_player_name(player_name)
	if sanitized_name != player_name:
		player_name = sanitized_name
		identity_dirty = true
	var tutorial_dirty := _migrate_player_progress()
	var locale_dirty := false
	if content_locale.is_empty():
		content_locale = Loc.ENG
		locale_dirty = true
	else:
		var normalized: String = Loc.normalize_locale(content_locale)
		if normalized != content_locale:
			content_locale = normalized
			locale_dirty = true
	if identity_dirty or tutorial_dirty or locale_dirty or not FileAccess.file_exists(SAVE_PATH):
		save_to_disk()


func _load_from_json() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		apply_preset(_default_preset(), false)
		return

	var data: Dictionary = parsed
	player_id = str(data.get("player_id", ""))
	player_name = str(data.get("player_name", ""))
	tutorial_played = bool(data.get("tutorial_played", false))
	tutorial_completed = bool(data.get("tutorial_completed", false))
	first_puzzle_intro_shown = bool(data.get("first_puzzle_intro_shown", false))

	var graphics: Dictionary = data.get("graphics", {})
	if typeof(graphics) != TYPE_DICTIONARY:
		graphics = {}
	preset = int(graphics.get("preset", Preset.LOW)) as Preset
	wind_enabled = bool(graphics.get("wind_enabled", false))
	clouds_enabled = bool(graphics.get("clouds_enabled", true))
	animal_motion = int(graphics.get("animal_motion", AnimalMotion.FROZEN)) as AnimalMotion
	msaa_mode = int(graphics.get("msaa_mode", MsaaMode.OFF)) as MsaaMode
	window_mode = _normalize_window_mode(int(graphics.get("window_mode", WindowMode.FULLSCREEN)))
	fps_cap = _normalize_fps_cap(int(graphics.get("fps_cap", FPS_CAP_DEFAULT)))

	var audio: Dictionary = data.get("audio", {})
	if typeof(audio) != TYPE_DICTIONARY:
		audio = {}
	music_volume = clampf(float(audio.get("music_volume", 0.5)), 0.0, 1.0)
	sfx_volume = clampf(float(audio.get("sfx_volume", 0.5)), 0.0, 1.0)
	master_volume = clampf(float(audio.get("master_volume", 1.0)), 0.0, 1.0)
	ui_scale = clampf(float(data.get("ui_scale", 1.0)), UI_SCALE_MIN, UI_SCALE_MAX)
	theme_id = str(data.get("theme_id", "cascadia"))
	if theme_id.is_empty():
		theme_id = "cascadia"
	if data.has("content_locale"):
		content_locale = Loc.normalize_locale(str(data.get("content_locale", Loc.ENG)))
	else:
		content_locale = Loc.ENG

	var progress = data.get("puzzle_progress", {})
	if typeof(progress) == TYPE_DICTIONARY:
		puzzle_progress = progress.duplicate(true)
	else:
		puzzle_progress = {}


func _load_from_legacy_cfg() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(LEGACY_SAVE_PATH) != OK:
		apply_preset(_default_preset(), false)
		return
	preset = int(cfg.get_value(SECTION, "preset", Preset.LOW)) as Preset
	wind_enabled = bool(cfg.get_value(SECTION, "wind_enabled", false))
	clouds_enabled = bool(cfg.get_value(SECTION, "clouds_enabled", true))
	animal_motion = int(cfg.get_value(SECTION, "animal_motion", AnimalMotion.FROZEN)) as AnimalMotion
	msaa_mode = int(cfg.get_value(SECTION, "msaa_mode", MsaaMode.OFF)) as MsaaMode
	music_volume = clampf(float(cfg.get_value(AUDIO_SECTION, "music_volume", 0.5)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value(AUDIO_SECTION, "sfx_volume", 0.5)), 0.0, 1.0)
	content_locale = Loc.ENG


func save_to_disk() -> void:
	var data := {
		"player_id": player_id,
		"player_name": player_name,
		"tutorial_played": tutorial_played,
		"tutorial_completed": tutorial_completed,
		"first_puzzle_intro_shown": first_puzzle_intro_shown,
		"graphics": {
			"preset": int(preset),
			"wind_enabled": wind_enabled,
			"clouds_enabled": clouds_enabled,
			"animal_motion": int(animal_motion),
			"msaa_mode": int(msaa_mode),
			"window_mode": int(window_mode),
			"fps_cap": fps_cap,
		},
		"audio": {
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"master_volume": master_volume,
		},
		"ui_scale": ui_scale,
		"theme_id": theme_id,
		"content_locale": content_locale,
		"puzzle_progress": puzzle_progress,
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


func set_content_locale(locale: String) -> void:
	var normalized: String = Loc.normalize_locale(locale)
	if content_locale == normalized:
		return
	content_locale = normalized
	save_to_disk()
	settings_changed.emit()


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


func mark_first_puzzle_intro_shown() -> void:
	if first_puzzle_intro_shown:
		return
	first_puzzle_intro_shown = true
	save_to_disk()


func get_puzzle_best_score(id: String) -> int:
	if id.is_empty():
		return 0
	var entry = puzzle_progress.get(id, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	return int(entry.get("best_score", 0))


func record_puzzle_score(id: String, score: int) -> void:
	if id.is_empty():
		return
	var previous := get_puzzle_best_score(id)
	if score <= previous:
		return
	puzzle_progress[id] = { "best_score": score }
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


func is_native_desktop() -> bool:
	return OS.has_feature("windows") or OS.has_feature("macos") or OS.has_feature("linux")


func _is_mobile_platform() -> bool:
	return OS.has_feature("android") \
		or OS.has_feature("ios") \
		or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")


func _normalize_window_mode(value: int) -> WindowMode:
	if value == int(WindowMode.WINDOWED) or value == int(WindowMode.FULLSCREEN_WINDOWED):
		return value as WindowMode
	return WindowMode.FULLSCREEN


func _normalize_fps_cap(value: int) -> int:
	if value == 0 or value == 30 or value == 60 or value == 120:
		return value
	return FPS_CAP_DEFAULT


func _default_preset() -> Preset:
	return Preset.LOW if _is_mobile_platform() or OS.has_feature("web") else Preset.HIGH


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
		if preset == Preset.CUSTOM:
			if do_save:
				save_to_disk()
			return
		_apply_named_preset_values(Preset.LOW)
		preset = Preset.CUSTOM
		apply()
		if do_save:
			save_to_disk()
		return

	preset = new_preset
	_apply_named_preset_values(new_preset)
	apply()
	if do_save:
		save_to_disk()


func _apply_named_preset_values(named_preset: Preset) -> void:
	match named_preset:
		Preset.LOW:
			wind_enabled = false
			clouds_enabled = true
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


func set_master_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if _applying_ui_sync:
		master_volume = clamped
		return
	if is_equal_approx(master_volume, clamped):
		return
	master_volume = clamped
	apply_audio()
	save_to_disk()


func set_ui_scale(value: float) -> void:
	var clamped := clampf(value, UI_SCALE_MIN, UI_SCALE_MAX)
	if _applying_ui_sync:
		ui_scale = clamped
		return
	if is_equal_approx(ui_scale, clamped):
		return
	ui_scale = clamped
	_apply_ui_scale()
	save_to_disk()


func set_window_mode(value: WindowMode) -> void:
	var normalized := _normalize_window_mode(int(value))
	if _applying_ui_sync:
		window_mode = normalized
		return
	if window_mode == normalized:
		return
	window_mode = normalized
	_apply_window_mode()
	save_to_disk()


func set_fps_cap(value: int) -> void:
	var normalized := _normalize_fps_cap(value)
	if _applying_ui_sync:
		fps_cap = normalized
		return
	if fps_cap == normalized:
		return
	fps_cap = normalized
	_apply_fps_cap()
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
	_apply_window_mode()
	_apply_fps_cap()
	_apply_ui_scale()
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


func _apply_window_mode() -> void:
	if not is_native_desktop() or OS.has_feature("editor"):
		return
	var win := get_window()
	if win == null:
		return
	match window_mode:
		WindowMode.WINDOWED:
			win.borderless = false
			win.mode = Window.MODE_WINDOWED
			win.size = WINDOWED_SIZE
		WindowMode.FULLSCREEN_WINDOWED:
			win.mode = Window.MODE_FULLSCREEN
		_:
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN


func _apply_fps_cap() -> void:
	if not is_native_desktop():
		return
	Engine.max_fps = fps_cap


func _apply_ui_scale() -> void:
	var win := get_window()
	if win == null:
		return
	win.content_scale_factor = clampf(ui_scale, UI_SCALE_MIN, UI_SCALE_MAX)
