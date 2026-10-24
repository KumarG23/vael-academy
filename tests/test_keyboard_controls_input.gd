extends GutTest
## Issue #89: Journal → System → Keyboard Controls through a live castle's
## viewport input, then the chosen keys in exploration, Journal, ChoiceMenu,
## room map/travel and dialogue. Shipped keys and #16 close consumption remain.

const UP := KEY_I
const DOWN := KEY_N
const LEFT := KEY_G
const RIGHT := KEY_L
const CONFIRM := KEY_O
const CANCEL := KEY_P

var _viewport: SubViewport
var _castle: CastleScene
var _original_path := ""
var _prefs_path := ""


func before_each() -> void:
	_original_path = KeyboardPreferences.prefs_path
	_prefs_path = "user://test_keyboard_controls_%d.cfg" % Time.get_ticks_usec()
	KeyboardPreferences.prefs_path = _prefs_path
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	Campaign.reset_new_game(false, 8901)
	Campaign.week = 2
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	_viewport.add_child(_castle)
	await wait_process_frames(2)


func after_each() -> void:
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right", "cursor_right"]:
		Input.action_release(action)
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	KeyboardPreferences.prefs_path = _original_path
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(_prefs_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_prefs_path + suffix))
	Campaign.reset_new_game(false)


func _ev(code: Key, pressed := true, echo := false, shift := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	event.shift_pressed = shift
	return event


func _key(code: Key, pressed := true, echo := false, shift := false) -> void:
	_viewport.push_input(_ev(code, pressed, echo, shift), true)


func _tap(code: Key) -> void:
	_key(code)
	_key(code, false)


func _assign_all() -> void:
	var picks := {"cursor_up": UP, "cursor_down": DOWN, "cursor_left": LEFT,
		"cursor_right": RIGHT, "cursor_confirm": CONFIRM, "cursor_cancel": CANCEL}
	for action: String in picks:
		assert_eq(KeyboardPreferences.assign(action, _ev(picks[action])), "")


## J → System tab → last row (Keyboard Controls) → Enter, with real keys only.
func _open_editor() -> KeyboardControlsEditor:
	_tap(KEY_J)
	var journal := _castle._journal
	assert_not_null(journal, "J opens the Journal")
	for i in range(4):
		_tap(KEY_RIGHT)
	assert_eq(journal._tab, 4, "System tab")
	_tap(KEY_UP)
	assert_eq(AcademyJournal.SYS_ROWS[journal._sys_i][1], "keyboard", "Keyboard Controls is discoverable at the end of System")
	_tap(KEY_ENTER)
	assert_not_null(journal._keys_editor, "Enter opens the editor")
	return journal._keys_editor


func _state() -> Array:
	return [Campaign.to_dict().duplicate(true), _castle._support_state.save_state().duplicate(true),
		_castle.room.id, _castle._avatar.position]


func test_editor_captures_a_fresh_press_once_and_the_new_key_navigates() -> void:
	var saves := SaveSystem.new("user://keyboard_editor_saves_%d" % Time.get_ticks_usec())
	assert_true(Campaign.save_to_slot(0, saves))
	var save_bytes := FileAccess.get_file_as_bytes(saves.slot_path(0))
	var before := _state()
	seed(8902)
	var expected_rng := [randi(), randi()]
	seed(8902)
	var editor := _open_editor()
	var journal := _castle._journal
	assert_eq(editor._row, 0, "starts on Up")
	_key(KEY_ENTER)
	assert_eq(editor._capturing, "cursor_up", "Enter starts capture")
	# Enter's own echo/release must not be taken as the new key.
	_key(KEY_ENTER, true, true)
	_key(KEY_ENTER, false)
	assert_eq(editor._capturing, "cursor_up", "echo/release are not a fresh press")
	assert_eq(KeyboardPreferences.extra_key("cursor_up"), KEY_NONE)
	_key(UP)
	assert_eq(editor._capturing, "", "capture ends after one accepted key")
	assert_eq(KeyboardPreferences.extra_key("cursor_up"), UP, "applied once")
	assert_string_contains(editor._status, "Up now also uses I")
	_key(UP, true, true)
	_key(UP, false)
	assert_eq(editor._row, 0, "the captured key's echo/release did nothing")
	assert_eq(editor._capturing, "", "no capture reopened")
	# The new key now navigates; the shipped key still does too.
	_tap(UP)
	assert_eq(editor._row, editor._row_count() - 1, "I moves up (wraps)")
	_tap(KEY_DOWN)
	assert_eq(editor._row, 0, "shipped Down still moves")
	_tap(KEY_W)
	assert_eq(editor._row, editor._row_count() - 1, "shipped W still moves")
	assert_true(is_instance_valid(journal) and _castle._journal == journal, "Journal stayed open throughout")
	assert_eq(_castle._menu_context, "", "no castle menu")
	assert_null(_castle._room_map, "no map")
	# Esc backs out to System, a second Esc closes the book (#16), a third opens the menu.
	_tap(KEY_ESCAPE)
	assert_null(journal._keys_editor, "Esc closes only the editor")
	assert_eq(_castle._journal, journal, "Journal still open on System")
	assert_eq(AcademyJournal.SYS_ROWS[journal._sys_i][1], "keyboard")
	_tap(KEY_ESCAPE)
	assert_null(_castle._journal)
	assert_eq(_castle._menu_context, "", "closing Esc consumed")
	assert_eq(_state(), before, "Campaign, supports, room and position unchanged")
	assert_eq([randi(), randi()], expected_rng, "global RNG untouched")
	assert_eq(FileAccess.get_file_as_bytes(saves.slot_path(0)), save_bytes, "no save written")
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(_prefs_path), OK)
	assert_eq(cfg.get_value("keyboard", "up"), "I", "persisted to installation settings")
	DirAccess.remove_absolute(saves.slot_path(0))
	DirAccess.remove_absolute(saves.save_dir)


