extends Node
## Issue #89 (WO-9.6 keybinds, partial): one optional player-chosen ADDITIONAL
## key for each of the six core actions. Shipped keys always stay bound — this
## only adds an InputMap event to the existing action and its matching built-in
## ui_* alias, so every existing consumer, gate and consumption rule keeps
## working unchanged. Installation-local, beside (never inside) campaign saves.

const PREFS_PATH := "user://settings.cfg"
const SECTION := "keyboard"
const ACTIONS := ["cursor_up", "cursor_down", "cursor_left", "cursor_right", "cursor_confirm", "cursor_cancel"]
const LABELS := {
	"cursor_up": "Up", "cursor_down": "Down", "cursor_left": "Left",
	"cursor_right": "Right", "cursor_confirm": "Confirm", "cursor_cancel": "Cancel",
}
## Settings keys, so the file reads `up = "P"` rather than an action name.
const SETTING_KEYS := {
	"cursor_up": "up", "cursor_down": "down", "cursor_left": "left",
	"cursor_right": "right", "cursor_confirm": "confirm", "cursor_cancel": "cancel",
}
## Castle walking/interaction and GUI focus read Godot's built-in ui_* actions;
## the extra key joins the alias that already means the same thing.
const ALIASES := {
	"cursor_up": "ui_up", "cursor_down": "ui_down", "cursor_left": "ui_left",
	"cursor_right": "ui_right", "cursor_confirm": "ui_accept", "cursor_cancel": "ui_cancel",
}
## Keys that production code reads directly by keycode (not through an action).
## tests/test_keyboard_preferences.gd scans src/ for KEY_* constants, so a new
## hard-coded shortcut cannot be added without reserving it here.
const FIXED_SHORTCUTS := [
	[KEY_J, "the Academy Journal"],                      # castle_scene, academy_journal
	[KEY_M, "the academy map"],                          # castle_scene
	[KEY_QUOTELEFT, "the room editor"],                  # castle_scene (AW-44 debug)
	[KEY_ESCAPE, "Cancel / close"],                      # castle map, editor, pilots
	[KEY_ENTER, "Confirm"],                              # dialogue, castle map
	[KEY_KP_ENTER, "Confirm"],                           # dialogue, castle map
	[KEY_SPACE, "Confirm / hold to fast-forward"],       # dialogue, map, exchange speed
	[KEY_UP, "Up"], [KEY_DOWN, "Down"],                  # dialogue, map, campus editor
	[KEY_LEFT, "Left"], [KEY_RIGHT, "Right"],            # campus editor
	[KEY_W, "Up"], [KEY_S, "Down / editor save"],        # dialogue choices, campus editor
	[KEY_TAB, "End Turn / map destinations"],            # battle_view, castle map, editor
	[KEY_T, "End Turn"],                                 # battle_view
	[KEY_H, "danger zones"],                             # battle_view, campus editor
	[KEY_PAGEUP, "unit cycling / page scroll"],          # battle_view, house choice
	[KEY_PAGEDOWN, "unit cycling / page scroll"],        # battle_view, house choice
	[KEY_R, "house preview"],                            # house choice, pilots
	[KEY_BRACKETLEFT, "the room editor"], [KEY_BRACKETRIGHT, "the room editor"],
	[KEY_DELETE, "the room editor"], [KEY_BACKSPACE, "Cancel / the room editor"],
	[KEY_X, "the room editor"], [KEY_F, "the room editor"],
	[KEY_EQUAL, "the room editor"], [KEY_KP_ADD, "the room editor"],
	[KEY_MINUS, "the room editor"], [KEY_KP_SUBTRACT, "the room editor"],
	# Dev Jump pilots (title → Dev Jump), debug-only but still reachable.
	[KEY_1, "a Dev Jump pilot"], [KEY_2, "a Dev Jump pilot"], [KEY_3, "a Dev Jump pilot"],
	[KEY_4, "a Dev Jump pilot"], [KEY_5, "a Dev Jump pilot"], [KEY_6, "a Dev Jump pilot"],
	[KEY_Q, "a Dev Jump pilot"], [KEY_E, "a Dev Jump pilot"], [KEY_C, "a Dev Jump pilot"],
	[KEY_K, "a Dev Jump pilot"], [KEY_A, "Left / a Dev Jump pilot"], [KEY_B, "a Dev Jump pilot"],
]
## Never assignable on their own, whether or not anything reads them.
const UNSUPPORTED := [
	KEY_NONE, KEY_UNKNOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_HYPER,
	KEY_CAPSLOCK, KEY_NUMLOCK, KEY_SCROLLLOCK, KEY_PRINT, KEY_SYSREQ,
]

