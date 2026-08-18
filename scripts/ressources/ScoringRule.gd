class_name ScoringRule
extends Resource

enum SpecialRule {
	NONE,
	SHORTEST_ROUTE,
	NEIGHBORS,
	GROUP_SIZE
}

@export var id:int = 0
@export var name:String = ""
@export var description:String = ""
# minimum group size required to earn flat_points
@export var min_group_size: int = 0
# max tiles that count toward points_per_tile_level (highest levels first)
@export var max_group_size: int = 0
# points each placed tile earns by level (always applied)
# zero is allowed when a rule awards only flat_points (or none per tile)
@export var points_per_tile_level: Array[Vector2i] = []
# flat bonus added only when min_group_size is met (stacks with points_per_tile_level)
@export var flat_points: int = 0
# an enum to switch to special scoring rules
@export var special_rule: SpecialRule = SpecialRule.NONE
# specs for the special rule to calculate the score
@export var special_rule_specs: Dictionary = {}

## For shortest_route (path length) and group_size (connected tile count)
# {
#points: [0,2,5,8,11,15] = points at that size/length (1-indexed via size-1)
#extra_points: 4 = points for each step over the array length
# }

## for neighbors
# {
#    neighbors_min: 3 = minimum amount of different neighbors to count
#    points_flat: 5 = points if neighbors_min is achieved
#    points_per: 2 = points per different neighbor
# }
