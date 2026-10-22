extends GutTest
## Issue #43: the Journal's master/music/SFX levels belong to the player's
## installation and survive closing and reopening the game. These tests launch
## genuinely fresh game processes (tests/fixtures/audio_prefs_probe.gd) with a
## disposable XDG_DATA_HOME, so the production `user://settings.cfg` path is the
## one written and read, and a player's own settings are never touched.

const PROBE := "res://tests/fixtures/audio_prefs_probe.gd"
const DEFAULTS := {"master": 1.0, "music": 0.7, "sfx": 0.85}

var _xdg := ""


func before_each() -> void:
	_xdg = ProjectSettings.globalize_path("user://test_audio_prefs_xdg_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_xdg)


func after_each() -> void:
	if _saved_prefs_path != "":
		_restore_autoload()
	_remove_tree(_xdg)


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for f in dir.get_files():
		dir.remove(f)
	DirAccess.remove_absolute(path)


## Where a fresh process with XDG_DATA_HOME=_xdg keeps `user://` (Linux layout;
## each probe also reports its real user dir, which must agree).
func _child_user_dir() -> String:
	return _xdg.path_join("godot/app_userdata").path_join(
		str(ProjectSettings.get_setting("application/config/name")))


func _prefs_file() -> String:
	return _child_user_dir().path_join("settings.cfg")


## Launch a fresh game process in `mode`; returns its parsed report ({} on failure).
func _launch(mode: String) -> Dictionary:
	var output: Array = []
	var code := OS.execute("env", PackedStringArray([
		"XDG_DATA_HOME=" + _xdg, OS.get_executable_path(),
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", PROBE, "--", mode,
	]), output, true)
	assert_eq(code, 0, "%s probe exits cleanly: %s" % [mode, output])
	var text := str(output)
	assert_false(text.contains("SCRIPT ERROR"), "no script errors in %s: %s" % [mode, output])
	for line in "\n".join(PackedStringArray(output)).split("\n"):
		if line.begins_with("AUDIO_PREFS_PROBE "):
			var report: Variant = JSON.parse_string(line.trim_prefix("AUDIO_PREFS_PROBE "))
			if report is Dictionary:
				assert_eq(report["user_dir"], _child_user_dir(), "probe uses the disposable user dir")
				return report
	fail_test("no probe report from %s: %s" % [mode, output])
	return {}


func _can_isolate() -> bool:
	if OS.get_name() != "Linux":
		# XDG_DATA_HOME only relocates user:// on Linux; elsewhere a child would
		# share the player's real settings file, so don't launch one.
		pending("fresh-process preference checks need Linux XDG_DATA_HOME isolation")
		return false
	return true


func _assert_levels(got: Dictionary, want: Dictionary, context: String) -> void:
	for k in want:
		assert_almost_eq(float(got.get(k, -1.0)), float(want[k]), 0.001, "%s: %s" % [context, k])


func _read_bytes(path: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(path)


func _write_prefs_text(text: String) -> void:
	DirAccess.make_dir_recursive_absolute(_child_user_dir())
	var f := FileAccess.open(_prefs_file(), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_journal_changes_survive_closing_and_reopening_the_game() -> void:
	if not _can_isolate():
		return
	var first := _launch("journal")
	if first.is_empty():
		return
	var chosen := {"master": 0.6, "music": 0.4, "sfx": 0.55}
	_assert_levels(first["restored"], DEFAULTS, "first launch starts at today's defaults")
	_assert_levels(first["after_input"], chosen, "Journal input applies immediately")
	assert_true(first["returned_to_title"], "Journal input returns to the real title with levels kept")
	assert_true(FileAccess.file_exists(_prefs_file()), "the change was saved for the installation")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_prefs_file()), OK, "the saved preferences parse")
	assert_almost_eq(float(cfg.get_value("audio", "master_volume", -1.0)), 0.6, 0.001)
	assert_almost_eq(float(cfg.get_value("audio", "music_volume", -1.0)), 0.4, 0.001)
	assert_almost_eq(float(cfg.get_value("audio", "sfx_volume", -1.0)), 0.55, 0.001)
	var saved := _read_bytes(_prefs_file())

	var second := _launch("startup")
	if second.is_empty():
		return
	_assert_levels(second["restored"], chosen, "a fresh process restores them before any scene")
	# The first sounds of the launch already play at the restored levels.
	assert_almost_eq(float(second["title_sfx_db"]), linear_to_db(0.55 * 0.6), 0.01, "first title SFX")
	assert_true(second["music_playing"], "the first music request plays")
	assert_almost_eq(float(second["music_db"]), linear_to_db(0.4 * 0.6), 0.01, "first music")
	assert_almost_eq(float(second["voice_db"]), linear_to_db(0.55 * 0.6), 0.01, "first narration")
	assert_eq(_read_bytes(_prefs_file()), saved, "reading never rewrites the player's file")


func test_fresh_launch_without_preferences_keeps_todays_defaults() -> void:
	if not _can_isolate():
		return
	var report := _launch("startup")
	if report.is_empty():
		return
	_assert_levels(report["restored"], DEFAULTS, "missing settings")
	assert_almost_eq(float(report["music_db"]), linear_to_db(0.7), 0.01, "default music level")
	assert_false(FileAccess.file_exists(_prefs_file()), "a plain launch writes no settings file")


func test_fresh_launch_with_a_malformed_file_keeps_defaults_and_the_file() -> void:
	if not _can_isolate():
		return
	_write_prefs_text("[audio\nmusic_volume = = ???\n%sgarbage" % char(1))
	var before := _read_bytes(_prefs_file())
	var report := _launch("startup")
	if report.is_empty():
		return
	_assert_levels(report["restored"], DEFAULTS, "unparseable settings")
	assert_true(report["music_playing"], "audio still works")
	assert_eq(_read_bytes(_prefs_file()), before, "an unreadable file is left as the player had it")


func test_fresh_launch_validates_each_field_independently() -> void:
	if not _can_isolate():
		return
	# zero is a real choice; a string and a non-finite value fall back alone.
	_write_prefs_text("[audio]\nmaster_volume=nan\nmusic_volume=0.0\nsfx_volume=\"loud\"\n")
	var report := _launch("startup")
	if report.is_empty():
		return
	_assert_levels(report["restored"], {"master": 1.0, "music": 0.0, "sfx": 0.85}, "mixed file")
	assert_almost_eq(float(report["music_db"]), linear_to_db(0.0001), 0.01, "zero music is floored silence")
	assert_almost_eq(float(report["title_sfx_db"]), linear_to_db(0.85), 0.01, "SFX at its default")


# --- the production read/write boundary, in-process ------------------------------
# AudioManager.load_preferences/save_preferences against disposable files: the
# autoload's prefs_path is swapped for each test and restored afterwards, and a
# fresh, un-readied AudioManager stands in for "the next launch".

const TEST_SLOT_DIR := "user://test_audio_prefs_saves"

var _saved_prefs_path := ""
var _saved_levels := {}


func _prefs_tmp() -> String:
	return _xdg.path_join("settings.cfg")


func _point_autoload_at_tmp() -> void:
	_saved_prefs_path = AudioManager.prefs_path
	_saved_levels = {}
	for key in AudioManager.DEFAULT_LEVELS:
		_saved_levels[key] = AudioManager.get(key)
	AudioManager.prefs_path = _prefs_tmp()


func _restore_autoload() -> void:
	AudioManager.prefs_path = _saved_prefs_path
	_saved_prefs_path = ""
	for key in _saved_levels:
		AudioManager.set(key, _saved_levels[key])
	AudioManager.muted = false
	AudioManager.stop_music()
	AudioManager.stop_voice()


## A new AudioManager reading `path` at _ready, as the next launch's autoload would.
func _next_launch(path: String) -> Node:
	var am: Node = load("res://src/core/audio_manager.gd").new()
	am.prefs_path = path
	add_child_autofree(am)
	return am


func _write_cfg(values: Dictionary, extra := {}) -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value("audio", key, values[key])
	for section in extra:
		for key in extra[section]:
			cfg.set_value(section, key, extra[section][key])
	assert_eq(cfg.save(_prefs_tmp()), OK)


func _levels_of(am: Node) -> Dictionary:
	return {"master": am.master_volume, "music": am.music_volume, "sfx": am.sfx_volume}


func _journal_on(row: String) -> Control:
	var journal: Control = load("res://src/ui/academy_journal.gd").new()
	journal._save = SaveSystem.new(TEST_SLOT_DIR)
	add_child_autofree(journal)
	journal._tab = 4  # System
	for i in range(journal.SYS_ROWS.size()):
		if journal.SYS_ROWS[i][1] == row:
			journal._sys_i = i
	return journal


func _press(action: String, times := 1) -> void:
	for i in range(times):
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = true
		get_viewport().push_input(ev)
		var up := InputEventAction.new()
		up.action = action
		get_viewport().push_input(up)


func test_journal_input_writes_each_level_and_the_next_launch_reads_it() -> void:
	_point_autoload_at_tmp()
	var journal := _journal_on("music")
	_press("cursor_left", 2)                   # 0.7 → 0.5
	_press("cursor_down")
	_press("cursor_right")  # SFX 0.85 → 0.95
	_press("cursor_down")
	_press("cursor_left", 12)  # Master → 0 (zero is a choice)
	assert_almost_eq(AudioManager.music_volume, 0.5, 0.001, "applied immediately")
	assert_almost_eq(AudioManager.master_volume, 0.0, 0.001, "clamped at zero")
	var next := _next_launch(_prefs_tmp())
	_assert_levels(_levels_of(next), {"master": 0.0, "music": 0.5, "sfx": 0.95}, "next launch")
	assert_almost_eq(next._music.volume_db, linear_to_db(0.0001), 0.01, "zero master is floored silence")
	journal.queue_free()


func test_tab_switching_and_unchanged_presses_write_nothing() -> void:
	_point_autoload_at_tmp()
	var journal := _journal_on("save0")
	_press("cursor_right")  # not a volume row: switches tab
	assert_false(FileAccess.file_exists(_prefs_tmp()), "tab switch is not a preference change")
	AudioManager.music_volume = 1.0
	journal._tab = 4
	journal._sys_i = 6  # Music Volume, already at the top
	_press("cursor_right")
	assert_false(FileAccess.file_exists(_prefs_tmp()), "a press that changes nothing writes nothing")


func test_each_field_is_validated_on_its_own() -> void:
	var cases := [
		# [stored value, expected level for music (default 0.7)]
		[0.25, 0.25], [0, 0.0], [1, 1.0], [1.5, 1.0], [-0.25, 0.0], [1e30, 1.0],
		[INF, 0.7], [-INF, 0.7], [NAN, 0.7], ["0.5", 0.7], [true, 0.7], [[0.5], 0.7],
		[{"v": 0.5}, 0.7], [null, 0.7],
	]
	for c in cases:
		_write_cfg({"music_volume": c[0], "master_volume": 0.9})
		var am := _next_launch(_prefs_tmp())
		assert_almost_eq(am.music_volume, float(c[1]), 0.0001, "music from %s" % var_to_str(c[0]))
		assert_almost_eq(am.master_volume, 0.9, 0.0001, "valid master kept beside %s" % var_to_str(c[0]))
		assert_almost_eq(am.sfx_volume, 0.85, 0.0001, "absent sfx keeps its default")
		assert_true(is_finite(am._music_db()), "player level stays finite")
		am.free()


func test_reading_never_rewrites_the_file() -> void:
	for text in [
		"[audio]\nmaster_volume=0.5\nmusic_volume=0.4\nsfx_volume=0.3\n",
		"[audio]\nmusic_volume=7.0\nsfx_volume=\"x\"\n; a player's comment\n",
		"not a config file [[[",
		"",
	]:
		var f := FileAccess.open(_prefs_tmp(), FileAccess.WRITE)
		f.store_string(text)
		f.close()
		var before := _read_bytes(_prefs_tmp())
		var stamp := FileAccess.get_modified_time(_prefs_tmp())
		var am := _next_launch(_prefs_tmp())
		am.load_preferences()
		assert_eq(_read_bytes(_prefs_tmp()), before, "bytes unchanged: %s" % text.c_escape())
		assert_eq(FileAccess.get_modified_time(_prefs_tmp()), stamp, "not touched: %s" % text.c_escape())
		assert_false(FileAccess.file_exists(_prefs_tmp() + ".tmp"), "no temp left behind")
		am.free()


func test_missing_or_malformed_file_keeps_defaults() -> void:
	var am := _next_launch(_prefs_tmp())
	assert_eq(am.load_preferences(), ERR_FILE_NOT_FOUND, "missing is reported, not an error")
	_assert_levels(_levels_of(am), DEFAULTS, "missing")
	assert_false(FileAccess.file_exists(_prefs_tmp()), "missing stays missing on read")
	var f := FileAccess.open(_prefs_tmp(), FileAccess.WRITE)
	f.store_string("[audio\nmusic_volume = = ???")
	f.close()
	am.music_volume = 0.1
	assert_ne(am.load_preferences(), OK, "a malformed file is reported")
	_assert_levels(_levels_of(am), DEFAULTS, "malformed")
	_consume_engine_errors()


func test_save_keeps_unrelated_settings_and_valid_values() -> void:
	_write_cfg({"music_volume": 0.3, "custom": "kept"}, {"video": {"vsync": false}})
	var am := _next_launch(_prefs_tmp())
	am.sfx_volume = 0.2
	assert_eq(am.save_preferences(), OK)
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_prefs_tmp()), OK)
	assert_eq(cfg.get_value("video", "vsync"), false, "unrelated section kept")
	assert_eq(cfg.get_value("audio", "custom"), "kept", "unrelated audio key kept")
	assert_almost_eq(float(cfg.get_value("audio", "music_volume")), 0.3, 0.0001, "restored level re-saved as-is")
	assert_almost_eq(float(cfg.get_value("audio", "sfx_volume")), 0.2, 0.0001, "changed level saved")
	assert_almost_eq(float(cfg.get_value("audio", "master_volume")), 1.0, 0.0001, "default level saved")
	assert_false(FileAccess.file_exists(_prefs_tmp() + ".tmp"), "temp file renamed away")


