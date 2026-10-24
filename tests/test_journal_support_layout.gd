extends GutTest
## GH-124: earned support records stay readable in the production Journal
## viewport through compact sizing, live resize, and the shipped key path.

const SIZES := [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]

var _viewport: SubViewport
var _journal: AcademyJournal
var _old_prefs_path: String
var _test_prefs_path: String
var _old_active_house: String
var _old_down_events: Array[InputEvent]


func before_each() -> void:
	Campaign.reset_new_game(false)
	_viewport = SubViewport.new()
	_viewport.size = SIZES[0]
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_journal = load("res://src/ui/academy_journal.gd").new()
	_journal._save = SaveSystem.new("user://test_journal_support_layout_%d" % Time.get_ticks_usec())
	_old_prefs_path = AudioManager.prefs_path
	_old_active_house = Roster.active_house
	_old_down_events.clear()
	for event in InputMap.action_get_events("cursor_down"):
		_old_down_events.append(event.duplicate())
	_test_prefs_path = "user://test_journal_support_layout_settings_%d.cfg" % Time.get_ticks_usec()
	AudioManager.prefs_path = _test_prefs_path
	var settings := FileAccess.open(_test_prefs_path, FileAccess.WRITE)
	settings.store_string("[sentinel]\nreference = unchanged\n")
	settings.close()
	_viewport.add_child(_journal)
	_journal._tab = 6
	await wait_frames(1)


func after_each() -> void:
	Campaign.reset_new_game(false)
	for slot in [0, 2]:
		_remove_scratch(_journal._save.slot_path(slot))
	_remove_scratch(_journal._save.autosave_path())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_journal._save.save_dir))
	if FileAccess.file_exists(_test_prefs_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_prefs_path))
	AudioManager.prefs_path = _old_prefs_path
	Roster.active_house = _old_active_house
	InputMap.action_erase_events("cursor_down")
	for event: InputEvent in _old_down_events:
		InputMap.action_add_event("cursor_down", event)


func _remove_scratch(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute)


func _earned_max_chain() -> void:
	# Supplementary display fixture: use the real chain thresholds and consent
	# API to supply all existing Liora C/B/A/S receipts; this is not an earned
	# playthrough claim and does not play a conversation.
	var state := SupportRegistry.build_state()
	state.add_points("kai", "liora", 120)
	state.consent_romance("kai", "liora")
	state.add_points("kai", "liora", 80)
	for rank in ["C", "B", "A", "S"]:
		state.mark_viewed("kai_liora", rank)
	state.viewed["kai_liora:B"] = false
	state.viewed["kai_liora:S"] = false
	Campaign.support_save = state.save_state()


func _press(action: String) -> void:
	for binding in InputMap.action_get_events(action):
		if binding is InputEventKey:
			for pressed in [true, false]:
				var ev: InputEventKey = binding.duplicate()
				ev.pressed = pressed
				ev.echo = false
				_viewport.push_input(ev, true)
			return
	assert_true(false, "%s has a keyboard binding" % action)


