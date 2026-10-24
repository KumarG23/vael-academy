extends GutTest
## Issue #117: the Journal System tab keeps all twelve existing rows, their
## complete data and the selected row readable/reachable at every supported size
## through live Journal input. Browsing/resizing is read-only; deliberate
## preference changes use disposable stores and restore live autoload state.

const SIZES := [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]
const LONG_CHAPTER := "closing_rite_thornrook_extended_variant"

var _viewport: SubViewport
var _journal: AcademyJournal
var _saved_paths := {}
var _saved_audio := []
var _saved_speed := ""
var _saved_extras := {}
var _scratch: Array[String] = []
var _save_dir := ""


func before_each() -> void:
	Campaign.reset_new_game(false, 117)
	_saved_paths = {"audio": AudioManager.prefs_path, "dialogue": DialoguePreferences.prefs_path,
		"keys": KeyboardPreferences.prefs_path}
	_saved_audio = [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]
	_saved_speed = DialoguePreferences.text_speed
	_saved_extras = KeyboardPreferences._extras.duplicate()
	var stamp := Time.get_ticks_usec()
	AudioManager.prefs_path = _scratch_path("audio_%d.cfg" % stamp)
	DialoguePreferences.prefs_path = _scratch_path("dialogue_%d.cfg" % stamp)
	KeyboardPreferences.prefs_path = _scratch_path("keys_%d.cfg" % stamp)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_journal = AcademyJournal.new()
	_save_dir = "user://test_journal_system_%d" % stamp
	_journal._save = SaveSystem.new(_save_dir)
	_viewport.add_child(_journal)
	_journal._tab = 4
	await wait_process_frames(2)


func after_each() -> void:
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras = _saved_extras.duplicate()
	KeyboardPreferences._apply()
	AudioManager.master_volume = _saved_audio[0]
	AudioManager.music_volume = _saved_audio[1]
	AudioManager.sfx_volume = _saved_audio[2]
	DialoguePreferences.text_speed = _saved_speed
	AudioManager.prefs_path = _saved_paths["audio"]
	DialoguePreferences.prefs_path = _saved_paths["dialogue"]
	KeyboardPreferences.prefs_path = _saved_paths["keys"]
	for path in _scratch:
		for suffix in ["", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_scratch.clear()
	_remove_slot_files()
	Campaign.reset_new_game(false)


func _scratch_path(name: String) -> String:
	var path := "user://test_journal_system_" + name
	_scratch.append(path)
	return path


func _remove_slot_files() -> void:
	var dir := DirAccess.open(_save_dir)
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir))


func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_viewport.push_input(event, true)


func _resize(size: Vector2i) -> void:
	_viewport.size = size
	await wait_process_frames(2)


func _layout() -> Dictionary:
	return _journal.call("_system_layout", _journal.call("_body_rect"), UITheme.font())


func _row(layout: Dictionary, index: int) -> Variant:
	for row: Dictionary in layout.rows:
		if row.index == index:
			return row
	return null


func _assert_row_readable(row: Dictionary, body: Rect2, context: String) -> void:
	var font := UITheme.font()
	assert_true(body.encloses(row.rect), "row %d inside body %s" % [row.index, context])
	assert_true(row.rect.encloses(row.label_rect), "label inside row %d %s" % [row.index, context])
	assert_eq(row.label, AcademyJournal.SYS_ROWS[row.index][0])
	for r: Rect2 in row.line_rects:
		assert_true(row.rect.encloses(r), "data line inside row %d %s" % [row.index, context])
		assert_false(r.intersects(row.label_rect), "data clear of label %d %s" % [row.index, context])
	if row.has("bar_rect"):
		assert_true(row.rect.encloses(row.bar_rect))
		assert_true(row.rect.encloses(row.pct_rect))
		assert_false(row.bar_rect.intersects(row.pct_rect))
		assert_false(row.bar_rect.intersects(row.label_rect))
		assert_gte(row.bar_rect.size.x, 24.0)
	var kind: String = row.kind
	var text := _journal.call("_system_data_text", kind) as String
	if text != "":
		assert_eq(" ".join(row.lines), text, "complete data text for row %d %s" % [row.index, context])
	assert_eq(row.rect.size.y >= font.get_height(14), true)