func test_escape_cancels_capture_without_assignment_or_closing_the_journal() -> void:
	var editor := _open_editor()
	var journal := _castle._journal
	_tap(KEY_DOWN)
	_tap(KEY_ENTER)
	assert_eq(editor._capturing, "cursor_down")
	_key(KEY_ESCAPE)
	assert_eq(editor._capturing, "", "Esc cancels capture")
	assert_string_contains(editor._status, "Cancelled")
	_key(KEY_ESCAPE, true, true)
	_key(KEY_ESCAPE, false)
	assert_eq(KeyboardPreferences.extra_key("cursor_down"), KEY_NONE, "nothing assigned")
	assert_eq(journal._keys_editor, editor, "editor still open (Esc echo/release swallowed)")
	assert_eq(_castle._journal, journal, "Journal still open")
	assert_eq(_castle._menu_context, "")
	assert_eq(InputMap.action_get_events("cursor_down").size(), 2, "shipped Down events only")


func test_conflicts_and_unsupported_input_give_feedback_and_keep_prior_bindings() -> void:
	assert_eq(KeyboardPreferences.assign("cursor_cancel", _ev(CANCEL)), "")
	var editor := _open_editor()
	var journal := _castle._journal
	for i in range(4):
		_tap(KEY_DOWN)
	_tap(KEY_ENTER)
	assert_eq(editor._capturing, "cursor_confirm")
	var cases := [[KEY_J, "Academy Journal"], [KEY_M, "academy map"], [KEY_SPACE, "default Confirm"],
		[KEY_T, "End Turn"], [KEY_PAGEDOWN, "unit cycling"], [KEY_QUOTELEFT, "room editor"],
		[CANCEL, "additional Cancel key"], [KEY_BACKSPACE, "default Cancel"], [KEY_SHIFT, "on its own"]]
	for c in cases:
		_tap(c[0])
		assert_string_contains(editor._status, c[1], "%s explained" % OS.get_keycode_string(c[0]))
		assert_string_contains(editor._status, "Press another key")
		assert_eq(editor._capturing, "cursor_confirm", "still waiting after %s" % OS.get_keycode_string(c[0]))
		assert_true(editor._status_error)
	_key(KEY_U, true, false, true)
	assert_string_contains(editor._status, "without Shift")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(400, 300)
	_viewport.push_input(click, true)
	assert_string_contains(editor._status, "Only keyboard keys")
	assert_eq(_castle._journal, journal, "no conflict closed or reopened the Journal")
	assert_null(_castle._room_map, "M did not open the map")
	assert_false(_castle._editor.active, "backtick did not open the room editor")
	assert_eq(KeyboardPreferences.extra_key("cursor_confirm"), KEY_NONE, "nothing assigned yet")
	assert_eq(KeyboardPreferences.extra_key("cursor_cancel"), CANCEL, "prior binding intact")
	_tap(CONFIRM)
	assert_eq(KeyboardPreferences.extra_key("cursor_confirm"), CONFIRM, "ordinary retry succeeds")
	assert_false(editor._status_error)


