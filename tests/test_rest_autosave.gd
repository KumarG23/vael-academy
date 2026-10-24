extends GutTest
## GH-85: production rest completion, independent atomic checkpoint, no polling.

class CountingSaves extends SaveSystem:
	var writes := 0
	func save_autosave(payload: Dictionary) -> bool:
		writes += 1
		return super.save_autosave(payload)

class RefusingCeremony extends CastleScene:
	func _queue_report_card(_index: int) -> bool:
		return false

var _sys: CountingSaves
var _previous: SaveSystem
var _castle: CastleScene
var _manual: Array[PackedByteArray] = []

func before_each() -> void:
	Campaign.reset_new_game(false, 853)
	Campaign.house_locked = true
	Campaign.week = 2
	_sys = CountingSaves.new()
	_sys.save_dir = "user://test_rest_autosave_%d" % Time.get_ticks_usec()
	_previous = Campaign.save_system_override
	Campaign.save_system_override = _sys
	_manual.clear()
	for slot in range(3):
		assert_true(_sys.save_slot(slot, {"campaign": {"marker": slot}}))
		_manual.append(FileAccess.get_file_as_bytes(_sys.slot_path(slot)))
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)

func after_each() -> void:
	if is_instance_valid(_castle):
		_castle.free()
	for slot in range(3):
		assert_eq(FileAccess.get_file_as_bytes(_sys.slot_path(slot)) if _sys.has_slot(slot) else PackedByteArray(), _manual[slot], "all manual bytes preserved")
	Campaign.save_system_override = _previous
	Campaign.reset_new_game(false)
	var dir := DirAccess.open(_sys.save_dir)
	for name: String in dir.get_files():
		dir.remove(name)
	for name: String in dir.get_directories():
		dir.remove(name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_sys.save_dir))

func _open() -> void:
	_castle = load("res://scenes/castle/castle.tscn").instantiate()
	add_child(_castle)

func _press_rest() -> void:
	_castle.enter_room("emberwing_hall")
	for point: CastlePoint in _castle.room.points:
		if point.id == "fn_rest":
			_castle._avatar.position = _castle._grid.cell_center(point.cell)
			_castle._update_prompt()
			var event := InputEventAction.new()
			event.action = "ui_accept"
			event.pressed = true
			_castle._unhandled_input(event)
			return
	fail_test("rest point missing")

func _stored(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))

func _assert_checkpoint() -> void:
	assert_eq(_sys.load_autosave().get("campaign"), _stored(Campaign.to_dict()), "entire settled Campaign including RNG/receipts/visits/supports")
	assert_eq(int(_sys.load_autosave().get("version", -1)), SaveSystem.VERSION)
	assert_false(_sys.load_autosave().has("slot"))
	assert_false(FileAccess.file_exists(_sys.autosave_path() + ".tmp"))

func test_plain_rest_is_the_only_trigger_and_repeated_input_is_held() -> void:
	_open()
	_castle.enter_room("common_hall")
	_castle._refresh_date()
	assert_false(_sys.has_autosave())
	Campaign.support_save = {"points": {"kai|perrin": 12}}
	Campaign.fish_log = {"Silver Dace": 2}
	Campaign.record_quiz(80)
	Campaign.set_unit_state("kai", {"level": 1, "xp": 95})
	var rng_before := str(Campaign.to_dict()["rng_state"])
	Campaign.train_unit("kai")
	assert_ne(str(Campaign.to_dict()["rng_state"]), rng_before, "actual level-up spends training RNG")
	assert_true(Campaign.training_used)
	_press_rest()
	var settled := Campaign.to_dict()
	_press_rest()
	assert_eq(Campaign.week, 3)
	assert_true(_castle.busy(), "deferred completion guards finishing input")
	assert_eq(_sys.writes, 0)
	await wait_process_frames(2)
	assert_eq(_sys.writes, 1)
	assert_eq(Campaign.to_dict(), settled)
	_assert_checkpoint()
	assert_eq(_castle._toast_label.text, "Autosaved.")
	await wait_process_frames(2)
	assert_eq(_sys.writes, 1, "no per-frame writes")