func test_save_replaces_an_unreadable_file_on_an_explicit_change() -> void:
	var f := FileAccess.open(_prefs_tmp(), FileAccess.WRITE)
	f.store_string("[audio\ngarbage")
	f.close()
	var am := _next_launch(_prefs_tmp())
	am.music_volume = 0.4
	assert_eq(am.save_preferences(), OK)
	var next := _next_launch(_prefs_tmp())
	_assert_levels(_levels_of(next), {"master": 1.0, "music": 0.4, "sfx": 0.85}, "after replacement")
	_consume_engine_errors()


func test_unwritable_preferences_never_stop_the_controls() -> void:
	_point_autoload_at_tmp()
	# Two ways the write can fail: the folder is gone, or a directory squats on
	# the file name so the final rename cannot land.
	for path in [_xdg.path_join("missing_dir/settings.cfg"), _xdg.path_join("squatter.cfg")]:
		if path.ends_with("squatter.cfg"):
			DirAccess.make_dir_recursive_absolute(path)
		AudioManager.prefs_path = path
		AudioManager.music_volume = 0.7
		AudioManager.play_music("res://assets/audio/music/campus_chill.mp3")
		var journal := _journal_on("music")
		_press("cursor_left")
		assert_almost_eq(AudioManager.music_volume, 0.6, 0.001, "control still applies: %s" % path)
		assert_almost_eq(AudioManager._music.volume_db, linear_to_db(0.6 * AudioManager.master_volume), 0.01,
			"live track follows: %s" % path)
		_press("cursor_left")
		assert_almost_eq(AudioManager.music_volume, 0.5, 0.001, "and keeps applying: %s" % path)
		assert_ne(AudioManager.save_preferences(), OK, "the failure is reported: %s" % path)
		assert_false(FileAccess.file_exists(path + ".tmp"), "no temp left behind: %s" % path)
		journal.free()
	assert_true(DirAccess.dir_exists_absolute(_xdg.path_join("squatter.cfg")), "nothing was clobbered")
	_consume_engine_errors()


