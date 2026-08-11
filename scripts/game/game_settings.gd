extends Node
## Persistent graphics + audio settings. Apply at boot and from SettingsPanel.

signal settings_changed

enum Preset { LOW, MEDIUM, HIGH, CUSTOM }
enum AnimalMotion { FROZEN, IDLE_SPECIAL, FULL_ROAM }
enum MsaaMode { OFF, X2, X4 }

const SAVE_PATH := "user://graphics_settings.cfg"
const SECTION := "graphics"
const AUDIO_SECTION := "audio"

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
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
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
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "preset", int(preset))
	cfg.set_value(SECTION, "wind_enabled", wind_enabled)
	cfg.set_value(SECTION, "clouds_enabled", clouds_enabled)
	cfg.set_value(SECTION, "animal_motion", int(animal_motion))
	cfg.set_value(SECTION, "msaa_mode", int(msaa_mode))
	cfg.set_value(AUDIO_SECTION, "music_volume", music_volume)
	cfg.set_value(AUDIO_SECTION, "sfx_volume", sfx_volume)
	cfg.save(SAVE_PATH)


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
