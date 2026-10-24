extends GutTest
## GH-108: the Journal Grades tab keeps every existing grade fact readable and
## reachable in default and compact windows, through the live Journal input path.
## Read-only view: nothing here may touch Campaign, saves or settings.

const SIZES := [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]
const MARKS := ["Coursework", "Battlefield", "The Arena", "Conduct"]

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
	_journal._save = SaveSystem.new("user://test_journal_grades_%d" % Time.get_ticks_usec())
	_original_prefs_path = AudioManager.prefs_path
	_test_prefs_path = "user://test_journal_grades_settings_%d.cfg" % Time.get_ticks_usec()
	AudioManager.prefs_path = _test_prefs_path
	_viewport.add_child(_journal)
	_journal._tab = 3
	await wait_frames(1)


func after_each() -> void:
	Campaign.reset_new_game(false)
	if FileAccess.file_exists(_test_prefs_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_prefs_path))
	AudioManager.prefs_path = _original_prefs_path


func _press_event(binding: InputEventKey) -> void:
	for pressed in [true, false]:
		var ev: InputEventKey = binding.duplicate()
		ev.pressed = pressed
		ev.echo = false
		_viewport.push_input(ev, true)


func _press(action: String) -> void:
	for binding in InputMap.action_get_events(action):
		if binding is InputEventKey:
			_press_event(binding)
			return
	assert_true(false, "%s has a keyboard binding" % action)


func _resize(size: Vector2i) -> void:
	_viewport.size = size
	await wait_frames(1)


func _layout() -> Dictionary:
	return _journal.call("_grades_layout", _journal.call("_body_rect"), UITheme.font())


