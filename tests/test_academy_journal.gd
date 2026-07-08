extends GutTest
## AW-39: the Academy Journal book UI — builds a live roster snapshot, cycles
## tabs, and drives multi-slot save/load + volume settings. (Runs under GUT so
## the autoloads it reads — Campaign, AudioManager — are registered.)

const TEST_SLOT := 2  # keep clear of a player's slots 0/1 during the run

var _journal


func before_each() -> void:
	Campaign.reset_new_game(false)
	_journal = load("res://src/ui/academy_journal.gd").new()
	add_child_autofree(_journal)
	await wait_frames(1)


func after_each() -> void:
	var save := SaveSystem.new()
	if save.has_slot(TEST_SLOT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save.slot_path(TEST_SLOT)))
	Campaign.reset_new_game(false)


func test_builds_a_snapshot_for_every_fielded_unit():
	assert_eq(_journal._snaps.size(), Roster.player_units().size(), "one card per fielded unit")
	var s: Dictionary = _journal._snaps[0]
	for key in ["id", "name", "class", "level", "stats", "items", "skills"]:
		assert_true(s.has(key), "snapshot has %s" % key)
	assert_true(s["stats"].has("hp") and int(s["stats"]["hp"]) > 0, "real stats captured")


func test_tabs_cycle():
	assert_eq(_journal._tab, 0)
	_journal._switch_tab(1)
	assert_eq(_journal._tab, 1, "roster → calendar")
	_journal._switch_tab(-1)
	assert_eq(_journal._tab, 0, "wraps back")
	for i in range(4):
		_journal._switch_tab(1)
	assert_eq(_journal._tab, 0, "four tabs wrap to the start")


func test_roster_selection_moves_and_wraps():
	_journal._tab = 0
	var n: int = _journal._snaps.size()
	_journal._move_row(-1)
	assert_eq(_journal._roster_i, n - 1, "up from the top wraps to the bottom")


func test_saving_writes_a_slot_and_the_label_updates():
	_journal._tab = 3
	_journal._do_save(TEST_SLOT)
	var save := SaveSystem.new()
	assert_true(save.has_slot(TEST_SLOT), "the slot now exists on disk")
	_journal._refresh_slots()
	assert_ne(_journal._slot_label(TEST_SLOT), "— empty —", "the System tab shows it as filled")


func test_volume_adjust_changes_the_audio_setting():
	_journal._tab = 3
	# find the Music Volume row
	for i in range(_journal.SYS_ROWS.size()):
		if _journal.SYS_ROWS[i][1] == "music":
			_journal._sys_i = i
			break
	var before: float = AudioManager.music_volume
	var changed: bool = _journal._adjust_volume(-1)
	assert_true(changed, "the volume row consumes ←/→")
	assert_lt(AudioManager.music_volume, before + 0.001, "music volume went down")
	AudioManager.music_volume = 0.7
