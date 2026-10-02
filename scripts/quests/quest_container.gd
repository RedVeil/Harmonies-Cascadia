extends Node2D
class_name QuestContainer

@export var layout_rect: ColorRect
@export var quest_scene: PackedScene
@export var max_gap : float = 60.0

var quests : Array[QuestItem] = []
var quest_amount : int = 0
var _pending_dismiss: Array[int] = []

## ----- Initialisation ----- ##

func init(quest_limit:int) -> void:
	quests.resize(quest_limit)

## ----- Pass Data Downstream ----- ##

func add_quest(id:int, questData:Quest) -> void:
	var quest := quest_scene.instantiate() as Node2D
	quests[id] = quest
	quest_amount += 1
	
	quest.init(self, questData)
	add_child(quest)
	
	_layout_quests()

func remove_quest(id:int) -> void:
	quest_amount -= 1
	quests[id].remove_quest()
	quests[id] = null
	_pending_dismiss.erase(id)
	
	_layout_quests()


func dismiss_quests(indices: Array, duration: float) -> void:
	for id in indices:
		var slot := int(id)
		var quest := quests[slot]
		if quest == null or _pending_dismiss.has(slot):
			continue
		_pending_dismiss.append(slot)
		quest.dismiss_finished.connect(_on_quest_dismiss_finished.bind(slot), CONNECT_ONE_SHOT)
		quest.play_dismiss(duration)


func cancel_pending_dismiss() -> void:
	var pending := _pending_dismiss.duplicate()
	_pending_dismiss.clear()
	for id in pending:
		var quest := quests[id]
		if quest != null:
			quest.cancel_dismiss()


func _on_quest_dismiss_finished(id: int) -> void:
	if quests[id] != null:
		quest_amount = maxi(quest_amount - 1, 0)
		quests[id] = null
	_pending_dismiss.erase(id)
	if _pending_dismiss.is_empty():
		_layout_quests()

func preview_progress(id:int, val:int) -> void:
	quests[id].preview_progress(val)

func apply_preview(id:int) -> void:
	quests[id].apply_preview()

func reset_preview(id:int) -> void:
	quests[id].reset_preview()

func undo(id:int) -> void:
	quests[id].undo()

## ----- Layout Logic ----- ##

func _layout_quests() -> void:
	if quest_amount <= 0:
		return
	var rect_top := layout_rect.position.y
	var rect_height := layout_rect.size.y
	var center_x := layout_rect.position.x + layout_rect.size.x / 2.0
	
	var gap : float = min(rect_height / float(quest_amount), max_gap)
	
	var quest_counter = 0
	for i in quests.size():
		var quest := quests[i]
		if quest != null:
			var y := rect_top + gap * float(quest_counter + 0.5)
			quest.position = Vector2(center_x, y)
			quest.z_index = quest_counter
			quest_counter += 1
