extends Control
## Issue #89 fresh-process probe. "configure"/"restore" drive the real Journal →
## System → Keyboard Controls editor with key events; "startup" reports what a
## new process has bound before its first frame, then feeds one real key press.


func _ready() -> void:
	# Before any frame: autoloads are ready, so record the startup bindings now.
	var o := _key(KEY_O)
	var report := {
		"user_dir": OS.get_user_data_dir(),
		"confirm_ready": InputMap.event_is_action(o, "cursor_confirm", true),
		"accept_ready": InputMap.event_is_action(o, "ui_accept", true),
		"enter_still_confirms": InputMap.event_is_action(_key(KEY_ENTER), "cursor_confirm", true),
	}
	_run.call_deferred(report)


func _run(report: Dictionary) -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[0]) if not args.is_empty() else "startup"
	var root := get_tree().root
	var prefs: Node = root.get_node("KeyboardPreferences")
	report["mode"] = mode
	report["audio_master"] = root.get_node("AudioManager").master_volume
	report["text_speed"] = root.get_node("DialoguePreferences").text_speed
	if mode == "startup":
		var menu := ChoiceMenu.new()
		root.add_child(menu)
		menu.open("Probe", ["Only"], Vector2(40, 40))
		var chosen := [-1]
		menu.chosen.connect(func(i: int) -> void: chosen[0] = i)
		await get_tree().process_frame
		_tap(KEY_O)
		report["menu_confirmed"] = chosen[0] == 0
	else:
		var journal: AcademyJournal = load("res://src/ui/academy_journal.gd").new()
		journal._save = SaveSystem.new("user://keyboard_prefs_probe_saves")
		root.add_child(journal)
		await get_tree().process_frame
		for i in range(4):
			_tap(KEY_RIGHT)    # Roster → System
		_tap(KEY_UP)           # wraps to the last System row: Keyboard Controls
		_tap(KEY_ENTER)
		var steps := 4 if mode == "configure" else 6  # Confirm row / Restore Defaults
		for i in range(steps):
			_tap(KEY_DOWN)
		_tap(KEY_ENTER)
		if mode == "configure":
			_tap(KEY_O)
		report["editor_open"] = journal._keys_editor != null
		report["journal_open"] = is_instance_valid(journal) and journal.visible
	report["assigned"] = prefs.extra_label("cursor_confirm")
	report["extra"] = prefs.extra_label("cursor_confirm")
	print("KEYBOARD_PREFS_PROBE " + JSON.stringify(report))
	get_tree().quit(0)


func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev


func _tap(code: Key) -> void:
	get_tree().root.push_input(_key(code, true))
	get_tree().root.push_input(_key(code, false))
