extends Node
## Thin Supabase REST client for daily leaderboard RPCs.

const CONFIG_PATH := "res://data/supabase_config.json"

var _url: String = ""
var _anon_key: String = ""
var last_error: String = ""


func _ready() -> void:
	_load_config()


func utc_date_string() -> String:
	return GameSession.get_utc_date_iso()


func is_configured() -> bool:
	if _url.is_empty() or _anon_key.is_empty():
		return false
	if _url.contains("YOUR_PROJECT") or _anon_key.contains("YOUR_ANON"):
		return false
	return true


func submit_daily_score(player_id: String, player_name: String, points: int) -> void:
	if not is_configured():
		return
	_submit_daily_score_async(player_id, player_name, points)


func fetch_page(date: String, offset: int, limit: int) -> Array:
	var result: Variant = await _rpc("daily_leaderboard_page", {
		"p_date": date,
		"p_offset": offset,
		"p_limit": limit,
	})
	if typeof(result) != TYPE_ARRAY:
		if last_error.is_empty():
			last_error = "Could not load leaderboard."
		return []
	var out: Array = []
	for item in result:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(_normalize_entry(item))
	return out


func fetch_player_entry(date: String, player_id: String) -> Dictionary:
	var result: Variant = await _rpc("daily_player_entry", {
		"p_date": date,
		"p_player_id": player_id,
	})
	if typeof(result) == TYPE_DICTIONARY:
		return _normalize_entry(result)
	if typeof(result) == TYPE_ARRAY and result.size() > 0 and typeof(result[0]) == TYPE_DICTIONARY:
		return _normalize_entry(result[0])
	return {}


func _submit_daily_score_async(player_id: String, player_name: String, points: int) -> void:
	await _rpc("submit_daily_score", {
		"p_player_id": player_id,
		"p_name": player_name,
		"p_points": points,
	})


func _normalize_entry(data: Dictionary) -> Dictionary:
	return {
		"rank": int(data.get("rank", 0)),
		"player_id": str(data.get("player_id", "")),
		"name": str(data.get("name", "")),
		"points": int(data.get("points", 0)),
	}


func _load_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("SupabaseClient: missing %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SupabaseClient: invalid config JSON")
		return
	var data: Dictionary = parsed
	_url = str(data.get("url", "")).strip_edges().trim_suffix("/")
	_anon_key = str(data.get("anon_key", "")).strip_edges()


func _rpc(fn_name: String, payload: Dictionary) -> Variant:
	last_error = ""
	if not is_configured():
		last_error = "Leaderboard is not configured."
		return null
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: %s" % _anon_key,
		"Authorization: Bearer %s" % _anon_key,
	])
	var url := "%s/rest/v1/rpc/%s" % [_url, fn_name]
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: failed to start %s (%s)" % [fn_name, err])
		http.queue_free()
		return null
	var completed: Variant = await http.request_completed
	http.queue_free()
	if typeof(completed) != TYPE_ARRAY or completed.size() < 4:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: incomplete response for %s" % fn_name)
		return null
	var result: int = int(completed[0])
	var code: int = int(completed[1])
	var body: PackedByteArray = completed[3] as PackedByteArray
	var text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: %s result %s" % [fn_name, result])
		return null
	if code < 200 or code >= 300:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: %s HTTP %s %s" % [fn_name, code, text])
		return null
	if text.is_empty():
		return null
	return JSON.parse_string(text)
