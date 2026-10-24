extends GutTest
## GH-96: the production Roster stays readable/reachable inside the Journal
## book at compact viewports, using native viewport key dispatch.

var _viewport: SubViewport
var _castle: CastleScene
var _journal: AcademyJournal
var _audio_prefs_path: String
var _dialogue_prefs_path: String


func before_each() -> void:
	Campaign.reset_new_game(false)
	_audio_prefs_path = AudioManager.prefs_path
	_dialogue_prefs_path = DialoguePreferences.prefs_path
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 450)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	_viewport.add_child(_castle)
	await wait_frames(1)
	_press(KEY_J)
	_journal = _castle._journal
	_journal._save = SaveSystem.new("user://gh96-roster-saves-%d" % Time.get_ticks_usec())
	_journal._save.save_slot(0, {"marker": "manual"})
	_journal._save.save_autosave({"marker": "autosave"})
	AudioManager.prefs_path = "user://gh96-audio-%d.cfg" % Time.get_ticks_usec()
	DialoguePreferences.prefs_path = "user://gh96-dialogue-%d.cfg" % Time.get_ticks_usec()
	_write_sentinel(AudioManager.prefs_path, "audio-settings-sentinel")
	_write_sentinel(DialoguePreferences.prefs_path, "dialogue-settings-sentinel")


func after_each() -> void:
	Campaign.reset_new_game(false)
	AudioManager.prefs_path = _audio_prefs_path
	DialoguePreferences.prefs_path = _dialogue_prefs_path


