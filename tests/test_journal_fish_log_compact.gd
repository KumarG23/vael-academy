extends GutTest
## Issue #136: inspect complete Fish Log strings through the production Journal
## Control, SubViewport and UITheme font at compact sizes and live resize.

const SIZES := [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]
const UNKNOWN_CATCH := "Unknown Accepted Save Catch With a Deliberately Long Name"
const EMPTY_TEXT := "No catches yet. Visit the waterside to try fishing."
const FIXTURE := {
	"Lakeperch": 1,
	"Silver Dace": 123456789,
	"Vael Kingfish": 2,
	"Warded Coin": 3,
	UNKNOWN_CATCH: 4,
}

var _viewport: SubViewport
var _journal: AcademyJournal
var _saved_paths := {}
var _saved_keys := {}
var _save_dir := ""
var _scratch_paths: Array[String] = []


func before_each() -> void:
	Campaign.reset_new_game(false, 136)
	_saved_paths = {"audio": AudioManager.prefs_path, "dialogue": DialoguePreferences.prefs_path,
		"keys": KeyboardPreferences.prefs_path}
	_saved_keys = KeyboardPreferences._extras.duplicate()
	var stamp := Time.get_ticks_usec()
	AudioManager.prefs_path = _scratch_path("audio_%d.cfg" % stamp)
	DialoguePreferences.prefs_path = _scratch_path("dialogue_%d.cfg" % stamp)
	KeyboardPreferences.prefs_path = _scratch_path("keys_%d.cfg" % stamp)
	_save_dir = "user://test_journal_fish_log_%d" % stamp
	_viewport = SubViewport.new()
	_viewport.size = SIZES[0]
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_journal = AcademyJournal.new()
	_journal._save = SaveSystem.new(_save_dir)
	_journal._tab = 5
	_viewport.add_child(_journal)
	await wait_process_frames(2)


func after_each() -> void:
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras = _saved_keys.duplicate()
	KeyboardPreferences._apply()
	KeyboardPreferences.prefs_path = _saved_paths["keys"]
	DialoguePreferences.prefs_path = _saved_paths["dialogue"]
	AudioManager.prefs_path = _saved_paths["audio"]
	for path in _scratch_paths:
		for suffix in ["", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	_scratch_paths.clear()
	_remove_save_dir()
	Campaign.reset_new_game(false)


func _scratch_path(name: String) -> String:
	var path := "user://test_journal_fish_log_" + name
	_scratch_paths.append(path)
	return path


func _remove_save_dir() -> void:
	var dir := DirAccess.open(_save_dir)
	if dir != null:
		for file in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_dir))