func test_clear_delete_and_restore_defaults_through_editor_rows() -> void:
	_assign_all()
	var editor := _open_editor()
	_tap(RIGHT)  # custom Right moves to the Clear button
	assert_eq(editor._col, 1)
	_tap(CONFIRM)  # custom Confirm presses it
	assert_eq(KeyboardPreferences.extra_key("cursor_up"), KEY_NONE, "Up's extra cleared")
	assert_true(InputMap.event_is_action(_ev(KEY_UP), "cursor_up", true), "shipped Up intact")
	_tap(KEY_DOWN)
	_tap(KEY_DELETE)
	assert_eq(KeyboardPreferences.extra_key("cursor_down"), KEY_NONE, "Delete clears the selected row")
	for i in range(5):
		_tap(KEY_DOWN)
	assert_eq(editor._row_kind(editor._row), "restore")
	_tap(KEY_ENTER)
	for action in KeyboardPreferences.ACTIONS:
		assert_eq(KeyboardPreferences.extra_key(action), KEY_NONE, "%s restored" % action)
	assert_string_contains(editor._status, "Default keys unchanged")
	_tap(KEY_DOWN)
	_tap(KEY_ENTER)  # Back to System
	assert_null(_castle._journal._keys_editor)
	assert_not_null(_castle._journal)


func test_extra_keys_drive_exploration_interaction_menus_and_journal() -> void:
	_assign_all()
	# Cancel opens the existing system menu, like Esc; inside it, Cancel closes it.
	_tap(CANCEL)
	assert_eq(_castle._menu_context, "system", "custom Cancel = exploration Esc")
	_key(CANCEL)
	assert_eq(_castle._menu_context, "", "custom Cancel closes the ChoiceMenu")
	_key(CANCEL, true, true)
	_key(CANCEL, false)
	assert_eq(_castle._menu_context, "", "its echo/release do not reopen it")
	# Interaction at a point: custom Confirm reaches the same activation as Enter.
	_castle.enter_room("training")
	for point in _castle.room.points:
		if point.id == "fn_train":
			_castle._avatar.position = _castle._grid.cell_center(point.cell)
	_castle._update_prompt()
	_tap(CONFIRM)
	assert_eq(_castle._menu_context, "training", "custom Confirm interacts")
	var menu := _castle._menu
	var index: int = menu._index
	_tap(DOWN)
	assert_eq(menu._index, (index + 1) % menu._options.size(), "custom Down moves the ChoiceMenu")
	_tap(UP)
	assert_eq(menu._index, index, "custom Up moves it back")
	_tap(CANCEL)
	assert_eq(_castle._menu_context, "")
	# Journal: custom Right switches tab, custom Cancel closes without leaking (#16).
	_tap(KEY_J)
	var journal := _castle._journal
	_tap(RIGHT)
	assert_eq(journal._tab, 1)
	_tap(LEFT)
	assert_eq(journal._tab, 0)
	_tap(CANCEL)
	assert_null(_castle._journal, "custom Cancel closes the Journal")
	assert_eq(_castle._menu_context, "", "and is consumed before exploration")
	# Walking polls the ui_* aliases: a real key event drives held movement.
	_castle.enter_room("entrance", Vector2i(11, 11))
	var start := _castle._avatar.position
	Input.parse_input_event(_ev(RIGHT))
	Input.flush_buffered_events()
	_castle._process(0.05)
	var moved := _castle._avatar.position
	Input.parse_input_event(_ev(RIGHT, false))
	Input.flush_buffered_events()
	_castle._process(0.05)
	assert_gt(moved.x, start.x, "held custom Right walks")
	assert_eq(_castle._avatar.position, moved, "release stops walking")


