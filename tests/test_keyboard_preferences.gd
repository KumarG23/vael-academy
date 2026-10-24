extends GutTest
## Issue #89: installation-local additional keys for the six core actions —
## validation against real production consumers, InputMap effect, persistence,
## failure/neighbor preservation and fresh-process restore.

const SIX := ["cursor_up", "cursor_down", "cursor_left", "cursor_right", "cursor_confirm", "cursor_cancel"]

var _original_path := ""
var _prefs_path := ""
var _xdg := ""
var _shipped := {}


func before_each() -> void:
	_original_path = KeyboardPreferences.prefs_path
	_prefs_path = "user://test_keyboard_preferences_%d.cfg" % Time.get_ticks_usec()
	KeyboardPreferences.prefs_path = _prefs_path
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	KeyboardPreferences.last_write_error = OK
	_shipped = _event_texts()
	_xdg = ProjectSettings.globalize_path("user://test_keyboard_prefs_xdg_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_xdg)


func after_each() -> void:
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	KeyboardPreferences.last_write_error = OK
	KeyboardPreferences.prefs_path = _original_path
	assert_eq(_event_texts(), _shipped, "every action is back to its shipped bindings")
	for suffix in ["", ".tmp"]:
		var path := ProjectSettings.globalize_path(_prefs_path + suffix)
		if DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_remove_tree(_xdg)


func _key(code: Key, shift := false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	return ev


func _event_texts() -> Dictionary:
	var out := {}
	for action in SIX + KeyboardPreferences.ALIASES.values():
		var names: Array = []
		for ev in InputMap.action_get_events(action):
			names.append(ev.as_text())
		out[action] = names
	return out


func test_assign_adds_one_key_to_action_and_alias_keeping_every_shipped_key() -> void:
	assert_eq(KeyboardPreferences.assign("cursor_confirm", _key(KEY_O)), "")
	var o := _key(KEY_O)
	assert_true(InputMap.event_is_action(o, "cursor_confirm", true), "core action accepts the extra key")
	assert_true(InputMap.event_is_action(o, "ui_accept", true), "castle/GUI alias accepts it too")
	for other in SIX:
		if other != "cursor_confirm":
			assert_false(InputMap.event_is_action(o, other, true), "%s unaffected" % other)
	for shipped in [KEY_ENTER, KEY_SPACE]:
		assert_true(InputMap.event_is_action(_key(shipped), "cursor_confirm", true), "shipped confirm still bound")
	assert_eq(KeyboardPreferences.extra_action(o), "cursor_confirm")
	assert_eq(KeyboardPreferences.extra_action(_key(KEY_ENTER)), "", "shipped keys are not reported as extras")
	assert_eq(KeyboardPreferences.extra_action(_key(KEY_O, true)), "", "Shift+O is not the bare extra key")
	# Re-assigning replaces the old extra; it never accumulates.
	assert_eq(KeyboardPreferences.assign("cursor_confirm", _key(KEY_U)), "")
	assert_false(InputMap.event_is_action(o, "cursor_confirm", true), "previous extra removed")
	assert_eq(InputMap.action_get_events("cursor_confirm").size(), _shipped["cursor_confirm"].size() + 1)
	assert_eq(KeyboardPreferences.default_label("cursor_confirm"), "Enter / Space")
	assert_eq(KeyboardPreferences.default_label("cursor_cancel"), "Esc / Backspace")
	assert_eq(KeyboardPreferences.extra_label("cursor_confirm"), "U")
	assert_eq(KeyboardPreferences.extra_label("cursor_up"), "none")


func test_rejects_shipped_fixed_modifier_chord_pointer_and_duplicate_keys_without_change() -> void:
	assert_eq(KeyboardPreferences.assign("cursor_cancel", _key(KEY_P)), "")
	var before := _event_texts()
	var cases := [
		[_key(KEY_W), "default Up"], [_key(KEY_D), "default Right"], [_key(KEY_ENTER), "default Confirm"],
		[_key(KEY_SPACE), "default Confirm"], [_key(KEY_ESCAPE), "default Cancel"],
		[_key(KEY_BACKSPACE), "default Cancel"], [_key(KEY_LEFT), "default Left"],
		[_key(KEY_KP_ENTER), "default Confirm"], [_key(KEY_TAB), "End Turn"],
		[_key(KEY_HOME), "built-in menu controls"], [_key(KEY_PAGEUP), "unit cycling"],
		[_key(KEY_J), "Academy Journal"], [_key(KEY_M), "academy map"], [_key(KEY_T), "End Turn"],
		[_key(KEY_H), "danger zones"], [_key(KEY_QUOTELEFT), "room editor"], [_key(KEY_R), "house preview"],
		[_key(KEY_1), "Dev Jump"], [_key(KEY_P), "additional Cancel key"],
		[_key(KEY_SHIFT), "can't be assigned on its own"], [_key(KEY_CTRL), "can't be assigned on its own"],
		[_key(KEY_CAPSLOCK), "can't be assigned on its own"], [_key(KEY_G, true), "without Shift"],
	]
	for c in cases:
		var why := KeyboardPreferences.assign("cursor_up", c[0])
		assert_string_contains(why, c[1], "%s rejected with an understandable reason" % (c[0] as InputEventKey).as_text())
	var chord := _key(KEY_G)
	chord.ctrl_pressed = true
	assert_string_contains(KeyboardPreferences.assign("cursor_up", chord), "without Shift, Ctrl")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_string_contains(KeyboardPreferences.assign("cursor_up", click), "Only keyboard keys")
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	assert_string_contains(KeyboardPreferences.assign("cursor_up", pad), "Only keyboard keys")
	assert_eq(_event_texts(), before, "every failed assignment leaves all bindings intact")
	assert_eq(KeyboardPreferences.extra_key("cursor_up"), KEY_NONE)
	assert_eq(KeyboardPreferences.assign("cursor_cancel", _key(KEY_P)), "", "re-choosing its own key is fine")
	assert_eq(KeyboardPreferences.assign("cursor_up", _key(KEY_G)), "", "a later ordinary retry succeeds")


## Derive, don't guess: every KEY_* constant production code compares against
## must be unassignable, so a new hard-coded shortcut can't silently collide.
func test_every_key_read_directly_by_production_code_is_reserved() -> void:
	var tokens := {}
	for path in _gd_files("res://src"):
		if path.ends_with("keyboard_preferences.gd"):
			continue
		var re := RegEx.create_from_string("\\bKEY_[A-Z0-9_]+\\b")
		for m in re.search_all(FileAccess.get_file_as_string(path)):
			tokens[m.get_string()] = path
	assert_gt(tokens.size(), 30, "scan found the production shortcuts")
	# Settings-name constants that merely start with KEY_ (not Key values).
	for not_a_key in ["KEY_TEXT_SPEED"]:
		tokens.erase(not_a_key)
	var names: Array = tokens.keys().filter(func(t: String) -> bool:
		return not (t.begins_with("KEY_MASK") or t.begins_with("KEY_MODIFIER") or t == "KEY_NONE"))
	var entries: PackedStringArray = []
	for token: String in names:
		entries.append('"%s": %s' % [token, token])
	var script := GDScript.new()
	script.source_code = "extends RefCounted\nfunc keys() -> Dictionary:\n\treturn {%s}\n" % ", ".join(entries)
	assert_eq(script.reload(), OK, "every scanned token is a Key constant (add settings names above)")
	var codes: Dictionary = script.new().keys()
	for token: String in codes:
		var why := KeyboardPreferences.rejection("cursor_up", _key(codes[token]))
		assert_ne(why, "", "%s (read by %s) cannot become an additional key" % [token, tokens[token]])
	assert_gt(codes.size(), 30, "the scanned keys were actually checked")


func test_clear_and_restore_defaults_affect_only_this_feature() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", 0.4)
	cfg.set_value("dialogue", "text_speed", "fast")
	cfg.set_value("other", "keep", [1, "two"])
	assert_eq(cfg.save(_prefs_path), OK)
	assert_eq(KeyboardPreferences.assign("cursor_up", _key(KEY_I)), "")
	assert_eq(KeyboardPreferences.assign("cursor_cancel", _key(KEY_P)), "")
	assert_eq(KeyboardPreferences.clear("cursor_up"), OK)
	assert_eq(KeyboardPreferences.extra_key("cursor_up"), KEY_NONE)
	assert_eq(KeyboardPreferences.extra_key("cursor_cancel"), KEY_P, "clearing one leaves the other")
	assert_true(InputMap.event_is_action(_key(KEY_W), "cursor_up", true), "shipped Up survives clear")
	var mid := ConfigFile.new()
	assert_eq(mid.load(_prefs_path), OK)
	assert_false(mid.has_section_key("keyboard", "up"))
	assert_eq(mid.get_value("keyboard", "cancel"), "P")
	assert_eq(KeyboardPreferences.restore_defaults(), OK)
	assert_eq(_event_texts(), _shipped, "Restore Defaults leaves exactly the shipped bindings")
	var after := ConfigFile.new()
	assert_eq(after.load(_prefs_path), OK)
	assert_false(after.has_section("keyboard"), "no custom bindings persisted")
	assert_eq(after.get_value("audio", "music_volume"), 0.4)
	assert_eq(after.get_value("dialogue", "text_speed"), "fast")
	assert_eq(after.get_value("other", "keep"), [1, "two"])


func test_round_trip_restores_every_action_and_keeps_neighbors() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", 0.6)
	cfg.set_value("dialogue", "text_speed", "instant")
	assert_eq(cfg.save(_prefs_path), OK)
	var picks := {"cursor_up": KEY_I, "cursor_down": KEY_N, "cursor_left": KEY_G,
		"cursor_right": KEY_L, "cursor_confirm": KEY_O, "cursor_cancel": KEY_P}
	for action in picks:
		assert_eq(KeyboardPreferences.assign(action, _key(picks[action])), "")
	var live := _event_texts()
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	assert_eq(KeyboardPreferences.load_preferences(), OK)
	assert_eq(_event_texts(), live, "reload restores the same six extras")
	var saved := ConfigFile.new()
	assert_eq(saved.load(_prefs_path), OK)
	assert_eq(saved.get_value("keyboard", "right"), "L", "readable key names")
	assert_eq(saved.get_value("audio", "master_volume"), 0.6)
	assert_eq(saved.get_value("dialogue", "text_speed"), "instant")
	# A second load is idempotent: no duplicated InputMap events.
	assert_eq(KeyboardPreferences.load_preferences(), OK)
	assert_eq(_event_texts(), live)


func test_missing_malformed_invalid_and_conflicting_values_mean_no_extra_key() -> void:
	assert_eq(KeyboardPreferences.load_preferences(), ERR_FILE_NOT_FOUND)
	assert_eq(_event_texts(), _shipped, "missing file: defaults only")
	var cfg := ConfigFile.new()
	cfg.set_value("keyboard", "up", 73)            # wrong type
	cfg.set_value("keyboard", "down", "Ctrl+N")    # chord
	cfg.set_value("keyboard", "left", "Bogus")     # unknown name
	cfg.set_value("keyboard", "right", "J")        # Journal shortcut
	cfg.set_value("keyboard", "confirm", "Escape") # would make Esc confirm
	cfg.set_value("keyboard", "cancel", "Enter")   # would make Enter cancel
	cfg.set_value("keyboard", "unknown", "Z")
	assert_eq(cfg.save(_prefs_path), OK)
	var bytes := FileAccess.get_file_as_bytes(_prefs_path)
	assert_eq(KeyboardPreferences.load_preferences(), OK)
	assert_eq(_event_texts(), _shipped, "no invalid or conflicting value is activated")
	for action in SIX:
		assert_eq(KeyboardPreferences.extra_key(action), KEY_NONE)
	cfg = ConfigFile.new()
	cfg.set_value("keyboard", "up", "Z")
	cfg.set_value("keyboard", "down", "Z")         # shared between two actions
	cfg.set_value("keyboard", "confirm", "O")
	assert_eq(cfg.save(_prefs_path), OK)
	assert_eq(KeyboardPreferences.load_preferences(), OK)
	assert_eq(KeyboardPreferences.extra_key("cursor_up"), KEY_NONE, "a shared key activates neither action")
	assert_eq(KeyboardPreferences.extra_key("cursor_down"), KEY_NONE)
	assert_eq(KeyboardPreferences.extra_key("cursor_confirm"), KEY_O, "valid neighbor still loads")
	var malformed := "[keyboard\nup = = \"I\""
	var file := FileAccess.open(_prefs_path, FileAccess.WRITE)
	file.store_string(malformed)
	file.close()
	assert_ne(KeyboardPreferences.load_preferences(), OK, "malformed config is reported")
	assert_engine_error("Unexpected EOF while parsing simple tag", "malformed ConfigFile parse error is expected")
	assert_eq(_event_texts(), _shipped, "malformed file: defaults only")
	assert_eq(FileAccess.get_file_as_string(_prefs_path), malformed, "reading never rewrites")
	assert_ne(bytes.size(), 0)


func test_failed_write_keeps_live_binding_and_prior_bytes_then_retry_succeeds() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_volume", 0.55)
	cfg.set_value("keyboard", "cancel", "P")
	assert_eq(cfg.save(_prefs_path), OK)
	KeyboardPreferences.load_preferences()
	var original := FileAccess.get_file_as_bytes(_prefs_path)
	var blocker := ProjectSettings.globalize_path(_prefs_path + ".tmp")
	assert_eq(DirAccess.make_dir_absolute(blocker), OK, "directory blocks the temporary file deterministically")
	assert_eq(KeyboardPreferences.assign("cursor_up", _key(KEY_I)), "", "the key itself is valid")
	assert_ne(KeyboardPreferences.last_write_error, OK, "failed write is reported")
	assert_true(InputMap.event_is_action(_key(KEY_I), "cursor_up", true), "binding works for this session")
	assert_eq(FileAccess.get_file_as_bytes(_prefs_path), original, "prior settings bytes intact")
	assert_ne(KeyboardPreferences.restore_defaults(), OK, "restore also reports the failed write")
	assert_eq(FileAccess.get_file_as_bytes(_prefs_path), original)
	assert_eq(DirAccess.remove_absolute(blocker), OK, "remove the blocker")
	assert_eq(KeyboardPreferences.assign("cursor_up", _key(KEY_I)), "")
	assert_eq(KeyboardPreferences.last_write_error, OK, "ordinary retry succeeds")
	var after := ConfigFile.new()
	assert_eq(after.load(_prefs_path), OK)
	assert_eq(after.get_value("keyboard", "up"), "I")
	assert_false(after.has_section_key("keyboard", "cancel"), "restore (live) was persisted by the retry")
	assert_eq(after.get_value("audio", "sfx_volume"), 0.55)


func test_unreadable_settings_are_reported_not_overwritten() -> void:
	var malformed := "[audio\nmaster_volume = ="
	var file := FileAccess.open(_prefs_path, FileAccess.WRITE)
	file.store_string(malformed)
	file.close()
	assert_eq(KeyboardPreferences.assign("cursor_left", _key(KEY_G)), "")
	assert_engine_error("Unexpected EOF while parsing simple tag", "unreadable file is detected")
	assert_ne(KeyboardPreferences.last_write_error, OK, "save refused truthfully")
	assert_eq(FileAccess.get_file_as_string(_prefs_path), malformed, "unreadable bytes are not replaced")
	assert_true(InputMap.event_is_action(_key(KEY_G), "cursor_left", true), "binding is live this session")


func test_new_game_and_slot_load_keep_preferences_out_of_campaign() -> void:
	assert_eq(KeyboardPreferences.assign("cursor_confirm", _key(KEY_O)), "")
	var saves := SaveSystem.new("user://test_keyboard_campaign_%d" % Time.get_ticks_usec())
	assert_true(Campaign.save_to_slot(0, saves))
	var text := FileAccess.get_file_as_string(saves.slot_path(0))
	assert_false(text.contains("keyboard") or text.contains("cursor_confirm"), "not part of the campaign schema")
	Campaign.reset_new_game(false)
	assert_eq(KeyboardPreferences.extra_key("cursor_confirm"), KEY_O, "New Game leaves keys alone")
	assert_true(Campaign.load_from_slot(0, saves))
	assert_eq(KeyboardPreferences.extra_key("cursor_confirm"), KEY_O, "loading a slot leaves keys alone")
	Campaign.reset_new_game(false)
	DirAccess.remove_absolute(saves.slot_path(0))
	DirAccess.remove_absolute(saves.save_dir)


func test_fresh_process_restores_keys_before_first_input_and_keeps_neighbors() -> void:
	if OS.get_name() != "Linux":
		pending("fresh-process user:// isolation needs Linux XDG_DATA_HOME")
		return
	var child_dir := _xdg.path_join("godot/app_userdata").path_join(str(ProjectSettings.get_setting("application/config/name")))
	DirAccess.make_dir_recursive_absolute(child_dir)
	var initial := ConfigFile.new()
	initial.set_value("audio", "master_volume", 0.6)
	initial.set_value("dialogue", "text_speed", "fast")
	assert_eq(initial.save(child_dir.path_join("settings.cfg")), OK)
	var configured := _launch_child("configure")
	assert_eq(configured.get("assigned"), "O", "real Journal editor input assigned the key")
	assert_eq(configured.get("journal_open"), true, "the Journal stayed open")
	var fresh := _launch_child("startup")
	assert_eq(fresh.get("user_dir"), child_dir, "child uses disposable user data")
	assert_true(fresh.get("confirm_ready", false), "extra Confirm is bound before the first frame")
	assert_true(fresh.get("accept_ready", false), "and on the castle/GUI alias")
	assert_true(fresh.get("enter_still_confirms", false), "shipped Enter still confirms")
	assert_eq(fresh.get("audio_master"), 0.6, "audio settings preserved")
	assert_eq(fresh.get("text_speed"), "fast", "dialogue settings preserved")
	assert_true(fresh.get("menu_confirmed", false), "the first real key press drives a ChoiceMenu")
	var restored := _launch_child("restore")
	assert_eq(restored.get("extra"), "none", "Restore Defaults via the editor removes it")
	var after := _launch_child("startup")
	assert_false(after.get("confirm_ready", true), "and it stays removed in the next process")
	assert_eq(after.get("audio_master"), 0.6)


func _launch_child(mode: String) -> Dictionary:
	var output: Array = []
	var code := OS.execute("env", PackedStringArray([
		"XDG_DATA_HOME=" + _xdg, OS.get_executable_path(), "--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"res://tests/fixtures/keyboard_prefs_probe.tscn", "--", mode,
	]), output, true)
	assert_eq(code, 0, "%s child exits cleanly: %s" % [mode, output])
	for line in "\n".join(PackedStringArray(output)).split("\n"):
		if line.begins_with("KEYBOARD_PREFS_PROBE "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("KEYBOARD_PREFS_PROBE "))
			if parsed is Dictionary:
				return parsed
	fail_test("missing %s child report: %s" % [mode, output])
	return {}


func _gd_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_gd_files(dir_path.path_join(sub)))
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	return out


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)
