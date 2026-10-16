extends GutTest
## CP-8: production executor, not the CP-6 sandbox or fabricated results.


func after_each() -> void:
	Campaign.reset_new_game(false)
	AudioManager.muted = false


func _view() -> BattleView:
	# This production presentation fixture represents post-Vision magic.
	Campaign.flags["crownspark_unlocked"] = true
	var view: BattleView = load("res://scenes/battle/mock_battle.tscn").instantiate()
	view.dialogue_enabled = false
	view.combat_seed = 1
	add_child_autofree(view)
	view._cursor.set_process(false)
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	kai.cell = Vector2i(8, 12)
	serra.cell = Vector2i(9, 12)
	kai.position = view._grid.cell_center(kai.cell)
	serra.position = view._grid.cell_center(serra.cell)
	return view


func _reference(view: BattleView, attacker: Unit, defender: Unit, lethal := false) -> Dictionary:
	for seed_value in range(10000):
		var rng := CombatRNG.new(seed_value)
		var result := CombatResolver.resolve(view._combatant_for(attacker, attacker.cell), view._combatant_for(defender, defender.cell), view._manhattan(attacker.cell, defender.cell), rng)
		if result.defender_defeated() == lethal and not result.attacker_defeated() and result.strikes[0].connected:
			view._rng = CombatRNG.new(seed_value)
			return {"rng": rng, "result": result}
	fail_test("no native review seed found")
	return {}


func _wait_idle(view: BattleView) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	while view._busy and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	assert_false(view._busy)


func test_only_approved_encounter_pair_weapons_and_designs_are_enabled():
	Campaign.reset_new_game(false)
	var view := _view()
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	var player := view._illustrated_combat
	assert_not_null(player)
	assert_true(player.supports_exchange(kai, serra))
	assert_true(player.supports_exchange(serra, kai), "enemy initiation keeps approved staging")
	assert_false(player.supports_exchange(view.unit_by_id("kael"), serra))
	kai.equip_weapon(load("res://data/weapons/iron_axe.tres"))
	assert_false(player.supports_exchange(kai, serra), "a sword painting cannot stand in for an axe")
	kai.equip_weapon(load("res://data/weapons/crownspark.tres"))
	assert_true(player.supports_exchange(kai, serra))
	kai._class_override = load("res://data/classes/warder_lord.tres")
	assert_false(player.supports_exchange(kai, serra), "promoted designs need their own approved art")
	kai._class_override = null
	serra.team = 2
	assert_false(player.supports_exchange(kai, serra), "unapproved staging stays on the existing path")
	var other: BattleView = load("res://scenes/battle/battle.tscn").instantiate()
	assert_false(other.illustrated_battles_enabled, "opt-in remains local to Mock Battle")
	other.free()


func test_real_command_menu_replays_once_and_spends_one_use_per_side():
	Campaign.reset_new_game(false)
	var view := _view()
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	var reference := _reference(view, kai, serra)
	var expected: CombatResult = reference["result"]
	var contacts: Array[StrikeResult] = []
	var cues: Array[String] = []
	var uses := kai.inventory.equipped_weapon_item().uses
	var counter_uses := serra.inventory.equipped_weapon_item().uses
	view._illustrated_combat.impact_applied.connect(func(source: Unit, strike: StrikeResult) -> void:
		contacts.append(strike)
		assert_true(view._busy)
		assert_false(view._ui_layer.visible)
		if strike.connected:
			assert_eq(source.current_hp, strike.defender_hp_after, "real map HP belongs to contact"))
	view._illustrated_combat.juice.sound_cued.connect(func(name: String) -> void: cues.append(name))
	var accept := InputEventAction.new()
	accept.action = "cursor_confirm"
	accept.pressed = true
	view._cursor.move_to(kai.cell)
	view._cursor._unhandled_input(accept)
	view._cursor._unhandled_input(accept)
	assert_eq(view._phase, BattleView.Phase.MENU)
	view._menu._index = view._menu_actions.find("attack")
	view._menu._unhandled_input(accept)
	if view._menu_context == "attack_weapon":
		view._menu._index = 0
		view._menu._unhandled_input(accept)
	assert_eq(view._phase, BattleView.Phase.TARGETING)
	view._cursor.move_to(serra.cell)
	view._cursor._unhandled_input(accept)
	await _wait_idle(view)
	assert_eq(str(contacts), str(expected.strikes))
	assert_eq(kai.current_hp, expected.attacker_hp_after)
	assert_eq(serra.current_hp, expected.defender_hp_after)
	assert_eq(kai.inventory.equipped_weapon_item().uses, uses - 1)
	assert_eq(serra.inventory.equipped_weapon_item().uses, counter_uses - 1)
	assert_eq(kai.xp, CombatXP.award(kai.level, serra.level, true, false))
	assert_eq(view._rng.state_value(), reference["rng"].state_value(), "presentation consumes no extra rolls")
	assert_eq(cues.count("blade_whoosh"), expected.strikes.size())
	assert_true(kai.has_acted)
	assert_true(view._ui_layer.visible)
	assert_false(view._illustrated_combat.busy)
	assert_false(view._illustrated_combat._stage.visible)
	assert_false(view._battle_popup._root.visible)
	assert_eq(view._phase, BattleView.Phase.IDLE)
	assert_null(kai._illustrated, "the tactical actor stays pixel art")
	assert_eq(kai._anim.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)


