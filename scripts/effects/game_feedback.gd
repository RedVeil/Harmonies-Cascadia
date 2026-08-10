## Autoload for UI / interaction sounds. Scene-local scripts own their animations.
extends Node

@onready var audio: FeedbackAudio = $FeedbackAudio

## ----- Internal Access ----- ##

func _audio() -> FeedbackAudio:
	if audio == null:
		audio = $FeedbackAudio as FeedbackAudio
	return audio

## ----- Audio Playback ----- ##

func run_tile_hover_slide() -> void:
	_audio().play_hover_tile()

func play_recycle() -> void:
	_audio().play_recycle()

func play_click_button() -> void:
	_audio().play_click_button()

func play_hover_button() -> void:
	_audio().play_hover_button()

func play_open_popup() -> void:
	_audio().play_open_popup()

func play_close_popup() -> void:
	_audio().play_close_popup()

func play_hover_card() -> void:
	_audio().play_hover_card()

func play_click_card() -> void:
	_audio().play_click_card()

func play_sounds(sounds: Array[AudioStream], volume_db: float = 0.0) -> void:
	_audio().play_sounds(sounds, volume_db)

func start_background_music() -> void:
	_audio().start_background_music()

func stop_background_music() -> void:
	_audio().stop_background_music()
