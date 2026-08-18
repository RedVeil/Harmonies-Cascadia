extends Area2D
class_name PlayCounter

var COLOR_BROWN := Color.html("#918478")

@onready var _label: Label = $Label


func _ready() -> void:
	input_pickable = false
	if _label:
		_label.add_theme_color_override("font_color", COLOR_BROWN)


func set_remaining(remaining: int) -> void:
	if remaining < 0:
		hide()
		return
	var label := _label
	if label == null:
		label = get_node_or_null("Label") as Label
	if label:
		label.text = str(remaining)
	show()
