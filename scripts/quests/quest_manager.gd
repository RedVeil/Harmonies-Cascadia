extends Node2D
class_name QuestManager

@export var quest_limit : int = 3

@onready var quest_container: QuestContainer = $QuestContainer

var active_quests : Array[int] = []
var completed_quests : Array[int] = []
var quest_score : int = 0

## contains group_ids for quest_progress for elemental quests 
## contains a single int counting up with the amount of eligble animals for animal quests
var eligble_groups : Array[Array] = []
var eligble_groups_preview : Array[Array] = []
var preview_quests : Array[int] = []

## ----- Initialisation ----- ##

func _ready() -> void:
	active_quests.resize(quest_limit)
	active_quests.fill(-1)
	eligble_groups.resize(quest_limit)
	eligble_groups_preview.resize(quest_limit)
	quest_container.init(quest_limit)

## ----- Pass data downstream ----- ##

func add_quest(id:int) -> void:
	var quest_index = active_quests.find(-1)
	if quest_index != -1:
		active_quests[quest_index] = id
		eligble_groups[quest_index] = []
		eligble_groups_preview[quest_index] = []
		quest_container.add_quest(quest_index, QuestCatalog.quest_options[id])
		
func remove_quest(index:int) -> void:
	completed_quests.append(active_quests[index])
	active_quests[index] = -1
	eligble_groups[index] = []
	eligble_groups_preview[index] = []
	quest_container.remove_quest(index)
	
func preview_progress(index:int, new_progress:int) -> void:
	preview_quests.append(index)
	quest_container.preview_progress(index, new_progress)

func apply_preview() -> void:
	for index in preview_quests:
		var quest_id = active_quests[index]
		var quest = QuestCatalog.quest_options[quest_id]
		if quest.type == 0:
			if eligble_groups_preview[index].size() >= quest.group_amount:
				remove_quest(index)
			else:
				eligble_groups[index] = eligble_groups_preview[index]
				eligble_groups_preview[index] = []
				quest_container.apply_preview(index)
		else:
			if eligble_groups_preview[index][0] >= quest.group_amount:
				remove_quest(index)
			else:
				eligble_groups[index] = eligble_groups_preview[index]
				eligble_groups_preview[index] = []
				quest_container.apply_preview(index)
	preview_quests = []

func reset_preview() -> void:
	for index in preview_quests:
		eligble_groups_preview[index] = []
		quest_container.reset_preview(index)
	preview_quests = []

## ----- Evaluate Quests ----- ##

func preview_element_quests(
	element:int, 
	old_groups:Array[int], 
	new_group_id:int, 
	coord:Vector2i, 
	group_coords:Array[Vector2i],
	hex_tiles:Dictionary[Vector2i, HexTileData]
	) -> int:
	var coords_ = group_coords.duplicate(true)
	coords_.append(coord)
	
	var new_score : int = 0
	
	for i in active_quests.size():
		var quest_id = active_quests[i]
		if quest_id != -1:
			var quest = QuestCatalog.quest_options[quest_id]
			if quest.type == 0 and quest.id == element:
				var prev_group_amount = eligble_groups[i].size()
				var new_group = []
				if old_groups.size() > 0:
					new_group = eligble_groups[i].filter(func (group): !old_groups.has(group))
				
				var group_size = 0
				for c in coords_:
					if quest.levels.has(hex_tiles[c].level):
						group_size += 1
				
				if group_size >= quest.min_group_size and group_size <= quest.max_group_size:
					new_group.append(new_group_id)
				
				if new_group.size() >= quest.group_amount:
					new_score += quest.points
					
				eligble_groups_preview[i] = new_group
				preview_progress(i, new_group.size())
	
	return new_score

func preview_animal_quests(animal_id:int) -> int:
	var new_score : int = 0
	for i in active_quests.size():
		var quest_id = active_quests[i]
		if quest_id != -1:
			var quest = QuestCatalog.quest_options[quest_id]
			if quest.type == 1 and quest.id == animal_id:
				var new_group = [1]
				if eligble_groups[i].size() > 0:
					new_group[0] += eligble_groups[i][0]
					
				if new_group[0] >= quest.group_amount:
					new_score += quest.points
				
				eligble_groups_preview[i] = new_group
				preview_progress(i, new_group[0])
	
	return new_score

## ----- Create new active Quests ----- ##

func pick_quest(type:int, element:int) -> void:
	var quest_index = active_quests.find(null)
	if quest_index != -1:
		var options_filtered = QuestCatalog.quest_options.filter(func (option): !completed_quests.has(option.id))
		var options_by_type = options_filtered.filter(func (option): option.type == type)
		if type == 0:
			var options_by_element = options_by_type.filter(func (option): option.target_id == element)
			active_quests[quest_index] = options_by_type.pick_random().id
		else:
			active_quests[quest_index] = options_by_type.pick_random().id
