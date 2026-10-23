extends GutTest
## GH-54: controlled calendar fixtures through production BattleView completion.
## Six-entry calendar arithmetic is scaffolding, not an authored school year.

const EMPTY_SAMPLES := {"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0}
const OLD_CARD := {"semester": 1, "rank": "D", "rank_name": "Faltering", "score": 42}


func after_each() -> void:
	BattleView.next_resume = {}
	BattleView.next_prep = false
	Campaign.reset_new_game(false)


func _view(house := "emberwing", week := 6, term := 2, casual := false) -> BattleView:
	Campaign.reset_new_game(casual)
	Campaign.set_house(house)
	Campaign.house_locked = true
	Campaign.week = week
	Campaign.semester = term
	Campaign.report_cards = [OLD_CARD.duplicate(true)] if term == 2 else []
	Campaign.deploy()
	return _scene(ChapterRegistry.scene_for("closing_rite", house))


func _scene(path: String) -> BattleView:
	var view: BattleView = load(path).instantiate()
	view.dialogue_enabled = false
	view.strike_delay = 0.0
	add_child_autofree(view)
	return view


func _rout(view: BattleView) -> void:
	for foe in view._living_foes_of(0).duplicate():
		view._kill(foe)
	view._check_objective()
	assert_true(view._battle_over)
	assert_true(view._battle_victory)
	assert_true(view._result_screen.is_shown())


# JSON numbers restore as floats; compare values across either save representation.
func _json_values(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _assert_closed() -> void:
	assert_eq(Campaign.week, 7)
	assert_eq(Campaign.semester, 3, "existing final scaffold boundary is unchanged")
	assert_eq(_json_values(Campaign.report_cards), _json_values([OLD_CARD, {"semester": 2, "rank": "B", "rank_name": "Accomplished", "score": 74}]))
	assert_eq(_json_values(Campaign.grade_samples), _json_values(EMPTY_SAMPLES), "closing battle belongs only to the locked term")
	assert_eq(Campaign.last_result, "victory")


func _repeat_completion(view: BattleView) -> void:
	var before := Campaign.to_dict().duplicate(true)
	view._end_battle(true)
	view._end_battle(false)
	view._check_objective()
	view._restore_post_load_ui()
	view._restore_post_load_ui()
	assert_eq(Campaign.to_dict(), before, "duplicate end/result restoration cannot capture, grade or advance")


func test_all_three_closing_routes_include_last_battle_once():
	for house in ["emberwing", "tidemark", "thornrook"]:
		var view := _view(house)
		var rng_before := view._rng.state_value()
		_rout(view)
		_assert_closed()
		assert_eq(view._rng.state_value(), rng_before, "completion consumes no combat RNG")
		assert_eq(Campaign.unit_states, view._captured_roster_progression())
		assert_eq(Campaign.support_save, view._support_state.save_state())
		_repeat_completion(view)
		view.free()


func test_first_scaffold_boundary_and_non_boundary_victory():
	var view := _view("emberwing", 3, 1)
	_rout(view)
	assert_eq(Campaign.week, 4)
	assert_eq(Campaign.semester, 2)
	assert_eq(Campaign.report_cards, [{"semester": 1, "rank": "B", "rank_name": "Accomplished", "score": 74}])
	assert_eq(Campaign.grade_samples, EMPTY_SAMPLES)
	view.free()
	view = _view("emberwing", 2, 1)
	Campaign.record_battle_score(60)
	_rout(view)
	assert_eq(Campaign.week, 3)
	assert_eq(Campaign.semester, 1)
	assert_eq(Campaign.report_cards, [])
	assert_eq(Campaign.grade_samples.battle_scores, [60, 100])
	assert_eq(Campaign.running_grade().score, 67)
	_repeat_completion(view)


func test_boundary_defeat_records_score_without_advancing_in_both_modes():
	for casual in [false, true]:
		var view := _view("emberwing", 6, 2, casual)
		Campaign.record_battle_score(90)
		view._kill(view.unit_by_id("kai"))
		view._check_objective()
		assert_false(view._battle_victory)
		assert_true(view._result_screen.is_shown())
		assert_eq(Campaign.week, 6)
		assert_eq(Campaign.semester, 2)
		assert_eq(Campaign.report_cards, [OLD_CARD])
		assert_eq(Campaign.grade_samples.battle_scores, [90, 30])
		assert_eq(Campaign.last_result, "defeat")
		_repeat_completion(view)
		view.free()


func test_loss_and_round_penalties_keep_existing_casual_revival_counting():
	for casual in [false, true]:
		var view := _view("emberwing", 2, 1, casual)
		view._turn.round_number = 12
		view._kill(view.unit_by_id("kael"))
		_rout(view)
		# Casual revival clears defeat bookkeeping, while downed units still cost score.
		assert_eq(Campaign.grade_samples.battle_scores, [80])
		assert_eq(view._defeated_unit_ids.has("kael"), not casual)
		assert_eq(Campaign.week, 3)
		_repeat_completion(view)
		view.free()


func test_pre_oath_victory_is_graded_but_keeps_week_one():
	Campaign.reset_new_game(false)
	Campaign.deploy()
	var view := _scene("res://scenes/battle/prologue.tscn")
	view._end_battle(true)
	assert_eq(Campaign.week, 1)
	assert_eq(Campaign.semester, 1)
	assert_eq(Campaign.report_cards, [])
	assert_eq(Campaign.grade_samples.battle_scores, [100])
	assert_false(Campaign.house_locked)
	_repeat_completion(view)


func test_arena_and_standalone_remain_excluded():
	var view := _view()
	view.free()
	view = _scene("res://scenes/battle/arena.tscn")
	# Direct production completion checks exclusion, without changing arena waves.
	view._end_battle(false)
	assert_eq(Campaign.grade_samples, EMPTY_SAMPLES)
	assert_eq(Campaign.week, 6)
	assert_eq(Campaign.report_cards, [OLD_CARD])
	_repeat_completion(view)
	view.free()
	view = _view()
	Campaign.active = false
	var before := Campaign.to_dict().duplicate(true)
	_rout(view)
	assert_eq(Campaign.to_dict(), before, "standalone battles never feed campaign grades")


func test_live_json_resume_then_completed_result_reload_are_stable():
	var view := _view("tidemark")
	# A prior score must average into the same locked term after a real resume.
	Campaign.record_battle_score(100)
	view._turn.round_number = 9
	view.unit_by_id("kai").current_hp = 17
	var saves := SaveSystem.new("user://test_gh54_resume")
	assert_true(saves.save_slot(0, view.make_save_payload()))
	var payload: Dictionary = saves.load_slot(0)
	view.free()
	Campaign.reset_new_game(false)
	var path := Resume.stage(payload)
	assert_eq(path, ChapterRegistry.scene_for("closing_rite", "tidemark"))
	view = _scene(path)
	assert_true(BattleView.next_resume.is_empty())
	assert_eq(view._turn.round_number, 9)
	assert_eq(view.unit_by_id("kai").current_hp, 17)
	assert_eq(Campaign.grade_samples.battle_scores, [100.0])
	_rout(view)
	_assert_closed()
	_repeat_completion(view)
	payload = JSON.parse_string(JSON.stringify(view.make_save_payload()))
	view.free()
	Campaign.reset_new_game(false)
	assert_false(Resume.battle_live(payload))
	assert_eq(Resume.stage(payload), "", "normal completed save routes to campaign, never back into combat")
	assert_true(Campaign.restore_save(payload.campaign))
	_assert_closed()
	# Defensive direct completed-result reconstruction also cannot regrade.
	Campaign.active = true
	view = _scene(path)
	view.apply_save_payload(payload)
	_assert_closed()
	_repeat_completion(view)


func test_real_duplicate_result_input_returns_without_regrading():
	for outcome in ["victory", "defeat"]:
		var output: Array = []
		var result := OS.execute(OS.get_executable_path(), PackedStringArray([
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"-s", "res://tests/fixtures/battle_grade_result.gd", "--", outcome,
		]), output, true)
		assert_eq(result, 0, "real result return: %s" % output)
		assert_string_contains(str(output), "Battle grade result: %s passed" % outcome)
		assert_false(str(output).contains("SCRIPT ERROR"), "no runtime errors: %s" % output)