var prefs_path := PREFS_PATH  # tests point this at disposable data
var last_write_error: Error = OK
var _extras := {}    # action -> Key, only for actions with an additional key
var _applied := {}   # action -> [action event, alias event] currently in InputMap
var _defaults := {}  # every InputMap action -> its shipped events (startup snapshot)


func _ready() -> void:
	# Autoloads are ready before the main scene, so the first input of a fresh
	# process already sees restored keys. Snapshot shipped bindings first.
	_snapshot_defaults()
	load_preferences()


func _exit_tree() -> void:
	_unapply()


func _snapshot_defaults() -> void:
	_defaults.clear()
	for action: StringName in InputMap.get_actions():
		var events: Array = []
		for ev in InputMap.action_get_events(action):
			events.append(ev.duplicate())
		_defaults[String(action)] = events


## The current additional key for `action`, or KEY_NONE.
func extra_key(action: String) -> Key:
	return _extras.get(action, KEY_NONE)


func extra_label(action: String) -> String:
	var key := extra_key(action)
	return "none" if key == KEY_NONE else key_name(key)


## Shipped keys for one of the six actions, for display ("↑ / W").
func default_label(action: String) -> String:
	var names: PackedStringArray = []
	for ev in _defaults.get(action, []):
		if ev is InputEventKey:
			var key: Key = ev.keycode if ev.keycode != KEY_NONE else ev.physical_keycode
			names.append(key_name(key))
	return " / ".join(names)


static func key_name(key: Key) -> String:
	match key:
		KEY_UP: return "↑"
		KEY_DOWN: return "↓"
		KEY_LEFT: return "←"
		KEY_RIGHT: return "→"
		KEY_ESCAPE: return "Esc"
		KEY_ENTER: return "Enter"
	return OS.get_keycode_string(key)


## Which of the six actions this event's ADDITIONAL key belongs to, or "".
## Consumers that read hard-coded keys use this so the extra key reaches the
## same branch without altering what the shipped keys do there.
func extra_action(event: InputEvent) -> String:
	if not (event is InputEventKey):
		return ""
	for action: String in _applied:
		if (_applied[action][0] as InputEventKey).is_match(event, true):
			return action
	return ""


## Why `event` can't become `action`'s additional key ("" = acceptable).
## Echo/release events are the caller's to ignore before asking.
func rejection(action: String, event: InputEvent) -> String:
	if not (event is InputEventKey):
		return "Only keyboard keys can be assigned. Press a key."
	var key := _event_key(event)
	if key in UNSUPPORTED or key & KEY_MODIFIER_MASK:
		return "That key can't be assigned on its own. Try another key."
	if event.shift_pressed or event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return "Use a single key without Shift, Ctrl, Alt or Meta."
	if OS.find_keycode_from_string(OS.get_keycode_string(key)) != key:
		return "That key isn't supported. Try another key."
	return _conflict(action, key, event)


func _conflict(action: String, key: Key, event: InputEvent = null) -> String:
	var shown := key_name(key)
	for other: String in ACTIONS:
		if other != action and _extras.get(other, KEY_NONE) == key:
			return "%s is already the additional %s key." % [shown, LABELS[other]]
	var probe := event
	if probe == null:
		probe = InputEventKey.new()
		probe.keycode = key
	# The six actions and their aliases first, so feedback names the shipped
	# meaning ("default Cancel") rather than a generic built-in action.
	var core: Array = ACTIONS + ALIASES.values()
	var builtin: Array = _defaults.keys().filter(func(a: String) -> bool: return a not in core)
	for holder: String in core + ["fixed"] + builtin:
		if holder == "fixed":
			for entry in FIXED_SHORTCUTS:
				if entry[0] == key:
					return "%s is already used for %s." % [shown, entry[1]]
			continue
		for ev in _defaults.get(holder, []):
			if not (ev is InputEventKey):
				continue
			# Match the way InputMap would, and also the bare key value either
			# way round, so a layout difference can't sneak past a shipped key.
			if ev.is_match(probe, true) or key in [ev.keycode, ev.physical_keycode]:
				if ev.ctrl_pressed or ev.alt_pressed or ev.shift_pressed or ev.meta_pressed:
					continue  # a chord (Ctrl+C) doesn't claim the bare key
				return "%s is already used for %s." % [shown, _owner_label(holder)]
	return ""


