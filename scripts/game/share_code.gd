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


## Copies text to the system clipboard. On web, uses JavaScriptBridge (with a DOM
## fallback when the itch iframe blocks the Clipboard API). Returns true if copy
## succeeded silently; false if a manual Ctrl+C overlay was left on the page.
static func copy_to_clipboard(text: String) -> bool:
	if OS.has_feature("web"):
		return _copy_to_clipboard_web(text)
	DisplayServer.clipboard_set(text)
	return true


static func _copy_to_clipboard_web(text: String) -> bool:
	var js_text := JSON.stringify(text)
	var code := """
(function(text) {
	var old = document.getElementById('symbia-share-overlay');
	if (old) { old.remove(); }
	var wrap = document.createElement('div');
	wrap.id = 'symbia-share-overlay';
	wrap.style.cssText = 'position:fixed;inset:0;z-index:999999;background:rgba(0,0,0,0.55);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:16px;box-sizing:border-box;font-family:sans-serif;';
	var ta = document.createElement('textarea');
	ta.value = text;
	ta.setAttribute('readonly', '');
	ta.style.cssText = 'width:min(560px,100%%);height:160px;font-size:14px;padding:12px;box-sizing:border-box;resize:none;';
	var hint = document.createElement('div');
	hint.textContent = 'Press Ctrl+C (Cmd+C on Mac) to copy, then Close';
	hint.style.cssText = 'color:#fff;margin:12px 0 8px;font-size:14px;text-align:center;';
	var btn = document.createElement('button');
	btn.textContent = 'Close';
	btn.style.cssText = 'padding:8px 20px;font-size:14px;cursor:pointer;';
	btn.onclick = function() { wrap.remove(); };
	wrap.appendChild(ta);
	wrap.appendChild(hint);
	wrap.appendChild(btn);
	document.body.appendChild(wrap);
	ta.focus();
	ta.select();
	var ok = false;
	try { ok = document.execCommand('copy'); } catch (e) {}
	if (!ok && navigator.clipboard && navigator.clipboard.writeText) {
		try { navigator.clipboard.writeText(text); } catch (e2) {}
	}
	if (ok) {
		wrap.remove();
		return true;
	}
	return false;
})(%s);
""" % js_text
	var result = JavaScriptBridge.eval(code)
	return bool(result)


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
