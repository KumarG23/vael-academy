extends GutTest
## GH-29: exercise the six actual registry routes, not a synthetic chapter.
## Controlled runtime fixtures; graphical qualification is tracked separately.

const HOUSES := ["emberwing", "tidemark", "thornrook"]
const EVENTS := ["mock_battle", "closing_rite"]


func after_each() -> void:
	BattleView.next_resume = {}
	Campaign.reset_new_game(false)


func _view(house: String, event: String, casual := false) -> BattleView:
	Campaign.reset_new_game(casual)
	Campaign.set_house(house)
	Campaign.house_locked = true
	Campaign.week = 1 if event == "mock_battle" else 6
	Campaign.deploy()
	var view: BattleView = load(ChapterRegistry.scene_for(event, house)).instantiate()
	view.dialogue_enabled = false
	view.strike_delay = 0.0
	add_child_autofree(view)
	return view


func _ids(house: String) -> Array[String]:
	var ids: Array[String] = []
	for file in Roster.HOUSE_ROSTERS[house]:
		var def: UnitDef = load("res://data/units/%s.tres" % file)
		ids.append(def.id)
	ids.sort()
	return ids


func _assert_forces(view: BattleView, house: String) -> void:
	var expected_player := _ids(house)
	expected_player.append("kai")
	expected_player.sort()
	var players: Array[String] = []
	for u in view._living_units_on_team(0):
		players.append(u.unit_id())
	players.sort()
	assert_eq(players, expected_player, view.chapter.id + " player roster")
	var rival_teams: Array[int] = []
	for rival in HOUSES:
		if rival == house:
			continue
		var ids: Array[String] = []
		var teams := {}
		for u in view._living_foes_of(0):
			if u.unit_def.house_id == rival:
				ids.append(u.unit_id())
				teams[u.team] = true
		ids.sort()
		assert_eq(ids, _ids(rival), view.chapter.id + " fields " + rival + " exactly once")
		assert_eq(teams.size(), 1, "each rival is one faction")
		if teams.size() == 1:
			rival_teams.append(teams.keys()[0])
	assert_eq(rival_teams.size(), 2)
	if rival_teams.size() == 2:
		assert_ne(rival_teams[0], rival_teams[1], "rivals are hostile to one another")
	assert_eq(view._nonplayer_teams(), [1, 2])


func test_six_routed_resources_and_runtime_forces():
	for house in HOUSES:
		for event in EVENTS:
			var view := _view(house, event)
			_assert_forces(view, house)
			assert_eq(view.chapter.objective, ChapterDef.Objective.ROUT)
			assert_eq(view.chapter.display_name, "Clash of Three Banners")
			assert_true(view.chapter.non_lethal)
			assert_eq(ChapterRegistry.resume_scene(view.chapter.id), ChapterRegistry.scene_for(event, house))
			var taken := {}
			for u in view._units:
				assert_false(taken.has(u.cell), "%s: unique %s" % [view.chapter.id, u.unit_id()])
				taken[u.cell] = true
				var ctx: BattleMoveContext = view._make_context(u)
				assert_true(ctx.in_bounds(u.cell))
				assert_lt(ctx.enter_cost(u.cell), Pathfinder.INF_COST, "%s: legal terrain for %s" % [view.chapter.id, u.unit_id()])
				assert_gt(MovementRange.standable_tiles(u.cell, u.move_points(), ctx).size(), 1)
			view.free()


func test_one_eliminated_rival_is_insufficient_then_last_house_wins():
	for house in HOUSES:
		for event in EVENTS:
			var view := _view(house, event)
			# Include the legacy boss in the first eliminated faction: boss data
			# remains for authored quotes, but cannot short-circuit ROUT.
			var first_team: int = view._boss_unit.team if is_instance_valid(view._boss_unit) else 1
			for foe in view._living_units_on_team(first_team).duplicate():
				view._kill(foe)
			await wait_physics_frames(2)
			view._check_objective()
			assert_false(view._battle_over, view.chapter.id + " requires both rival houses")
			for foe in view._living_foes_of(0).duplicate():
				view._kill(foe)
			await wait_physics_frames(2)
			view._check_objective()
			assert_true(view._battle_over)
			assert_true(view._battle_victory)
			assert_eq(Campaign.last_result, "victory")
			view.free()


