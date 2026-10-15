extends GutTest
## CP-9 provisional isolated rules and actual illustrated input/contact flow.


func _base() -> StrikeResult:
	var strike := StrikeResult.new()
	strike.connected = true
	strike.damage = 11
	strike.defender_hp_before = 26
	strike.defender_hp_after = 15
	return strike


func _config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/proto/active_defense.json"))


func test_timing_boundaries_damage_spam_and_no_input():
	var base := _base()
	var settings: Dictionary = _config()["normal"]
	for action: String in ["dodge", "block"]:
		for offset: float in [-float(settings[action + "_window"]), 0.0, float(settings[action + "_window"])]:
			var trial := ActiveDefenseTrial.new(settings)
			trial.elapsed = float(settings["cue"]) + offset
			if trial.elapsed > float(settings["windup"]):
				continue
			assert_true(trial.attempt(action))
			assert_false(trial.attempt(action), "one attempt per strike")
			var report := trial.resolve(base, 0.5)
			assert_eq(report["result"], action)
			assert_eq(report["strike"].damage, 0 if action == "dodge" else 6)
			assert_eq(report["strike"].defender_hp_after, 26 if action == "dodge" else 20)
			assert_eq(base.defender_hp_after, 15, "native result is immutable")
			assert_false(trial.attempt("dodge"), "closed window rejects input")
	var early := ActiveDefenseTrial.new(settings)
	assert_false(early.attempt("invalid"))
	assert_true(early.attempt("dodge"))
	early.advance(0.68, false)
	assert_false(early.attempt("block"), "early spam cannot be rescued by another key")
	assert_eq(early.resolve(base, 0.5)["result"], "failed")
	var late := ActiveDefenseTrial.new(settings)
	late.advance(1.0, false)
	late.attempt("block")
	assert_eq(late.resolve(base, 0.5)["result"], "failed")
	var none := ActiveDefenseTrial.new(settings)
	assert_eq(none.resolve(base, 0.5)["strike"].defender_hp_after, 15)
	base.connected = false
	base.damage = 0
	base.defender_hp_after = 26
	var miss := ActiveDefenseTrial.new(settings)
	miss.attempt("block")
	assert_eq(miss.resolve(base, 0.5)["result"], "native_miss")
	base.connected = true
	base.damage = 1
	var minimum := ActiveDefenseTrial.new(settings)
	minimum.elapsed = settings["cue"]
	minimum.attempt("block")
	assert_eq(minimum.resolve(base, 0.5)["strike"].damage, 1, "round up; block is not another full evade")


func test_assist_and_windows_are_stable_across_frame_rates():
	var config := _config()
	assert_gt(config["practice"]["dodge_window"], config["normal"]["dodge_window"])
	assert_gt(config["practice"]["block_window"], config["normal"]["block_window"])
	assert_gt(config["normal"]["block_window"], config["normal"]["dodge_window"], "block trades damage for easier timing")
	assert_gt(config["practice"]["block_window"], config["practice"]["dodge_window"])
	for step: float in [1.0 / 30, 1.0 / 60, 1.0 / 144, 1.3]:
		var trial := ActiveDefenseTrial.new(config["practice"])
		while trial.elapsed < float(trial.settings["windup"]):
			trial.advance(step, true)
		var report := trial.resolve(_base(), 0.5)
		assert_eq(report["result"], "block")
		assert_true(report["assisted"])
		assert_eq(report["offset"], 0.0)


func _press_at(pilot: ActiveDefensePilot, choice: String, offset: float) -> void:
	var target := float(pilot.trial.settings["cue"]) + offset
	while pilot.trial.elapsed < target:
		await get_tree().process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_Q if choice == "dodge" else KEY_E
	event.pressed = true
	pilot._unhandled_input(event)
	# Repeated key-down/other button cannot overwrite the first attempt.
	event.echo = true
	pilot._unhandled_input(event)
	assert_false(pilot.attempt("block" if choice == "dodge" else "dodge"))


func test_real_input_changes_only_the_single_strike_at_contact():
	var campaign := Campaign.to_dict().duplicate(true)
	var pilot: ActiveDefensePilot = load("res://scenes/proto/active_defense_pilot.tscn").instantiate()
	add_child_autofree(pilot)
	var rng_state := pilot._rng.state_value()
	var inventory := pilot.kai.progression_state().duplicate(true)
	var events: Array[StrikeResult] = []
	var requested := [""]
	pilot.window_opened.connect(func() -> void:
		if requested[0] != "":
			_press_at(pilot, requested[0], 0.0))
	pilot.judged.connect(func(_report: Dictionary) -> void:
		assert_eq(pilot.kai.current_hp, 26, "judging never applies HP early")
		assert_eq(pilot.presentation.juice.active_target.current_hp, 26))
	pilot.presentation.impact_applied.connect(func(source: Unit, strike: StrikeResult) -> void:
		events.append(strike)
		assert_eq(source.current_hp, strike.defender_hp_after)
		if pilot.last_report["result"] == "dodge":
			var juice := pilot.presentation.juice
			assert_gt(absf(juice.active_target.position.x - juice._target_home.x), 75.0, "Kai clears the thrust before contact"))
	for choice: String in ["dodge", "block", "", "assist"]:
		requested[0] = choice if choice in ["dodge", "block"] else ""
		pilot.auto_block = choice == "assist"
		events.clear()
		await pilot.begin_trial()
		assert_eq(events.size(), 1, "no stale native counters")
		assert_eq(pilot.last_result.strikes.size(), 1)
		var result: String = "block" if choice == "assist" else (choice if choice != "" else "no_input")
		assert_eq(pilot.last_report["result"], result)
		assert_eq(pilot.kai.current_hp, 26 if result == "dodge" else (20 if result == "block" else 15))
		assert_eq(pilot.last_base.defender_hp_after, 15)
		assert_eq(pilot.last_result.defender_hp_after, pilot.kai.current_hp)
		assert_false(pilot.presentation.busy)
		assert_true(pilot._ui_layer.visible)
		assert_eq(pilot._rng.state_value(), rng_state)
		assert_eq(pilot.kai.progression_state(), inventory, "no XP or weapon-use writes")
		assert_eq(Campaign.to_dict(), campaign)
		assert_almost_eq(Engine.time_scale, 1.0, 0.001)