func test_enemy_initiation_and_magic_use_the_same_executor_results():
	Campaign.reset_new_game(false)
	var view := _view()
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	var events: Array[StrikeResult] = []
	var cues: Array[String] = []
	view._illustrated_combat.impact_applied.connect(func(_source: Unit, strike: StrikeResult) -> void: events.append(strike))
	view._illustrated_combat.juice.sound_cued.connect(func(name: String) -> void: cues.append(name))
	var reference := _reference(view, serra, kai)
	await view._execute_attack(serra, kai)
	assert_eq(str(events), str(reference["result"].strikes))
	assert_eq(view._rng.state_value(), reference["rng"].state_value())
	assert_true(view._ui_layer.visible)
	events.clear()
	cues.clear()
	kai.current_hp = kai.max_hp()
	serra.current_hp = serra.max_hp()
	kai.equip_weapon(load("res://data/weapons/crownspark.tres"))
	kai.cell = Vector2i(7, 12)
	kai.position = view._grid.cell_center(kai.cell)
	var uses := kai.inventory.equipped_weapon_item().uses
	var counter_uses := serra.inventory.equipped_weapon_item().uses
	reference = _reference(view, kai, serra)
	var before_xp := kai.xp
	await view._execute_attack(kai, serra)
	assert_eq(str(events), str(reference["result"].strikes))
	assert_eq(view._rng.state_value(), reference["rng"].state_value())
	assert_eq(kai.inventory.equipped_weapon_item().uses, uses - 1)
	assert_eq(serra.inventory.equipped_weapon_item().uses, counter_uses, "out-of-range lance never spends a use")
	assert_gt(kai.xp, before_xp)
	assert_eq(cues.count("magic_gather"), events.size())
	assert_eq(cues.count("magic_release"), events.size())
	var connected := 0
	for strike in events:
		if strike.connected:
			connected += 1
	assert_eq(cues.count("magic_impact"), connected)
	assert_false(cues.has("blade_whoosh"))
	for name in cues:
		assert_not_null(AudioManager._sfx_cache.get(name), "cue loads an actual audio stream")


func _advance_dialogues(view: BattleView, scripts: Array) -> void:
	var deadline := Time.get_ticks_msec() + 20000
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	while is_instance_valid(view) and not view._result_screen.is_shown() and Time.get_ticks_msec() < deadline:
		for node in view.find_children("*", "", true, false):
			if node is DialogueScene and not node.is_finished():
				if not scripts.has(node._script):
					scripts.append(node._script)
				node._unhandled_key_input(accept)
		await get_tree().create_timer(0.04).timeout


func test_lethal_yield_level_up_and_campaign_capture_follow_the_presentation():
	Campaign.reset_new_game(false)
	Campaign.deploy()
	var view := _view()
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	for unit in view._units.duplicate():
		if unit.team != 0 and unit != serra:
			view._remove_unit_without_events(unit)  # fixture: only the final rival remains
	serra.current_hp = 1
	kai.xp = 95
	var uses := kai.inventory.equipped_weapon_item().uses
	var reference := _reference(view, kai, serra, true)
	var rng: CombatRNG = reference["rng"]
	var expected_gains := LevelUp.roll(kai.unit_def.growths(), rng)
	var scripts: Array = []
	var cues: Array[String] = []
	view._illustrated_combat.juice.sound_cued.connect(func(name: String) -> void: cues.append(name))
	view.dialogue_enabled = true
	_advance_dialogues(view, scripts)
	await view._execute_attack(kai, serra)
	var deadline := Time.get_ticks_msec() + 10000
	while not view._result_screen.is_shown() and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.04).timeout
	assert_true(view._boss_quote_played)
	assert_false(view._boss_alive)
	assert_true(view._battle_over)
	assert_true(view._battle_victory)
	assert_true(view._result_screen.is_shown())
	assert_eq(scripts.size(), 3, "boss quote, yield and outro all run after/before the appropriate stage")
	if scripts.size() == 3:
		var paths: Array[String] = [view.chapter.boss_quote_dialogue, view.chapter.boss_yield_dialogue, view.chapter.outro_dialogue]
		for index in range(3):
			assert_eq(scripts[index].steps[0].text, DialogueScript.from_file(paths[index]).steps[0].text)
	assert_eq(kai.level, 2)
	assert_eq(kai._stat_bonus, expected_gains)
	assert_eq(view._rng.state_value(), rng.state_value(), "only combat + real level-up rolls consumed")
	assert_eq(kai.inventory.equipped_weapon_item().uses, uses - 1)
	assert_eq(Campaign.last_result, "victory")
	assert_eq(Campaign.get_unit_state("kai"), kai.progression_state())
	assert_true(view._defeated_unit_ids.has("serra"))
	assert_true(view._permadead_unit_ids.is_empty(), "Mock Battle remains non-lethal")
	assert_eq(cues.count("armor_drop"), 1)
	assert_true(view._ui_layer.visible)
	assert_false(view._illustrated_combat._stage.visible)
