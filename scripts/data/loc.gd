class_name Loc
extends RefCounted
## Resolves `{eng, ger}` JSON copy (or a plain string) for the current content locale.

const ENG := "eng"
const GER := "ger"
const DEFAULT_LOCALE := ENG

const CONTINUE := {ENG: "Continue", GER: "Weiter"}
const END := {ENG: "End", GER: "Beenden"}
const PART_COMPLETE := {ENG: "Part complete", GER: "Teil abgeschlossen"}
const PART_BREAK_BODY := {
	ENG: "Continue to the next lesson, or end the tutorial.",
	GER: "Weiter zur nächsten Lektion, oder Tutorial beenden.",
}
const PUZZLE_FALLBACK := {ENG: "Puzzle", GER: "Rätsel"}
const UI_PATH := "res://data/ui_strings.json"

static var _ui: Dictionary = {}


static func normalize_locale(value: String) -> String:
	var raw := value.strip_edges().to_lower()
	if raw.begins_with("de") or raw == GER:
		return GER
	return ENG


static func os_locale() -> String:
	return normalize_locale(OS.get_locale())


static func current_locale() -> String:
	if GameSettings == null:
		return DEFAULT_LOCALE
	return normalize_locale(str(GameSettings.content_locale))


static func text(value, fallback: String = "") -> String:
	return text_for(current_locale(), value, fallback)


static func source_eng(value, fallback: String = "") -> String:
	return text_for(ENG, value, fallback)


static func text_for(locale: String, value, fallback: String = "") -> String:
	var resolved := normalize_locale(locale)
	if typeof(value) == TYPE_DICTIONARY:
		var picked := str(value.get(resolved, "")).strip_edges()
		if picked.is_empty():
			picked = str(value.get(ENG, "")).strip_edges()
		if picked.is_empty():
			picked = fallback
		return picked
	if typeof(value) == TYPE_STRING:
		var as_string := str(value)
		if as_string.is_empty():
			return fallback
		return as_string
	return fallback


static func merge_eng(previous, new_eng: String) -> Dictionary:
	var ger := ""
	if typeof(previous) == TYPE_DICTIONARY:
		ger = str(previous.get(GER, "")).strip_edges()
	if ger.is_empty():
		ger = new_eng
	return {ENG: new_eng, GER: ger}


static func ui(key: String, fallback: String = "") -> String:
	var fb := fallback if not fallback.is_empty() else key
	return text(ui_entry(key), fb)


static func ui_entry(key: String):
	_ensure_ui()
	var current = _ui
	for part in key.split("."):
		if typeof(current) != TYPE_DICTIONARY or not current.has(part):
			return null
		current = current[part]
	return current


static func _ensure_ui() -> void:
	if not _ui.is_empty():
		return
	if not FileAccess.file_exists(UI_PATH):
		push_error("Loc: missing %s" % UI_PATH)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(UI_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Loc: invalid %s" % UI_PATH)
		return
	_ui = parsed