func test_failed_write_preserves_previous_file_and_a_later_change_can_save() -> void:
	_point_autoload_at_tmp()
	_write_cfg({"music_volume": 0.3}, {"video": {"vsync": false}})
	var previous := _read_bytes(_prefs_tmp())
	# Block the temporary write while keeping a valid destination file intact.
	DirAccess.make_dir_recursive_absolute(_prefs_tmp() + ".tmp")
	var journal := _journal_on("music")
	_press("cursor_left")
	assert_eq(_read_bytes(_prefs_tmp()), previous, "failed save preserves existing user data")
	assert_almost_eq(AudioManager.music_volume, 0.6, 0.001, "failed save still applies live")
	DirAccess.remove_absolute(_prefs_tmp() + ".tmp")
	_press("cursor_left")
	var next := _next_launch(_prefs_tmp())
	assert_almost_eq(next.music_volume, 0.5, 0.001, "subsequent input retries successfully")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_prefs_tmp()), OK)
	assert_eq(cfg.get_value("video", "vsync"), false, "unrelated data survives recovery")
	_consume_engine_errors()
	journal.queue_free()


func test_restoring_while_muted_keeps_the_mute_lifecycle() -> void:
	_write_cfg({"music_volume": 0.4, "sfx_volume": 0.3, "master_volume": 0.5})
	var am: Node = load("res://src/core/audio_manager.gd").new()
	am.prefs_path = _prefs_tmp()
	am.muted = true  # pre-_ready mute (issue #10) meets the startup restore
	add_child_autofree(am)
	assert_true(am.muted, "restore does not unmute")
	am.play_music("res://assets/audio/music/campus_chill.mp3")
	assert_false(am._music.playing, "still silent while muted")
	am.muted = false
	assert_true(am._music.playing, "unmute plays the requested track")
	assert_almost_eq(am._music.volume_db, linear_to_db(0.4 * 0.5), 0.01, "at the restored level")
	am.play_voice("res://assets/audio/vo/prologue/p2_narrows.wav")
	assert_almost_eq(am._voice.volume_db, linear_to_db(0.3 * 0.5), 0.01, "narrator at the restored level")