func test_report_and_festival_callbacks_settle_before_one_write() -> void:
	_open()
	Campaign.week = Campaign.semester_end_week()
	Campaign.record_quiz(100)
	Campaign.record_battle_score(100)
	Campaign.record_arena_run(10)
	Campaign.add_conduct(40)
	_castle._rest_week()
	assert_eq(Campaign.week, 4)
	var card := _castle._dialogue
	assert_eq(_castle._dialogue_queue.size(), 1)
	await wait_process_frames(2)
	assert_false(_sys.has_autosave())
	_castle._rest_week()
	card._finish()
	card.finished.emit()
	var festival := _castle._dialogue
	assert_eq(int(Campaign.flags.get("gold", 0)), 400)
	assert_true(str(Campaign.unit_states).contains("promotion_seal"))
	await wait_process_frames(2)
	assert_false(_sys.has_autosave(), "not between ceremony and festival")
	festival._finish()
	festival.finished.emit()
	_castle._rest_week()
	assert_eq(Campaign.week, 4, "completion press cannot rest again")
	await wait_process_frames(2)
	assert_eq(_sys.writes, 1)
	assert_true(Campaign.flags.get("festival_seen", false))
	assert_true(Campaign.flags.get("cooking_unlocked", false))
	assert_true(Campaign.flags.get("merchant_unlocked", false))
	_assert_checkpoint()
	var saved := Campaign.to_dict()
	_castle.free()
	assert_true(Campaign.load_autosave(_sys))
	_open()
	assert_null(_castle._dialogue)
	assert_eq(_stored(Campaign.to_dict()), _stored(saved))
	assert_eq(_sys.writes, 1, "loading/entry never writes")

func test_interrupted_ceremony_keeps_previous_checkpoint() -> void:
	assert_true(Campaign.save_autosave())
	var prior := FileAccess.get_file_as_bytes(_sys.autosave_path())
	_open()
	Campaign.week = Campaign.semester_end_week()
	_castle._rest_week()
	_castle._dialogue._finish()
	_castle.free() # festival abandoned after payout: checkpoint stays old
	await wait_process_frames(2)
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), prior)
	assert_eq(_sys.writes, 1)
	_open()
	_castle._dialogue._finish()
	await wait_process_frames(2)
	assert_eq(_sys.writes, 1, "entry completion is not a rest request")

func test_refusal_busy_and_departure_do_not_write() -> void:
	_open()
	Campaign.week = 1 # battle
	_castle._rest_week()
	assert_eq(Campaign.week, 1)
	Campaign.week = 2
	_castle._menu_context = "system"
	_castle._rest_week()
	assert_eq(Campaign.week, 2)
	_castle._menu_context = ""
	_castle._leaving = true
	_castle._rest_week()
	assert_eq(Campaign.week, 2)
	_castle._leaving = false
	_castle._rest_week()
	_castle._leaving = true # departure pending before deferred write
	await wait_process_frames(2)
	assert_false(_sys.has_autosave())
	assert_eq(_sys.writes, 0)

func test_failed_write_keeps_previous_and_later_rest_retries() -> void:
	_open()
	assert_true(Campaign.save_autosave())
	var prior := FileAccess.get_file_as_bytes(_sys.autosave_path())
	var tmp := ProjectSettings.globalize_path(_sys.autosave_path() + ".tmp")
	assert_eq(DirAccess.make_dir_absolute(tmp), OK)
	_castle._rest_week()
	var settled := Campaign.to_dict()
	await wait_process_frames(2)
	assert_eq(Campaign.to_dict(), settled)
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), prior)
	assert_string_contains(_castle._toast_label.text, "Autosave failed.")
	assert_false(_castle.busy(), "IO failure never blocks play")
	assert_eq(DirAccess.remove_absolute(tmp), OK)
	_castle._rest_week()
	while _castle._dialogue != null:
		_castle._dialogue._finish()
	await wait_process_frames(2)
	_assert_checkpoint()
	assert_eq(_sys.writes, 3)

