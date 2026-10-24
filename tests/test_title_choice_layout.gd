extends GutTest
## GH-122: actual production geometry, using the active fonts, before/after resize.

var _viewport: SubViewport
var _title: TitleScreen
var _saves: SaveSystem
var _before: Dictionary
var _installation: Dictionary

func before_each() -> void:
	_before = {"campaign": Campaign.to_dict().duplicate(true), "active": Campaign.active,
		"skip": Campaign._skip_next_hub_reset, "roster": Roster.active_house,
		"resume": BattleView.next_resume.duplicate(true), "prep": BattleView.next_prep,
		"room": CastleScene.next_room, "spawn": CastleScene.next_spawn,
		"save_override": Campaign.save_system_override, "rng": Campaign._training_rng,
		"rng_seed": Campaign._training_rng.seed_value()}
	_installation = {}
	for path in ["user://saves/slot_0.json", "user://saves/slot_1.json", "user://saves/slot_2.json", "user://saves/autosave.json", "user://settings.cfg"]:
		_installation[path] = _bytes(path)
	_saves = SaveSystem.new("user://test_title_choice_%d" % Time.get_ticks_usec())
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_title = load("res://scenes/title/title.tscn").instantiate()
	_title._save_system = _saves
	_viewport.add_child(_title)

func test_existing_complete_recovery_labels_fit_the_drawn_width() -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		_title._slots = [{"slot": 2, "chapter_id": "mock_battle_vs_thornrook", "casual_mode": false, "in_battle": true},
			{"autosave": true, "chapter_id": "closing_rite_emberwing", "week": 6, "casual_mode": true}]
		_title._menu.open("Autosave unavailable. Retry or Back.", _title._slot_labels(), _title._menu_pos())
		var menu := _title._menu
		assert_true(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(Rect2(menu.position, menu.size)),
			"entire production drawn/hit rect at %s" % dimensions)
		_title._layout_title()
		_assert_complete_layout()

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_viewport.push_input(event, true)

func _assert_complete_layout() -> void:
	var menu := _title._menu
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	assert_true(viewport_rect.encloses(Rect2(menu.position, menu.size)), "whole drawn/hit rect fits")
	var heading: Rect2 = _title.heading_layout()["rect"]
	assert_lte(heading.end.y + 8, menu.position.y, "heading/subtitle clear the menu")
	assert_lte(menu.position.y + menu.size.y, _viewport.size.y - 30.0, "footer clear")
	if _title._status != "":
		assert_lte(_title.status_rect().end.y, heading.position.y, "status clear of heading")
	for line: String in _title.heading_layout()["lines"]:
		assert_lte(ThemeDB.fallback_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x,
			heading.size.x, "complete heading glyph width")
	assert_eq("".join(menu._title_lines), menu._title, "complete retry/title text")
	for line: String in menu._title_lines:
		assert_lte(UITheme.font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x,
			menu._width - ChoiceMenu.PAD * 2, "title glyph width")
	for i in range(menu._options.size()):
		assert_eq("".join(menu._row_lines[i]), str(menu._options[i]), "all characters preserved")
		for line: String in menu._row_lines[i]:
			assert_lte(UITheme.font().get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x,
				menu._width - ChoiceMenu.PAD * 2 - 6.0, "active-font row glyph width")
	var selected := menu.row_rect(menu._index)
	assert_true(selected.has_area(), "selected row is completely visible")
	assert_eq(menu.row_at(selected.get_center()), menu._index)
	assert_lte(selected.end.y + menu.position.y, _viewport.size.y - 30.0 - ChoiceMenu.PAD + 0.001)

