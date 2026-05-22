extends Node

var path = "res://data/scoring_rules.json"
var rules : Array[ScoringRule] = []

func _ready() -> void:
	load_rules()

func load_rules():
	if not FileAccess.file_exists(path):
		push_error("Score data not found: %s" % path)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_ARRAY:
		push_error("Invalid score data JSON: %s" % path)
		return false
	for rule in parsed:
		rules.append(parse_rule(rule))

func parse_rule(data:Dictionary) -> ScoringRule:
	var rule = ScoringRule.new()
	rule.id = data.id
	rule.name = data.name
	rule.min_group_size = data.min_group_size
	rule.max_group_size = data.max_group_size
	rule.flat_points = data.flat_points
	rule.special_rule = data.special_rule
	rule.special_rule_specs = data.special_rule_specs
	
	var points_per_tile_level : Array[Vector2i] = []
	for entry in data.points_per_tile_level:
		points_per_tile_level.append(Vector2i(entry[0], entry[1]))
	rule.points_per_tile_level = points_per_tile_level
	
	return rule
