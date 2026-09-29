extends Node
## Local-first run and error analytics. Gameplay never waits on the network.

const QUEUE_PATH := "user://analytics_queue.json"
const QUEUE_LIMIT := 100
const FLUSH_INTERVAL_SEC := 45.0
const REQUEST_TIMEOUT_SEC := 15.0
const BACKOFF_START_SEC := 15.0
const BACKOFF_MAX_SEC := 300.0
const PAYLOAD_CHAR_LIMIT := 15000
const MESSAGE_CHAR_LIMIT := 500
const BREADCRUMB_LIMIT := 15
const ERROR_DEBOUNCE_MSEC := 60000

const _SEND_OK := 0
const _SEND_RETRY := 1
const _SEND_DROP := 2

var _run_id: String = ""
var _session_id: String = ""
var _tracking: bool = false
var _seed_shop: bool = false
var _started_msec: int = 0
var _elapsed_offset_msec: int = 0

var _animals_offered: Dictionary = {}
var _animals_bought: Dictionary = {}
var _animals_placed: Dictionary = {}
var _animals_recycled: Dictionary = {}
var _tiles_offered: Dictionary = {}
var _tiles_placed: Dictionary = {}
var _quests_offered: Dictionary = {}
var _quests_taken: Dictionary = {}
var _quests_completed: Dictionary = {}
var _placements: int = 0
var _undos: int = 0
var _packs: int = 0
var _rerolls: int = 0
var _market_buys: int = 0
var _breadcrumbs: Array = []

var _queue: Array = []
var _flushing: bool = false
var _flush_requested: bool = false
var _backoff_sec: float = BACKOFF_START_SEC
var _next_flush_msec: int = 0
var _error_seen: Dictionary = {}
var _in_error_log: bool = false

var _http: HTTPRequest
var _js_callback = null
var _web_gen: int = 0
var _web_done: bool = false
var _web_text: String = ""
var _error_log: Logger


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_session_id = _uuid()
	_load_queue()
	_error_log = AnalyticsErrorLog.new(self)
	OS.add_logger(_error_log)
	var timer := Timer.new()
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.wait_time = FLUSH_INTERVAL_SEC
	timer.autostart = true
	timer.timeout.connect(request_flush)
	add_child(timer)
	if OS.has_feature("web"):
		_js_callback = JavaScriptBridge.create_callback(_on_web_done)
	else:
		_http = HTTPRequest.new()
		_http.process_mode = Node.PROCESS_MODE_ALWAYS
		_http.timeout = REQUEST_TIMEOUT_SEC
		_http.accept_gzip = false
		add_child(_http)
	call_deferred("request_flush")


func run_id() -> String:
	return _run_id if _tracking else ""


func start_run() -> void:
	if GameSession.game_mode == GameSession.GameMode.PUZZLE_MAKER:
		stop_tracking()
		return
	_run_id = _uuid()
	_reset_counters()
	_elapsed_offset_msec = 0
	_tracking = true
	_seed_shop = false
	_started_msec = Time.get_ticks_msec()


func stop_tracking() -> void:
	_tracking = false
	_seed_shop = false
	_run_id = ""
	_reset_counters()


func export_state() -> Dictionary:
	return {
		"run_id": run_id(),
		"elapsed_msec": _elapsed_msec(),
		"animals_offered": _animals_offered.duplicate(true),
		"animals_bought": _animals_bought.duplicate(true),
		"animals_placed": _animals_placed.duplicate(true),
		"animals_recycled": _animals_recycled.duplicate(true),
		"tiles_offered": _tiles_offered.duplicate(true),
		"tiles_placed": _tiles_placed.duplicate(true),
		"quests_offered": _quests_offered.duplicate(true),
		"quests_taken": _quests_taken.duplicate(true),
		"quests_completed": _quests_completed.duplicate(true),
		"placements": _placements,
		"undos": _undos,
		"packs_taken": _packs,
		"rerolls": _rerolls,
		"market_buys": _market_buys,
	}


## Returns true when the visible shop still needs to be counted.
## Same-process continues and saves that already stored counters do not recount it.
func resume_run(saved_id: String, saved_counters: Dictionary = {}) -> bool:
	if GameSession.game_mode == GameSession.GameMode.PUZZLE_MAKER:
		stop_tracking()
		return false
	var id := saved_id.strip_edges()
	if id == _run_id and _tracking:
		_seed_shop = false
		return false
	_run_id = id if not id.is_empty() else _uuid()
	_reset_counters()
	_tracking = true
	_started_msec = Time.get_ticks_msec()
	if not saved_counters.is_empty():
		_apply_saved_counters(saved_counters)
		_seed_shop = false
		return false
	_elapsed_offset_msec = 0
	_seed_shop = true
	return true


