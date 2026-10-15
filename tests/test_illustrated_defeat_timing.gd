extends GutTest
## CP-7: lethal HP belongs to contact, the collapsed pose belongs after impact.


func _check_upright_hold(target: Unit, samples: Array) -> void:
	await get_tree().create_timer(0.12).timeout
	assert_eq(target._illustrated.pose, "parry_hit", "upright reaction remains readable after hit-stop")
	assert_eq(target.current_hp, 0, "the visual hold does not defer damage")
	samples.append(true)


func test_native_lethal_hits_hold_upright_before_collapse():
	var pilot: HybridCombatPilot = load("res://scenes/proto/hybrid_combat_pilot.tscn").instantiate()
	add_child_autofree(pilot)
	pilot._cursor.set_process(false)
	pilot.mode = "B"
	var sequence: Array[String] = []
	var samples: Array = []
	var contacts: Array[StrikeResult] = []
	pilot.presentation.impact_applied.connect(func(source: Unit, strike: StrikeResult) -> void:
		contacts.append(strike)
		if strike.connected and strike.defender_hp_after == 0:
			assert_eq(source.current_hp, 0, "source HP updates at contact")
			sequence.append("hp_zero"))
	pilot.presentation.beat.connect(func(name: String) -> void:
		var juice := pilot.presentation.juice
		if name == "commit":
			assert_ne(juice.active_target._illustrated.pose, "defeat", "no collapse during anticipation/approach")
		if name == "contact" and juice.active_strike.connected and juice.active_strike.defender_hp_after == 0:
			assert_eq(juice.active_target._illustrated.pose, "parry_hit")
			sequence.append("upright_hit")
			_check_upright_hold(juice.active_target, samples)
		if name == "defeat":
			assert_eq(juice.active_target._illustrated.pose, "defeat")
			assert_eq(juice.active_target.current_hp, 0)
			assert_eq(samples.size(), 1, "collapse follows the rendered upright hold")
			assert_eq(juice.active_target.scale, Vector2.ONE)
			assert_eq(juice.active_target.rotation, 0.0)
			sequence.append("collapse"))
	for kind: String in ["defeat", "critical"]:
		sequence.clear()
		samples.clear()
		contacts.clear()
		await pilot.review(kind)
		assert_eq(sequence, ["hp_zero", "upright_hit", "collapse"], kind)
		assert_eq(contacts, pilot.last_result.strikes, "every native hit/counter is applied once")
		assert_eq(pilot.serra.current_hp, pilot.last_result.defender_hp_after)
		assert_false(pilot.presentation.busy)
		assert_almost_eq(Engine.time_scale, 1.0, 0.001)