## Every scroll position's layout, with all text seen and every item index reached.
func _sweep() -> Dictionary:
	var body: Rect2 = _journal.call("_body_rect")
	var first := _layout()
	var texts := ""
	var reached := {}
	for start in range(first["max_start"] + 1):
		_journal.set("_grades_scroll", start)
		var layout := _layout()
		assert_eq(layout["visible_indices"][0], start, "browse position %d is the first shown item" % start)
		for i in layout["visible_indices"]:
			reached[i] = true
		for op: Dictionary in layout["ops"]:
			var rect: Rect2 = op["rect"]
			assert_true(body.encloses(rect), "%s %s stays inside the book body" % [op["kind"], rect])
			if layout["scrolls"]:
				assert_true(rect.end.y <= layout["feedback_rect"].position.y + 0.5,
					"grade content clears the browse feedback line")
			if op["kind"] == "text":
				texts += op["text"] + "\n"
				assert_true(rect.size.x <= body.size.x + 0.5, "text '%s' fits the body width" % op["text"])
		if layout["scrolls"]:
			assert_true(body.encloses(layout["feedback_rect"]), "browse feedback is inside the body")
			var fw := UITheme.font().get_string_size(layout["feedback"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			assert_true(fw <= body.size.x, "browse feedback fits")
	_journal.set("_grades_scroll", 0)
	var top := _layout()
	assert_true(top["visible_indices"].has(1), "the first page shows Academy Standing with its heading")
	return {"texts": texts, "reached": reached, "count": first["items"].size(), "scrolls": first["scrolls"]}


func _assert_complete(seen: Dictionary) -> void:
	var g := Campaign.running_grade()
	var texts: String = seen["texts"]
	assert_eq(seen["reached"].size(), seen["count"], "every grade item is reachable by browsing")
	for needle in ["ACADEMY STANDING", "Semester %d  ·  Week %d" % [Campaign.semester, Campaign.week],
			str(g["rank"]), "%d  ·  %s" % [int(g["score"]), str(g["rank_name"])],
			"the grade if the semester ended today",
			"→ Next report card: end of Semester %d (Week %d)" % [Campaign.semester, Campaign.semester_end_week()]]:
		assert_true(texts.contains(needle), "'%s' is shown" % needle)
	for k in Grading.WEIGHTS:
		assert_true(texts.contains("↑ " + str(g["hints"][k])), "complete %s hint is shown" % k)
		assert_true(texts.contains("%d%%" % roundi(Grading.WEIGHTS[k] * 100)), "%s weight is shown" % k)
	for label in MARKS:
		assert_true(texts.contains(label), "%s mark is shown" % label)
	for rc in Campaign.report_cards:
		assert_true(texts.contains("Semester %d — %s (%s, %d)" % [int(rc["semester"]), rc["rank"], rc["rank_name"], int(rc["score"])]),
			"locked card for semester %d is shown" % int(rc["semester"]))


func _populate() -> void:
	Campaign.record_quiz(88)
	Campaign.record_quiz(72)
	Campaign.record_battle_score(76)
	Campaign.record_arena_run(3)
	Campaign.add_conduct(40)


func test_current_hint_origin_would_exceed_compact_body():
	# Evidence for the pre-#108 defect: the old fixed hint column started at body.x+510.
	await _resize(Vector2i(640, 360))
	var body: Rect2 = _journal.call("_body_rect")
	assert_lt(body.size.x, 510.0, "compact body is narrower than the old fixed hint origin")


func test_fresh_no_data_grades_complete_and_inside_body_at_every_size():
	for size in SIZES:
		await _resize(size)
		var seen := _sweep()
		_assert_complete(seen)
		assert_true(seen["texts"].contains("(no marks yet)"), "no-data state is explicit at %s" % size)
		assert_false(seen["texts"].contains("Semester 1 —"), "no history is invented at %s" % size)


func test_populated_scores_and_multiple_locked_cards_are_reachable():
	_populate()
	Campaign.close_semester()
	_populate()
	Campaign.close_semester()
	_populate()
	for size in SIZES:
		await _resize(size)
		_assert_complete(_sweep())


func test_compact_windows_page_to_first_and_final_item_through_live_input():
	_populate()
	Campaign.close_semester()
	await _resize(Vector2i(640, 360))
	var layout := _layout()
	assert_true(layout["scrolls"], "compact window needs browsing")
	assert_gt(layout["max_start"], 0, "there is something below the first page")
	_press("cursor_up")
	assert_eq(_journal.get("_grades_scroll"), 0, "Up at the top stays clamped")
	for i in range(layout["max_start"] + 3):
		_press("cursor_down")
	assert_eq(_journal.get("_grades_scroll"), layout["max_start"], "Down stops at the final page")
	var final := _layout()
	assert_eq(final["visible_indices"][-1], final["items"].size() - 1, "final locked card is visible at the end")
	for i in range(layout["max_start"] + 3):
		_press("cursor_up")
	assert_eq(_journal.get("_grades_scroll"), 0, "Up returns to the first page")


func test_custom_keys_browse_and_tab_or_reopen_resets():
	await _resize(Vector2i(640, 360))
	var original_down := InputMap.action_get_events("cursor_down")
	var custom := InputEventKey.new()
	custom.keycode = KEY_K
	custom.physical_keycode = KEY_K
	InputMap.action_erase_events("cursor_down")
	InputMap.action_add_event("cursor_down", custom)
	_press("cursor_down")
	assert_eq(_journal.get("_grades_scroll"), 1, "a rebound Down key browses Grades")
	InputMap.action_erase_events("cursor_down")
	for e in original_down:
		InputMap.action_add_event("cursor_down", e)
	_press("cursor_right")
	_press("cursor_left")
	assert_eq(_journal._tab, 3, "tabs still switch away and back")
	assert_eq(_journal.get("_grades_scroll"), 0, "browsing resets after a tab change")


func test_live_resize_clamps_browse_position():
	await _resize(Vector2i(640, 360))
	for i in range(30):
		_press("cursor_down")
	assert_gt(_journal.get("_grades_scroll"), 0)
	await _resize(Vector2i(1280, 720))
	_layout()
	assert_eq(_journal.get("_grades_scroll"), 0, "a window with room for all content resets the browse position")
	_assert_complete(_sweep())


func test_confirm_and_browsing_are_read_only():
	_populate()
	Campaign.close_semester()
	assert_true(_journal._save.save_slot(0, {"sentinel": "manual"}), "isolated manual sentinel")
	var manual_path: String = _journal._save.slot_path(0)
	var autosave_path: String = _journal._save.save_dir + "/autosave.json"
	var f := FileAccess.open(autosave_path, FileAccess.WRITE)
	f.store_string("autosave-sentinel")
	f.close()
	f = FileAccess.open(_test_prefs_path, FileAccess.WRITE)
	f.store_string("settings-sentinel")
	f.close()
	var manual_before := FileAccess.get_file_as_bytes(manual_path)
	var autosave_before := FileAccess.get_file_as_bytes(autosave_path)
	var settings_before := FileAccess.get_file_as_bytes(_test_prefs_path)
	var campaign_before := Campaign.to_dict()
	var cards_before := Campaign.report_cards.duplicate(true)
	var deliveries_before := Campaign.report_card_deliveries.duplicate(true)
	for size in SIZES:
		await _resize(size)
		for i in range(12):
			_press("cursor_down")
		_press("cursor_confirm")
		assert_eq(_journal._tab, 3, "Enter is actionless on Grades at %s" % size)
	assert_eq(Campaign.to_dict(), campaign_before, "Campaign (samples, cards, rewards, week) is unchanged")
	assert_eq(Campaign.report_cards, cards_before, "locked report cards are unchanged")
	assert_eq(Campaign.report_card_deliveries, deliveries_before, "reward delivery records are unchanged")
	assert_eq(_journal._save.list_slots(3).size(), 1, "no extra save slot appears")
	assert_eq(FileAccess.get_file_as_bytes(manual_path), manual_before, "manual save bytes unchanged")
	assert_eq(FileAccess.get_file_as_bytes(autosave_path), autosave_before, "autosave bytes unchanged")
	assert_eq(FileAccess.get_file_as_bytes(_test_prefs_path), settings_before, "settings bytes unchanged")


func test_grades_close_is_consumed_and_exploration_resumes():
	var castle_viewport := SubViewport.new()
	castle_viewport.size = Vector2i(640, 360)
	castle_viewport.handle_input_locally = true
	add_child_autofree(castle_viewport)
	var castle: CastleScene = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	castle_viewport.add_child(castle)
	await wait_frames(1)
	for pressed in [true, false]:
		var j := InputEventKey.new()
		j.keycode = KEY_J
		j.physical_keycode = KEY_J
		j.pressed = pressed
		castle_viewport.push_input(j, true)
	assert_not_null(castle._journal, "J opens the Journal")
	castle._journal._tab = 3
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = KEY_ESCAPE
		e.physical_keycode = KEY_ESCAPE
		e.pressed = pressed
		castle_viewport.push_input(e, true)
	assert_null(castle._journal, "Esc closes the Grades page")
	assert_eq(castle._menu_context, "", "the close did not leak into the system menu")
	assert_false(castle.busy(), "exploration input is usable again")
