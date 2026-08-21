class_name WebTextPrompt
extends RefCounted
## Mobile/web LineEdit workaround: Godot canvas cannot open the OS keyboard
## reliably (even with experimental_virtual_keyboard). Shows a real HTML
## <input> overlay via JavaScriptBridge and syncs text back into the LineEdit.

var _js_callback = null
var _target: LineEdit
var _bound: Dictionary = {} # LineEdit -> placeholder label


static func is_needed() -> bool:
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


func setup() -> void:
	if not OS.has_feature("web"):
		return
	_js_callback = JavaScriptBridge.create_callback(_on_js)
	JavaScriptBridge.eval(
		"""
(function() {
	if (window.symbiaTextPrompt) return;
	window.symbiaTextPrompt = {
		_cb: null,
		_restore: null,
		setCallback: function(cb) { this._cb = cb; },
		_isolateFocus: function() {
			var canvas = document.querySelector('canvas');
			var saved = { canvasPe: null, hidden: [] };
			if (canvas) {
				saved.canvasPe = canvas.style.pointerEvents;
				canvas.style.pointerEvents = 'none';
				canvas.blur();
				if (canvas.parentElement) {
					canvas.parentElement.querySelectorAll('input, textarea, [contenteditable="true"]').forEach(function(el) {
						if (el.closest('#symbia-text-prompt')) return;
						saved.hidden.push({ el: el, display: el.style.display, pe: el.style.pointerEvents });
						el.blur();
						el.style.display = 'none';
						el.style.pointerEvents = 'none';
					});
				}
			}
			document.querySelectorAll('input, textarea, [contenteditable="true"]').forEach(function(el) {
				if (el.closest('#symbia-text-prompt')) return;
				for (var i = 0; i < saved.hidden.length; i++) {
					if (saved.hidden[i].el === el) return;
				}
				saved.hidden.push({ el: el, display: el.style.display, pe: el.style.pointerEvents });
				el.blur();
				el.style.display = 'none';
				el.style.pointerEvents = 'none';
			});
			if (document.activeElement && document.activeElement !== document.body) {
				document.activeElement.blur();
			}
			return saved;
		},
		_restoreFocus: function(saved) {
			if (!saved) return;
			var canvas = document.querySelector('canvas');
			if (canvas && saved.canvasPe !== null) {
				canvas.style.pointerEvents = saved.canvasPe;
			}
			saved.hidden.forEach(function(item) {
				item.el.style.display = item.display || '';
				item.el.style.pointerEvents = item.pe || '';
			});
			window.symbiaTextPrompt._suppressGodotInputs();
		},
		_suppressGodotInputs: function() {
			if (document.getElementById('symbia-text-prompt')) return;
			document.querySelectorAll('input, textarea, [contenteditable="true"]').forEach(function(el) {
				if (el.closest('#symbia-text-prompt')) return;
				el.blur();
				el.style.display = 'none';
				el.style.pointerEvents = 'none';
			});
			var canvas = document.querySelector('canvas');
			if (canvas) {
				canvas.style.pointerEvents = '';
				canvas.focus();
			}
		},
		_focusInput: function(input) {
			input.readOnly = true;
			input.focus({ preventScroll: true });
			input.readOnly = false;
			input.focus({ preventScroll: true });
			try {
				var len = input.value.length;
				input.setSelectionRange(len, len);
			} catch (e) {}
			try { input.click(); } catch (e2) {}
			requestAnimationFrame(function() {
				input.focus({ preventScroll: true });
			});
			setTimeout(function() { input.focus({ preventScroll: true }); }, 50);
			setTimeout(function() { input.focus({ preventScroll: true }); }, 150);
		},
		open: function(initial, placeholder, labelText, maxLen) {
			var old = document.getElementById('symbia-text-prompt');
			if (old) old.remove();
			window.symbiaTextPrompt._restore = window.symbiaTextPrompt._isolateFocus();
			var wrap = document.createElement('div');
			wrap.id = 'symbia-text-prompt';
			wrap.style.cssText = 'position:fixed;inset:0;z-index:999999;background:rgba(0,0,0,0.6);display:flex;flex-direction:column;align-items:center;justify-content:flex-start;padding:24px 16px;box-sizing:border-box;font-family:sans-serif;';
			var label = document.createElement('div');
			label.textContent = labelText || placeholder || 'Enter text';
			label.style.cssText = 'color:#fff;font-size:16px;margin-bottom:10px;width:min(560px,100%);';
			var input = document.createElement('input');
			input.type = 'text';
			input.inputMode = 'text';
			input.enterKeyHint = 'done';
			input.value = initial || '';
			input.placeholder = placeholder || '';
			input.autocomplete = 'off';
			input.autocapitalize = 'words';
			input.spellcheck = false;
			if (maxLen && maxLen > 0) input.maxLength = maxLen;
			input.style.cssText = 'width:min(560px,100%);font-size:16px;padding:14px 12px;box-sizing:border-box;border-radius:8px;border:1px solid #ccc;color:#111;background:#fff;';
			var row = document.createElement('div');
			row.style.cssText = 'display:flex;gap:12px;margin-top:12px;';
			var done = document.createElement('button');
			done.textContent = 'Done';
			done.style.cssText = 'padding:10px 20px;font-size:16px;cursor:pointer;';
			var cancel = document.createElement('button');
			cancel.textContent = 'Cancel';
			cancel.style.cssText = 'padding:10px 20px;font-size:16px;cursor:pointer;';
			var finish = function(action) {
				if (window.symbiaTextPrompt._cb) {
					window.symbiaTextPrompt._cb(input.value, action);
				}
				window.symbiaTextPrompt._restoreFocus(window.symbiaTextPrompt._restore);
				window.symbiaTextPrompt._restore = null;
				wrap.remove();
			};
			done.onclick = function() { finish('submit'); };
			cancel.onclick = function() { finish('cancel'); };
			input.addEventListener('keydown', function(e) {
				if (e.key === 'Enter') {
					e.preventDefault();
					finish('submit');
				}
			});
			row.appendChild(done);
			row.appendChild(cancel);
			wrap.appendChild(label);
			wrap.appendChild(input);
			wrap.appendChild(row);
			document.body.appendChild(wrap);
			wrap.addEventListener('touchstart', function(e) {
				if (e.target === input || e.target === done || e.target === cancel) return;
				e.preventDefault();
				window.symbiaTextPrompt._focusInput(input);
			}, { passive: false });
			window.symbiaTextPrompt._focusInput(input);
		},
		close: function() {
			var old = document.getElementById('symbia-text-prompt');
			if (old) old.remove();
			window.symbiaTextPrompt._restoreFocus(window.symbiaTextPrompt._restore);
			window.symbiaTextPrompt._restore = null;
			window.symbiaTextPrompt._suppressGodotInputs();
		}
	};
})();
"""
	)
	var window := JavaScriptBridge.get_interface("window")
	window.symbiaTextPrompt.setCallback(_js_callback)
	window.symbiaTextPrompt._suppressGodotInputs()


