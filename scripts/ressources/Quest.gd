class_name Quest
extends Resource

enum QuestType {
	ELEMENT,
	ANIMAL
}

@export var id:int = 0
@export var name:String = ""
@export var description:String = ""
# are we looking for animals or elements?
@export var type : QuestType = QuestType.ELEMENT
# id of the element or animal we are looking for
@export var target_id: int = 0
# if its elements what levels of that element do we count?
@export var levels: Array[int] = []
# what does the group size have to be atleast to count? 
# (if its a mixed group and we only count a certain amount of levels in that group we sum it and compare against this)
@export var min_group_size: int = 0
# whats the max group size it can be to count?
# (if its a mixed group and we only count a certain amount of levels in that group we sum it and compare against this)
@export var max_group_size: int = 0
# how many groups do we need to award points?
@export var group_amount: int = 0
@export var points: int = 0
