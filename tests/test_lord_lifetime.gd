extends GutTest
## GH-19: node lifetime must not change the chapter's must-survive rule.
## These are controlled runtime fixtures, not fresh graphical playthroughs.


func after_each() -> void:
	BattleView.next_resume = {}
	Campaign.reset_new_game(false)


func _view(non_lethal := true, casual := false, lordless := false) -> BattleView:
	Campaign.reset_new_game(casual)
	var view: BattleView = load("res://scenes/battle/mock_battle.tscn").instantiate()
	view.chapter = view.chapter.duplicate(true)
	view.chapter.non_lethal = non_lethal
	view.casual_mode = casual
	view.dialogue_enabled = false
	view.strike_delay = 0.0
	if lordless:
		var spawn := UnitSpawn.new()
		spawn.unit = load("res://data/units/kael.tres")
		spawn.cell = Vector2i(2, 12)
		view.chapter.player_spawns = [spawn]
	add_child_autofree(view)
	await wait_physics_frames(2)
	return view


func test_freed_lord_loses_every_objective_in_both_modes_and_lethality_rules():
	for non_lethal in [false, true]:
		for casual in [false, true]:
			for objective in [ChapterDef.Objective.ROUT, ChapterDef.Objective.DEFEAT_BOSS, ChapterDef.Objective.SEIZE]:
				var view := await _view(non_lethal, casual)
				view.chapter.objective = objective
				var kai := view.unit_by_id("kai")
				view.chapter.seize_cell = kai.cell
				view._kill(kai)
				# Unlike the preserved synchronous mock-battle regression, cross
				# the queue_free boundary BEFORE the objective sees the board.
				await wait_physics_frames(2)
				assert_false(is_instance_valid(kai), "Kai's node really was freed")
				assert_gt(view._living_units_on_team(0).size(), 0, "allies survive")
				view._check_objective()
				assert_true(view._battle_over, "lord loss ends the battle")
				assert_false(view._battle_victory)
				view.queue_free()
				await wait_physics_frames(2)


func test_freed_lord_defeat_precedes_rout_and_boss_victory():
	for objective in [ChapterDef.Objective.ROUT, ChapterDef.Objective.DEFEAT_BOSS]:
		var view := await _view()
		view.chapter.objective = objective
		view._kill(view.unit_by_id("kai"))
		for foe in view._living_foes_of(0).duplicate():
			view._kill(foe)
		await wait_physics_frames(2)
		view._check_objective()
		assert_gt(view._living_units_on_team(0).size(), 0)
		assert_true(view._battle_over)
		assert_false(view._battle_victory, "lord defeat takes precedence over cleared foes")


func test_authored_prologue_lord_still_loses_after_deletion():
	Campaign.reset_new_game(true)
	var view: BattleView = load("res://scenes/battle/prologue.tscn").instantiate()
	view.dialogue_enabled = false
	view.strike_delay = 0.0
	add_child_autofree(view)
	assert_false(view.chapter.player_spawns.is_empty(), "prologue uses authored allies")
	view._kill(view.unit_by_id("kai"))
	await wait_physics_frames(2)
	assert_false(is_instance_valid(view._lord_unit))
	assert_gt(view._living_units_on_team(0).size(), 0)
	view._check_objective()
	assert_true(view._battle_over)
	assert_false(view._battle_victory)


func _lethal_seed(view: BattleView, attacker: Unit, defender: Unit) -> void:
	# Use the real resolver with original weapons/stats; only the fixture's
	# Kai HP/positions and deterministic RNG seed are controlled.
	for seed_value in range(1000):
		var result := CombatResolver.resolve(view._combatant_for(attacker, attacker.cell),
			view._combatant_for(defender, defender.cell), 1, CombatRNG.new(seed_value))
		if result.defender_defeated() and not result.attacker_defeated():
			view._rng = CombatRNG.new(seed_value)
			return
	fail_test("no lethal native resolver seed found")


func test_animated_executor_lord_loss_with_surviving_allies():
	await _animated_lord_loss(false)


func test_illustrated_executor_lord_loss_with_surviving_allies():
	await _animated_lord_loss(true)


