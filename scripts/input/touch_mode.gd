extends Node
## Autoload: touchscreen detection for input/UI branching.


func is_touch() -> bool:
	return DisplayServer.is_touchscreen_available()