func _write_slots() -> void:
	_journal._save.save_slot(0, {"campaign": {"current_chapter_id": LONG_CHAPTER, "casual_mode": true},
		"battle": {"chapter_id": "mock_battle", "battle_over": false}})
	_journal._save.save_slot(1, {"campaign": Campaign.to_dict()})
	_journal._refresh_slots()


func _file_bytes() -> Dictionary:
	var out := {}
	var dir := DirAccess.open(_save_dir)
	if dir != null:
		for f in dir.get_files():
			out[f] = FileAccess.get_file_as_bytes(_save_dir + "/" + f)
	for path in [AudioManager.prefs_path, DialoguePreferences.prefs_path, KeyboardPreferences.prefs_path]:
		if FileAccess.file_exists(path):
			out[path] = FileAccess.get_file_as_bytes(path)
	return out


func test_row_order_and_kinds_unchanged():
	var kinds: Array = []
	for row in AcademyJournal.SYS_ROWS:
		kinds.append(row[1])
	assert_eq(kinds, ["save0", "save1", "save2", "load0", "load1", "load2", "music", "sfx", "master",
		"text_speed", "title", "keyboard"])


func test_all_rows_readable_and_reachable_at_every_size_and_live_resize():
	_write_slots()
	for size in SIZES + [Vector2i(800, 450), Vector2i(1280, 720), Vector2i(640, 360)]:
		await _resize(size)
		var body: Rect2 = _journal.call("_body_rect")
		var seen := {}
		for step in range(AcademyJournal.SYS_ROWS.size() * 2 + 1):
			var layout := _layout()
			var sel: Variant = _row(layout, _journal._sys_i)
			assert_not_null(sel, "selected row %d visible at %s" % [_journal._sys_i, size])
			for row: Dictionary in layout.rows:
				_assert_row_readable(row, body, str(size))
				seen[row.index] = true
			for k in range(layout.rows.size() - 1):
				assert_lte(layout.rows[k].rect.end.y, layout.rows[k + 1].rect.position.y + 0.01, "rows do not overlap")
				assert_eq(layout.rows[k + 1].index, layout.rows[k].index + 1)
			if layout.windowed:
				assert_true(layout.rows.size() < AcademyJournal.SYS_ROWS.size())
			else:
				assert_eq(layout.rows.size(), AcademyJournal.SYS_ROWS.size())
			_tap(KEY_DOWN)
		assert_eq(seen.size(), AcademyJournal.SYS_ROWS.size(), "every row reachable at %s" % size)
		# Up wraps from the first row to the final one.
		_journal._sys_i = 0
		_tap(KEY_UP)
		assert_eq(_journal._sys_i, AcademyJournal.SYS_ROWS.size() - 1)
		assert_not_null(_row(_layout(), 11))
		# Final row survives a resize in both directions.
		for other in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(800, 450)]:
			await _resize(other)
			assert_eq(_journal._sys_i, 11)
			assert_not_null(_row(_layout(), 11), "selected final row visible at %s" % other)


func test_compact_body_stays_clear_of_footer_and_keeps_font_size():
	for size in SIZES:
		await _resize(size)
		var body: Rect2 = _journal.call("_body_rect")
		var footer: Rect2 = _journal.call("_footer_rect", "←/→ tab      ↑/↓ move      Enter select      J / Esc close")
		assert_lte(body.end.y, footer.position.y + 0.01, "body clear of footer at %s" % size)
		assert_eq(AcademyJournal.SYS_FONT_SIZE, 14, "no squeezed font")


func test_long_slot_summaries_and_volume_values():
	_write_slots()
	for size in SIZES:
		await _resize(size)
		var body: Rect2 = _journal.call("_body_rect")
		for volumes in [[0.0, 0.0, 0.0], [1.0, 1.0, 1.0], [0.3, 0.5, 0.7]]:
			AudioManager.music_volume = volumes[0]
			AudioManager.sfx_volume = volumes[1]
			AudioManager.master_volume = volumes[2]
			for i in range(AcademyJournal.SYS_ROWS.size()):
				_journal._sys_i = i
				var layout := _layout()
				var row: Dictionary = _row(layout, i)
				assert_not_null(row)
				_assert_row_readable(row, body, str(size))
				if row.has("bar_rect"):
					var expected := roundi(float(row.value) * 100)
					assert_eq(row.pct, "%d%%" % expected)
		_journal._sys_i = 0
		var slot_row: Dictionary = _row(_layout(), 0)
		assert_string_contains(" ".join(slot_row.lines), LONG_CHAPTER)
		assert_string_contains(" ".join(slot_row.lines), "Casual")
		assert_string_contains(" ".join(slot_row.lines), "⚔ mid-battle")
	_journal._sys_i = 2
	assert_eq(" ".join((_row(_layout(), 2) as Dictionary).lines), "— empty —")


