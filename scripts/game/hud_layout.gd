extends CanvasLayer
## Keeps Node2D HUD widgets aligned to edge-anchored Control slots.
## Widgets are siblings of Root (not children of slots) so their Control
## tooltips/labels keep Node2D-local layout instead of inheriting slot size.

@onready var _root: Control = $Root

var _pairs: Array[Array] = []

func _ready() -> void:
	_pairs = [
		[$Root/PointCounterSlot, $PointCounter],
		[$Root/QuestManagerSlot, $QuestManager],
		[$Root/BoosterManagerSlot, $BoosterManager],
		[$Root/CardManagerSlot, $CardManager],
		[$Root/ScoreTooltipSlot, $ScoreTooltip],
		[$Root/SettingsButtonSlot, $SettingsButton],
		[$Root/UndoButtonSlot, $UndoButton],
		[$Root/CardRecyclingSlot, $CardRecycling],
		[$Root/EndGameButtonSlot, $EndGameButton],
	]
	get_viewport().size_changed.connect(_relayout)
	_root.resized.connect(_relayout)
	call_deferred("_relayout")

func _relayout() -> void:
	for pair in _pairs:
		var slot: Control = pair[0]
		var widget: Node2D = pair[1]
		widget.global_position = slot.global_position