func seed_shop_from(booster_manager) -> void:
	if not _seed_shop:
		return
	_seed_shop = false
	note_opening_shop(booster_manager)


func note_opening_shop(booster_manager) -> void:
	if not _tracking or booster_manager == null:
		return
	for booster in booster_manager.boosters:
		note_shown_booster(booster)
	note_market_offers(booster_manager._market_offers)


func on_setting_changed() -> void:
	if not GameSettings.analytics_enabled:
		return
	_backoff_sec = BACKOFF_START_SEC
	_next_flush_msec = 0
	request_flush()


func note_shown_booster(booster) -> void:
	if not _tracking or booster == null:
		return
	for card in booster.cards:
		if card == null:
			continue
		if int(card.type) == CardData.CARD_TYPE.ELEMENT:
			_bump(_tiles_offered, int(card.id))
	for quest_id in booster.quest_ids:
		_bump(_quests_offered, int(quest_id))


func note_market_offers(offers: Array) -> void:
	for offer in offers:
		note_animal_offer(offer)


func note_animal_offer(animal) -> void:
	if not _tracking or animal == null:
		return
	if int(animal.amount) <= 0:
		return
	_bump(_animals_offered, int(animal.id))


func note_animal_bought(animal_id: int) -> void:
	if not _tracking:
		return
	_bump(_animals_bought, animal_id)


func note_animal_placed(animal_id: int) -> void:
	if not _tracking:
		return
	_bump(_animals_placed, animal_id)


func note_animal_unplaced(animal_id: int) -> void:
	if not _tracking:
		return
	_bump(_animals_placed, animal_id, -1)


func note_animal_recycled(animal_id: int, count: int) -> void:
	if not _tracking:
		return
	_bump(_animals_recycled, animal_id, maxi(count, 1))


func note_tile_placed(element_id: int) -> void:
	if not _tracking:
		return
	_bump(_tiles_placed, element_id)


func note_tile_unplaced(element_id: int) -> void:
	if not _tracking:
		return
	_bump(_tiles_placed, element_id, -1)


func note_quest_taken(quest_id: int) -> void:
	if not _tracking:
		return
	_bump(_quests_taken, quest_id)


func note_quest_completed(quest_id: int) -> void:
	if not _tracking:
		return
	_bump(_quests_completed, quest_id)


func note_quest_uncompleted(quest_id: int) -> void:
	if not _tracking:
		return
	_bump(_quests_completed, quest_id, -1)


func note_pack() -> void:
	if not _tracking:
		return
	_packs += 1


func note_reroll() -> void:
	if not _tracking:
		return
	_rerolls += 1


func note_market_buy() -> void:
	if not _tracking:
		return
	_market_buys += 1


func note_placement() -> void:
	if not _tracking:
		return
	_placements += 1


func note_undo() -> void:
	if not _tracking:
		return
	_undos += 1
	_placements = maxi(_placements - 1, 0)


func breadcrumb(action: String, detail: Dictionary = {}) -> void:
	_breadcrumbs.append({
		"action": action,
		"detail": detail.duplicate(true),
	})
	while _breadcrumbs.size() > BREADCRUMB_LIMIT:
		_breadcrumbs.pop_front()


func snapshot_run(end_reason: String, score_engine = null, hex_manager = null) -> void:
	if not _tracking or _run_id.is_empty():
		return
	var payload := {
		"mode": _mode_name(),
		"map_size": int(GameSession.map_size),
		"seed": int(GameSession.run_seed),
		"puzzle_id": GameSession.puzzle_id,
		"locale": GameSettings.content_locale,
		"platform": _platform_tag(),
		"duration_sec": maxi(int(_elapsed_msec() / 1000.0), 0),
		"end_reason": end_reason,
		"score_total": int(score_engine.total_score) if score_engine != null else 0,
		"score_element": int(score_engine.element_score) if score_engine != null else 0,
		"score_animal": int(score_engine.animal_score) if score_engine != null else 0,
		"score_quest": int(score_engine.quest_score) if score_engine != null else 0,
		"rules": _active_rules(score_engine),
		"element_points": _element_points(score_engine, hex_manager),
		"animals_offered": _animals_offered.duplicate(true),
		"animals_bought": _animals_bought.duplicate(true),
		"animals_placed": _animals_placed.duplicate(true),
		"animals_recycled": _animals_recycled.duplicate(true),
		"tiles_offered": _tiles_offered.duplicate(true),
		"tiles_placed": _tiles_placed.duplicate(true),
		"quests_offered": _quests_offered.duplicate(true),
		"quests_taken": _quests_taken.duplicate(true),
		"quests_completed": _quests_completed.duplicate(true),
		"placements": _placements,
		"undos": _undos,
		"packs_taken": _packs,
		"rerolls": _rerolls,
		"market_buys": _market_buys,
	}
	_enqueue("run", payload)


