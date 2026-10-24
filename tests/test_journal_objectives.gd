extends GutTest
## GH-106: production book input/layout; no battle instance or progression.

var _viewport: SubViewport
var _journal: AcademyJournal

func before_each() -> void:
	Campaign.reset_new_game(false, 106)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_journal = AcademyJournal.new()
	_journal._save = SaveSystem.new("user://test_objectives_%d" % Time.get_ticks_usec())
	_viewport.add_child(_journal)
	await wait_process_frames(2)

func after_each() -> void:
	Campaign.reset_new_game(false)

func _tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_viewport.push_input(event, true)

func test_appended_tab_and_actionless_confirm():
	assert_eq(AcademyJournal.TAB_NAMES.slice(0, 7),
		["Roster", "Calendar", "Inventory", "Grades", "System", "Fish Log", "Supports"])
	assert_eq(AcademyJournal.TAB_NAMES.size(), 8, "Objectives appended at index 7")
	_tap(KEY_LEFT)
	assert_eq(_journal._tab, 7)
	var before := Campaign.to_dict().duplicate(true)
	_tap(KEY_ENTER)
	assert_eq(Campaign.to_dict(), before)
	assert_eq(_journal._tab, 7)
	_tap(KEY_RIGHT)
	assert_eq(_journal._tab, 0)

func test_current_routes_and_neutral_states():
	assert_true(_journal.has_method("_objective_lines"), "current assignment is available without deploying")
	if not _journal.has_method("_objective_lines"):
		return
	for house in ["emberwing", "tidemark", "thornrook"]:
		Campaign.house_id = house
		for week in [1, 6]:
			Campaign.week = week
			var event := Campaign.current_event()
			var scene := load(ChapterRegistry.scene_for(event.chapter_id, house)) as PackedScene
			var chapter: ChapterDef = null
			var state := scene.get_state()
			for p in state.get_node_property_count(0):
				if state.get_node_property_name(0, p) == &"chapter":
					chapter = state.get_node_property_value(0, p)
			assert_not_null(chapter)
			var reference: GDScript = load("res://src/ui/mission_reference.gd")
			assert_same(reference.chapter_from_path(ChapterRegistry.scene_for(event.chapter_id, house)), chapter,
				"metadata is the actual selected resource for %s / week %d" % [house, week])
			var before := Campaign.to_dict().duplicate(true)
			var lines: Array = _journal.call("_objective_lines")
			assert_eq(Campaign.to_dict(), before, "battle metadata preserves whole Campaign/RNG state")
			assert_eq(lines, ["Week %d · %s" % [week, event.label], chapter.display_name,
				"Objective: Rout the enemy", "Deploy from the War Room."])
	for week in [2, 4, 99]:
		Campaign.week = week
		var lines: Array = _journal.call("_objective_lines")
		assert_true("No mission this week." in lines)
		assert_false("Deploy from the War Room." in lines)
		assert_false("year complete" in " ".join(lines).to_lower())

