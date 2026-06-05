class_name FeedbackAnimHelper

## Shared tween lifecycle for scene-local feedback animations.

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