func note_leaderboard_failure(fn_name: String, detail: String) -> void:
	_enqueue_error("leaderboard", detail, "", fn_name, 0)


func note_save_failure(stage: String, detail: String) -> void:
	breadcrumb("save", {"stage": stage})
	_enqueue_error("save", detail, "", stage, 0)


func request_flush() -> void:
	if not _can_flush() or _queue.is_empty():
		return
	if Time.get_ticks_msec() < _next_flush_msec:
		return
	if _flushing:
		_flush_requested = true
		return
	_flushing = true
	_flush_requested = false
	_flush_loop()


func _on_engine_error(
	function: String,
	file: String,
	line: int,
	code: String,
	rationale: String,
	error_type: int
) -> void:
	if _in_error_log:
		return
	if error_type != Logger.ErrorType.ERROR_TYPE_ERROR and error_type != Logger.ErrorType.ERROR_TYPE_SCRIPT:
		return
	if file.ends_with("analytics.gd"):
		return
	var key := "%s:%d" % [file, line]
	var now := Time.get_ticks_msec()
	if _error_seen.has(key) and now - int(_error_seen[key]) < ERROR_DEBOUNCE_MSEC:
		return
	_error_seen[key] = now
	var message := rationale if not rationale.is_empty() else code
	if not code.is_empty() and not rationale.is_empty():
		message = "%s: %s" % [code, rationale]
	_in_error_log = true
	_enqueue_error("script", message, file, function, line)
	_in_error_log = false


func _enqueue_error(source: String, message: String, file: String, function: String, line: int) -> void:
	var text := message
	if text.length() > MESSAGE_CHAR_LIMIT:
		text = text.substr(0, MESSAGE_CHAR_LIMIT)
	_enqueue("error", {
		"source": source,
		"message": text,
		"file": file,
		"function": function,
		"line": line,
		"mode": _mode_name(),
		"platform": _platform_tag(),
		"locale": GameSettings.content_locale,
		"breadcrumb": _breadcrumbs.duplicate(true),
	})


func _enqueue(kind: String, payload: Dictionary) -> void:
	if not GameSettings.analytics_enabled:
		return
	var event := {
		"kind": kind,
		"run_id": _event_run_id(),
		"player_id": _player_id(),
		"build": _build_version(),
		"payload": payload,
	}
	if JSON.stringify(event).length() > PAYLOAD_CHAR_LIMIT and kind == "error":
		payload["breadcrumb"] = []
		event["payload"] = payload
	if JSON.stringify(event).length() > PAYLOAD_CHAR_LIMIT:
		return
	_queue.append(event)
	_trim_queue()
	_save_queue()
	call_deferred("request_flush")


func _event_run_id() -> String:
	if not _run_id.is_empty():
		return _run_id
	if _session_id.is_empty():
		_session_id = _uuid()
	return _session_id


func _player_id() -> String:
	var id := GameSettings.player_id.strip_edges()
	return id if not id.is_empty() else "unknown"


func _build_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


func _can_flush() -> bool:
	if not GameSettings.analytics_enabled:
		return false
	if not is_instance_valid(SupabaseClient) or not SupabaseClient.is_configured():
		return false
	return true


func _flush_loop() -> void:
	while not _queue.is_empty():
		if not _can_flush():
			break
		if OS.has_feature("web") and not _web_online():
			_schedule_retry()
			break
		var outcome := await _post_event(_queue[0])
		if outcome == _SEND_OK or outcome == _SEND_DROP:
			if not _queue.is_empty():
				_queue.pop_front()
			_save_queue()
			if outcome == _SEND_OK:
				_backoff_sec = BACKOFF_START_SEC
			continue
		_schedule_retry()
		break
	_flushing = false
	if _flush_requested:
		_flush_requested = false
		request_flush()


func _schedule_retry() -> void:
	_next_flush_msec = Time.get_ticks_msec() + int(_backoff_sec * 1000.0)
	_backoff_sec = minf(_backoff_sec * 2.0, BACKOFF_MAX_SEC)