func test_measured_wrapping_and_bounded_scroll_after_live_resize():
	assert_true(_journal.has_method("_objectives_layout"), "renderer exposes active-font measured lines")
	if not _journal.has_method("_objectives_layout"):
		return
	_journal._tab = 7
	var original := Campaign.calendar()
	var event := CalendarEventDef.new()
	event.kind = CalendarEventDef.Kind.BATTLE
	event.chapter_id = "mock_battle"
	event.label = "A long existing label ".repeat(18)
	Campaign._calendar = [event]
	for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		_viewport.size = size
		await wait_process_frames(2)
		var body := _journal._body_rect()
		_assert_book_bounds(body)
		var reached: Array = []
		for step in range(_journal.call("_objectives_layout", body, UITheme.font()).total + 1):
			var layout: Dictionary = _journal.call("_objectives_layout", body, UITheme.font())
			for row: Dictionary in layout.rows:
				assert_true(body.encloses(row.rect), "actual glyph line clears tabs/footer at %s" % size)
				assert_lte(UITheme.font().get_string_size(row.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x,
					body.size.x, "complete line fits")
				if row.index not in reached:
					reached.append(row.index)
			_tap(KEY_DOWN)
		assert_eq(reached.size(), _journal.call("_objectives_layout", body, UITheme.font()).total,
			"every wrapped line is reachable")
		for step in range(_journal.call("_objectives_layout", body, UITheme.font()).total + 1):
			_tap(KEY_UP)
		assert_eq(_journal.get("_objectives_scroll"), 0)
	Campaign._calendar = original

func test_metadata_checks_root_and_inheritance_without_instantiation():
	var path := "res://src/ui/mission_reference.gd"
	assert_true(ResourceLoader.exists(path), "pure mission metadata helper exists")
	if not ResourceLoader.exists(path):
		return
	var reference: GDScript = load(path)
	var inherited := load("res://tests/fixtures/objectives/inherited.tscn") as PackedScene
	assert_eq(reference.chapter_from_scene(inherited), load("res://data/chapters/prologue.tres"))
	assert_eq(reference.chapter_from_path("res://tests/fixtures/objectives/overridden.tscn"), load("res://data/chapters/indoor_demo.tres"))
	for fixture in ["wrong_root", "no_chapter", "null_override"]:
		assert_null(reference.chapter_from_scene(load("res://tests/fixtures/objectives/%s.tscn" % fixture)))
	assert_null(reference.chapter_from_scene(null))
	assert_null(reference.chapter_from_path(""))
	assert_null(reference.chapter_from_path("res://tests/fixtures/objectives/not_available.tscn"))
	assert_null(reference.chapter_from_path("res://data/chapters/prologue.tres"))

func test_all_objective_wording_including_boss_fallback():
	var path := "res://src/ui/mission_reference.gd"
	assert_true(ResourceLoader.exists(path))
	if not ResourceLoader.exists(path):
		return
	var reference: GDScript = load(path)
	var chapter := ChapterDef.new()
	chapter.objective = ChapterDef.Objective.SEIZE
	assert_eq(reference.objective_text(chapter), "Objective: Seize the marked tile")
	chapter.objective = ChapterDef.Objective.DEFEAT_BOSS
	assert_eq(reference.objective_text(chapter), "Objective: Defeat the enemy commander — or rout them all")
	chapter = load("res://data/chapters/prologue.tres")
	var boss := load("res://data/units/bandit_boss.tres") as UnitDef
	assert_eq(reference.boss_display_name(chapter), boss.display_name)
	assert_eq(reference.objective_text(chapter), "Objective: Defeat %s — or rout them all" % boss.display_name)
	var battle := BattleView.new() # Wording only: never added to a tree / readied.
	battle.chapter = chapter
	assert_eq(battle._objective_text(), reference.objective_text(chapter))
	battle.free()

func test_unknown_current_chapter_fails_closed_using_isolated_event():
	assert_true(_journal.has_method("_objective_lines"))
	if not _journal.has_method("_objective_lines"):
		return
	var original := Campaign.calendar()
	var event := CalendarEventDef.new()
	event.kind = CalendarEventDef.Kind.BATTLE
	event.chapter_id = "isolated_test_unavailable"
	event.label = "Test event"
	Campaign._calendar = [event]
	var lines: Array = _journal.call("_objective_lines")
	assert_eq(lines, ["Week 1 · Test event", "Mission details unavailable."])
	Campaign._calendar = original

func test_native_controls_close_and_whole_state_and_file_invariance():
	_journal.queue_free()
	await wait_process_frames(1)
	Campaign.week = 2
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	var castle := (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate() as CastleScene
	_viewport.add_child(castle)
	await wait_process_frames(2)
	var prefs_path := KeyboardPreferences.prefs_path
	var extras := KeyboardPreferences._extras.duplicate()
	KeyboardPreferences.prefs_path = "user://test_objectives_keys_%d.cfg" % Time.get_ticks_usec()
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	for pair in [["cursor_up", KEY_I], ["cursor_down", KEY_N], ["cursor_left", KEY_G],
		["cursor_right", KEY_L], ["cursor_confirm", KEY_O], ["cursor_cancel", KEY_P]]:
		var event := InputEventKey.new()
		event.keycode = pair[1]
		assert_eq(KeyboardPreferences.assign(pair[0], event), "")
	var save := SaveSystem.new("user://test_objectives_bytes_%d" % Time.get_ticks_usec())
	for slot in range(3):
		assert_true(Campaign.save_to_slot(slot, save))
	var auto_path := save.save_dir + "/autosave.json"
	var auto_file := FileAccess.open(auto_path, FileAccess.WRITE)
	auto_file.store_string("isolated-autosave-sentinel")
	auto_file.close()
	var paths: Array[String] = [auto_path, KeyboardPreferences.prefs_path]
	for slot in range(3):
		paths.append(save.slot_path(slot))
	for path in [AudioManager.prefs_path, DialoguePreferences.prefs_path]:
		if path not in paths:
			paths.append(path)
	var bytes := {}
	for path in paths:
		bytes[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	Campaign.training_used = true
	Campaign._skip_next_hub_reset = true
	var original_prep := BattleView.next_prep
	BattleView.next_prep = true
	var before := Campaign.to_dict().duplicate(true)
	var active := Campaign.active
	var skip_reset := Campaign._skip_next_hub_reset
	var prep := BattleView.next_prep
	var supports := castle._support_state.save_state().duplicate(true)
	for keys in [[KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_ESCAPE],
		[KEY_G, KEY_L, KEY_I, KEY_N, KEY_O, KEY_P]]:
		_tap(KEY_J)
		_journal = castle._journal
		_journal._save = save
		_tap(keys[0])
		assert_eq(_journal._tab, 7)
		for size in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]:
			_viewport.size = size
			await wait_process_frames(1)
			_tap(keys[2])
			_tap(keys[3])
			_tap(keys[4])
			assert_eq(castle._journal, _journal, "confirm remains actionless")
		_tap(keys[1])
		assert_eq(_journal._tab, 0)
		_tap(keys[0])
		_tap(keys[5])
		assert_null(castle._journal)
		assert_false(castle.busy(), "close resumes exploration")
		assert_eq(castle._menu_context, "", "no close input leaks to castle")
		_tap(KEY_J)
		_tap(keys[0])
		_tap(KEY_J)
		assert_null(castle._journal, "J also closes without reopening")
	assert_eq(Campaign.to_dict(), before, "entire campaign including RNG unchanged")
	assert_eq(Campaign.active, active)
	assert_eq(Campaign._skip_next_hub_reset, skip_reset)
	assert_eq(BattleView.next_prep, prep)
	assert_eq(castle._support_state.save_state(), supports)
	for path in paths:
		var after: Variant = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		assert_eq(after, bytes[path], "all manual/autosave/settings bytes and absence preserved")
	_tap(KEY_ESCAPE)
	assert_eq(castle._menu_context, "system", "fresh input reaches normal exploration")
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras = extras
	KeyboardPreferences.prefs_path = prefs_path
	KeyboardPreferences._apply()
	BattleView.next_prep = original_prep

func _assert_book_bounds(body: Rect2) -> void:
	var font := UITheme.font()
	var vp := Vector2(_viewport.size)
	var m := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var book := Rect2(m, vp - m * 2)
	var safe := book.grow(-24)
	var title := _journal._heading_rect()
	assert_true(safe.encloses(title), "title clears ornate frame")
	var tx := book.position.x + 34
	var ty := book.position.y + 78
	for label: String in AcademyJournal.TAB_NAMES:
		var width := _journal._tab_width(font, label, 16)
		if tx + width > book.end.x - 34 and tx > book.position.x + 34:
			tx = book.position.x + 34
			ty += 22
		var glyph := Rect2(Vector2(tx, ty - font.get_ascent(16)),
			font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16))
		assert_true(safe.encloses(glyph), "complete tab clears ornate frame")
		assert_gte(glyph.position.y, title.end.y, "tabs clear title")
		assert_lte(glyph.end.y, body.position.y, "tabs clear body")
		tx += width + 10
	var footer := _journal._footer_rect("←/→ tab      ↑/↓ scroll      J / Esc close")
	assert_true(safe.encloses(footer), "full Objectives footer clears frame")
	assert_lte(body.end.y, footer.position.y, "body clears actual footer glyphs")
