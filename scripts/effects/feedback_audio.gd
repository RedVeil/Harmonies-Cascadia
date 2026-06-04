extends Node
class_name FeedbackAudio

## Assign AudioStream arrays on FeedbackAudio (child of GameFeedback autoload).
## Each effect picks a random clip from its pool. Empty pools stay silent.

@export_group("Draw Card")
@export var draw_card_sounds: Array[AudioStream] = []
@export var draw_card_pitch_min: float = 0.93
@export var draw_card_pitch_max: float = 1.07
@export var draw_card_volume_jitter_db: float = 2.5

@export_group("Hover Card")
@export var hover_card_sounds: Array[AudioStream] = []
@export var hover_card_pitch_min: float = 0.95
@export var hover_card_pitch_max: float = 1.05
@export var hover_card_volume_jitter_db: float = 1.5

@export_group("Click Card")
@export var click_card_sounds: Array[AudioStream] = []

@export_group("Hover Tile")
@export var hover_tile_sounds: Array[AudioStream] = []
@export var hover_tile_pitch_min: float = 0.95
@export var hover_tile_pitch_max: float = 1.05
@export var hover_tile_volume_jitter_db: float = 1.5
@export var hover_tile_extra_volume_db: float = -4.0

@export_group("Place Tile")
@export var place_tile_sounds: Array[AudioStream] = []
@export var contributor_sounds: Array[AudioStream] = []

@export_group("Points Scored")
@export var points_scored_sounds: Array[AudioStream] = []

@export_group("Undo")
@export var undo_sounds: Array[AudioStream] = []

@export_group("Recycle")
@export var recycle_sounds: Array[AudioStream] = []

@export_group("Click Button")
@export var click_button_sounds: Array[AudioStream] = []

@export_group("Mix")
@export var master_volume_offset_db: float = -20.0

@onready var _player: AudioStreamPlayer = $AudioStreamPlayer

func play_stream(
	stream: AudioStream,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null:
		return
	_player.stream = stream
	_player.pitch_scale = pitch_scale
	_player.volume_db = volume_db + master_volume_offset_db
	_player.play()

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

func play_draw_card() -> void:
	_play_from_pool(
		draw_card_sounds,
		draw_card_pitch_min,
		draw_card_pitch_max,
		draw_card_volume_jitter_db
	)

func play_hover_card() -> void:
	_play_from_pool(
		hover_card_sounds,
		hover_card_pitch_min,
		hover_card_pitch_max,
		hover_card_volume_jitter_db
	)

func play_click_card() -> void:
	_play_from_pool(click_card_sounds)

func play_hover_tile() -> void:
	_play_from_pool(
		hover_tile_sounds,
		hover_tile_pitch_min,
		hover_tile_pitch_max,
		hover_tile_volume_jitter_db,
		hover_tile_extra_volume_db
	)

func play_place_tile() -> void:
	_play_from_pool(place_tile_sounds)

func play_tile_contributor() -> void:
	if contributor_sounds.is_empty():
		_play_from_pool(place_tile_sounds, 0.9, 0.95, 0.0, -3.0)
	else:
		_play_from_pool(contributor_sounds)

func play_points_scored() -> void:
	_play_from_pool(points_scored_sounds)

func play_undo() -> void:
	_play_from_pool(undo_sounds)

func play_recycle() -> void:
	_play_from_pool(recycle_sounds)

func play_click_button() -> void:
	_play_from_pool(click_button_sounds)
