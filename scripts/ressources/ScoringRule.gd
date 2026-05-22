class_name ScoringRule
extends Resource

enum SpecialRule {
	NONE,
	SHORTEST_ROUTE,
	NEIGHBORS
}

@export var id:int = 0
@export var name:String = ""
# whats the minimum amount of tiles in the group to count?
@export var min_group_size: int = 0
# whats the maximum amount of tiles in the group to count?
@export var max_group_size: int = 0
# how many points does each level earn? 
# zero is allowed since it could just award flat points
@export var points_per_tile_level: Array[Vector2i] = []
# does it give flat points if min/max and special rule are satisfied?
@export var flat_points: int = 0
# an enum to switch to special scoring rules
@export var special_rule: SpecialRule = SpecialRule.NONE
# specs for the special rule to calculate the score
@export var special_rule_specs: Dictionary = {}

## For shortest_route
# {
#points: [0,2,5,8,11,15] = specific point count at length
#extra_points: 4 = points for each length over the array length
# }

## for neighbors
# {
#    neighbors_min: 3 = minimum amount of different neighbors to count
#    points_flat: 5 = points if neighbors_min is achieved
#    points_per: 2 = points per different neighbor
# }