func test_all_production_title_contexts_live_shrink_restore_and_full_labels() -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		_title._open_main()
		_assert_complete_layout()
		_key(KEY_ENTER)
		assert_eq(_title._context, "new")
		assert_eq(_title._menu._options, ["Classic (permadeath)", "Casual", "Back"])
		_assert_complete_layout()
		_key(KEY_UP)
		_key(KEY_ENTER)
		assert_eq(_title._context, "main", "New Game Back dispatch")
		_key(KEY_DOWN)
		_key(KEY_ENTER)
		assert_eq(_title._context, "load")
		assert_eq(_title._menu._options, ["(no saves found)", "Back"])
		_assert_complete_layout()
		_title._slots = [{"slot": 0, "chapter_id": "closing_rite_emberwing", "casual_mode": true, "in_battle": true},
			{"slot": 1, "chapter_id": "mock_battle_vs_emberwing", "casual_mode": false, "in_battle": true},
			{"slot": 2, "chapter_id": "mock_battle_vs_thornrook", "casual_mode": false, "in_battle": true},
			{"autosave": true, "chapter_id": "closing_rite_emberwing", "week": 6, "casual_mode": true}]
		_title._menu.open("Autosave unavailable. Retry or Back.", _title._slot_labels(), _title._menu_pos())
		_title._layout_title()
		assert_eq(_title._menu._options[2], "Slot 2 — mock_battle_vs_thornrook (Classic)  ⚔ mid-battle")
		assert_eq(_title._menu._options[3], "Autosave — closing_rite_emberwing W6 (Casual)")
		for i in range(5):
			_assert_complete_layout()
			_key(KEY_DOWN)
		_key(KEY_UP)
		assert_eq(_title._menu._index, 4)
		_key(KEY_ENTER)
		assert_eq(_title._context, "main", "Load Back dispatch")

func test_current_selection_survives_resize_with_status_and_retry() -> void:
	_title._open_load()
	_title._slots = [{"slot": 2, "chapter_id": "mock_battle_vs_thornrook", "casual_mode": false, "in_battle": true},
		{"autosave": true, "chapter_id": "closing_rite_emberwing", "week": 6, "casual_mode": true}]
	_title._menu.open("Autosave unavailable. Retry or Back.", _title._slot_labels(), _title._menu_pos())
	_key(KEY_DOWN)
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		assert_eq(_title._menu._index, 1)
		_assert_complete_layout()
	_title._report_load_failure(2)
	for dimensions in [Vector2i(640, 360), Vector2i(800, 450), Vector2i(1280, 720)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		_assert_complete_layout()

func test_sparse_occupied_and_vanished_files_keep_mapping_retry_and_bytes() -> void:
	var campaign := Campaign.to_dict()
	campaign["chapter_id"] = "mock_battle_vs_thornrook"
	campaign["casual"] = false
	assert_true(_saves.save_slot(2, {"campaign": campaign}))
	campaign["chapter_id"] = "closing_rite_emberwing"
	campaign["week"] = 6
	campaign["flags"] = [] # occupied with summary, rejected by existing atomic loader
	assert_true(_saves.save_autosave({"campaign": campaign}))
	var manual_bytes := FileAccess.get_file_as_bytes(_saves.slot_path(2))
	var auto_bytes := FileAccess.get_file_as_bytes(_saves.autosave_path())
	_title._open_load()
	assert_eq(_title._slots.size(), 2)
	assert_eq(_title._slots[0]["slot"], 2, "physical sparse slot")
	assert_true(_title._slots[1]["autosave"])
	_key(KEY_DOWN)
	_key(KEY_ENTER)
	assert_eq(_title._menu._index, 1)
	assert_eq(_title._menu._title, "Autosave unavailable. Retry or Back.")
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		_assert_complete_layout()
		_key(KEY_ENTER)
		assert_eq(_title._menu._index, 1, "retry keeps Autosave selected")
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(2)), manual_bytes)
	assert_eq(FileAccess.get_file_as_bytes(_saves.autosave_path()), auto_bytes)
	# Deliberate fixture removal, outside read-only navigation interval.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.autosave_path()))
	_key(KEY_ENTER)
	assert_eq(_title._menu._index, 1, "missing recovery never falls back to manual")
	_assert_complete_layout()
	_key(KEY_UP)
	# Deliberate rejection fixture replacement; preserve its bytes during retry.
	assert_true(_saves.save_slot(2, {"campaign": {"flags": [], "week": 3}}))
	manual_bytes = FileAccess.get_file_as_bytes(_saves.slot_path(2))
	_key(KEY_ENTER)
	assert_eq(_title._status, "Slot 2 couldn't be loaded — choose another slot.")
	_assert_complete_layout()
	_key(KEY_ENTER)
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(2)), manual_bytes)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.slot_path(2)))
	_key(KEY_ENTER)
	assert_eq(_title._status, "Slot 2 is empty.")
	_assert_complete_layout()
	_key(KEY_UP) # first -> final Back
	_key(KEY_ENTER)
	assert_eq(_title._context, "main")