func _post_event(event: Dictionary) -> int:
	var body := {
		"p_kind": str(event.get("kind", "")),
		"p_run_id": str(event.get("run_id", "")),
		"p_player_id": str(event.get("player_id", "")),
		"p_build": str(event.get("build", "")),
		"p_payload": event.get("payload", {}),
	}
	if OS.has_feature("web"):
		return await _post_web(body)
	return await _post_http(body)


func _post_http(body: Dictionary) -> int:
	if _http == null or not is_instance_valid(_http):
		_http = HTTPRequest.new()
		_http.process_mode = Node.PROCESS_MODE_ALWAYS
		_http.timeout = REQUEST_TIMEOUT_SEC
		_http.accept_gzip = false
		add_child(_http)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: %s" % SupabaseClient.configured_key(),
		"Authorization: Bearer %s" % SupabaseClient.configured_key(),
	])
	var url := "%s/rest/v1/rpc/record_analytics_event" % SupabaseClient.configured_url()
	var err := _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		return _SEND_RETRY
	var completed: Variant = await _http.request_completed
	if typeof(completed) != TYPE_ARRAY or completed.size() < 4:
		return _SEND_RETRY
	var result: int = int(completed[0])
	var code: int = int(completed[1])
	if result != HTTPRequest.RESULT_SUCCESS:
		return _SEND_RETRY
	return _classify_status(code)


func _post_web(body: Dictionary) -> int:
	if _js_callback == null:
		return _SEND_RETRY
	var js_window = JavaScriptBridge.get_interface("window")
	if js_window == null:
		return _SEND_RETRY
	js_window._symbiaAnalyticsCb = _js_callback
	_web_gen += 1
	var gen := _web_gen
	var req := {
		"gen": gen,
		"url": "%s/rest/v1/rpc/record_analytics_event" % SupabaseClient.configured_url(),
		"headers": {
			"Content-Type": "application/json",
			"Accept": "application/json",
			"apikey": SupabaseClient.configured_key(),
			"Authorization": "Bearer %s" % SupabaseClient.configured_key(),
		},
		"body": JSON.stringify(body),
	}
	_web_done = false
	_web_text = ""
	JavaScriptBridge.eval("window._symbiaAnalyticsReq = JSON.parse(%s);" % JSON.stringify(JSON.stringify(req)))
	JavaScriptBridge.eval("""
(function() {
	var req = window._symbiaAnalyticsReq;
	if (!req || !window._symbiaAnalyticsCb) {
		return;
	}
	fetch(req.url, { method: 'POST', headers: req.headers, body: req.body })
		.then(function(r) {
			return r.text().then(function(t) {
				return JSON.stringify({ gen: req.gen, ok: r.ok, status: r.status, text: t });
			});
		})
		.then(function(s) { window._symbiaAnalyticsCb(s); })
		.catch(function() {
			window._symbiaAnalyticsCb(JSON.stringify({
				gen: req.gen,
				ok: false,
				status: 0,
				text: ''
			}));
		});
})();
""")
	var started := Time.get_ticks_msec()
	while not _web_done:
		if gen != _web_gen:
			return _SEND_RETRY
		if Time.get_ticks_msec() - started > int(REQUEST_TIMEOUT_SEC * 1000.0):
			_web_gen += 1
			return _SEND_RETRY
		await get_tree().process_frame
	if gen != _web_gen:
		return _SEND_RETRY
	var parsed: Variant = JSON.parse_string(_web_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return _SEND_RETRY
	var data: Dictionary = parsed
	return _classify_status(int(data.get("status", 0)))


func _on_web_done(args: Array) -> void:
	var raw := "" if args.is_empty() else str(args[0])
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	if int(parsed.get("gen", -1)) != _web_gen:
		return
	_web_text = raw
	_web_done = true


func _web_online() -> bool:
	var result: Variant = JavaScriptBridge.eval("typeof navigator === 'undefined' ? true : navigator.onLine")
	if result == null:
		return true
	return bool(result)


func _classify_status(code: int) -> int:
	if code >= 200 and code < 300:
		return _SEND_OK
	# 400/422 are rejected payloads. Anything else, including a missing RPC, stays queued.
	if code == 400 or code == 422:
		return _SEND_DROP
	return _SEND_RETRY


func _trim_queue() -> void:
	while _queue.size() > QUEUE_LIMIT:
		var dropped := false
		for i in _queue.size():
			if str(_queue[i].get("kind", "")) == "error":
				_queue.remove_at(i)
				dropped = true
				break
		if not dropped:
			_queue.pop_front()


func _load_queue() -> void:
	_queue = []
	if not FileAccess.file_exists(QUEUE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(QUEUE_PATH))
	if typeof(parsed) != TYPE_ARRAY:
		return
	_queue = parsed
	_trim_queue()


func _save_queue() -> void:
	var f := FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_queue))
	f.flush()
	f.close()


