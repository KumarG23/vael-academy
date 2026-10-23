extends GutTest
## Issue #16 / AW-39: closing the Academy Journal with Esc or J must consume
## that key. Real key events go through a viewport's input dispatch into a live
## castle, so the castle sees exactly what a player's keypress would deliver.

var _viewport: SubViewport
var _castle: CastleScene


func before_each() -> void:
	Campaign.reset_new_game(false)
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	_viewport.add_child(_castle)
	await wait_frames(1)


func after_each() -> void:
	Campaign.reset_new_game(false)


func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		_viewport.push_input(ev, true)


func _open_journal() -> AcademyJournal:
	_press(KEY_J)
	assert_not_null(_castle._journal, "J opens the Journal from exploration")
	return _castle._journal


func _assert_back_to_exploration(journal: AcademyJournal, how: String) -> void:
	assert_null(_castle._journal, "%s leaves no Journal open" % how)
	assert_eq(_castle._menu_context, "", "%s does not open the castle system menu" % how)
	assert_false(_castle.busy(), "%s restores exploration input" % how)
	assert_true(journal.is_queued_for_deletion(), "%s closes the original book once" % how)


func _ui_journals() -> int:
	var n := 0
	for child in _castle._ui.get_children():
		if child is AcademyJournal and not child.is_queued_for_deletion():
			n += 1
	return n


func test_escape_on_the_roster_tab_closes_to_exploration():
	var journal := _open_journal()
	assert_eq(journal._tab, 0, "opens on the Roster tab")
	var closes := [0]
	journal.closed.connect(func() -> void: closes[0] += 1)
	_press(KEY_ESCAPE)
	assert_eq(closes[0], 1, "exactly one close")
	_assert_back_to_exploration(journal, "Esc")
	assert_eq(_ui_journals(), 0, "no replacement Journal")
	# Exploration owns Escape again: the next press is the castle's own menu.
	_press(KEY_ESCAPE)
	assert_eq(_castle._menu_context, "system", "a fresh Esc reaches exploration")


func test_j_closes_without_reopening_a_new_journal():
	var journal := _open_journal()
	var closes := [0]
	journal.closed.connect(func() -> void: closes[0] += 1)
	_press(KEY_J)
	assert_eq(closes[0], 1, "exactly one close")
	_assert_back_to_exploration(journal, "J")
	assert_eq(_ui_journals(), 0, "no replacement Journal")
	var again := _open_journal()
	assert_ne(again, journal, "a later J opens a new book from exploration")


func test_escape_backs_out_of_the_inventory_hub_before_closing():
	var journal := _open_journal()
	journal._tab = 2
	journal._inv_mode = 2
	_press(KEY_ESCAPE)
	assert_eq(journal._inv_mode, 1, "Esc steps give -> item")
	assert_eq(_castle._journal, journal, "the same book stays open")
	assert_eq(_castle._menu_context, "", "no system menu while backing out")
	_press(KEY_ESCAPE)
	assert_eq(journal._inv_mode, 0, "Esc steps item -> students")
	assert_eq(_castle._journal, journal, "still the same book")
	_press(KEY_ESCAPE)
	_assert_back_to_exploration(journal, "Esc at the student list")


func test_j_closes_from_inside_the_inventory_hub():
	var journal := _open_journal()
	journal._tab = 2
	journal._inv_mode = 2
	_press(KEY_J)
	_assert_back_to_exploration(journal, "J inside the hub")
	assert_eq(_ui_journals(), 0, "no replacement Journal")


func test_fish_log_is_reachable_by_viewport_input_and_closes_without_leak():
	Campaign.fish_log = {"Lakeperch": 2, "Warded Coin": 1, "Unknown Saved Catch": 5}
	var before := Campaign.to_dict()
	var journal := _open_journal()
	for _i in range(5):
		_press(KEY_RIGHT)
	assert_eq(journal._tab, 5, "Fish Log is reachable after the existing tabs")
	_press(KEY_UP)
	assert_eq(journal._fish_i, 2, "real viewport input wraps to the last stable catch")
	assert_eq(Campaign.to_dict(), before, "opening and navigating the log leaves campaign and RNG unchanged")
	_press(KEY_J)
	_assert_back_to_exploration(journal, "J from Fish Log")
	assert_eq(_castle._menu_context, "", "the close key does not leak into exploration")
	Campaign.fish_log["Lakeperch"] = 6
	var reopened := _open_journal()
	for _i in range(5):
		_press(KEY_RIGHT)
	assert_eq(reopened._fish_log_entries()[0]["count"], 6,
		"a newly opened Journal reads the current saved campaign count")
	_press(KEY_ESCAPE)
	_assert_back_to_exploration(reopened, "Esc from reopened Fish Log")
