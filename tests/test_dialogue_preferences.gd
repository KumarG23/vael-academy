extends GutTest
## Issue #62: installation-local reading speed, Journal input, and dialogue use.

var _original_path := ""
var _original_mode := "normal"
var _prefs_path := ""
var _xdg := ""
var _audio_original_path := ""
var _audio_test_path := ""
var _audio_original_levels := {}
var _audio_original_muted := false
var _install_settings_path := ""
var _install_settings_existed := false
var _install_settings_bytes := PackedByteArray()


func before_each() -> void:
	_original_path = DialoguePreferences.prefs_path
	_original_mode = DialoguePreferences.text_speed
	_prefs_path = "user://test_dialogue_preferences_%d.cfg" % Time.get_ticks_usec()
	DialoguePreferences.prefs_path = _prefs_path
	DialoguePreferences.text_speed = "normal"
	DialoguePreferences.last_write_error = OK
	_audio_original_path = AudioManager.prefs_path
	_audio_original_levels = {
		"master_volume": AudioManager.master_volume,
		"music_volume": AudioManager.music_volume,
		"sfx_volume": AudioManager.sfx_volume,
	}
	_audio_original_muted = AudioManager.muted
	_install_settings_path = ProjectSettings.globalize_path(_audio_original_path)
	_install_settings_existed = FileAccess.file_exists(_install_settings_path)
	_install_settings_bytes = FileAccess.get_file_as_bytes(_install_settings_path) if _install_settings_existed else PackedByteArray()
	_audio_test_path = "user://test_dialogue_audio_preferences_%d.cfg" % Time.get_ticks_usec()
	AudioManager.prefs_path = _audio_test_path
	_xdg = ProjectSettings.globalize_path("user://test_dialogue_prefs_xdg_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_xdg)


func after_each() -> void:
	DialoguePreferences.prefs_path = _original_path
	DialoguePreferences.text_speed = _original_mode
	DialoguePreferences.last_write_error = OK
	AudioManager.prefs_path = _audio_original_path
	for key: String in _audio_original_levels:
		AudioManager.set(key, _audio_original_levels[key])
	AudioManager.muted = _audio_original_muted
	assert_eq(AudioManager.prefs_path, _audio_original_path, "AudioManager preference path is restored")
	assert_eq(AudioManager.master_volume, _audio_original_levels["master_volume"], "incoming master level is restored")
	assert_eq(AudioManager.music_volume, _audio_original_levels["music_volume"], "incoming music level is restored")
	assert_eq(AudioManager.sfx_volume, _audio_original_levels["sfx_volume"], "incoming SFX level is restored")
	assert_eq(AudioManager.muted, _audio_original_muted, "incoming mute state is restored")
	for suffix in ["", ".tmp"]:
		var path := ProjectSettings.globalize_path(_prefs_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		assert_false(FileAccess.file_exists(path), "dialogue preference test file and temp neighbor are removed")
		path = ProjectSettings.globalize_path(_audio_test_path + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		assert_false(FileAccess.file_exists(path), "audio preference test file and temp neighbor are removed")
	_remove_tree(_xdg)


func test_system_row_changes_speed_and_consumes_real_journal_input() -> void:
	var journal := AcademyJournal.new()
	journal._save = SaveSystem.new("user://test_text_speed_saves_%d" % Time.get_ticks_usec())
	add_child_autofree(journal)
	await wait_frames(1)
	journal._tab = 4
	var speed_row := _row_index("text_speed")
	journal._sys_i = speed_row
	var before_tab := journal._tab
	var before_row := journal._sys_i
	var event := InputEventAction.new()
	event.action = "cursor_right"
	event.pressed = true
	get_viewport().push_input(event)
	await wait_frames(1)
	assert_eq(DialoguePreferences.text_speed, "fast", "right selects Fast")
	assert_eq(journal._tab, before_tab, "speed adjustment does not change tabs")
	assert_eq(journal._sys_i, before_row, "speed adjustment does not activate or move rows")
	assert_true(get_viewport().is_input_handled(), "the adjustment consumes the input")
	assert_eq(journal._toast, "Text speed: Fast (96 chars/sec)")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_prefs_path), OK, "the changed setting is persisted")
	assert_eq(cfg.get_value("dialogue", "text_speed"), "fast")


func test_system_save_audio_and_title_rows_remain_available() -> void:
	var journal := AcademyJournal.new()
	journal._save = SaveSystem.new("user://test_text_speed_rows_%d" % Time.get_ticks_usec())
	add_child_autofree(journal)
	journal._tab = 4
	assert_eq(_row_index("save0"), 0)
	assert_eq(_row_index("music"), 6)
	assert_eq(_row_index("master"), 8)
	assert_eq(_row_index("text_speed"), 9)
	assert_eq(_row_index("title"), 10)
	journal._sys_i = _row_index("music")
	assert_true(journal._adjust_volume(-1), "audio controls still adjust")
	assert_eq(AudioManager.prefs_path, _audio_test_path, "Journal audio writes target this test's disposable file")
	assert_true(FileAccess.file_exists(ProjectSettings.globalize_path(_audio_test_path)), "Journal audio adjustment saves only the disposable file")
	assert_eq(FileAccess.file_exists(_install_settings_path), _install_settings_existed, "installation settings file presence is unchanged")
	if _install_settings_existed:
		assert_eq(FileAccess.get_file_as_bytes(_install_settings_path), _install_settings_bytes, "installation settings bytes are unchanged")
	journal._sys_i = _row_index("save0")
	journal._activate()
	assert_eq(journal._toast, "Saved to slot 1", "save row remains usable")


func test_system_write_failure_keeps_the_choice_and_says_it_was_not_saved() -> void:
	var journal := AcademyJournal.new()
	journal._save = SaveSystem.new("user://test_text_speed_failed_save_%d" % Time.get_ticks_usec())
	add_child_autofree(journal)
	DialoguePreferences.prefs_path = "user://missing_text_speed_dir_%d/settings.cfg" % Time.get_ticks_usec()
	journal._tab = 4
	journal._sys_i = _row_index("text_speed")
	assert_true(journal._adjust_volume(1), "the setting remains adjustable when disk writes fail")
	assert_eq(DialoguePreferences.text_speed, "fast", "live selection changes despite write failure")
	assert_true(journal._toast.contains("save failed"), "feedback truthfully reports the failed persistence")


func test_modes_apply_to_reveal_advance_choice_and_event_order_once() -> void:
	for mode in DialoguePreferences.MODES:
		DialoguePreferences.text_speed = mode
		var scene := DialogueScene.new()
		var lines: Array[String] = []
		var events: Array[String] = []
		var choices := [0]
		var finished := [0]
		scene.line_shown.connect(func(step): lines.append(step.text))
		scene.event_triggered.connect(func(name, _params): events.append(name))
		scene.choice_shown.connect(func(_step): choices[0] += 1)
		scene.finished.connect(func(): finished[0] += 1)
		add_child_autofree(scene)
		scene.play(DialogueScript.from_json('[{"speaker":"A","text":"First line"},{"event":"beat"},{"speaker":"B","text":"Second line"},{"choice":"Pick","options":[{"text":"Go","flag":"picked"}]},{"event":"done"}]'))
		assert_eq(scene._effective_typewriter_speed(), DialoguePreferences.SPEEDS[mode], "%s uses preference" % mode)
		assert_eq(scene.is_revealing(), mode != "instant", "%s initial reveal state" % mode)
		if scene.is_revealing():
			scene.advance()
			assert_eq(scene.current_line().text, "First line", "%s first advance completes reveal only" % mode)
			scene.advance()
		else:
			scene.advance()
		assert_eq(scene.current_line().text, "Second line", "%s progresses without auto-advancing" % mode)
		assert_eq(lines, ["First line", "Second line"], "%s line callback order is stable" % mode)
		assert_eq(events, ["beat"], "%s nonterminal event fires once" % mode)
		if scene.is_revealing():
			scene.advance()
			scene.advance()
		else:
			scene.advance()
		assert_eq(choices[0], 1, "%s choice is shown once" % mode)
		scene.choose(0)
		assert_true(scene.flags.get("picked", false), "%s choice flag is recorded" % mode)
		assert_eq(events, ["beat", "done"], "%s terminal event fires once" % mode)
		assert_eq(finished[0], 1, "%s completion fires once" % mode)
		scene.free()
		await wait_frames(1)


func test_explicit_instance_speed_overrides_preference_including_instant() -> void:
	DialoguePreferences.text_speed = "fast"
	var scene := DialogueScene.new()
	add_child_autofree(scene)
	scene.typewriter_speed = 10.0
	assert_eq(scene._effective_typewriter_speed(), 10.0, "explicit slow pilot override wins")
	scene.typewriter_speed = 0.0
	assert_eq(scene._effective_typewriter_speed(), 0.0, "explicit instant test override wins")
	scene.typewriter_speed = -1.0
	assert_eq(scene._effective_typewriter_speed(), 96.0, "negative sentinel follows preference")


func test_config_round_trip_preserves_audio_and_unrelated_keys() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", 0.4)
	cfg.set_value("other", "keep", "readable")
	assert_eq(cfg.save(_prefs_path), OK)
	DialoguePreferences.text_speed = "fast"
	assert_eq(DialoguePreferences.save_preferences(), OK)
	var loaded := ConfigFile.new()
	assert_eq(loaded.load(_prefs_path), OK)
	assert_eq(loaded.get_value("audio", "music_volume"), 0.4)
	assert_eq(loaded.get_value("other", "keep"), "readable")
	assert_eq(loaded.get_value("dialogue", "text_speed"), "fast")
	var save_path := "user://test_text_speed_campaign_%d" % Time.get_ticks_usec()
	var saves := SaveSystem.new(save_path)
	assert_true(saves.save_slot(0, {"campaign": Campaign.to_dict()}), "campaign slot can be saved normally")
	var campaign_data: Dictionary = saves.load_slot(0).get("campaign", {})
	assert_false(campaign_data.has("text_speed"), "installation preference is not part of campaign schema")
	Campaign.reset_new_game(false)
	assert_eq(DialoguePreferences.text_speed, "fast", "New Game reset leaves installation preference alone")
	assert_true(Campaign.load_from_slot(0, saves), "campaign slot still loads normally")
	assert_eq(DialoguePreferences.text_speed, "fast", "loading a slot leaves installation preference alone")


func test_missing_invalid_and_unknown_values_default_to_normal() -> void:
	DialoguePreferences.text_speed = "fast"
	assert_eq(DialoguePreferences.load_preferences(), ERR_FILE_NOT_FOUND)
	assert_eq(DialoguePreferences.text_speed, "normal", "omitted file defaults safely")
	var cfg := ConfigFile.new()
	cfg.set_value("dialogue", "text_speed", "ultra")
	assert_eq(cfg.save(_prefs_path), OK)
	assert_eq(DialoguePreferences.load_preferences(), OK)
	assert_eq(DialoguePreferences.text_speed, "normal", "unknown stored mode defaults safely")
	cfg = ConfigFile.new()
	cfg.set_value("dialogue", "text_speed", 96)
	assert_eq(cfg.save(_prefs_path), OK)
	DialoguePreferences.load_preferences()
	assert_eq(DialoguePreferences.text_speed, "normal", "wrong-type value defaults safely")
	var malformed := "[dialogue\ntext_speed = = invalid"
	var file := FileAccess.open(_prefs_path, FileAccess.WRITE)
	file.store_string(malformed)
	file.close()
	var malformed_err := DialoguePreferences.load_preferences()
	assert_ne(malformed_err, OK, "malformed config is reported")
	assert_engine_error("Unexpected EOF while parsing simple tag", "malformed ConfigFile parse error is expected")
	assert_eq(DialoguePreferences.text_speed, "normal", "malformed config defaults safely")
	assert_eq(FileAccess.get_file_as_string(_prefs_path), malformed, "malformed file is not rewritten")


func test_failed_write_keeps_live_choice_and_prior_file_then_retry_succeeds() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", 0.6)
	cfg.set_value("other", "keep", "untouched")
	cfg.set_value("dialogue", "text_speed", "normal")
	assert_eq(cfg.save(_prefs_path), OK)
	var original := FileAccess.get_file_as_bytes(_prefs_path)
	var blocker := ProjectSettings.globalize_path(_prefs_path + ".tmp")
	assert_eq(DirAccess.make_dir_absolute(blocker), OK, "directory blocks temporary file creation deterministically")
	assert_ne(DialoguePreferences.set_text_speed("fast"), OK, "failed write is reported")
	assert_eq(DialoguePreferences.text_speed, "fast", "live choice remains usable")
	assert_eq(FileAccess.get_file_as_bytes(_prefs_path), original, "prior readable file remains intact")
	assert_true(DirAccess.remove_absolute(blocker) == OK, "remove deterministic write blocker")
	assert_eq(DialoguePreferences.set_text_speed("fast"), OK, "retry succeeds")
	var after := ConfigFile.new()
	assert_eq(after.load(_prefs_path), OK)
	assert_eq(after.get_value("audio", "master_volume"), 0.6, "retry preserves audio setting")
	assert_eq(after.get_value("other", "keep"), "untouched", "retry preserves unrelated key")
	assert_eq(after.get_value("dialogue", "text_speed"), "fast")


func test_journal_choice_survives_a_fresh_process_before_dialogue_and_keeps_audio() -> void:
	if OS.get_name() != "Linux":
		pending("fresh-process user:// isolation needs Linux XDG_DATA_HOME")
		return
	var child_dir := _child_user_dir()
	DirAccess.make_dir_recursive_absolute(child_dir)
	var initial := ConfigFile.new()
	initial.set_value("audio", "master_volume", 0.6)
	initial.set_value("audio", "music_volume", 0.4)
	initial.set_value("audio", "sfx_volume", 0.55)
	assert_eq(initial.save(child_dir.path_join("settings.cfg")), OK)
	var chosen := _launch_child("journal")
	assert_eq(chosen.get("chosen"), "fast", "Journal System input changes the live choice")
	assert_eq(int(chosen.get("tab", -1)), 4, "System tab is retained")
	var fresh := _launch_child("startup")
	assert_eq(fresh.get("text_speed"), "fast", "fresh process restores the installation preference")
	assert_eq(float(fresh.get("speed_before_first_line", -1.0)), 96.0, "first existing dialogue sees restored speed")
	assert_true(fresh.get("first_line_revealing", false), "Fast still reveals instead of auto-advancing")
	assert_eq(fresh.get("audio"), [0.6, 0.4, 0.55], "existing audio preferences survive text-speed writes")


func _row_index(kind: String) -> int:
	for i in range(AcademyJournal.SYS_ROWS.size()):
		if AcademyJournal.SYS_ROWS[i][1] == kind:
			return i
	return -1


func _child_user_dir() -> String:
	return _xdg.path_join("godot/app_userdata").path_join(str(ProjectSettings.get_setting("application/config/name")))


func _launch_child(mode: String) -> Dictionary:
	var output: Array = []
	var code := OS.execute("env", PackedStringArray([
		"XDG_DATA_HOME=" + _xdg, OS.get_executable_path(), "--headless",
		"--path", ProjectSettings.globalize_path("res://"),
		"res://tests/fixtures/dialogue_prefs_probe.tscn", "--", mode,
	]), output, true)
	assert_eq(code, 0, "%s child exits cleanly: %s" % [mode, output])
	for line in "\n".join(PackedStringArray(output)).split("\n"):
		if line.begins_with("DIALOGUE_PREFS_PROBE "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("DIALOGUE_PREFS_PROBE "))
			if parsed is Dictionary:
				assert_eq(parsed.get("user_dir"), _child_user_dir(), "child uses disposable user data")
				return parsed
	fail_test("missing %s child report: %s" % [mode, output])
	return {}


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)