func test_extra_keys_in_room_map_and_travel_keep_modal_consumption() -> void:
	_assign_all()
	_castle.enter_room("entrance")
	_tap(KEY_M)
	var map := _castle._room_map
	assert_not_null(map)
	_tap(CANCEL)
	assert_null(_castle._room_map, "custom Cancel closes the map")
	assert_eq(_castle._menu_context, "", "without reaching the system menu")
	_key(CANCEL, true, true)
	_key(CANCEL, false)
	assert_eq(_castle._menu_context, "", "echo/release do not leak")
	var before := Campaign.to_dict().duplicate(true)
	_tap(KEY_M)
	map = _castle._room_map
	_tap(KEY_TAB)
	assert_true(map.showing_destinations)
	var first: int = map.selected
	_key(DOWN)
	_key(DOWN, true, true)  # held Down repeats like the arrow
	assert_eq(map.selected, posmod(first + 2, map.destinations.size()), "custom Down navigates with repeat")
	_key(DOWN, false)
	_tap(UP)
	assert_eq(map.selected, posmod(first + 1, map.destinations.size()), "custom Up navigates")
	_tap(LEFT)
	_tap(RIGHT)
	assert_not_null(_castle._room_map, "Left/Right stay consumed by the modal map")
	while map.destinations[map.selected].id != "campus":
		_tap(DOWN)
	_key(CONFIRM)
	assert_null(_castle._room_map, "custom Confirm travels")
	await wait_until(func(): return not _castle.busy(), 2.0)
	assert_eq(_castle.room.id, "campus")
	_key(CONFIRM, false)
	assert_eq(_castle._menu_context, "", "release did not interact")
	assert_eq(Campaign.academy_visits, before["academy_visits"], "travel adds no visit")


func test_extra_keys_drive_dialogue_choices_and_advance_only() -> void:
	_assign_all()
	var dialogue := DialogueScene.new()
	dialogue.typewriter_speed = 0.0
	_viewport.add_child(dialogue)
	dialogue.play(DialogueScript.from_json('[{"text":"Line"},{"choice":"Pick","options":[{"text":"First","flag":"a"},{"text":"Second","flag":"b"}]},{"text":"After"}]'))
	_tap(CANCEL)
	_tap(LEFT)
	assert_eq(dialogue.current_line().text, "Line", "Cancel/Left keep their (no) meaning in dialogue")
	_key(CONFIRM)
	assert_true(dialogue.awaiting_choice(), "custom Confirm advances")
	_key(CONFIRM, true, true)
	_key(CONFIRM, false)
	assert_true(dialogue.awaiting_choice(), "echo/release do not choose")
	_tap(DOWN)
	assert_eq(dialogue._choice_index, 1)
	_tap(UP)
	assert_eq(dialogue._choice_index, 0)
	_tap(DOWN)
	_tap(CONFIRM)
	assert_true(dialogue.flags.get("b", false), "custom Confirm chooses the highlighted option")
	assert_eq(dialogue.current_line().text, "After")
	dialogue.queue_free()


func test_editor_fits_default_and_compact_windows() -> void:
	var editor := _open_editor()
	for size in [Vector2(1280, 720), Vector2(1152, 648), Vector2(800, 450)]:
		var g := editor.layout(size)
		var book: Rect2 = g["book"]
		assert_true(Rect2(Vector2.ZERO, size).encloses(book), "%s book inside window" % size)
		assert_gte(g["pitch"], 16.0, "%s rows readable" % size)
		assert_lte(g["rows_bottom"], g["status_top"], "%s rows clear the feedback line" % size)
		var font := UITheme.font()
		var safe := book.grow(-(UITheme.DST_MARGIN + 8.0))
		var title_size := font.get_string_size("Keyboard Controls", HORIZONTAL_ALIGNMENT_LEFT, -1, g["title_fs"])
		var title := Rect2(Vector2(g["x"], g["title_y"] - font.get_ascent(g["title_fs"])), title_size)
		var hint_size := font.get_string_size(KeyboardControlsEditor.FOOTER_HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, g["small"])
		var hint := Rect2(Vector2(g["x"] + (g["width"] - hint_size.x) * 0.5,
			g["footer_y"] - font.get_ascent(g["small"])), hint_size)
		assert_true(safe.encloses(title), "%s complete heading clears frame ornament" % size)
		assert_true(safe.encloses(hint), "%s complete navigation hint clears frame" % size)
		assert_lte(g["status_top"] + font.get_height(g["small"]) * 2.0,
			hint.position.y - 8.0, "%s two feedback lines clear the hint" % size)
		assert_gt(g["rows_top"], g["header_y"])
	_viewport.size = Vector2i(800, 450)
	await wait_process_frames(2)
	assert_eq(editor.get_viewport_rect().size, Vector2(800, 450), "drawing uses the live compact viewport")
