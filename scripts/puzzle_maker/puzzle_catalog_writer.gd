extends RefCounted
class_name PuzzleCatalogWriter

## Upserts a puzzle definition into data/puzzles.json and reloads GameSession.


static func upsert(puzzle: Dictionary) -> bool:
	var id := str(puzzle.get("id", "")).strip_edges()
	if id.is_empty():
		push_error("PuzzleCatalogWriter: puzzle id is required")
		return false

	var path := GameSession.PUZZLES_PATH
	var puzzles: Array = []
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if typeof(parsed) == TYPE_DICTIONARY:
			var listed = parsed.get("puzzles", [])
			if typeof(listed) == TYPE_ARRAY:
				puzzles = listed
		elif typeof(parsed) == TYPE_ARRAY:
			puzzles = parsed

	var found := false
	var max_order := 0
	for i in puzzles.size():
		var entry = puzzles[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		max_order = maxi(max_order, int(entry.get("order", 0)))
		if str(entry.get("id", "")) == id:
			if not puzzle.has("order"):
				puzzle["order"] = int(entry.get("order", i + 1))
			puzzles[i] = puzzle
			found = true
			break

	if not found:
		if not puzzle.has("order"):
			puzzle["order"] = max_order + 1
		puzzles.append(puzzle)

	var payload := {"puzzles": puzzles}
	var json := JSON.stringify(payload, "\t")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("PuzzleCatalogWriter: cannot write %s (error %s)" % [
			path, FileAccess.get_open_error()
		])
		return false
	f.store_string(json)
	f.store_string("\n")
	f.close()
	GameSession.reload_puzzles()
	return true
