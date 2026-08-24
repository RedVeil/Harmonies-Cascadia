class_name ShareCode
extends RefCounted

## Local share codes: seed + ring_count + score.
## Format: HC1-<base64url(JSON)>

const PREFIX := "HC1-"
const VERSION := 1
const ITCH_URL := "https://0xveil.itch.io/symbia"

static var _paste_helper: ShareCode
var _paste_cb = null
var _paste_done: Callable


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


## Reads clipboard text. On web, tries the Clipboard API then falls back to a
## DOM textarea overlay (itch iframe often blocks clipboard-read). Calls
## on_done with the pasted string, or not at all if the user cancels.
static func request_clipboard_text(on_done: Callable) -> void:
	if not on_done.is_valid():
		return
	if not OS.has_feature("web"):
		on_done.call(DisplayServer.clipboard_get())
		return
	if _paste_helper == null:
		_paste_helper = ShareCode.new()
	_paste_helper._request_clipboard_web(on_done)


func _request_clipboard_web(on_done: Callable) -> void:
	_paste_done = on_done
	if _paste_cb == null:
		_paste_cb = JavaScriptBridge.create_callback(_on_paste_js)
	JavaScriptBridge.eval(
		"""
(function() {
	if (window.symbiaPastePrompt) return;
	window.symbiaPastePrompt = {
		_cb: null,
		setCallback: function(cb) { this._cb = cb; },
		_finish: function(text, action) {
			if (this._cb) this._cb(String(text || ''), action || 'submit');
			var old = document.getElementById('symbia-paste-overlay');
			if (old) old.remove();
		},
		_showOverlay: function() {
			var self = this;
			var old = document.getElementById('symbia-paste-overlay');
			if (old) old.remove();
			var wrap = document.createElement('div');
			wrap.id = 'symbia-paste-overlay';
			wrap.style.cssText = 'position:fixed;inset:0;z-index:999999;background:rgba(0,0,0,0.55);display:flex;flex-direction:column;align-items:center;justify-content:center;padding:16px;box-sizing:border-box;font-family:sans-serif;';
			var ta = document.createElement('textarea');
			ta.value = '';
			ta.placeholder = 'Paste a share code';
			ta.style.cssText = 'width:min(560px,100%);height:160px;font-size:14px;padding:12px;box-sizing:border-box;resize:none;';
			var hint = document.createElement('div');
			hint.textContent = 'Press Ctrl+V (Cmd+V on Mac) to paste, then Continue';
			hint.style.cssText = 'color:#fff;margin:12px 0 8px;font-size:14px;text-align:center;';
			var row = document.createElement('div');
			row.style.cssText = 'display:flex;gap:12px;';
			var done = document.createElement('button');
			done.textContent = 'Continue';
			done.style.cssText = 'padding:8px 20px;font-size:14px;cursor:pointer;';
			var cancel = document.createElement('button');
			cancel.textContent = 'Cancel';
			cancel.style.cssText = 'padding:8px 20px;font-size:14px;cursor:pointer;';
			done.onclick = function() { self._finish(ta.value, 'submit'); };
			cancel.onclick = function() { self._finish('', 'cancel'); };
			ta.addEventListener('keydown', function(e) {
				if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
					e.preventDefault();
					self._finish(ta.value, 'submit');
				}
			});
			row.appendChild(done);
			row.appendChild(cancel);
			wrap.appendChild(ta);
			wrap.appendChild(hint);
			wrap.appendChild(row);
			document.body.appendChild(wrap);
			ta.focus();
		},
		open: function() {
			var self = this;
			var old = document.getElementById('symbia-paste-overlay');
			if (old) old.remove();
			var show = function() { self._showOverlay(); };
			if (navigator.clipboard && navigator.clipboard.readText) {
				navigator.clipboard.readText().then(function(text) {
					if (text) {
						self._finish(text, 'submit');
					} else {
						show();
					}
				}).catch(function() { show(); });
				return;
			}
			show();
		}
	};
})();
"""
	)
	var window := JavaScriptBridge.get_interface("window")
	if window == null or window.symbiaPastePrompt == null:
		return
	window.symbiaPastePrompt.setCallback(_paste_cb)
	window.symbiaPastePrompt.open()


func _on_paste_js(args: Array) -> void:
	var text := str(args[0]) if not args.is_empty() else ""
	var action := str(args[1]) if args.size() > 1 else "submit"
	var done := _paste_done
	_paste_done = Callable()
	if action == "cancel" or not done.is_valid():
		return
	done.call(text)


## Returns { "ok": bool, "seed": int, "ring_count": int, "score": int, "error": String }
static func decode(code: String) -> Dictionary:
	var raw := extract_code(code)
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


static func extract_code(text: String) -> String:
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