func test_text_speeds_and_key_summaries_complete():
	for size in SIZES:
		await _resize(size)
		var body: Rect2 = _journal.call("_body_rect")
		for mode in DialoguePreferences.MODES:
			DialoguePreferences.text_speed = mode
			_journal._sys_i = 9
			var row: Dictionary = _row(_layout(), 9)
			assert_not_null(row)
			_assert_row_readable(row, body, str(size))
			assert_eq(" ".join(row.lines), DialoguePreferences.label())
		for count in [0, 6]:
			KeyboardPreferences._extras.clear()
			for a in range(count):
				KeyboardPreferences._extras[KeyboardPreferences.ACTIONS[a]] = KEY_F1 + a
			_journal._sys_i = 11
			var krow: Dictionary = _row(_layout(), 11)
			_assert_row_readable(krow, body, str(size))
			assert_eq(" ".join(krow.lines), "Default keys" if count == 0 else "Default + %d additional" % count)


func test_browse_and_resize_leave_state_and_files_unchanged():
	_write_slots()
	var campaign := Campaign.to_dict().duplicate(true)
	var files := _file_bytes()
	var volumes := [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]
	for size in SIZES:
		await _resize(size)
		for i in range(14):
			_tap(KEY_DOWN)
		for i in range(5):
			_tap(KEY_UP)
	assert_eq(Campaign.to_dict(), campaign)
	assert_eq(_file_bytes(), files)
	assert_eq([AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume], volumes)
	assert_false(FileAccess.file_exists(AudioManager.prefs_path))
	assert_false(FileAccess.file_exists(DialoguePreferences.prefs_path))
	assert_false(FileAccess.file_exists(KeyboardPreferences.prefs_path))


func test_left_right_adjusts_preferences_and_enter_is_actionless_on_them():
	await _resize(Vector2i(640, 360))
	_journal._sys_i = 6
	AudioManager.music_volume = 0.5
	_tap(KEY_RIGHT)
	assert_almost_eq(AudioManager.music_volume, 0.6, 0.001)
	assert_eq(_journal._tab, 4, "Left/Right adjusts instead of switching tabs on a volume row")
	assert_true(FileAccess.file_exists(AudioManager.prefs_path), "persisted through production path")
	_journal._sys_i = 9
	DialoguePreferences.text_speed = "normal"
	_tap(KEY_RIGHT)
	assert_ne(DialoguePreferences.text_speed, "normal")
	var before := Campaign.to_dict().duplicate(true)
	var files := _file_bytes()
	_tap(KEY_ENTER)
	assert_eq(Campaign.to_dict(), before)
	assert_eq(_file_bytes(), files)
	_journal._sys_i = 10
	_tap(KEY_LEFT)
	assert_eq(_journal._tab, 3, "Left on a non-adjustable row switches tab")


func test_save_and_empty_load_feedback_one_based_at_compact_size():
	await _resize(Vector2i(640, 360))
	_journal._sys_i = 2
	_tap(KEY_ENTER)
	assert_eq(_journal._toast, "Saved to slot 3")
	assert_true(_journal._save.has_slot(2))
	assert_eq(_journal._sys_i, 2)
	_journal._sys_i = 3
	_tap(KEY_ENTER)
	assert_eq(_journal._toast, "Slot 1 is empty")


func test_keyboard_editor_return_preserves_selected_row():
	await _resize(Vector2i(640, 360))
	_journal._sys_i = 11
	_tap(KEY_ENTER)
	assert_not_null(_journal._keys_editor)
	await _resize(Vector2i(800, 450))
	_tap(KEY_ESCAPE)
	await wait_process_frames(2)
	assert_null(_journal._keys_editor)
	assert_eq(_journal._sys_i, 11)
	assert_not_null(_row(_layout(), 11))
	assert_true(is_instance_valid(_journal), "cancel from editor does not close the Journal")


