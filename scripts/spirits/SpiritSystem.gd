class_name SpiritSystem
extends RefCounted

const TileState = preload("res://scripts/game/TileState.gd")

var active_quest: Dictionary = {}
var forest_modifier_delta: int = 0

func maybe_spawn_first_forest_spirit(first_forest_placed: bool, current_turn: int) -> void:
	if not first_forest_placed:
		return
	if not active_quest.is_empty():
		return
	active_quest = {
		"id": "forest_cluster_5",
		"target_count": 5,
		"turn_limit": 15,
		"start_turn": current_turn,
		"completed": false,
		"failed": false
	}

func evaluate(board: Dictionary, grid, current_turn: int) -> Dictionary:
	if active_quest.is_empty():
		return {"delta": 0, "status": "none"}
	if active_quest["completed"] or active_quest["failed"]:
		return {"delta": 0, "status": "resolved"}

	var connected_max := _largest_connected_forest_cluster(board, grid)
	if connected_max >= active_quest["target_count"]:
		active_quest["completed"] = true
		forest_modifier_delta += 1
		return {"delta": 50, "status": "completed"}

	if current_turn - active_quest["start_turn"] >= active_quest["turn_limit"]:
		active_quest["failed"] = true
		forest_modifier_delta -= 1
		return {"delta": 0, "status": "failed"}

	return {"delta": 0, "status": "active"}

func quest_summary(current_turn: int) -> String:
	if active_quest.is_empty():
		return "No active spirit quest"
	if active_quest["completed"]:
		return "Spirit done: +50 and forests now +1"
	if active_quest["failed"]:
		return "Spirit failed: forests now -1"
	var left: int = int(active_quest["turn_limit"]) - (current_turn - int(active_quest["start_turn"]))
	return "Spirit: build 5 connected forests in %d turns" % max(left, 0)

func _largest_connected_forest_cluster(board: Dictionary, grid) -> int:
	var seen: Dictionary = {}
	var best := 0
	for c in board.keys():
		if seen.has(c):
			continue
		var t: TileState = board[c]
		if t.element != TileState.Element.FOREST:
			continue
		var q: Array[Vector2i] = [c]
		seen[c] = true
		var size := 0
		while not q.is_empty():
			var curr: Vector2i = q.pop_front()
			size += 1
			for n in grid.neighbors(curr):
				if seen.has(n):
					continue
				if (board[n] as TileState).element == TileState.Element.FOREST:
					seen[n] = true
					q.append(n)
		best = maxi(best, size)
	return best
