extends Node
## Thin Supabase REST client for daily leaderboard RPCs.

const CONFIG_PATH := "res://data/supabase_config.json"
const RPC_TIMEOUT_MS := 15000

var _url: String = ""
var _anon_key: String = ""
var last_error: String = ""

var _rpc_gate: int = 0
var _rpc_next: int = 0
var _http: HTTPRequest

var _js_callback = null
var _web_gen: int = 0
var _web_done: bool = false
var _web_text: String = ""


func _ready() -> void:
	_load_config()
	if OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(_on_web_rpc_done)
	else:
		_http = HTTPRequest.new()
		_http.timeout = RPC_TIMEOUT_MS / 1000.0
		_http.accept_gzip = false
		add_child(_http)


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
	if not is_configured():
		last_error = "Leaderboard is not configured."
		return null
	var ticket := _rpc_next
	_rpc_next += 1
	while ticket != _rpc_gate:
		await get_tree().process_frame
	last_error = ""
	var result: Variant
	if OS.has_feature("web"):
		result = await _rpc_web(fn_name, payload)
	else:
		result = await _rpc_http(fn_name, payload)
	_rpc_gate += 1
	return result


func _rpc_http(fn_name: String, payload: Dictionary) -> Variant:
	if _http == null or not is_instance_valid(_http):
		_http = HTTPRequest.new()
		_http.timeout = RPC_TIMEOUT_MS / 1000.0
		_http.accept_gzip = false
		add_child(_http)
	if not _http.is_inside_tree():
		add_child(_http)
	await get_tree().process_frame
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: %s" % _anon_key,
		"Authorization: Bearer %s" % _anon_key,
	])
	var url := "%s/rest/v1/rpc/%s" % [_url, fn_name]
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if err != OK:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: failed to start %s (%s)" % [fn_name, err])
		return null
	var completed: Variant = await _http.request_completed
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


func _rpc_web(fn_name: String, payload: Dictionary) -> Variant:
	if _js_callback == null:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: web callback missing")
		return null
	var js_window = JavaScriptBridge.get_interface("window")
	if js_window == null:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: window missing")
		return null
	js_window._symbiaSupabaseCb = _js_callback
	_web_gen += 1
	var gen := _web_gen
	var req := {
		"gen": gen,
		"url": "%s/rest/v1/rpc/%s" % [_url, fn_name],
		"headers": {
			"Content-Type": "application/json",
			"Accept": "application/json",
			"apikey": _anon_key,
			"Authorization": "Bearer %s" % _anon_key,
		},
		"body": JSON.stringify(payload),
	}
	_web_done = false
	_web_text = ""
	JavaScriptBridge.eval("window._symbiaSupabaseReq = JSON.parse(%s);" % JSON.stringify(JSON.stringify(req)))
	JavaScriptBridge.eval("""
(function() {
	var req = window._symbiaSupabaseReq;
	if (!req || !window._symbiaSupabaseCb) {
		return;
	}
	fetch(req.url, { method: 'POST', headers: req.headers, body: req.body })
		.then(function(r) {
			return r.text().then(function(t) {
				return JSON.stringify({ gen: req.gen, ok: r.ok, status: r.status, text: t });
			});
		})
		.then(function(s) { window._symbiaSupabaseCb(s); })
		.catch(function(e) {
			window._symbiaSupabaseCb(JSON.stringify({
				gen: req.gen,
				ok: false,
				status: 0,
				text: '',
				error: String(e)
			}));
		});
})();
""")
	var started := Time.get_ticks_msec()
	while not _web_done:
		if gen != _web_gen:
			return null
		if Time.get_ticks_msec() - started > RPC_TIMEOUT_MS:
			_web_gen += 1
			last_error = "Could not load leaderboard."
			push_warning("SupabaseClient: %s web fetch timed out" % fn_name)
			return null
		await get_tree().process_frame
	if gen != _web_gen:
		return null
	var parsed: Variant = JSON.parse_string(_web_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: %s invalid web response" % fn_name)
		return null
	var data: Dictionary = parsed
	var code := int(data.get("status", 0))
	var text := str(data.get("text", ""))
	if not bool(data.get("ok", false)) or code < 200 or code >= 300:
		last_error = "Could not load leaderboard."
		push_warning("SupabaseClient: %s HTTP %s %s" % [fn_name, code, text])
		return null
	if text.is_empty():
		return null
	return JSON.parse_string(text)


func _on_web_rpc_done(args: Array) -> void:
	var raw := "" if args.is_empty() else str(args[0])
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if int(parsed.get("gen", -1)) != _web_gen:
		return
	_web_text = raw
	_web_done = true