func test_escape_closes_with_input_consumed():
	await _resize(Vector2i(640, 360))
	watch_signals(_journal)
	_journal._sys_i = 11
	_tap(KEY_ESCAPE)
	assert_signal_emitted(_journal, "closed")


func test_degenerate_body_still_yields_selected_row_without_errors():
	_journal._sys_i = 7
	var layout: Dictionary = _journal.call("_system_layout", Rect2(Vector2(10, 10), Vector2(0, 0)), UITheme.font())
	assert_eq(layout.rows.size(), 1)
	assert_eq(layout.rows[0].index, 7)


## Review finding (P2): active System feedback must not collide with the row
## hint, rows or footer. The feedback uses a reserved System-local line.
func _assert_feedback_clear(context: String) -> void:
	var font := UITheme.font()
	var body: Rect2 = _journal.call("_body_rect")
	var layout := _layout()
	var toast: Rect2 = layout.toast_rect
	var hint: Rect2 = layout.hint_rect
	var footer: Rect2 = _journal.call("_footer_rect", "←/→ tab      ↑/↓ move      Enter select      J / Esc close")
	assert_true(body.encloses(toast), "toast inside body %s" % context)
	assert_lte(toast.end.y, footer.position.y + 0.01, "toast clear of footer %s" % context)
	assert_gte(toast.size.x, font.get_string_size(_journal._toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0 - 0.01,
		"complete message fits its box %s" % context)
	assert_false(toast.intersects(hint), "toast clear of range hint %s" % context)
	for row: Dictionary in layout.rows:
		assert_false(toast.intersects(row.rect), "toast clear of row %d %s" % [row.index, context])
		if layout.windowed:
			assert_false(hint.intersects(row.rect), "hint clear of row %d %s" % [row.index, context])
	if layout.windowed:
		assert_true(body.encloses(hint))
		assert_lte(hint.end.y, footer.position.y + 0.01)
	assert_not_null(_row(layout, _journal._sys_i), "selected row still visible %s" % context)


func test_active_feedback_never_collides_with_hint_rows_or_footer():
	_write_slots()
	_journal._save.save_slot(2, {"campaign": "broken"})  # occupied, rejected by the existing loader
	_journal._refresh_slots()
	for size in SIZES + [Vector2i(640, 360), Vector2i(1280, 720)]:
		await _resize(size)
		var steps := [
			[6, KEY_RIGHT, "volume"], [9, KEY_RIGHT, "text speed fast"], [9, KEY_RIGHT, "text speed instant"],
			[2, KEY_ENTER, "save slot 3"], [5, KEY_ENTER, "load rejected"], [5, KEY_ENTER, "load rejected retry"],
		]
		for step in steps:
			_journal._sys_i = step[0]
			_tap(step[1])
			if _journal._toast_t <= 0.0:
				continue  # a volume change with no text feedback
			_assert_feedback_clear("%s %s" % [step[2], size])
			# Navigation still works while the message is up.
			var before: int = _journal._sys_i
			_tap(KEY_DOWN)
			assert_eq(_journal._sys_i, (before + 1) % AcademyJournal.SYS_ROWS.size())
			_assert_feedback_clear("after Down %s %s" % [step[2], size])
		# Live resize while a message is active, then expiry does not reflow the rows.
		_journal._show_toast("Slot 3 couldn't be loaded — choose another slot.", true)
		for other in [Vector2i(640, 360), Vector2i(800, 450), size]:
			await _resize(other)
			_assert_feedback_clear("resize active %s" % other)
		var active_rows: Array = _layout().rows.map(func(r): return r.index)
		_journal._toast_t = 0.0
		await wait_process_frames(1)
		assert_eq(_layout().rows.map(func(r): return r.index), active_rows, "expiry does not reflow rows")


func test_every_system_message_fits_the_compact_feedback_line():
	await _resize(Vector2i(640, 360))
	var body: Rect2 = _journal.call("_body_rect")
	var font := UITheme.font()
	var messages := ["Saved to slot 3", "Couldn't save slot 3", "Slot 3 is empty",
		"Slot 3 couldn't be loaded — choose another slot.", "Text speed: Fast (96 chars/sec) · save failed",
		"Text speed: Normal (48 chars/sec) · save failed"]
	for message in messages:
		_journal._show_toast(message)
		assert_lte(font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0, body.size.x,
			"%s fits the 640x360 body" % message)
		_assert_feedback_clear(message)