func bind_line_edit(line_edit: LineEdit, placeholder: String = "") -> void:
	if not OS.has_feature("web") or line_edit == null:
		return
	if _bound.has(line_edit):
		return
	_bound[line_edit] = placeholder
	line_edit.focus_mode = Control.FOCUS_NONE
	line_edit.virtual_keyboard_enabled = false
	line_edit.gui_input.connect(_on_line_edit_gui_input.bind(line_edit, placeholder))


func open(line_edit: LineEdit, placeholder: String = "") -> void:
	if not OS.has_feature("web") or line_edit == null:
		return
	if _js_callback == null:
		setup()
	line_edit.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	_target = line_edit
	var window := JavaScriptBridge.get_interface("window")
	if window != null and window.symbiaTextPrompt != null:
		window.symbiaTextPrompt.setCallback(_js_callback)
	var ph := placeholder if not placeholder.is_empty() else line_edit.placeholder_text
	var label := ph if not ph.is_empty() else "Enter text"
	window.symbiaTextPrompt.open(line_edit.text, ph, label, line_edit.max_length)


func _on_line_edit_gui_input(event: InputEvent, line_edit: LineEdit, placeholder: String) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return
	open(line_edit, placeholder)
	line_edit.accept_event()


func _on_js(args: Array) -> void:
	_hide_web_keyboard()
	if args.is_empty() or _target == null or not is_instance_valid(_target):
		return
	var text := str(args[0])
	var action := str(args[1]) if args.size() > 1 else "submit"
	if action == "cancel":
		_target = null
		return
	_target.text = text
	_target.caret_column = text.length()
	if action == "submit":
		_target.text_submitted.emit(text)
		_target = null


func _hide_web_keyboard() -> void:
	if not OS.has_feature("web"):
		return
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		DisplayServer.virtual_keyboard_hide()
	var window := JavaScriptBridge.get_interface("window")
	if window != null and window.symbiaTextPrompt != null:
		window.symbiaTextPrompt._suppressGodotInputs()