func test_custom_key_aliases_and_pointer_dispatch_preserve_indices() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_N
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_O
	var original_down := InputMap.action_get_events("cursor_down")
	var original_confirm := InputMap.action_get_events("cursor_confirm")
	InputMap.action_add_event("cursor_down", down)
	InputMap.action_add_event("cursor_confirm", confirm)
	_key(KEY_N)
	_key(KEY_O)
	InputMap.action_erase_events("cursor_down")
	InputMap.action_erase_events("cursor_confirm")
	for event: InputEvent in original_down:
		InputMap.action_add_event("cursor_down", event)
	for event: InputEvent in original_confirm:
		InputMap.action_add_event("cursor_confirm", event)
	assert_eq(_title._context, "load", "additional keyboard aliases use the real input path")
	_viewport.size = Vector2i(640, 360)
	await get_tree().process_frame
	var menu := _title._menu
	var back := menu.row_rect(1)
	assert_true(back.has_area())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = menu.position + back.get_center()
	click.global_position = click.position
	_viewport.push_input(click, true)
	assert_eq(_title._context, "main", "actual pointer Back dispatch")

func _bytes(path: String) -> Array:
	return [FileAccess.file_exists(path), FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()]

func after_each() -> void:
	assert_eq(Campaign.to_dict(), _before["campaign"], "whole Campaign/RNG/support/progression preserved")
	assert_same(Campaign._training_rng, _before["rng"], "navigation retains the original RNG object")
	assert_eq(Campaign._training_rng.seed_value(), _before["rng_seed"])
	assert_eq(Campaign.active, _before["active"])
	assert_eq(Campaign._skip_next_hub_reset, _before["skip"])
	assert_eq(Roster.active_house, _before["roster"])
	assert_eq(BattleView.next_resume, _before["resume"])
	assert_eq(BattleView.next_prep, _before["prep"])
	assert_eq(CastleScene.next_room, _before["room"])
	assert_eq(CastleScene.next_spawn, _before["spawn"])
	assert_same(Campaign.save_system_override, _before["save_override"])
	for path: String in _installation:
		assert_eq(_bytes(path), _installation[path], "installation bytes untouched: " + path)
	Campaign.from_dict(_before["campaign"])
	Campaign._training_rng = _before["rng"]
	Campaign._training_rng.set_state(int(str(_before["campaign"]["rng_state"])))
	Campaign.active = _before["active"]
	Campaign._skip_next_hub_reset = _before["skip"]
	Roster.active_house = _before["roster"]
	BattleView.next_resume = _before["resume"]
	BattleView.next_prep = _before["prep"]
	CastleScene.next_room = _before["room"]
	CastleScene.next_spawn = _before["spawn"]
	Campaign.save_system_override = _before["save_override"]
	var dir := DirAccess.open(_saves.save_dir)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.save_dir))

func test_three_physical_occupied_slots_are_listed_and_browsed_without_writes() -> void:
	var files: Array[PackedByteArray] = []
	for slot in range(3):
		var campaign := Campaign.to_dict()
		campaign["chapter_id"] = ["mock_battle_vs_emberwing", "mock_battle_vs_thornrook", "closing_rite_emberwing"][slot]
		campaign["casual"] = slot == 1
		assert_true(_saves.save_slot(slot, {"campaign": campaign, "battle": {"battle_over": false}}))
		files.append(FileAccess.get_file_as_bytes(_saves.slot_path(slot)))
	_title._open_load()
	assert_eq(_title._slots.size(), 3)
	for slot in range(3):
		assert_eq(_title._slots[slot]["slot"], slot)
		assert_string_contains(_title._menu._options[slot], "Slot %d — " % slot)
	for dimensions in [Vector2i(1280, 720), Vector2i(800, 450), Vector2i(640, 360), Vector2i(1280, 720)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		for i in range(4):
			_assert_complete_layout()
			_key(KEY_DOWN)
	for slot in range(3):
		assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(slot)), files[slot])
	assert_false(_saves.has_autosave())
