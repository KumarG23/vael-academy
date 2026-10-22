extends GutTest
## GH-56: newly closed cards survive scene interruption and ordinary slot IO.

var _castle: CastleScene
var _sys: SaveSystem

func before_each() -> void:
	Campaign.reset_new_game(false)
	Campaign.house_locked = true
	_sys = SaveSystem.new("user://test_report_card_delivery")

func after_each() -> void:
	if is_instance_valid(_castle):
		_castle.free()
	Campaign.reset_new_game(false)
	var dir := DirAccess.open(_sys.save_dir)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)

func _open() -> void:
	_castle = load("res://scenes/castle/castle.tscn").instantiate()
	add_child(_castle)

func _close(perfect: bool = false) -> void:
	if perfect:
		Campaign.record_quiz(100)
		Campaign.record_battle_score(100)
		Campaign.record_arena_run(10)
		Campaign.add_conduct(40)
	Campaign.week = Campaign.semester_end_week()
	Campaign.advance_week()

func test_pending_card_round_trip_and_interrupted_reentry() -> void:
	_close()
	assert_true(Campaign.save_to_slot(0, _sys))
	assert_true(Campaign.load_from_slot(0, _sys))
	_open()
	assert_not_null(_castle._dialogue, "battle-closed card delivered on entry")
	assert_eq(int(Campaign.flags.get("gold", 0)), 0, "unfinished presentation has no payout")
	_castle.free()
	_open()
	assert_not_null(_castle._dialogue, "interruption retains pending delivery")
	if _castle._dialogue == null:
		return
	var card := _castle._dialogue
	_castle._refresh_date()
	_castle._play_report_card()
	_castle._rest_week()
	assert_eq(Campaign.week, 4, "pending dialogue prevents a second rest")
	assert_eq(Campaign.report_cards.size(), 1)
	assert_eq(_castle._dialogue_queue.size(), 1, "date refresh queues no duplicate festival/card")
	card._finish()
	var gold := int(Campaign.flags.get("gold", 0))
	assert_eq(gold, CastleScene.RANK_REWARD_GOLD["C"])
	card.finished.emit()
	_castle._refresh_date()
	_castle._play_report_card()
	assert_eq(int(Campaign.flags.get("gold", 0)), gold, "duplicate callbacks never pay again")
	assert_true(Campaign.save_to_slot(0, _sys))
	_castle.free()
	assert_true(Campaign.load_from_slot(0, _sys))
	_open()
	assert_eq(int(Campaign.flags.get("gold", 0)), gold)
	assert_true(Campaign.flags.get("merchant_unlocked", false))

func test_rest_ceremony_pays_only_when_finished() -> void:
	_open()
	Campaign.week = Campaign.semester_end_week()
	_castle._rest_week()
	assert_eq(Campaign.report_cards.size(), 1)
	assert_eq(int(Campaign.flags.get("gold", 0)), 0)
	_castle._dialogue._finish()
	assert_eq(int(Campaign.flags.get("gold", 0)), CastleScene.RANK_REWARD_GOLD["C"])

func test_final_boundary_queues_feast_after_card() -> void:
	Campaign.semester = 2
	Campaign.last_result = "victory"
	_close(true)
	_open()
	assert_not_null(_castle._dialogue)
	assert_eq(_castle._dialogue_queue.size(), 1, "feast waits behind card")
	assert_false(Campaign.flags.get("feast_seen", false), "unfinished feast remains retryable")
	_castle._dialogue._finish()
	assert_eq(int(Campaign.flags.get("gold", 0)), CastleScene.RANK_REWARD_GOLD["S"])
	assert_true(str(Campaign.get_unit_state("kai")).contains("promotion_seal"))
	assert_not_null(_castle._dialogue, "feast now plays")
	_castle._dialogue._finish()
	assert_true(Campaign.flags.get("feast_seen", false))
	_castle._refresh_date()
	assert_null(_castle._dialogue)