func test_new_game_preserves_recovery_and_no_write_on_load() -> void:
	assert_true(Campaign.save_autosave())
	var bytes := FileAccess.get_file_as_bytes(_sys.autosave_path())
	var title := TitleScreen.new()
	title.prepare_new_game(true)
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), bytes)
	assert_true(Campaign.load_autosave(_sys))
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), bytes)
	assert_eq(_sys.writes, 1)
	title.free()

func test_title_autosave_mapping_rejection_retry_and_fresh_process_restore() -> void:
	_open()
	_castle.free()
	# Sparse manual list must retain physical slot IDs alongside the named entry.
	DirAccess.remove_absolute(_sys.slot_path(0))
	DirAccess.remove_absolute(_sys.slot_path(1))
	_manual[0] = PackedByteArray()
	_manual[1] = PackedByteArray()
	assert_true(Campaign.save_autosave())
	var title := TitleScreen.new()
	title._save_system = _sys
	add_child(title)
	title._open_load()
	assert_eq(title._slots.size(), 2)
	assert_eq(title._slots[0]["slot"], 2)
	assert_true(title._slots[1]["autosave"])
	assert_string_contains(title._slot_labels()[1], "Autosave")
	assert_string_contains(title._slot_labels()[1], "W2")
	var before := Campaign.to_dict()
	var roster := Roster.active_house
	BattleView.next_resume = {"keep": true}
	BattleView.next_prep = true
	CastleScene.next_room = "library"
	CastleScene.next_spawn = Vector2i(2, 3)
	var source := FileAccess.get_file_as_bytes(_sys.autosave_path())
	var invalid: Array = [{}, {"campaign": {}}, {"campaign": {"week": 8}},
		{"campaign": {"week": 8, "house_id": "tidemark", "flags": []}},
		{"campaign": before, "battle": {"battle_over": false}}]
	for payload: Dictionary in invalid:
		assert_true(_sys.save_autosave(payload))
		var corrupt := FileAccess.get_file_as_bytes(_sys.autosave_path())
		title._choose_slot(1)
		assert_eq(Campaign.to_dict(), before)
		assert_eq(Roster.active_house, roster)
		assert_eq(BattleView.next_resume, {"keep": true})
		assert_true(BattleView.next_prep)
		assert_eq(CastleScene.next_room, "library")
		assert_eq(CastleScene.next_spawn, Vector2i(2, 3))
		assert_false(Campaign._skip_next_hub_reset)
		assert_false(Campaign.active)
		assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), corrupt)
		assert_eq(title._context, "load")
		assert_eq(title._menu._index, 1)
		assert_string_contains(title._menu._title, "Autosave unavailable")
	for raw: String in ["{bad", "[]", "null", ""]:
		var file := FileAccess.open(_sys.autosave_path(), FileAccess.WRITE)
		file.store_string(raw)
		file.close()
		title._choose_slot(1)
		assert_eq(Campaign.to_dict(), before)
		assert_eq(FileAccess.get_file_as_string(_sys.autosave_path()), raw)
	DirAccess.remove_absolute(_sys.autosave_path())
	title._choose_slot(1)
	assert_eq(Campaign.to_dict(), before, "disappeared autosave never falls back")
	assert_true(_sys.save_autosave({"campaign": before}))
	assert_true(title.prepare_autosave(), "same entry retries after replacement")
	title._on_cancelled()
	assert_eq(title._context, "main")
	title.free()
	BattleView.next_resume = {}
	BattleView.next_prep = false
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/fixtures/autosave_title_restore.gd", "--", _sys.save_dir,
	]), output, true)
	assert_eq(code, 0, str(output))
	assert_string_contains(str(output), "Fresh Title autosave restore passed")
	assert_false(str(output).contains("SCRIPT ERROR"))
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), source)