func _owner_label(action: String) -> String:
	if LABELS.has(action):
		return "default %s" % LABELS[action]
	for core: String in ALIASES:
		if ALIASES[core] == action:
			return "default %s" % LABELS[core]
	return "built-in menu controls"


static func _event_key(event: InputEventKey) -> Key:
	if event.keycode != KEY_NONE:
		return event.keycode
	if event.physical_keycode != KEY_NONE:
		return DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	return KEY_NONE


## Validate and apply `event` as `action`'s additional key. On rejection nothing
## changes. On success the binding is live before IO; a failed write keeps it
## for this session and leaves `last_write_error` for truthful feedback.
## Returns "" on success, otherwise the rejection message.
func assign(action: String, event: InputEvent) -> String:
	if action not in ACTIONS:
		return "Unknown action."
	var why := rejection(action, event)
	if why != "":
		return why
	_unapply()
	_extras[action] = _event_key(event)
	_apply()
	last_write_error = save_preferences()
	return ""


func clear(action: String) -> Error:
	_unapply()
	_extras.erase(action)
	_apply()
	last_write_error = save_preferences()
	return last_write_error


## Restore Defaults: drop every additional key; shipped keys were never touched.
func restore_defaults() -> Error:
	_unapply()
	_extras.clear()
	_apply()
	last_write_error = save_preferences()
	return last_write_error


## Missing/unreadable/invalid values mean "no additional key". A persisted key
## that conflicts with a shipped/fixed key, or that two actions share, is not
## activated. Reading never writes.
func load_preferences() -> Error:
	_unapply()
	_extras.clear()
	if not FileAccess.file_exists(prefs_path):
		return ERR_FILE_NOT_FOUND
	var cfg := ConfigFile.new()
	var err := cfg.load(prefs_path)
	if err != OK:
		push_warning("Keyboard preferences unreadable (%s): %s — using default keys only" % [error_string(err), prefs_path])
		return err
	var wanted := {}
	for action: String in ACTIONS:
		if not cfg.has_section_key(SECTION, SETTING_KEYS[action]):
			continue
		var value: Variant = cfg.get_value(SECTION, SETTING_KEYS[action])
		var key := OS.find_keycode_from_string(value) if value is String else KEY_NONE
		var probe := InputEventKey.new()
		probe.keycode = key
		if key == KEY_NONE or OS.get_keycode_string(key) != value or rejection(action, probe) != "":
			push_warning("Keyboard preference %s=%s is not a usable key — ignored" % [SETTING_KEYS[action], var_to_str(value)])
			continue
		wanted[action] = key
	for action: String in wanted:
		var shared := false
		for other: String in wanted:
			shared = shared or (other != action and wanted[other] == wanted[action])
		if shared:
			push_warning("Keyboard preference %s shares its key with another action — ignored" % SETTING_KEYS[action])
		else:
			_extras[action] = wanted[action]
	_apply()
	return OK


## Rewrites only the [keyboard] section of a readable file (other sections are
## kept byte-for-byte in meaning); an unreadable file is left alone and reported.
## Temp-write + rename so a failed write never truncates the player's settings.
func save_preferences() -> Error:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(prefs_path):
		var read_err := cfg.load(prefs_path)
		if read_err != OK:
			push_warning("Keyboard preferences not saved because settings are unreadable (%s): %s" % [error_string(read_err), prefs_path])
			return read_err
	if cfg.has_section(SECTION):
		cfg.erase_section(SECTION)
	for action: String in ACTIONS:
		if _extras.has(action):
			cfg.set_value(SECTION, SETTING_KEYS[action], OS.get_keycode_string(_extras[action]))
	var tmp := prefs_path + ".tmp"
	var err := cfg.save(tmp)
	if err == OK:
		err = DirAccess.rename_absolute(tmp, prefs_path)
	if err != OK:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		push_warning("Keyboard preferences not saved (%s): %s" % [error_string(err), prefs_path])
	return err


func _apply() -> void:
	for action: String in _extras:
		var pair: Array = []
		for target: String in [action, ALIASES[action]]:
			var ev := InputEventKey.new()
			ev.keycode = _extras[action]
			InputMap.action_add_event(target, ev)
			pair.append(ev)
		_applied[action] = pair


func _unapply() -> void:
	for action: String in _applied:
		var pair: Array = _applied[action]
		InputMap.action_erase_event(action, pair[0])
		InputMap.action_erase_event(ALIASES[action], pair[1])
	_applied.clear()
