class_name ShareCode
extends RefCounted

## Local share codes: seed + ring_count + score.
## Format: HC1-<base64url(JSON)>

const PREFIX := "HC1-"
const VERSION := 1
const ITCH_URL := "https://0xveil.itch.io/symbia"


static func encode(seed: int, ring_count: int, score: int) -> String:
	var payload := {
		"v": VERSION,
		"s": seed,
		"r": ring_count,
		"c": score,
	}
	var json := JSON.stringify(payload)
	var b64 := Marshalls.raw_to_base64(json.to_utf8_buffer())
	b64 = b64.replace("+", "-").replace("/", "_").rstrip("=")
	return PREFIX + b64


static func clipboard_message(seed: int, ring_count: int, score: int) -> String:
	var code := encode(seed, ring_count, score)
	return "I got %d in Symbia — can you beat it?\nPlay it here: %s and just enter my code: %s." % [score, ITCH_URL, code]


## Returns { "ok": bool, "seed": int, "ring_count": int, "score": int, "error": String }
static func decode(code: String) -> Dictionary:
	var raw := _extract_code(code)
	if raw.is_empty():
		return _fail("Enter a share code.")
	if not raw.begins_with(PREFIX):
		return _fail("Unrecognized code.")
	var b64 := raw.substr(PREFIX.length())
	b64 = b64.replace("-", "+").replace("_", "/")
	while b64.length() % 4 != 0:
		b64 += "="
	var bytes := Marshalls.base64_to_raw(b64)
	if bytes.is_empty():
		return _fail("Invalid code.")
	var parsed = JSON.parse_string(bytes.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return _fail("Invalid code.")
	var data: Dictionary = parsed
	if int(data.get("v", 0)) != VERSION:
		return _fail("Unsupported code version.")
	if not data.has("s") or not data.has("r") or not data.has("c"):
		return _fail("Incomplete code.")
	var seed := int(data["s"])
	var ring_count := int(data["r"])
	var score := int(data["c"])
	if ring_count < 0 or ring_count > 32:
		return _fail("Invalid map size in code.")
	if score < 0:
		return _fail("Invalid score in code.")
	return {
		"ok": true,
		"seed": seed,
		"ring_count": ring_count,
		"score": score,
		"error": "",
	}


static func _extract_code(text: String) -> String:
	var raw := text.strip_edges()
	if raw.is_empty():
		return ""
	var start := raw.find(PREFIX)
	if start < 0:
		return raw
	var token := ""
	for i in range(start, raw.length()):
		var ch := raw[i]
		if not _is_code_char(ch):
			break
		token += ch
	return token


static func _is_code_char(ch: String) -> bool:
	return ch.length() == 1 and ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"


static func _fail(message: String) -> Dictionary:
	return {
		"ok": false,
		"seed": 0,
		"ring_count": 0,
		"score": 0,
		"error": message,
	}