func _animated_lord_loss(illustrated: bool) -> void:
	watch_signals(EventBus)
	for casual in [false, true]:
		var view := await _view(true, casual)
		Campaign.deploy()
		view.strike_delay = 0.45
		if not illustrated:
			# Pin the on-map branch, including its post-kill camera await.
			view._illustrated_combat.queue_free()
			view._illustrated_combat = null
		var kai := view.unit_by_id("kai")
		var serra := view.unit_by_id("serra")
		kai.current_hp = 1
		kai.cell = Vector2i(8, 12)
		serra.cell = Vector2i(9, 12)
		kai.position = view._grid.cell_center(kai.cell)
		serra.position = view._grid.cell_center(serra.cell)
		if illustrated:
			assert_true(view._illustrated_combat.supports_exchange(serra, kai))
		_lethal_seed(view, serra, kai)
		await view._execute_attack(serra, kai)
		if not illustrated:
			assert_false(is_instance_valid(kai), "camera pullback crossed queued deletion")
		await wait_physics_frames(2)
		assert_false(is_instance_valid(kai))
		assert_false(view._lord_alive)
		assert_gt(view._living_units_on_team(0).size(), 0)
		assert_true(view._battle_over, "animated executor ends in defeat")
		assert_false(view._battle_victory)
		assert_true(view._result_screen.is_shown())
		assert_true(view._permadead_unit_ids.is_empty(), "rite remains non-lethal")
		assert_signal_not_emitted(EventBus, "battle_won")
		assert_eq(Campaign.last_result, "defeat")
		assert_eq(Campaign.week, 1, "defeat does not advance the school calendar")


func test_fallen_freed_lord_snapshot_resumes_as_defeat_without_another_action():
	for non_lethal in [false, true]:
		for casual in [false, true]:
			var view := await _view(non_lethal, casual)
			Campaign.deploy()
			view._kill(view.unit_by_id("kai"))
			await wait_physics_frames(2)
			var payload := view.make_save_payload()
			assert_false(payload.battle.battle_over, "legacy ongoing snapshot after Kai fell")
			# Match disk serialization (including the legacy schema), then the
			# real title/Journal Resume.stage -> BattleView._ready route.
			payload = JSON.parse_string(JSON.stringify(payload))
			var scene_path := Resume.stage(payload)
			assert_ne(scene_path, "")
			var loaded: BattleView = load(scene_path).instantiate()
			loaded.chapter = view.chapter.duplicate(true)
			loaded.dialogue_enabled = false
			loaded.strike_delay = 0.0
			add_child_autofree(loaded)
			await wait_physics_frames(2)
			assert_null(loaded.unit_by_id("kai"))
			assert_false(is_instance_valid(loaded._lord_unit))
			assert_gt(loaded._living_units_on_team(0).size(), 0)
			assert_true(loaded._battle_over, "resume immediately resolves recorded lord loss")
			assert_false(loaded._battle_victory)
			assert_true(loaded._result_screen.is_shown())
			assert_eq(Campaign.last_result, "defeat")
			# A subsequent direct load of the completed defeat is stable too.
			loaded.apply_save_payload(loaded.make_save_payload())
			await wait_physics_frames(2)
			loaded._check_objective()
			assert_true(loaded._battle_over)
			assert_false(loaded._battle_victory)


func test_authored_lordless_chapter_keeps_objectives_and_save_compatibility():
	for objective in [ChapterDef.Objective.ROUT, ChapterDef.Objective.DEFEAT_BOSS, ChapterDef.Objective.SEIZE]:
		var view := await _view(true, false, true)
		view.chapter.objective = objective
		view.chapter.seize_cell = view.unit_by_id("kael").cell
		assert_null(view.unit_by_id("kai"), "authored force genuinely defines no lord")
		view.apply_save_payload(JSON.parse_string(JSON.stringify(view.make_save_payload())))
		await wait_physics_frames(2)
		view._check_objective()
		assert_false(view._battle_over, "absence of a lord is not a casualty")
		if objective == ChapterDef.Objective.DEFEAT_BOSS:
			view._kill(view.unit_by_id("serra"))
		else:
			for foe in view._living_foes_of(0).duplicate():
				view._kill(foe)
		await wait_physics_frames(2)
		view._check_objective()
		if objective == ChapterDef.Objective.SEIZE:
			assert_false(view._battle_over, "non-lord cannot seize")
			view._kill(view.unit_by_id("kael"))
			await wait_physics_frames(2)
			view._check_objective()
			assert_true(view._battle_over, "lordless full wipe still loses")
			assert_false(view._battle_victory)
		else:
			assert_true(view._battle_over)
			assert_true(view._battle_victory, "ordinary lordless rout/boss victory survives load")


func test_legacy_live_lord_save_keeps_defaults_and_can_seize():
	var view := await _view()
	view.chapter.objective = ChapterDef.Objective.SEIZE
	var payload := view.make_save_payload()
	payload.battle.erase("lord_alive")  # legacy loader defaults to living
	view.apply_save_payload(JSON.parse_string(JSON.stringify(payload)))
	await wait_physics_frames(2)
	assert_false(view._battle_over)
	assert_true(view._lord_alive)
	assert_not_null(view.unit_by_id("kai"))
	view.chapter.seize_cell = view.unit_by_id("kai").cell
	view._check_objective()
	assert_true(view._battle_over)
	assert_true(view._battle_victory, "reconstructed lord still satisfies seize")
