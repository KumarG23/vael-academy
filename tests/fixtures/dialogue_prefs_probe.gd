extends Control
## Issue #62 fresh-process probe: Journal input writes speed, then a separate
## process reports the restored mode before playing an existing dialogue.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := str(args[0]) if not args.is_empty() else "startup"
	var prefs: Node = get_tree().root.get_node("DialoguePreferences")
	var audio: Node = get_tree().root.get_node("AudioManager")
	var report := {
		"mode": mode,
		"user_dir": OS.get_user_data_dir(),
		"text_speed": prefs.text_speed,
		"audio": [audio.master_volume, audio.music_volume, audio.sfx_volume],
	}
	if mode == "journal":
		var journal: AcademyJournal = load("res://src/ui/academy_journal.gd").new()
		journal._save = SaveSystem.new("user://dialogue_prefs_probe_saves")
		get_tree().root.add_child(journal)
		await get_tree().process_frame
		journal._tab = 4
		for i in range(AcademyJournal.SYS_ROWS.size()):
			if AcademyJournal.SYS_ROWS[i][1] == "text_speed":
				journal._sys_i = i
				break
		var ev := InputEventAction.new()
		ev.action = "cursor_right"
		ev.pressed = true
		get_tree().root.push_input(ev)
		await get_tree().process_frame
		report["chosen"] = prefs.text_speed
		report["tab"] = journal._tab
		report["row"] = journal._sys_i
	else:
		var dialogue := DialogueScene.new()
		get_tree().root.add_child(dialogue)
		dialogue.play(DialogueScript.from_file("res://data/dialogue/sample.json"))
		report["speed_before_first_line"] = dialogue._effective_typewriter_speed()
		report["first_line_revealing"] = dialogue.is_revealing()
	print("DIALOGUE_PREFS_PROBE " + JSON.stringify(report))
	get_tree().quit(0)