func _resume(view: BattleView) -> BattleView:
	var io := SaveSystem.new("user://three_house_tests")
	assert_true(io.save_slot(0, view.make_save_payload()))
	var path := Resume.stage(io.load_slot(0))
	assert_eq(path, ChapterRegistry.resume_scene(view.chapter.id))
	var loaded: BattleView = load(path).instantiate()
	loaded.dialogue_enabled = false
	loaded.strike_delay = 0.0
	add_child_autofree(loaded)
	return loaded


func test_saved_forces_resume_with_independent_teams_and_continue():
	for house in HOUSES:
		for event in EVENTS:
			var view := _view(house, event)
			var loaded := _resume(view)
			_assert_forces(loaded, house)
			assert_false(loaded._battle_over)
			for foe in loaded._living_units_on_team(1).duplicate():
				loaded._kill(foe)
			await wait_physics_frames(2)
			loaded._check_objective()
			assert_false(loaded._battle_over)
			for foe in loaded._living_foes_of(0).duplicate():
				loaded._kill(foe)
			loaded._check_objective()
			assert_true(loaded._battle_victory)
			view.free()
			loaded.free()


func test_friendly_losses_survive_result_campaign_save_and_next_deploy():
	for casual in [false, true]:
		for house in HOUSES:
			for event in EVENTS:
				var view := _view(house, event, casual)
				# Every house unit yields, including Nilu; Kai alone wins the fixture.
				for u in view._living_units_on_team(0).duplicate():
					if u.unit_id() != "kai":
						view._kill(u)
				await wait_physics_frames(2)
				var loaded := _resume(view)
				for foe in loaded._living_foes_of(0).duplicate():
					loaded._kill(foe)
				loaded._check_objective()
				assert_true(loaded._battle_victory)
				assert_true(loaded._permadead_unit_ids.is_empty())
				assert_eq(Campaign.last_result, "victory")
				var io := SaveSystem.new("user://three_house_tests")
				assert_true(Campaign.save_to_slot(1, io))
				assert_true(Campaign.load_from_slot(1, io))
				var next := _view_after_campaign(house, event)
				for id in _ids(house):
					var returned := next.unit_by_id(id)
					assert_not_null(returned, id + " returns after yielding")
					assert_true(returned.is_alive())
				assert_eq(next._living_units_on_team(0).size(), _ids(house).size() + 1)
				view.free()
				loaded.free()
				next.free()


func _view_after_campaign(house: String, event: String) -> BattleView:
	Campaign.deploy()
	var view: BattleView = load(ChapterRegistry.scene_for(event, house)).instantiate()
	view.dialogue_enabled = false
	view.strike_delay = 0.0
	add_child_autofree(view)
	return view


func test_freed_lord_and_resumed_loss_precede_last_house_victory_on_every_route():
	for casual in [false, true]:
		for house in HOUSES:
			for event in EVENTS:
				var view := _view(house, event, casual)
				var week := Campaign.week
				var kai := view.unit_by_id("kai")
				view._kill(kai)
				for foe in view._living_foes_of(0).duplicate():
					view._kill(foe)
				await wait_physics_frames(2)
				assert_false(is_instance_valid(kai))
				var loaded := _resume(view)
				assert_true(loaded._battle_over)
				assert_false(loaded._battle_victory)
				assert_eq(Campaign.last_result, "defeat")
				assert_eq(Campaign.week, week)
				view._check_objective()
				assert_false(view._battle_victory)
				view.free()
				loaded.free()


func test_native_ai_can_attack_either_opponent_and_execute_rival_combat():
	for house in HOUSES:
		for event in EVENTS:
			var view := _view(house, event)
			for team in [1, 2]:
				var actors := view._living_units_on_team(team)
				assert_false(actors.is_empty())
				if actors.is_empty():
					continue
				var actor: Unit = actors[0]
				for target_team in [0, 3 - team]:
					var targets := view._living_units_on_team(target_team)
					assert_false(targets.is_empty())
					if targets.is_empty():
						continue
					var target: Unit = targets[0]
					# Controlled adjacent pair on the actual map with original kits.
					actor.cell = Vector2i(9, 7)
					target.cell = Vector2i(10, 7)
					var decision := AIBrain.decide(actor, [actor, target], view.chapter, view._terrain_db, AIBrain.Behavior.AGGRESSOR)
					assert_eq(decision.target, target, "AI recognizes team %d as hostile to %d" % [target_team, team])
					if target_team != 0:
						var item := actor.inventory.equipped_weapon_item()
						var uses: int = item.uses
						actor.cell = decision.move_to
						await view._execute_attack(actor, target)
						assert_lt(item.uses, uses, "native rival combat consumes weapon uses")
			view.free()
