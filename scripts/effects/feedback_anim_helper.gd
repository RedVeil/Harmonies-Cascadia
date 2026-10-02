class_name FeedbackAnimHelper

## Shared tween lifecycle for scene-local feedback animations.

## ----- Tween Lifecycle ----- ##

static func set_tween(tweens: Dictionary, key: StringName, tween: Tween) -> void:
	if tweens.has(key):
		var existing: Tween = tweens[key]
		if existing.is_valid():
			existing.kill()
	tweens[key] = tween

static func kill_all(tweens: Dictionary) -> void:
	for key in tweens.keys():
		var tween: Tween = tweens[key]
		if tween.is_valid():
			tween.kill()
	tweens.clear()

static func create_tween(
	host: Node,
	tweens: Dictionary,
	key: StringName,
	parallel: bool = false
) -> Tween:
	var tween := host.create_tween()
	if parallel:
		tween.set_parallel(true)
	set_tween(tweens, key, tween)
	return tween

static func play_sounds(sounds: Array[AudioStream], volume_db: float = 0.0) -> void:
	if sounds.is_empty():
		return
	GameFeedback.play_sounds(sounds, volume_db)


## Scale punch: snap from `start_scale` through `peak_scale`, then settle on `rest_scale`.
## `t` runs 0 to 1 across `up_duration` + `settle_duration`.
static func pop_scale(
	t: float,
	start_scale: float,
	peak_scale: float,
	rest_scale: float,
	up_duration: float,
	settle_duration: float
) -> float:
	var total := up_duration + settle_duration
	if total <= 0.0:
		return rest_scale
	var elapsed := clampf(t, 0.0, 1.0) * total
	if elapsed <= up_duration:
		return Tween.interpolate_value(
			start_scale,
			peak_scale - start_scale,
			elapsed,
			up_duration,
			Tween.TRANS_BACK,
			Tween.EASE_OUT
		)
	return Tween.interpolate_value(
		peak_scale,
		rest_scale - peak_scale,
		elapsed - up_duration,
		settle_duration,
		Tween.TRANS_QUAD,
		Tween.EASE_OUT
	)
