extends GutTest
## GH-92: Calendar uses the live Journal input and the same measured layout
## that its renderer draws. This must remain a read-only view of CalendarDef.

var _viewport: SubViewport
var _journal: AcademyJournal
var _original_prefs_path: String
var _test_prefs_path: String


func before_each() -> void:
	Campaign.reset_new_game(false)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_journal = load("res://src/ui/academy_journal.gd").new()
	_journal._save = SaveSystem.new("user://test_journal_calendar_%d" % Time.get_ticks_usec())
	_original_prefs_path = AudioManager.prefs_path
	_test_prefs_path = "user://test_journal_calendar_settings_%d.cfg" % Time.get_ticks_usec()
	AudioManager.prefs_path = _test_prefs_path
	_viewport.add_child(_journal)
	await wait_frames(1)


func after_each() -> void:
	Campaign.reset_new_game(false)
	if FileAccess.file_exists(_test_prefs_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_prefs_path))
	AudioManager.prefs_path = _original_prefs_path


func _press(action: String) -> void:
	for binding in InputMap.action_get_events(action):
		if binding is InputEventKey:
			var key_event: InputEventKey = binding.duplicate()
			key_event.pressed = true
			key_event.echo = false
			_viewport.push_input(key_event, true)
			key_event = binding.duplicate()
			key_event.pressed = false
			key_event.echo = false
			_viewport.push_input(key_event, true)
			return
	assert_true(false, "%s has a keyboard binding for real viewport input" % action)


func _open_calendar() -> void:
	_journal._tab = 1
	_journal.queue_redraw()
	await wait_frames(1)


func test_calendar_selects_current_week_and_live_input_scrolls_to_both_ends():
	Campaign.week = 4
	_journal.queue_free()
	await wait_frames(1)
	_journal = load("res://src/ui/academy_journal.gd").new()
	_journal._save = SaveSystem.new("user://test_journal_calendar_reopen_%d" % Time.get_ticks_usec())
	_viewport.add_child(_journal) # Reopening reads the current saved week.
	await _open_calendar()
	var selected: Variant = _journal.get("_calendar_i")
	assert_true(selected != null,
		"calendar has a row selection independent of Campaign.week")
	if selected == null:
		return
	assert_eq(int(selected), 3, "current week starts selected")
	var events := Campaign.calendar()
	for i in range(events.size() - 1):
		_press("cursor_down")
	assert_eq(_journal.get("_calendar_i"), events.size() - 1,
		"production viewport Down input reaches the final existing event")
	if not _journal.has_method("_body_rect") or not _journal.has_method("_calendar_layout"):
		assert_true(false, "calendar exposes the measured layout used by its renderer")
		return
	var body: Rect2 = _journal.call("_body_rect")
	var layout: Dictionary = _journal.call("_calendar_layout", body, UITheme.font())
	assert_eq(layout["visible_indices"][-1], events.size() - 1,
		"selected final event is inside the measured body")
	for row: Dictionary in layout["rows"]:
		var row_rect: Rect2 = row["rect"]
		assert_true(body.encloses(row_rect), "calendar row stays within tabs/footer body")
		var event: CalendarEventDef = events[row["index"]]
		var label_size := UITheme.font().get_multiline_string_size(event.label,
			HORIZONTAL_ALIGNMENT_LEFT, row["label_width"], 16, -1, TextServer.BREAK_WORD_BOUND)
		assert_true(label_size.y <= row_rect.size.y - 8.0,
			"complete existing label fits row %d without clipping" % event.week)
	for i in range(events.size() - 1):
		_press("cursor_up")
	assert_eq(_journal.get("_calendar_i"), 0,
		"production viewport Up input returns to the first existing event")


