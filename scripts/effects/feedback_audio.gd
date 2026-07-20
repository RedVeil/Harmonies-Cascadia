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

@export_group("Undo")
@export var undo_sounds: Array[AudioStream] = []
@export var undo_extra_volume_db: float = 0.0

@export_group("Recycle")
@export var recycle_sounds: Array[AudioStream] = []
@export var recycle_extra_volume_db: float = 0.0

@export_group("Click Button")
@export var click_button_sounds: Array[AudioStream] = []
@export var click_button_extra_volume_db: float = 0.0

@export_group("Mix")
@export var master_volume_offset_db: float = -20.0
## Shared voices for placement, hover, clicks, etc.
@export var polyphony: int = 8

var _players: Array[AudioStreamPlayer] = []
var _next_player_index: int = 0

## ----- Initialisation ----- ##

func _ready() -> void:
	_build_player_pool()

## ----- Player Pool ----- ##

func _build_player_pool() -> void:
	_players.clear()
	var count := maxi(polyphony, 1)
	for i in count:
		var player := AudioStreamPlayer.new()
		player.name = "SfxPlayer_%d" % i
		add_child(player)
		_players.append(player)

func _acquire_sfx_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	_next_player_index = (_next_player_index + 1) % _players.size()
	return _players[_next_player_index]

## ----- Internal Playback ----- ##

func _play_on_player(
	player: AudioStreamPlayer,
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null or player == null:
		return
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch_scale
	player.volume_db = volume_db + master_volume_offset_db
	player.play()

func play_stream(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null or _players.is_empty():
		return
	_play_on_player(_acquire_sfx_player(), stream, volume_db, pitch_scale)

func play_sounds(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	play_stream(sounds.pick_random())

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

func play_undo() -> void:
	_play_from_pool(
		undo_sounds,
		1.0,
		1.0,
		0.0,
		undo_extra_volume_db
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
