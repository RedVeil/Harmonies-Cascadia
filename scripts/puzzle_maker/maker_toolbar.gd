extends CanvasLayer
## Top-right toolbar buttons for the puzzle maker.

@export var maker: PuzzleMakerController

@onready var _animals_btn: Button = $Panel/VBox/AnimalsButton
@onready var _quests_btn: Button = $Panel/VBox/QuestsButton
@onready var _packs_btn: Button = $Panel/VBox/PacksButton
@onready var _scoring_btn: Button = $Panel/VBox/ScoringButton
@onready var _save_btn: Button = $Panel/VBox/SaveButton
@onready var _load_btn: Button = $Panel/VBox/LoadButton
@onready var _leave_btn: Button = $Panel/VBox/LeaveButton
@onready var _hint: Label = $Panel/VBox/HintLabel
@onready var _title: Label = $Panel/VBox/Title
@onready var _rings_spin: SpinBox = $Panel/VBox/MapRow/RingsSpin
@onready var _plays_spin: SpinBox = $Panel/VBox/ActionsRow/PlaysSpin


func _ready() -> void:
	_animals_btn.pressed.connect(func() -> void:
		GameFeedback.play_click_button()
		if maker:
			maker.open_animals()
	)
	_quests_btn.pressed.connect(func() -> void:
		GameFeedback.play_click_button()
		if maker:
			maker.open_quests()
	)
	_packs_btn.pressed.connect(func() -> void:
		GameFeedback.play_click_button()
		if maker:
			maker.open_packs()
	)
	_scoring_btn.pressed.connect(func() -> void:
		GameFeedback.play_click_button()
		if maker:
			maker.open_scoring()
	)
	_save_btn.pressed.connect(func() -> void:
		GameFeedback.play_click_button()
		if maker:
			maker.open_save()
	)
	_load_btn.pressed.connect(func() -> void:
		GameFeedback.play_click_button()
		if maker:
			maker.open_load()
	)
	_leave_btn.pressed.connect(func() -> void:
		GameFeedback.play_click_button()
		if maker:
			maker.leave_to_menu()
	)
	_hint.text = "Right-click a tile to erase. Element hand stamps forever."
	call_deferred("_sync_spinners_from_maker")
	_rings_spin.value_changed.connect(_on_rings_changed)
	_plays_spin.value_changed.connect(_on_plays_changed)


func _sync_spinners_from_maker() -> void:
	if maker == null:
		return
	_rings_spin.set_value_no_signal(float(maker.get_ring_count()))
	_plays_spin.set_value_no_signal(float(maker.get_max_plays()))
	var title := str(maker.draft.get("title", "")).strip_edges()
	if title.is_empty():
		title = str(maker.draft.get("id", "")).strip_edges()
	_title.text = title if not title.is_empty() else "Puzzle Maker"


func _on_rings_changed(value: float) -> void:
	if maker:
		maker.set_ring_count(int(value))


func _on_plays_changed(value: float) -> void:
	if maker:
		maker.set_max_plays(int(value))