func _press_keycode(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	_viewport.push_input(ev, true)
	ev = InputEventKey.new()
	ev.keycode = keycode
	_viewport.push_input(ev, true)


func _resize(size: Vector2i) -> void:
	_viewport.size = size
	await wait_frames(1)


func test_complete_existing_earned_record_fits_actual_body_and_footer_at_all_sizes() -> void:
	_earned_max_chain()
	_journal._support_i = 1
	for size in SIZES:
		await _resize(size)
		var body: Rect2 = _journal._body_rect()
		var font: Font = UITheme.font()
		_journal._support_detail_page = 0
		var layout: Dictionary = _journal._support_layout(body, font)
		assert_eq(layout["record"]["rank"], "S", "current companion and rank remain visible at %s" % size)
		assert_true(body.encloses(layout["title"]["rect"]), "heading glyphs fit actual body at %s" % size)
		assert_true(body.encloses(layout["header"]["rect"]), "companion/rank glyphs fit body at %s" % size)
		var reached := {}
		var page_count: int = layout["page_count"]
		for page in range(page_count):
			layout = _journal._support_layout(body, font)
			var footer: Dictionary = layout["feedback"]
			var footer_width := font.get_string_size(footer["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			assert_lte(footer_width, body.size.x, "truthful pager hint fits at %s" % size)
			assert_true(body.encloses(footer["rect"]), "footer glyph bounds fit body at %s" % size)
			for status: Dictionary in layout["statuses"]:
				var rect: Rect2 = status["rect"]
				reached[status["index"]] = status["text"]
				assert_true(body.encloses(rect), "%s glyph fits actual body at %s" % [status["text"], size])
				assert_lte(rect.end.y, footer["rect"].position.y,
					"%s glyph clears actual browse footer at %s" % [status["text"], size])
				assert_lte(rect.end.x, body.end.x, "%s status is not clipped horizontally" % status["text"])
			if page + 1 < page_count:
				_press_keycode(KEY_PAGEDOWN)
		assert_eq(reached.size(), 4, "all C/B/A/S status rows are reachable at %s" % size)
		assert_eq([reached.get(0), reached.get(1), reached.get(2), reached.get(3)],
			["C conversation  ·  Viewed", "B conversation  ·  Unviewed",
			"A conversation  ·  Viewed", "S conversation  ·  Unviewed"],
			"every saved viewed/unviewed status remains exact at %s" % size)
		for _page in range(page_count):
			_press_keycode(KEY_PAGEUP)
		assert_eq(_journal._support_detail_page, 0, "PageUp returns to the first status page at %s" % size)
		_journal._support_detail_page = 0


func test_old_full_record_block_overlaps_the_compact_browse_footer() -> void:
	_earned_max_chain()
	await _resize(Vector2i(640, 360))
	var body: Rect2 = _journal._body_rect()
	var font: Font = UITheme.font()
	var old_last_baseline := body.position.y + 8.0 + 38.0 + 22.0 + 3 * 19.0
	var old_last_bottom := old_last_baseline + font.get_descent(14)
	var old_footer_top := body.end.y - 4.0 - font.get_ascent(13)
	print("GH-124 compact production SubViewport: body=%s, old S-status bottom=%.1f, footer top=%.1f" %
		[body, old_last_bottom, old_footer_top])
	assert_gt(old_last_bottom, old_footer_top,
		"the former monolithic C/B/A/S block collided with the actual compact footer")


func test_support_navigation_preserves_state_bytes_and_selection_through_resize() -> void:
	_earned_max_chain()
	var before := Campaign.to_dict()
	var active_house := Roster.active_house
	assert_true(_journal._save.save_slot(0, {"sentinel": "manual"}), "manual sentinel is written")
	assert_true(_journal._save.save_autosave({"sentinel": "autosave"}), "Autosave sentinel is written")
	var protected_paths := [_journal._save.slot_path(0), _journal._save.autosave_path(), _test_prefs_path]
	var saved_bytes: Array[PackedByteArray] = []
	for path: String in protected_paths:
		saved_bytes.append(FileAccess.get_file_as_bytes(path))
	_journal._support_i = 0
	_press("cursor_down")
	assert_eq(_journal._support_i, 1, "Down selects the final current-roster chain")
	await _resize(Vector2i(640, 360))
	assert_eq(_journal._support_i, 1, "live shrink retains selected companion")
	_press_keycode(KEY_PAGEDOWN)
	var compact_layout: Dictionary = _journal._support_layout(_journal._body_rect(), UITheme.font())
	assert_gt(compact_layout["page_count"], 1, "complete compact record pages its statuses")
	assert_eq(_journal._support_detail_page, 1, "PageDown reaches the next detail page via dispatched input")
	await _resize(Vector2i(1280, 720))
	var restored: Dictionary = _journal._support_layout(_journal._body_rect(), UITheme.font())
	assert_lt(_journal._support_detail_page, restored["page_count"], "detail selection stays valid after restore")
	_press("cursor_up")
	assert_eq(_journal._support_i, 0, "Up returns to the first companion")
	_press("cursor_up")
	assert_eq(_journal._support_i, 1, "Up wraps to the final companion")
	assert_eq(Campaign.to_dict(), before, "reference navigation and resize preserve Campaign/support/RNG/progression")
	assert_eq(Roster.active_house, active_house, "reference navigation preserves roster selection")
	for i in range(protected_paths.size()):
		assert_eq(FileAccess.get_file_as_bytes(protected_paths[i]), saved_bytes[i],
			"reference navigation preserves manual/autosave/settings bytes at %s" % protected_paths[i].get_file())


func test_existing_left_right_tab_navigation_and_enter_stay_actionless() -> void:
	_earned_max_chain()
	var before := Campaign.to_dict()
	_press("cursor_confirm")
	assert_eq(_journal._tab, 6, "Enter on Supports remains actionless")
	assert_eq(Campaign.to_dict(), before, "Enter does not change support state")
	_press("cursor_left")
	assert_eq(_journal._tab, 5, "Left still changes Journal tabs")
	_press("cursor_right")
	assert_eq(_journal._tab, 6, "Right returns to Supports")
	assert_eq(Campaign.to_dict(), before, "tab navigation stays read-only")


func test_additional_cursor_key_still_browses_current_support_chains() -> void:
	var custom := InputEventKey.new()
	custom.keycode = KEY_N
	InputMap.action_add_event("cursor_down", custom)
	_press_keycode(KEY_N)
	assert_eq(_journal._support_i, 1, "additional cursor key selects the next authored support chain")


func test_empty_roster_wording_wraps_and_no_rank_record_stays_complete() -> void:
	Roster.active_house = "tidemark"
	for size in SIZES:
		await _resize(size)
		var body: Rect2 = _journal._body_rect()
		var layout: Dictionary = _journal._support_layout(body, UITheme.font())
		assert_true(body.encloses(layout["title"]["rect"]), "empty-state heading fits body at %s" % size)
		assert_true(body.encloses(layout["empty_message"]["rect"]), "complete no-chain wording wraps in body at %s" % size)
		assert_gt(layout["empty_message"]["rect"].size.y, 0.0, "empty wording has active-font height at %s" % size)
	Roster.active_house = "emberwing"
	var kael := _entry(_journal._support_entries(), "kael")
	assert_eq(kael["rank"], "", "Kael has no earned rank in a fresh campaign")
	assert_true(kael["conversations"].is_empty(), "Kael has no earned conversations in a fresh campaign")
	var body: Rect2 = _journal._body_rect()
	var empty_record: Dictionary = _journal._support_layout(body, UITheme.font(), [kael])
	assert_true(body.encloses(empty_record["header"]["rect"]), "no-rank text stays complete in the body")
	assert_true(body.encloses(empty_record["empty"]["rect"]), "no-conversations text stays complete in the body")


func test_existing_maximum_support_receipts_survive_journal_save_reload() -> void:
	_earned_max_chain()
	var expected := Campaign.support_save.duplicate(true)
	_journal._do_save(2)
	Campaign.reset_new_game(false)
	assert_true(Campaign.load_from_slot(2, _journal._save), "ordinary Journal save reloads")
	_journal.hide()
	var reopened: AcademyJournal = load("res://src/ui/academy_journal.gd").new()
	reopened._save = _journal._save
	_viewport.add_child(reopened)
	await wait_frames(1)
	reopened._tab = 6
	var liora := _entry(reopened._support_entries(), "liora")
	assert_eq(liora["rank"], "S", "existing S rank remains in the reference")
	assert_eq(liora["conversations"].size(), 4, "all unlocked rank receipts remain available")
	assert_eq(Campaign.support_save["viewed"], expected["viewed"], "viewed/unviewed receipts survive reload")
	assert_eq(Campaign.support_save["ranks"], expected["ranks"], "rank state survives reload")


func _entry(entries: Array, id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if str(entry["id"]) == id:
			return entry
	return {}