func test_calendar_layout_clamps_for_default_and_compact_resizes_and_keeps_current_visible():
	Campaign.week = 6
	_journal.queue_free()
	await wait_frames(1)
	_journal = load("res://src/ui/academy_journal.gd").new()
	_journal._save = SaveSystem.new("user://test_journal_calendar_resize_%d" % Time.get_ticks_usec())
	_viewport.add_child(_journal)
	await _open_calendar()
	if not _journal.has_method("_body_rect") or not _journal.has_method("_calendar_layout"):
		assert_true(false, "calendar exposes the measured layout used by its renderer")
		return
	var body: Rect2 = _journal.call("_body_rect")
	var layout: Dictionary = _journal.call("_calendar_layout", body, UITheme.font())
	assert_true(layout["visible_indices"].has(5), "last current week is visible on open at default size")
	for size in [Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		_viewport.size = size
		await wait_frames(1)
		body = _journal.call("_body_rect")
		layout = _journal.call("_calendar_layout", body, UITheme.font())
		assert_true(layout["visible_indices"].has(5), "current week remains visible at %s" % size)
		var last_rect: Rect2 = layout["rows"][-1]["rect"]
		assert_true(last_rect.end.y <= body.end.y, "final visible row fits at %s" % size)
		var selected: int = _journal.get("_calendar_i")
		assert_true(layout["visible_indices"].has(selected), "selection stays visible after resize at %s" % size)
		var selected_event: CalendarEventDef = Campaign.calendar()[selected]
		var selected_row: Dictionary = {}
		for row: Dictionary in layout["rows"]:
			if row["index"] == selected:
				selected_row = row
		assert_false(selected_row.is_empty(), "selected row is measured after resize at %s" % size)
		var label_size := UITheme.font().get_multiline_string_size(selected_event.label,
			HORIZONTAL_ALIGNMENT_LEFT, selected_row["label_width"], 16, -1, TextServer.BREAK_WORD_BOUND)
		assert_true(label_size.y <= selected_row["rect"].size.y - 8.0,
			"full current event label fits at %s" % size)
	_journal.set("_calendar_i", 5)
	_journal.set("_calendar_scroll", 5)
	var shorter: Array = Campaign.calendar().slice(0, 3)
	layout = _journal.call("_calendar_layout", body, UITheme.font(), shorter)
	assert_eq(_journal.get("_calendar_i"), 2, "selection clamps when a shorter calendar is supplied")
	assert_true(layout["visible_indices"].has(2), "clamped selection remains visible")
	assert_lte(_journal.get("_calendar_scroll"), 2, "scroll clamps to the shorter calendar")


func test_calendar_empty_and_out_of_range_week_is_safe_and_read_only():
	var events := Campaign.calendar()
	var original := events.duplicate()
	var original_week := Campaign.week
	var original_campaign := Campaign.to_dict()
	Campaign.week = events[-1].week + 5
	if not _journal.has_method("_body_rect") or not _journal.has_method("_calendar_layout"):
		assert_true(false, "calendar exposes the measured layout used by its renderer")
		return
	_journal._tab = 1
	_journal.queue_redraw()
	await wait_frames(1)
	assert_eq(Campaign.current_event(), null, "out-of-range week remains truthful")
	assert_true(_journal.call("_calendar_layout", _journal.call("_body_rect"), UITheme.font())["visible_indices"].size() > 0,
		"out-of-range week still permits browsing existing events")
	assert_true(_journal.call("_calendar_layout", _journal.call("_body_rect"), UITheme.font(), [])["visible_indices"].is_empty(),
		"empty data has no fabricated rows")
	Campaign.week = original_week
	assert_eq(Campaign.calendar(), original, "Calendar resource order and contents are preserved")
	assert_eq(Campaign.to_dict(), original_campaign, "Journal navigation itself leaves the Campaign unchanged")


func test_calendar_confirm_is_non_action_and_left_right_still_switch_tabs():
	assert_true(_journal._save.save_slot(0, {"sentinel": "manual"}), "write isolated manual-save sentinel")
	var manual_path: String = _journal._save.slot_path(0)
	var autosave_path: String = _journal._save.save_dir + "/autosave.json"
	var autosave := FileAccess.open(autosave_path, FileAccess.WRITE)
	autosave.store_string("autosave-sentinel")
	autosave.close()
	var settings := FileAccess.open(_test_prefs_path, FileAccess.WRITE)
	settings.store_string("settings-sentinel")
	settings.close()
	var manual_before := FileAccess.get_file_as_bytes(manual_path)
	var autosave_before := FileAccess.get_file_as_bytes(autosave_path)
	var settings_before := FileAccess.get_file_as_bytes(_test_prefs_path)
	var before := Campaign.to_dict()
	_journal._tab = 1
	_press("cursor_confirm")
	assert_eq(_journal._tab, 1, "Enter does not leave or act from Calendar")
	assert_eq(Campaign.to_dict(), before, "Calendar confirm leaves Campaign and RNG untouched")
	assert_eq(_journal._save.list_slots(3).size(), 1, "Calendar confirm creates no extra manual slot")
	_press("cursor_right")
	assert_eq(_journal._tab, 2, "Right still switches to Inventory")
	_press("cursor_left")
	assert_eq(_journal._tab, 1, "Left still switches back to Calendar")
	assert_eq(FileAccess.get_file_as_bytes(manual_path), manual_before, "manual save bytes are unchanged")
	assert_eq(FileAccess.get_file_as_bytes(autosave_path), autosave_before, "autosave bytes are unchanged")
	assert_eq(FileAccess.get_file_as_bytes(_test_prefs_path), settings_before, "settings bytes are unchanged")
