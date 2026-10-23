extends SceneTree
## Issue #43: a genuinely fresh game process for the audio-preference tests.
## The parent test launches this twice with a disposable XDG_DATA_HOME, so the
## production `user://` preference file is the one written and read:
##   journal  — drive the real Journal System rows with input events, then quit
##   startup  — report what the fresh AudioManager restored, and the levels the
##              first title SFX, music and narration actually play at
## Output is one `AUDIO_PREFS_PROBE {json}` line for the parent to parse.

const CAMPUS_CHILL := "res://assets/audio/music/campus_chill.mp3"
const NARRATION := "res://assets/audio/vo/prologue/p2_narrows.wav"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# SceneTree scripts reach autoloads after initialization through the root.
	var audio: Node = root.get_node("AudioManager")
	var mode: String = OS.get_cmdline_user_args()[0]
	var out := {
		"mode": mode,
		"user_dir": OS.get_user_data_dir(),
		"restored": _levels(audio),  # before any scene runs: autoload _ready only
	}
	if mode == "journal":
		await _drive_journal()
		out["after_input"] = _levels(audio)
		out["returned_to_title"] = current_scene.scene_file_path == "res://scenes/title/title.tscn"
	elif mode == "startup":
		out.merge(await _first_playback(audio))
	print("AUDIO_PREFS_PROBE " + JSON.stringify(out))
	quit(0)


func _levels(audio: Node) -> Dictionary:
	return {"master": audio.master_volume, "music": audio.music_volume, "sfx": audio.sfx_volume}


func _press(action: String, times := 1) -> void:
	for i in range(times):
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		root.push_input(ev)
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		root.push_input(up)
		await process_frame


## Real viewport input into the Journal: → to the System tab, ↓ to each volume
## row, ← to lower it. Music 0.7→0.4, SFX 0.85→0.55, Master 1.0→0.6.
func _drive_journal() -> void:
	var journal: Control = load("res://src/ui/academy_journal.gd").new()
	journal._save = SaveSystem.new("user://audio_prefs_probe_saves")  # never a player slot
	root.add_child(journal)
	current_scene = journal
	await process_frame
	await _press("cursor_right", 4)   # Roster → Calendar → Inventory → Grades → System
	await _press("cursor_down", 6)    # Save ×3, Load ×3 → Music Volume
	await _press("cursor_left", 3)
	await _press("cursor_down")       # SFX Volume
	await _press("cursor_left", 3)
	await _press("cursor_down")       # Master Volume
	await _press("cursor_left", 4)
	await _press("cursor_down")       # Text Speed row, added by issue #62
	await _press("cursor_down")       # Return to Title, real deferred scene change
	await _press("cursor_confirm")
	await process_frame
	await process_frame


## The first sounds of a launch: the title menu's cursor SFX (real input), then
## the first music and narration requests, as a dialogue/castle would make them.
func _first_playback(audio: Node) -> Dictionary:
	change_scene_to_file("res://scenes/title/title.tscn")
	await process_frame
	await process_frame
	await _press("cursor_down")
	var sfx_db := -1000.0
	for p: AudioStreamPlayer in audio._voices:
		if p.playing:
			sfx_db = p.volume_db
	audio.play_music(CAMPUS_CHILL)
	audio.play_voice(NARRATION)
	return {
		"title_sfx_db": sfx_db,
		"music_playing": audio._music.playing,
		"music_db": audio._music.volume_db,
		"voice_db": audio._voice.volume_db,
	}