func _press(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_viewport.push_input(event, true)


func _layout() -> Dictionary:
	return _journal._fish_log_layout(_journal._body_rect(), UITheme.font())


func _row(layout: Dictionary, index: int) -> Dictionary:
	for row: Dictionary in layout["rows"]:
		if row["index"] == index:
			return row
	return {}


func _assert_glyph_rect(rect: Rect2, body: Rect2, context: String) -> void:
	assert_true(body.encloses(rect), "%s glyph bounds stay inside Fish Log body: %s / %s" % [context, rect, body])


func test_fish_log_complete_names_and_exact_quantities_fit_at_each_size_and_are_selectable() -> void:
	Campaign.fish_log = FIXTURE.duplicate(true)
	var font := UITheme.font()
	var expected_names := ["Lakeperch", "Silver Dace", "Unknown Accepted Save Catch With a Deliberately Long Name",
		"Vael Kingfish", "Warded Coin"]
	for size: Vector2i in SIZES:
		_viewport.size = size
		await wait_process_frames(2)
		var body: Rect2 = _journal._body_rect()
		for index in range(expected_names.size()):
			_journal._fish_i = index
			var layout := _layout()
			assert_false(layout["empty"], "saved catches are drawn at %s" % size)
			assert_lte(layout["first_index"], index, "selected catch starts in the visible row window")
			assert_gt(layout["last_index"], index, "selected catch ends in the visible row window")
			var row := _row(layout, index)
			assert_false(row.is_empty(), "entry %d is present in the actual draw layout at %s" % [index, size])
			assert_eq(" ".join(row["name_lines"].map(func(line: Dictionary) -> String: return line["text"])),
				expected_names[index], "complete saved name is rendered at %s" % size)
			var expected_count := "×%d" % int(FIXTURE[expected_names[index]])
			assert_eq("".join(row["count_lines"].map(func(line: Dictionary) -> String: return line["text"])),
				expected_count, "exact saved quantity is rendered at %s" % size)
			assert_true(body.encloses(row["rect"]), "selected row remains inside the body at %s" % size)
			for line: Dictionary in row["name_lines"]:
				_assert_glyph_rect(line["rect"], body, "name %d at %s" % [index, size])
				assert_true(row["rect"].encloses(line["rect"]), "name glyph stays inside its selected row")
			for line: Dictionary in row["count_lines"]:
				_assert_glyph_rect(line["rect"], body, "quantity %d at %s" % [index, size])
				assert_true(row["rect"].encloses(line["rect"]), "quantity glyph stays inside its row")
				assert_lte(line["rect"].size.x,
					maxf(74.0, body.size.x * 0.38), "active-font quantity line fits its measured column")
			assert_false(row["rect"].intersects(layout["hint_lines"][0]["rect"]),
				"selected row clears the browse hint at %s" % size)
		var footer := _journal._footer_rect("←/→ tab      ↑/↓ move      Enter select      J / Esc close")
		assert_true(footer.position.y >= body.end.y, "shared footer clears Fish Log body at %s" % size)
		assert_gte(font.get_string_size("Fishing Catch Log", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, 1.0)


func test_fish_log_empty_message_heading_browse_hint_and_footer_fit_without_overlap() -> void:
	Campaign.fish_log = {}
	for size: Vector2i in SIZES:
		_viewport.size = size
		await wait_process_frames(2)
		var body: Rect2 = _journal._body_rect()
		var layout := _layout()
		assert_true(layout["empty"], "empty saved log uses its existing empty state")
		assert_eq(" ".join(layout["empty_lines"].map(func(line: Dictionary) -> String: return line["text"])), EMPTY_TEXT)
		_assert_glyph_rect(layout["title"]["rect"], body, "heading at %s" % size)
		for line: Dictionary in layout["empty_lines"]:
			_assert_glyph_rect(line["rect"], body, "empty state at %s" % size)
			assert_false(line["rect"].intersects(layout["hint_lines"][0]["rect"]),
				"empty message clears browse hint at %s" % size)
		_assert_glyph_rect(layout["hint_lines"][0]["rect"], body, "browse hint at %s" % size)
		var footer := _journal._footer_rect("←/→ tab      ↑/↓ move      Enter select      J / Esc close")
		assert_true(footer.position.y >= body.end.y, "shared footer clears empty state at %s" % size)


func test_fish_log_live_resize_input_read_only_state_files_and_save_round_trip() -> void:
	Campaign.fish_log = FIXTURE.duplicate(true)
	var save := _journal._save as SaveSystem
	for slot in range(3):
		assert_true(save.save_slot(slot, {"campaign": Campaign.to_dict()}), "seed disposable manual slot %d" % slot)
	assert_true(save.save_autosave({"campaign": Campaign.to_dict()}), "seed a disposable Autosave")
	var settings := {
		AudioManager.prefs_path: "audio settings sentinel\n".to_utf8_buffer(),
		DialoguePreferences.prefs_path: "dialogue settings sentinel\n".to_utf8_buffer(),
		KeyboardPreferences.prefs_path: "keyboard settings sentinel\n".to_utf8_buffer(),
	}
	for path: String in settings:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(settings[path])
		file.close()
	var before_campaign := Campaign.to_dict()
	var before_files := {save.autosave_path(): FileAccess.get_file_as_bytes(save.autosave_path())}
	for slot in range(3):
		before_files[save.slot_path(slot)] = FileAccess.get_file_as_bytes(save.slot_path(slot))
	for path: String in settings:
		before_files[path] = FileAccess.get_file_as_bytes(path)
	for size: Vector2i in [SIZES[2], SIZES[1], SIZES[0], SIZES[1], SIZES[2]]:
		_viewport.size = size
		await wait_process_frames(2)
		assert_true(_layout()["rows"].size() > 0, "live resize keeps selected catch rendered at %s" % size)
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras["cursor_up"] = KEY_U
	KeyboardPreferences._extras["cursor_down"] = KEY_N
	KeyboardPreferences._apply()
	_journal._fish_i = 0
	_press(KEY_U)
	assert_eq(_journal._fish_i, FIXTURE.size() - 1, "Up wraps from the first saved entry")
	_press(KEY_N)
	assert_eq(_journal._fish_i, 0, "Down wraps from the final saved entry")
	for index in range(1, FIXTURE.size()):
		_press(KEY_N)
		assert_eq(_journal._fish_i, index, "rebindable Down reaches saved entry %d" % index)
	_press(KEY_N)
	assert_eq(_journal._fish_i, 0, "Down wraps from the final saved entry")
	_press(KEY_ENTER)
	assert_eq(_journal._tab, 5, "Enter is actionless on the read-only Fish Log tab")
	assert_eq(Campaign.to_dict(), before_campaign, "open, browse and live resize preserve complete Campaign/RNG")
	for path: String in before_files:
		assert_eq(FileAccess.get_file_as_bytes(path), before_files[path], "read-only Fish Log leaves bytes unchanged: %s" % path)
	assert_true(Campaign.load_from_slot(0, save), "ordinary Campaign/SaveSystem round trip succeeds")
	var expected_names := FIXTURE.keys()
	expected_names.sort()
	var restored_names := Campaign.fish_log.keys()
	assert_eq(restored_names.size(), expected_names.size(), "the round trip retains every saved name")
	for name: String in expected_names:
		assert_true(Campaign.fish_log.has(name), "the round trip retains saved key %s" % name)
		assert_eq(int(Campaign.fish_log[name]), int(FIXTURE[name]),
			"the existing loaded-count conversion retains displayed quantity for %s" % name)