func _write_sentinel(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _press(keycode: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	event.echo = echo
	_viewport.push_input(event, true)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	_viewport.push_input(release, true)


func test_compact_roster_pages_all_existing_details_and_keeps_selected_row_visible() -> void:
	assert_not_null(_journal)
	_journal.visible = true
	var campaign_before := Campaign.to_dict()
	var protected_paths := [_journal._save.slot_path(0), _journal._save.autosave_path(), AudioManager.prefs_path, DialoguePreferences.prefs_path]
	var protected_bytes: Array[PackedByteArray] = []
	for path in protected_paths:
		protected_bytes.append(FileAccess.get_file_as_bytes(path))
	var sizes := [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]
	for size in sizes:
		_viewport.size = size
		_journal.queue_redraw()
		await wait_frames(1)
		var body: Rect2 = _journal._roster_body_rect()
		var frame_margin := Vector2(minf(80.0, size.x * 0.08), minf(56.0, size.y * 0.08))
		var book := Rect2(frame_margin, Vector2(size) - frame_margin * 2.0)
		var footer_hint := _journal._roster_footer_hint()
		var footer_bounds: Rect2 = _journal._roster_footer_bounds(book, UITheme.font(), footer_hint)
		var measured_footer_width: float = UITheme.font().get_string_size(footer_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		assert_lte(absf(footer_bounds.size.x - measured_footer_width), 0.01,
			"footer bounds use the active font's measured text width at %s" % size)
		assert_gte(footer_bounds.position.x, book.position.x + AcademyJournal.ROSTER_FOOTER_SAFE_INSET,
			"footer clears the left corner filigree at %s" % size)
		assert_lte(footer_bounds.end.x, book.end.x - AcademyJournal.ROSTER_FOOTER_SAFE_INSET,
			"footer clears the right corner filigree at %s" % size)
		assert_lte(footer_bounds.end.y, book.end.y - AcademyJournal.ROSTER_FOOTER_SAFE_INSET,
			"footer glyph bounds clear the lower frame ornament at %s" % size)
		var list_width: float = clampf(body.size.x * 0.29, 112.0, 210.0)
		var detail_width := body.size.x - list_width - 14.0
		assert_gt(body.size.x, list_width + 14.0, "detail pane has usable width at %s" % size)
		assert_gt(body.size.y, 0.0, "body remains inside the book at %s" % size)
		_journal._roster_i = 0
		_journal._roster_detail_page = 0
		var snap: Dictionary = _journal._snaps[0]
		var lines: Array[String] = _journal._roster_detail_lines(snap, UITheme.font(), detail_width)
		var page_size: int = _journal._roster_detail_page_size(body.size.y)
		var rendered_pages: Array[String] = []
		var page_count := ceili(float(lines.size()) / page_size)
		for page in range(page_count):
			assert_eq(_journal._roster_detail_page, page, "detail page %d is reachable with viewport input" % (page + 1))
			var first_line := page * page_size
			var last_line := mini(lines.size(), (page + 1) * page_size)
			for i in range(first_line, last_line):
				var measured := UITheme.font().get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
				assert_lte(measured, detail_width - 2.0, "rendered detail line fits its pane: %s" % lines[i])
				rendered_pages.append(lines[i])
			var last_baseline := body.position.y + 60.0 + (last_line - first_line - 1) * 18.0
			var last_bottom := last_baseline + UITheme.font().get_descent(14)
			assert_lte(last_bottom, body.end.y - UITheme.font().get_ascent(14),
				"detail text clears the footer using actual font metrics at %s" % size)
			if page + 1 == page_count:
				assert_gte(footer_bounds.position.y - last_bottom, 1.0,
					"final detail line clears the measured Roster footer at %s" % size)
			if page + 1 < page_count:
				_press(KEY_PAGEDOWN)
			else:
				_press(KEY_PAGEDOWN)
				assert_eq(_journal._roster_detail_page, page, "PageDown clamps at the final detail page")
		assert_true(rendered_pages.has("Stats"), "the selected detail exposes the stat section")
		for label in AcademyJournal.STAT_LABELS:
			assert_true(" ".join(rendered_pages).contains(label), "all eight stats remain reachable: %s" % label)
			var stat_value: String = str(snap["stats"][AcademyJournal.STAT_KEYS[AcademyJournal.STAT_LABELS.find(label)]])
			assert_true(" ".join(rendered_pages).contains(label + " " + stat_value),
				"the rendered stat keeps its selected value: %s %s" % [label, stat_value])
		assert_true(" ".join(rendered_pages).contains("Carries"), "carried gear remains reachable")
		assert_true(" ".join(rendered_pages).contains("Skills"), "skills remain reachable")
		assert_eq(_journal._roster_i, 0, "the first roster member is selected after resize")
		var first_visible_rows: int = maxi(1, int(floor((body.size.y - 4.0) / 26.0)))
		assert_true(_journal._roster_i < first_visible_rows, "the selected first row is visible at %s" % size)
		for member_i in range(_journal._snaps.size()):
			_press(KEY_DOWN)
			assert_eq(_journal._snaps[_journal._roster_i]["id"], _journal._snaps[(member_i + 1) % _journal._snaps.size()]["id"],
				"Down selects each roster member at %s" % size)
		_journal._roster_detail_page = 999
		_journal.queue_redraw()
		await wait_frames(1)
		var final_page_count := maxi(1, ceili(float(lines.size()) / _journal._roster_detail_page_size(body.size.y)))
		assert_eq(_journal._roster_detail_page, final_page_count - 1, "resize/render clamps detail page to final page")
		_journal._roster_i = _journal._snaps.size() - 1
		_press(KEY_DOWN)
		assert_eq(_journal._roster_i, 0, "Down wraps from the final member to the first")
		_press(KEY_UP)
		assert_eq(_journal._roster_i, _journal._snaps.size() - 1, "Up reaches the final member")
		var rows_visible: int = maxi(1, int(floor((body.size.y - 4.0) / 26.0)))
		var first_visible: int = clampi(_journal._roster_i - rows_visible + 1, 0, maxi(0, _journal._snaps.size() - rows_visible))
		assert_true(_journal._roster_i >= first_visible and _journal._roster_i < first_visible + rows_visible,
			"the selected final roster row is visible at %s" % size)
	assert_eq(Campaign.to_dict(), campaign_before, "read-only roster browsing preserves complete Campaign and RNG")
	for i in range(protected_paths.size()):
		assert_eq(FileAccess.get_file_as_bytes(protected_paths[i]), protected_bytes[i],
			"roster browsing preserves manual/autosave/settings bytes for %s" % protected_paths[i].get_file())


func test_detail_page_keys_are_consumed_at_boundaries_and_close_returns_to_exploration() -> void:
	var page_before: int = _journal._roster_detail_page
	_press(KEY_PAGEUP)
	assert_eq(_journal._roster_detail_page, page_before, "PageUp clamps at the first detail page")
	_press(KEY_PAGEDOWN, true)
	assert_eq(_journal._roster_detail_page, page_before, "an echo cannot page or leak into exploration")
	_press(KEY_J)
	assert_null(_castle._journal, "J closes the Journal after detail browsing")
	assert_eq(_castle._menu_context, "", "the close key is consumed before castle exploration")
	assert_false(_castle.busy(), "exploration is usable after close")


func test_empty_and_multiple_equipment_and_skills_remain_present_and_missing_portrait_falls_back() -> void:
	var sample: Dictionary = _journal._snaps[0].duplicate(true)
	sample["id"] = "gh96_missing_portrait"
	sample["items"] = ["Iron Sword", "Vulnerary", "Longbow"]
	sample["skills"] = ["Adept", "Vantage"]
	assert_null(_journal._portrait(sample["id"]), "an unknown portrait uses the existing no-portrait fallback")
	var lines: Array = _journal._roster_detail_lines(sample, UITheme.font(), 300.0)
	var combined := " ".join(lines)
	for item in sample["items"]:
		assert_true(combined.contains(item), "all carried equipment remains present: %s" % item)
	for skill in sample["skills"]:
		assert_true(combined.contains(skill), "all existing skills remain present: %s" % skill)
	sample["items"] = []
	sample["skills"] = []
	var empty_lines: Array[String] = _journal._roster_detail_lines(sample, UITheme.font(), 300.0)
	assert_true(empty_lines.has("Carries"), "the empty pack section remains labeled")
	assert_true(empty_lines.has("Skills"), "the empty skill section remains labeled")
	assert_eq(empty_lines.count("—"), 2, "empty pack and skills each have explicit readable states")