func test_legacy_history_is_not_backpaid_but_future_card_delivers() -> void:
	_close()
	var legacy := Campaign.to_dict()
	legacy.erase("report_card_deliveries")
	assert_true(Campaign.restore_save(legacy))
	_open()
	assert_eq(int(Campaign.flags.get("gold", 0)), 0)
	# Festival may play; it is unrelated to the historical locked card.
	while _castle._dialogue != null:
		_castle._dialogue._finish()
	_close()
	_castle._refresh_date()
	assert_not_null(_castle._dialogue, "future term still delivers")
	_castle._dialogue._finish()
	assert_eq(int(Campaign.flags.get("gold", 0)), CastleScene.RANK_REWARD_GOLD["C"])

func test_metadata_rejects_atomically_for_campaign_and_battle_resume() -> void:
	_close()
	var valid := Campaign.to_dict()
	var bad: Array = [null, {}, "bad", [null], [{}],
		[{"card_index": 0, "delivered": 1}],
		[{"card_index": "0", "delivered": false}],
		[{"card_index": -1, "delivered": false}],
		[{"card_index": 0.5, "delivered": false}],
		[{"card_index": 1, "delivered": false}],
		[{"card_index": 0, "delivered": false}, {"card_index": 0, "delivered": true}]]
	for shape: Variant in bad:
		var saved := valid.duplicate(true)
		saved["report_card_deliveries"] = shape
		saved["week"] = 99
		saved["house_id"] = "tidemark"
		var before := Campaign.to_dict()
		assert_true(_sys.save_slot(0, {"campaign": saved}))
		assert_false(Campaign.load_from_slot(0, _sys))
		assert_eq(Campaign.to_dict(), before)
		var staged := BattleView.next_resume
		assert_eq(Resume.stage({"campaign": saved, "battle": {"chapter_id": "mock_battle", "battle_over": false}, "roster": []}), "")
		assert_eq(Campaign.to_dict(), before)
		assert_eq(BattleView.next_resume, staged)
	for field: String in ["rank", "score", "rank_name", "semester"]:
		var saved := valid.duplicate(true)
		saved["report_cards"][0][field] = []
		assert_false(Campaign.restore_save(saved))
		assert_eq(Campaign.to_dict(), valid)
	valid["future_extension"] = {"unknown": true}
	valid["report_card_deliveries"][0]["future_extension"] = 42
	assert_true(Campaign.restore_save(valid), "unknown fields tolerated")

func test_receipts_reference_the_corresponding_card_not_latest_history() -> void:
	_close(true)
	_close()
	_open()
	assert_string_contains(_castle._dialogue.current_line().text, "Semester 1")
	assert_eq(_castle._dialogue_queue.size(), 1)
	_castle._dialogue._finish()
	assert_eq(int(Campaign.flags.get("gold", 0)), 400)
	assert_string_contains(_castle._dialogue.current_line().text, "Semester 2")
	_castle._dialogue._finish()
	assert_eq(int(Campaign.flags.get("gold", 0)), 480)
	assert_eq(Campaign.report_cards.size(), 2)

func test_detached_ceremony_callback_keeps_pending_and_rewards_untouched() -> void:
	_close()
	_open()
	var scene := _castle._dialogue
	_castle.remove_child(_castle._ui)
	# A detached dialogue finishing cannot commit rewards or consume its queue.
	scene._finish()
	assert_eq(int(Campaign.flags.get("gold", 0)), 0)
	_castle._ui.free()
	_castle.free()
	_open()
	assert_string_contains(_castle._dialogue.current_line().text, "Semester 1")

func test_full_inventory_s_keeps_existing_no_seal_policy() -> void:
	var unit := Unit.new()
	unit.setup(load("res://data/units/kai.tres").duplicate(), Grid.new(1, 1), Vector2i.ZERO)
	while not unit.inventory.is_full():
		unit.inventory.add(InventoryItem.from_item(load("res://data/items/vulnerary.tres")))
	Campaign.set_unit_state("kai", unit.save_state())
	unit.free()
	_close(true)
	_open()
	_castle._dialogue._finish()
	assert_eq(int(Campaign.flags.get("gold", 0)), 400)
	assert_false(str(Campaign.get_unit_state("kai")).contains("promotion_seal"))
	_castle._play_report_card()
	assert_eq(int(Campaign.flags.get("gold", 0)), 400)