func test_legacy_checkpoint_uses_existing_defaults_without_backpay() -> void:
	var legacy := Campaign.to_dict()
	legacy.erase("academy_visits")
	legacy.erase("report_card_deliveries")
	legacy["report_cards"] = [{"semester": 1, "rank": "S", "rank_name": "Ascendant", "score": 100}]
	assert_true(_sys.save_autosave({"campaign": legacy}))
	assert_true(Campaign.load_autosave())
	assert_eq(Campaign.academy_visits, [])
	assert_eq(Campaign.pending_report_cards(), [])
	_open()
	assert_null(_castle._dialogue, "historical card is never replayed/backpaid")
	assert_eq(int(Campaign.flags.get("gold", 0)), 0)
	assert_eq(_sys.writes, 1, "legacy load doesn't migrate/rewrite")

func test_detached_rest_cannot_replace_checkpoint() -> void:
	_open()
	assert_true(Campaign.save_autosave())
	var bytes := FileAccess.get_file_as_bytes(_sys.autosave_path())
	Campaign.week = Campaign.semester_end_week()
	_castle._rest_week()
	var ui := _castle._ui
	_castle.remove_child(ui)
	_castle._dialogue._finish()
	ui.free()
	_castle.free()
	await wait_process_frames(2)
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), bytes)
	assert_eq(_sys.writes, 1)

func test_unplayable_ceremony_keeps_previous_checkpoint() -> void:
	assert_true(Campaign.save_autosave())
	var bytes := FileAccess.get_file_as_bytes(_sys.autosave_path())
	_castle = RefusingCeremony.new()
	add_child(_castle)
	Campaign.week = Campaign.semester_end_week()
	_castle._rest_week()
	await wait_process_frames(2)
	assert_eq(Campaign.week, 4)
	assert_eq(Campaign.pending_report_cards(), [0])
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), bytes)
	assert_eq(_sys.writes, 1)
	assert_false(_castle.busy(), "unavailable presentation doesn't lock live play")

func test_title_switching_manual_and_autosave_failures_clears_other_feedback() -> void:
	# Actual viewport input crosses both accepted feedback paths. The draw signal
	# observes what Title rendered, not only the backing status string.
	assert_true(_sys.save_slot(2, {"campaign": {"flags": []}}))
	_manual[2] = FileAccess.get_file_as_bytes(_sys.slot_path(2))
	assert_true(_sys.save_autosave({"campaign": {}}))
	var auto_bytes := FileAccess.get_file_as_bytes(_sys.autosave_path())
	var before := Campaign.to_dict()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.handle_input_locally = true
	add_child(viewport)
	var title := TitleScreen.new()
	title._save_system = _sys
	viewport.add_child(title)
	var drawn_status: Array[String] = []
	title.draw.connect(func() -> void: drawn_status.append(title._status))
	title._open_load()
	title._menu._index = 2
	for key: Key in [KEY_ENTER, KEY_DOWN, KEY_ENTER, KEY_UP, KEY_ENTER]:
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = key
			event.physical_keycode = key
			event.pressed = pressed
			viewport.push_input(event, true)
		await wait_process_frames(2)
		if key == KEY_DOWN or key == KEY_UP:
			continue
		if title._menu._index == 3:
			assert_eq(title._status, "")
			assert_false(drawn_status.is_empty(), "Title rendered the prior manual failure")
			if not drawn_status.is_empty():
				assert_eq(drawn_status[-1], "", "old manual error band was redrawn away")
			assert_string_contains(title._menu._title, "Autosave unavailable")
		else:
			assert_string_contains(title._status, "Slot 2 couldn't be loaded")
			assert_eq(title._menu._title, "Load Game", "manual rejection must not keep Autosave's heading")
	assert_eq(Campaign.to_dict(), before)
	assert_eq(FileAccess.get_file_as_bytes(_sys.autosave_path()), auto_bytes)
	viewport.free()
