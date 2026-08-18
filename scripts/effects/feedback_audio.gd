extends Node
class_name FeedbackAudio

## Assign AudioStream arrays on FeedbackAudio (child of GameFeedback autoload).
## UI interaction sounds live here. Animation sounds are set on each scene's export groups.

@export_group("Hover Card")
@export var hover_card_sounds: Array[AudioStream] = []
@export var hover_card_pitch_min: float = 0.95
@export var hover_card_pitch_max: float = 1.05
@export var hover_card_volume_jitter_db: float = 1.5
@export var hover_card_extra_volume_db: float = 0.0

@export_group("Click Card")
@export var click_card_sounds: Array[AudioStream] = []
@export var click_card_extra_volume_db: float = 0.0

@export_group("Hover Tile")
@export var hover_tile_sounds: Array[AudioStream] = []
@export var hover_tile_pitch_min: float = 0.95
@export var hover_tile_pitch_max: float = 1.05
@export var hover_tile_volume_jitter_db: float = 1.5
@export var hover_tile_extra_volume_db: float = -4.0

@export_group("Recycle")
@export var recycle_sounds: Array[AudioStream] = []
@export var recycle_extra_volume_db: float = 0.0

@export_group("Click Button")
@export var click_button_sounds: Array[AudioStream] = []
@export var click_button_extra_volume_db: float = 0.0

@export_group("Hover Button")
@export var hover_button_sounds: Array[AudioStream] = []
@export var hover_button_pitch_min: float = 0.95
@export var hover_button_pitch_max: float = 1.05
@export var hover_button_volume_jitter_db: float = 1.5
@export var hover_button_extra_volume_db: float = 0.0

@export_group("Open Popup")
@export var open_popup_sounds: Array[AudioStream] = []
@export var open_popup_extra_volume_db: float = 0.0

@export_group("Close Popup")
@export var close_popup_sounds: Array[AudioStream] = []
@export var close_popup_extra_volume_db: float = 0.0

@export_group("Background Music")
@export var background_music: AudioStream
@export var music_volume_db: float = -20.0

@export_group("Mix")
@export var master_volume_offset_db: float = -20.0
## Shared voices for placement, hover, clicks, etc.
@export var polyphony: int = 8

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0
var _music_player: AudioStreamPlayer
var _user_music_linear: float = 0.5
var _user_sfx_linear: float = 0.5

## ----- Initialisation ----- ##

func _ready() -> void:
	_build_player_pool()
	_build_music_player()
	apply_user_volumes()
	start_background_music()

## ----- Player Pool ----- ##

func _build_player_pool() -> void:
	_players.clear()
	var count := maxi(polyphony, 1)
	for i in count:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer_%d" % i
		add_child(player)
		_players.append(player)

func _build_music_player() -> void:
	if _music_player != null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

func _acquire_sfx_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	_next_player_index = (_next_player_index + 1) % _players.size()
	return _players[_next_player_index]

## ----- User volume (0..1 linear) ----- ##

func apply_user_volumes() -> void:
	_user_music_linear = clampf(GameSettings.music_volume, 0.0, 1.0)
	_user_sfx_linear = clampf(GameSettings.sfx_volume, 0.0, 1.0)
	_refresh_music_volume()

func _linear_gain_db(linear: float) -> float:
	if linear <= 0.0001:
		return -80.0
	return linear_to_db(linear)

func _refresh_music_volume() -> void:
	if _music_player == null:
		return
	_music_player.volume_db = music_volume_db + _linear_gain_db(_user_music_linear)

## ----- Internal Playback ----- ##

func _play_on_player(
	player: AudioStreamPlayer,
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null or player == null:
		return
	if _user_sfx_linear <= 0.0001:
		return
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db + master_volume_offset_db + _linear_gain_db(_user_sfx_linear)
	player.play()

func play_stream(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null or _players.is_empty():
		return
	_play_on_player(_acquire_sfx_player(), stream, volume_db, pitch_scale)

func play_sounds(sounds: Array[AudioStream], volume_db: float = 0.0) -> void:
	if sounds.is_empty():
		return
	play_stream(sounds.pick_random(), volume_db)

func _random_pitch(min_scale: float, max_scale: float) -> float:
	return randf_range(min_scale, max_scale)

func _random_volume_jitter(jitter_db: float) -> float:
	if jitter_db <= 0.0:
		return 0.0
	return randf_range(-jitter_db, jitter_db)

func _play_from_pool(
	pool: Array[AudioStream],
	pitch_min: float = 1.0,
	pitch_max: float = 1.0,
	volume_jitter_db: float = 0.0,
	extra_volume_db: float = 0.0
) -> void:
	if pool.is_empty():
		return
	play_stream(
		pool.pick_random(),
		_random_volume_jitter(volume_jitter_db) + extra_volume_db,
		_random_pitch(pitch_min, pitch_max)
	)

## ----- Sound Effects ----- ##

func play_hover_card() -> void:
	_play_from_pool(
		hover_card_sounds,
		hover_card_pitch_min,
		hover_card_pitch_max,
		hover_card_volume_jitter_db,
		hover_card_extra_volume_db
	)

func play_click_card() -> void:
	_play_from_pool(
		click_card_sounds,
		1.0,
		1.0,
		0.0,
		click_card_extra_volume_db
	)

func play_hover_tile() -> void:
	_play_from_pool(
		hover_tile_sounds,
		hover_tile_pitch_min,
		hover_tile_pitch_max,
		hover_tile_volume_jitter_db,
		hover_tile_extra_volume_db
	)

func play_recycle() -> void:
	_play_from_pool(
		recycle_sounds,
		1.0,
		1.0,
		0.0,
		recycle_extra_volume_db
	)

func play_click_button() -> void:
	_play_from_pool(
		click_button_sounds,
		1.0,
		1.0,
		0.0,
		click_button_extra_volume_db
	)

func play_hover_button() -> void:
	_play_from_pool(
		hover_button_sounds,
		hover_button_pitch_min,
		hover_button_pitch_max,
		hover_button_volume_jitter_db,
		hover_button_extra_volume_db
	)

func play_open_popup() -> void:
	_play_from_pool(
		open_popup_sounds,
		1.0,
		1.0,
		0.0,
		open_popup_extra_volume_db
	)

func play_close_popup() -> void:
	_play_from_pool(
		close_popup_sounds,
		1.0,
		1.0,
		0.0,
		close_popup_extra_volume_db
	)

## ----- Background Music ----- ##

func start_background_music() -> void:
	if background_music == null:
		return
	if _music_player == null:
		_build_music_player()
	if _music_player.playing and _music_player.stream == background_music:
		return
	_ensure_stream_loops(background_music)
	_music_player.stream = background_music
	_music_player.pitch_scale = 1.0
	_refresh_music_volume()
	_music_player.play()

func stop_background_music() -> void:
	if _music_player == null:
		return
	_music_player.stop()

func _ensure_stream_loops(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