class RefusingCastle extends CastleScene:
	func _play_dialogue_json(_text: String, _on_complete := Callable()) -> bool:
		return false


func test_unplayable_presentation_does_not_consume_receipt() -> void:
	_close()
	_castle = RefusingCastle.new()
	add_child(_castle)
	assert_eq(Campaign.pending_report_cards(), [0])
	assert_eq(int(Campaign.flags.get("gold", 0)), 0)
	assert_false(Campaign.flags.get("merchant_unlocked", false))
	_castle.free()
	_open()
	assert_string_contains(_castle._dialogue.current_line().text, "Semester 1")


func test_production_battle_result_returns_to_castle_at_both_boundaries() -> void:
	for term: String in ["1", "2"]:
		var output: Array = []
		var code := OS.execute(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"-s", "res://tests/fixtures/report_card_battle_return.gd", "--", term,
		]), output, true)
		assert_eq(code, 0, "production return term %s: %s" % [term, output])
		assert_string_contains(str(output), "Report card production result -> castle passed")
		assert_false(str(output).contains("SCRIPT ERROR"))


func test_completed_s_card_save_reentry_retries_only_interrupted_feast() -> void:
	Campaign.semester = 2
	Campaign.last_result = "victory"
	_close(true)
	_open()
	_castle._dialogue._finish()
	var inventory := Campaign.get_unit_state("kai").duplicate(true)
	assert_true(Campaign.save_to_slot(0, _sys))
	_castle.free()
	assert_true(Campaign.load_from_slot(0, _sys))
	_open()
	assert_eq(JSON.parse_string(JSON.stringify(Campaign.get_unit_state("kai"))),
		JSON.parse_string(JSON.stringify(inventory)), "seal never duplicates across JSON numeric normalization")
	assert_eq(int(Campaign.flags.get("gold", 0)), 400)
	assert_true(_castle._dialogue_queue.is_empty(), "only interrupted feast remains")
	assert_string_contains(_castle._dialogue.current_line().text, "Closing Rite is won")
	var feast := _castle._dialogue
	feast._finish()
	feast.finished.emit()
	_castle._refresh_date()
	assert_null(_castle._dialogue)
	assert_eq(int(Campaign.flags.get("gold", 0)), 400)


func test_festival_completion_grants_conduct_and_cooking_only_once() -> void:
	_close()
	_open()
	_castle._dialogue._finish()
	var samples := Campaign.grade_samples.duplicate(true)
	var festival := _castle._dialogue
	assert_false(Campaign.flags.get("cooking_unlocked", false))
	_castle._refresh_date()
	assert_true(_castle._dialogue_queue.is_empty())
	festival._finish()
	festival.finished.emit()
	_castle._refresh_date()
	assert_eq(int(Campaign.grade_samples["conduct_points"]), int(samples["conduct_points"]) + 3)
	assert_true(Campaign.flags.get("cooking_unlocked", false))
	assert_null(_castle._dialogue)


func test_shipped_rank_gold_values_and_locked_history_are_preserved() -> void:
	for case: Array in [[100, "S", 400], [80, "A", 250], [70, "B", 150], [60, "C", 80], [0, "D", 40]]:
		Campaign.reset_new_game(false)
		Campaign.house_locked = true
		Campaign.record_quiz(case[0])
		Campaign.record_battle_score(case[0])
		Campaign.record_arena_run(case[0] / 10)
		Campaign.add_conduct(maxi(0, case[0] - 60))
		_close()
		var history := Campaign.report_cards.duplicate(true)
		assert_eq(history[0]["rank"], case[1])
		_open()
		_castle._dialogue._finish()
		assert_eq(int(Campaign.flags.get("gold", 0)), case[2])
		assert_eq(Campaign.report_cards, history, "delivery never regrades history")
		_castle.free()
