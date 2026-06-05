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

func play_undo() -> void:
	_audio().play_undo()

func play_recycle() -> void:
	_audio().play_recycle()

func play_click_button() -> void:
	_audio().play_click_button()

func play_hover_card() -> void:
	_audio().play_hover_card()

func play_click_card() -> void:
	_audio().play_click_card()

func play_sounds(sounds: Array[AudioStream]) -> void:
	_audio().play_sounds(sounds)