func _elapsed_msec() -> int:
	if _started_msec <= 0:
		return _elapsed_offset_msec
	return _elapsed_offset_msec + maxi(Time.get_ticks_msec() - _started_msec, 0)


func _apply_saved_counters(saved: Dictionary) -> void:
	_animals_offered = _count_dict(saved.get("animals_offered", {}))
	_animals_bought = _count_dict(saved.get("animals_bought", {}))
	_animals_placed = _count_dict(saved.get("animals_placed", {}))
	_animals_recycled = _count_dict(saved.get("animals_recycled", {}))
	_tiles_offered = _count_dict(saved.get("tiles_offered", {}))
	_tiles_placed = _count_dict(saved.get("tiles_placed", {}))
	_quests_offered = _count_dict(saved.get("quests_offered", {}))
	_quests_taken = _count_dict(saved.get("quests_taken", {}))
	_quests_completed = _count_dict(saved.get("quests_completed", {}))
	_placements = int(saved.get("placements", 0))
	_undos = int(saved.get("undos", 0))
	_packs = int(saved.get("packs_taken", 0))
	_rerolls = int(saved.get("rerolls", 0))
	_market_buys = int(saved.get("market_buys", 0))
	_elapsed_offset_msec = int(saved.get("elapsed_msec", 0))


func _count_dict(value) -> Dictionary:
	var out := {}
	if typeof(value) != TYPE_DICTIONARY:
		return out
	for key in value.keys():
		out[str(key)] = int(value[key])
	return out


func _reset_counters() -> void:
	_animals_offered = {}
	_animals_bought = {}
	_animals_placed = {}
	_animals_recycled = {}
	_tiles_offered = {}
	_tiles_placed = {}
	_quests_offered = {}
	_quests_taken = {}
	_quests_completed = {}
	_placements = 0
	_undos = 0
	_packs = 0
	_rerolls = 0
	_market_buys = 0
	_breadcrumbs = []


func _bump(bucket: Dictionary, id: int, delta: int = 1) -> void:
	var key := str(id)
	var next := int(bucket.get(key, 0)) + delta
	if next <= 0:
		bucket.erase(key)
	else:
		bucket[key] = next


func _active_rules(score_engine) -> Dictionary:
	var rules := {}
	if score_engine == null:
		return rules
	for element_type in score_engine.active_rules.keys():
		var rule = score_engine.active_rules[element_type]
		if rule == null:
			continue
		rules[str(int(element_type))] = int(rule.id)
	return rules


func _element_points(score_engine, hex_manager) -> Dictionary:
	var totals := {}
	if score_engine == null:
		return totals
	for gid in score_engine.points_per_element_group.keys():
		var points := int(score_engine.points_per_element_group[gid])
		var element := 0
		if hex_manager != null and hex_manager.groups.has(gid):
			var members: Array = hex_manager.groups[gid]
			if not members.is_empty():
				var coord: Vector2i = members[0]
				if hex_manager.tiles.has(coord):
					element = int(hex_manager.tiles[coord].element)
		_bump(totals, element, points)
	return totals


func _mode_name() -> String:
	match GameSession.game_mode:
		GameSession.GameMode.DAILY:
			return "daily"
		GameSession.GameMode.WEEKLY:
			return "weekly"
		GameSession.GameMode.ENDLESS:
			return "endless"
		GameSession.GameMode.CHALLENGE:
			return "challenge"
		GameSession.GameMode.TUTORIAL:
			return "tutorial"
		GameSession.GameMode.PUZZLE:
			return "puzzle"
		GameSession.GameMode.PUZZLE_MAKER:
			return "puzzle_maker"
		_:
			return "normal"


func _platform_tag() -> String:
	if OS.has_feature("web"):
		if OS.has_feature("web_android") or OS.has_feature("web_ios"):
			return "web_mobile"
		return "web"
	return OS.get_name().to_lower()


func _uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var bytes := PackedByteArray()
	bytes.resize(16)
	for i in 16:
		bytes[i] = rng.randi() & 255
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]


class AnalyticsErrorLog extends Logger:
	var _host: WeakRef

	func _init(host: Node) -> void:
		_host = weakref(host)

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		var host = _host.get_ref()
		if host == null or not host.has_method("_on_engine_error"):
			return
		host._on_engine_error(function, file, line, code, rationale, error_type)