## Preferences belong to the installation: New Game, saving, loading any slot and
## a fresh title screen leave them alone, and no save payload carries them.
func test_campaign_flows_leave_preferences_alone_and_saves_without_them() -> void:
	_point_autoload_at_tmp()
	var journal := _journal_on("sfx")
	_press("cursor_left", 4)  # 0.85 → 0.45, saved
	var want := _levels_of(AudioManager)
	var prefs := _read_bytes(_prefs_tmp())
	var saves := SaveSystem.new(TEST_SLOT_DIR)
	var title: Control = load("res://scenes/title/title.tscn").instantiate()
	title._save_system = saves
	add_child_autofree(title)  # what Return to Title builds
	title.prepare_new_game(false)
	for slot in range(journal.SLOTS):
		Campaign.week = slot + 1
		journal._do_save(slot)
		var raw := FileAccess.get_file_as_string(saves.slot_path(slot))
		assert_false(raw.contains("volume"), "slot %d payload has no audio preferences" % slot)
	for slot in range(journal.SLOTS):
		assert_true(title.prepare_load(slot, saves), "load slot %d" % slot)
		_assert_levels(_levels_of(AudioManager), want, "after loading slot %d" % slot)
	title.prepare_new_game(true)
	_assert_levels(_levels_of(AudioManager), want, "after New Game")
	assert_eq(_read_bytes(_prefs_tmp()), prefs, "flows never rewrite the preferences")
	for slot in range(journal.SLOTS):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(slot)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SLOT_DIR))
	Campaign.reset_new_game(false)
	Campaign.active = false


## Expected engine-level noise (ConfigFile parse errors, failed renames) is part
## of these failure cases, not a test defect.
func _consume_engine_errors() -> void:
	for err in get_errors():
		err.handled = true
