extends GutTest
## CP-6: mechanics and result parity, never a proxy for visual approval.


func _pilot() -> HybridCombatPilot:
	var pilot: HybridCombatPilot = load("res://scenes/proto/hybrid_combat_pilot.tscn").instantiate()
	add_child_autofree(pilot)
	pilot._cursor.set_process(false)
	return pilot


func test_review_cases_are_native_resolver_results_without_consuming_live_rng():
	var campaign := Campaign.to_dict().duplicate(true)
	var pilot := _pilot()
	var live_rng := pilot._rng.state_value()
	for kind: String in ["sword", "critical", "miss", "magic", "defeat"]:
		var result := pilot.prepare_review(kind)
		assert_not_null(result)
		var replay := CombatResolver.resolve(pilot._combatant_for(pilot.kai, pilot.kai.cell), pilot._combatant_for(pilot.serra, pilot.serra.cell), pilot._manhattan(pilot.kai.cell, pilot.serra.cell), CombatRNG.new(pilot.last_seed))
		assert_eq(str(result.strikes), str(replay.strikes), "the complete result is reproducible, including counters")
		assert_eq(pilot._rng.state_value(), live_rng, "review selection leaves live combat RNG untouched")
		var first := result.strikes[0]
		if kind == "miss":
			assert_false(first.connected)
		elif kind == "critical":
			assert_true(first.was_crit)
		elif kind == "defeat":
			assert_eq(first.defender_hp_after, 0)
		else:
			assert_true(first.connected)
	assert_eq(Campaign.to_dict(), campaign)
	assert_eq(pilot.kai._anim.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_null(pilot.kai._illustrated, "tactical Kai stays pixel art")


func test_existing_pixel_kits_have_chained_attacks_and_animated_reactions():
	for id: String in ["kai", "serra"]:
		var kit := BattlePopup.load_kit(id)
		for name: String in ["idle", "attack_wind", "attack_strike", "crit_wind", "crit_strike", "hit", "ko"]:
			assert_true(kit.has_animation(name))
			assert_gte(kit.get_frame_count(name), 7)
			assert_eq(kit.get_frame_texture(name, 0).get_size(), kit.get_frame_texture("idle", 0).get_size(), "shared canvas registration across states")


func test_full_a_b_replays_apply_same_hp_and_return_to_pixel_map():
	var campaign := Campaign.to_dict().duplicate(true)
	var pilot := _pilot()
	var events: Array = []
	var expected: Array[StrikeResult] = []
	pilot.pixel.contact.connect(func(strike: StrikeResult) -> void: events.append(strike))
	pilot.presentation.impact_applied.connect(func(_target: Unit, strike: StrikeResult) -> void: events.append(strike))
	var summaries: Dictionary = {}
	for kind: String in ["sword", "critical", "miss", "magic", "defeat"]:
		for variant: String in ["A", "B"]:
			events.clear()
			pilot.mode = variant
			await pilot.review(kind)
			expected.assign(pilot.last_result.strikes)
			assert_eq(events, expected, "both players apply every result once, in counter order")
			assert_eq(pilot.kai.current_hp, pilot.last_result.attacker_hp_after)
			assert_eq(pilot.serra.current_hp, pilot.last_result.defender_hp_after)
			assert_true(pilot._ui_layer.visible)
			assert_false(pilot.presentation._stage.visible)
			assert_false(pilot.pixel._root.visible)
			assert_false(pilot._busy)
			assert_false(pilot.presentation.busy)
			assert_almost_eq(Engine.time_scale, 1.0, 0.001)
			assert_eq(pilot.presentation._veil.color.a, 0.0)
			var summary := str(expected) + "|" + str(pilot.kai.current_hp) + "|" + str(pilot.serra.current_hp)
			if variant == "A":
				summaries[kind] = summary
			else:
				assert_eq(summary, summaries[kind], "matched scenario/result parity")
	assert_eq(Campaign.to_dict(), campaign, "no campaign/save/progression mutation")


func test_illustrated_miss_clears_the_blade_before_contact_without_hit_fx():
	var pilot := _pilot()
	pilot.mode = "B"
	var checked := [false]
	pilot.presentation.impact_applied.connect(func(_source: Unit, strike: StrikeResult) -> void:
		if checked[0] or strike.connected:
			return
		checked[0] = true
		var juice := pilot.presentation.juice
		assert_gt(juice.active_target.position.x - juice._target_home.x, 75.0, "defender is already clear at the impact beat")
		assert_eq(pilot.serra.current_hp, pilot.serra.max_hp())
		assert_eq(juice.active_target.scale, Vector2.ONE)
		assert_eq(juice.active_target.rotation, 0.0)
		var hits := 0
		for child in pilot.presentation.effects.get_children():
			if child is CombatFX and child.effect in ["white_hit", "gold_crit"]:
				hits += 1
		assert_eq(hits, 0, "a miss produces no impact burst"))
	await pilot.review("miss")
	assert_true(checked[0])


func test_real_tactical_input_enters_selected_presentation_and_consumes_rng_once():
	var pilot := _pilot()
	pilot.mode = "B"
	var seed := 71
	pilot._rng = CombatRNG.new(seed)
	var reference_rng := CombatRNG.new(seed)
	var expected := CombatResolver.resolve(pilot._combatant_for(pilot.kai, pilot.kai.cell), pilot._combatant_for(pilot.serra, pilot.serra.cell), 1, reference_rng)
	var accept := InputEventAction.new()
	accept.action = "cursor_confirm"
	accept.pressed = true
	pilot._cursor.move_to(pilot.kai.cell)
	pilot._cursor._unhandled_input(accept)
	assert_eq(pilot._phase, BattleView.Phase.SELECTED)
	pilot._cursor._unhandled_input(accept)
	assert_eq(pilot._phase, BattleView.Phase.MENU)
	# Choose Attack through the actual menu input callback, then target Serra.
	pilot._menu._index = pilot._menu_actions.find("attack")
	pilot._menu._unhandled_input(accept)
	if pilot._menu_context == "attack_weapon":
		pilot._menu._index = 0
		pilot._menu._unhandled_input(accept)
	assert_eq(pilot._phase, BattleView.Phase.TARGETING)
	pilot._cursor.move_to(pilot.serra.cell)
	pilot._cursor._unhandled_input(accept)
	var deadline := Time.get_ticks_msec() + 15000
	while pilot._busy and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	assert_false(pilot._busy)
	assert_eq(str(pilot.last_result.strikes), str(expected.strikes))
	assert_eq(pilot._rng.state_value(), reference_rng.state_value(), "presentation consumes no extra rolls")
	assert_eq(pilot.kai.current_hp, expected.attacker_hp_after)
	assert_eq(pilot.serra.current_hp, expected.defender_hp_after)
	assert_true(pilot._ui_layer.visible)
