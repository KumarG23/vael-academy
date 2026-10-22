extends GutTest
## Issue #14 / AW-74–75: physical save rows must match their labels and writes.
## Real keys traverse viewport -> ChoiceMenu -> battle controllers -> JSON IO.

var _viewport: SubViewport
var _view: BattleView
var _saves: SaveSystem


func before_each() -> void:
	Campaign.reset_new_game(true)
	BattleView.next_prep = false
	BattleView.next_resume = {}
	_saves = SaveSystem.new("user://test_battle_save_menu_%d" % Time.get_ticks_usec())
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)


func after_each() -> void:
	_clear_slots()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.save_dir))
	BattleView.next_prep = false
	BattleView.next_resume = {}
	Campaign.reset_new_game(false)


func _clear_slots() -> void:
	for slot in range(3):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_saves.slot_path(slot)))


func _start(scene: String = "prologue", prep: bool = false) -> void:
	BattleView.next_prep = prep
	_view = (load("res://scenes/battle/%s.tscn" % scene) as PackedScene).instantiate()
	_view.dialogue_enabled = false
	_view.strike_delay = 0.0
	_view.combat_seed = 14
	_view._save_system = _saves
	_viewport.add_child(_view)
	await wait_physics_frames(2)
	# Position the cursor only; every menu action below uses real key dispatch.
	for y in range(_view._grid.height):
		for x in range(_view._grid.width):
			var cell := Vector2i(x, y)
			if _view.unit_at(cell) == null:
				_view._cursor.move_to(cell)
				return
	fail_test("the fixture needs an empty map cell")


func _press(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		_viewport.push_input(event, true)


func _choose_row(row: int) -> void:
	for i in range(row):
		_press(KEY_DOWN)
	assert_eq(_view._menu._index, row, "keyboard selection reaches the intended row")
	_press(KEY_ENTER)


func _open_save() -> void:
	_press(KEY_ENTER)
	assert_eq(_view._menu_context, "prep_field" if _view._prep_active else "field")
	var row: int = _view._menu._options.find("Save game")
	assert_gte(row, 0, "the real entry menu offers Save game")
	if row < 0:
		return
	_choose_row(row)
	assert_eq(_view._menu_context, "save_slot")
	assert_true(_view._menu.visible)
	assert_false(_view._cursor.active, "the slot picker owns input")


func _seed(occupied: Array) -> void:
	_clear_slots()
	for slot in occupied:
		_view._turn.round_number = int(slot) + 1
		assert_true(_view.save_to_slot(int(slot)), "seed a real disposable battle snapshot")
	_view._turn.round_number = 9


func _assert_rows(occupied: Array) -> void:
	var expected: Array = []
	for slot in range(3):
		expected.append("Slot %d — %s" % [slot + 1,
			_view.chapter.id if occupied.has(slot) else "empty"])
	assert_eq(_view._menu._options, expected, "exactly three rows in physical slot order")
	var listed: Array = _saves.list_slots(3).map(func(entry: Dictionary) -> int: return entry["slot"])
	assert_eq(listed, occupied, "list_slots still returns only occupied slots")


func _exercise_writes(occupied: Array) -> void:
	for target in range(3):
		_seed(occupied)
		var before: Dictionary = {}
		for slot in occupied:
			before[slot] = FileAccess.get_file_as_bytes(_saves.slot_path(int(slot)))
		var expected: Dictionary = _view.make_save_payload()
		expected["version"] = SaveSystem.VERSION
		expected["slot"] = target
		_open_save()
		_assert_rows(occupied)
		_choose_row(target)
		assert_eq(_saves.load_slot(target), JSON.parse_string(JSON.stringify(expected)),
			"the selected physical slot receives the complete current payload")
		for slot in range(3):
			if slot == target:
				if before.has(slot):
					assert_ne(FileAccess.get_file_as_bytes(_saves.slot_path(slot)), before[slot],
						"the selected occupied slot was updated")
			elif before.has(slot):
				assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(slot)), before[slot],
					"every other occupied slot retains its exact bytes")
			else:
				assert_false(_saves.has_slot(slot), "unselected empty slots stay empty")
		assert_false(_view._menu.visible)
		assert_true(_view._cursor.active)
		assert_eq(_view._save_menu_origin, "")
		assert_eq(_view._phase, BattleView.Phase.PREP if _view._prep_active else BattleView.Phase.IDLE)
		# Reopening must reflect the write at its actual position.
		var now := occupied.duplicate()
		if not now.has(target):
			now.append(target)
			now.sort()
		_open_save()
		_assert_rows(now)
		_press(KEY_ESCAPE)
		if _view._prep_active:
			_press(KEY_ESCAPE)  # prep slot cancel returns to the preparations menu


func test_field_only_slot_three_occupied():
	await _start()
	_exercise_writes([2])


func test_field_gap_between_slots_one_and_three():
	await _start()
	_exercise_writes([0, 2])


func test_empty_and_full_slot_lists():
	await _start()
	_exercise_writes([])
	_exercise_writes([0, 1, 2])


func test_preparations_share_sparse_slot_mapping_and_writes():
	await _start("mock_battle", true)
	assert_true(_view._prep_active)
	_exercise_writes([2])
	_exercise_writes([0, 2])


func test_arena_field_shares_sparse_slot_mapping_and_writes():
	await _start("arena")
	assert_true(_view.chapter.is_arena)
	assert_false(_view._prep_active)
	_exercise_writes([2])
	_exercise_writes([0, 2])


func _exercise_cancel() -> void:
	_seed([0, 2])
	var before := [FileAccess.get_file_as_bytes(_saves.slot_path(0)),
		FileAccess.get_file_as_bytes(_saves.slot_path(2))]
	_open_save()
	_press(KEY_DOWN)
	_press(KEY_ESCAPE)
	assert_eq(_view._save_menu_origin, "")
	if _view._prep_active:
		assert_eq(_view._menu_context, "prep_field", "cancel returns to the preparations menu")
		assert_eq(_view._menu._title, "Preparations")
		assert_true(_view._menu.visible)
		assert_false(_view._cursor.active)
		_press(KEY_ESCAPE)
	assert_eq(_view._phase, BattleView.Phase.PREP if _view._prep_active else BattleView.Phase.IDLE)
	assert_false(_view._menu.visible)
	assert_true(_view._cursor.active, "map input is restored")
	assert_false(_saves.has_slot(1), "cancelling the empty row creates no save")
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(0)), before[0])
	assert_eq(FileAccess.get_file_as_bytes(_saves.slot_path(2)), before[1])
	_open_save()  # input and the original entry path remain usable


func test_field_cancellation_preserves_slots_and_restores_map_input():
	await _start()
	_exercise_cancel()


func test_preparations_cancellation_preserves_slots_and_restores_prep():
	await _start("mock_battle", true)
	_exercise_cancel()


func test_arena_cancellation_preserves_slots_and_restores_map_input():
	await _start("arena")
	_exercise_cancel()
