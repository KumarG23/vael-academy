extends GutTest
## GH-75 / WO-9.5: held Space changes only the current exchange's pace.
## Fixtures and native-state comparison helpers follow accepted GH-65 coverage.
## Production views, real viewport input, same-seed outcomes and wall-clock bounds.

const MOCK := "res://scenes/battle/mock_battle.tscn"

var _dialogue_scripts: Array = []


func after_each() -> void:
	Campaign.reset_new_game(false)
	AudioManager.muted = false
	Engine.time_scale = 1.0


# --- fixtures -------------------------------------------------------------------

## Each view gets its own 1280×720 viewport: input reaches only that battle.
func _mock(popups := false, size := Vector2i(1280, 720)) -> BattleView:
	Campaign.reset_new_game(false)
	Campaign.deploy()
	Campaign.flags["crownspark_unlocked"] = true  # CP-8 fixture: post-Vision magic
	var host := SubViewport.new()
	host.size = size
	host.handle_input_locally = true
	add_child_autofree(host)
	var view: BattleView = load(MOCK).instantiate()
	view.dialogue_enabled = false
	view.combat_seed = 1
	view.battle_popups_enabled = popups
	host.add_child(view)
	view._cursor.set_process(false)
	return view


func _place(view: BattleView, unit: Unit, cell: Vector2i) -> void:
	unit.cell = cell
	unit.position = view._grid.cell_center(cell)


## Kai/Serra adjacent: the one approved illustrated encounter (CP-8).
func _illustrated() -> BattleView:
	var view := _mock()
	_place(view, view.unit_by_id("kai"), Vector2i(8, 12))
	_place(view, view._boss_unit, Vector2i(9, 12))
	return view


## Kael/Osric adjacent: fully kitted, so pixel popup when enabled, else map strikes.
func _kitted(popups: bool) -> BattleView:
	var view := _mock(popups)
	_place(view, view.unit_by_id("kael"), Vector2i(8, 10))
	_place(view, view.unit_by_id("osric"), Vector2i(9, 10))
	return view


func _seed_for(view: BattleView, attacker: Unit, defender: Unit, want: Callable) -> int:
	for seed_value in range(20000):
		var result := CombatResolver.resolve(view._combatant_for(attacker, attacker.cell),
			view._combatant_for(defender, defender.cell), view._manhattan(attacker.cell, defender.cell),
			CombatRNG.new(seed_value))
		if want.call(result):
			return seed_value
	fail_test("no native seed found")
	return 0


## Damage of one ordinary (non-crit) connecting blow, from the native resolver.
func _hit_damage(view: BattleView, attacker: Unit, defender: Unit) -> int:
	var seed_value := _seed_for(view, attacker, defender, func(r: CombatResult) -> bool:
		return r.strikes[0].connected and not r.strikes[0].was_crit)
	return CombatResolver.resolve(view._combatant_for(attacker, attacker.cell), view._combatant_for(defender, defender.cell),
		view._manhattan(attacker.cell, defender.cell), CombatRNG.new(seed_value)).strikes[0].damage


static func _counters(result: CombatResult) -> int:
	var n := 0
	for strike in result.strikes:
		if strike.is_counter:
			n += 1
	return n


static func _misses(result: CombatResult) -> int:
	var n := 0
	for strike in result.strikes:
		if not strike.connected:
			n += 1
	return n


static func _crits(result: CombatResult) -> int:
	var n := 0
	for strike in result.strikes:
		if strike.was_crit:
			n += 1
	return n


# --- real viewport input -----------------------------------------------------------

func _key(view: BattleView, keycode: Key, pressed: bool, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	event.echo = echo
	view.get_viewport().push_input(event, true)


func _tap(view: BattleView, keycode: Key) -> void:
	_key(view, keycode, true)
	_key(view, keycode, false)


func _click(view: BattleView, cell: Vector2i) -> void:
	var at: Vector2 = view._cursor.get_global_transform_with_canvas() * view._grid.cell_center(cell)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	view.get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = at
		click.global_position = at
		view.get_viewport().push_input(click, true)


## The ordinary Attack command through the cursor/menu, by keyboard (Enter).
## Returns as soon as the attack is committed; the exchange plays on.
func _command_attack(view: BattleView, unit: Unit, target: Unit) -> void:
	view._cursor.move_to(unit.cell)
	_tap(view, KEY_ENTER)
	_tap(view, KEY_ENTER)
	assert_eq(view._phase, BattleView.Phase.MENU, "command menu opened")
	view._menu._index = view._menu_actions.find("attack")
	_tap(view, KEY_ENTER)
	if view._menu_context == "attack_weapon":
		view._menu._index = 0
		_tap(view, KEY_ENTER)
	assert_eq(view._phase, BattleView.Phase.TARGETING)
	view._cursor.move_to(target.cell)
	_tap(view, KEY_ENTER)


func _armed(view: BattleView) -> bool:
	var layer = view._combat_exec.get("_skip_input")
	return layer != null and is_instance_valid(layer) and layer.is_armed()


func _now() -> int:
	return Time.get_ticks_msec()


## Starts an exchange and holds Space the first frame `when` is true.
## Returns {pressed, start, press, done} in ms.
func _play(view: BattleView, start: Callable, done: Callable, when: Callable = Callable()) -> Dictionary:
	var info := {"pressed": false, "start": _now(), "press": -1, "done": -1}
	start.call()
	var deadline := _now() + 30000
	while not done.call() and _now() < deadline:
		if when.is_valid() and not info["pressed"] and when.call():
			_key(view, KEY_SPACE, true)
			info["pressed"] = true
			info["press"] = _now()
		await get_tree().process_frame
	info["done"] = _now()
	assert_true(done.call(), "exchange completed")
	return info


func _attack_done(view: BattleView, attacker: Unit) -> Callable:
	return func() -> bool:
		return not view._busy and not _armed(view) and (not is_instance_valid(attacker) or attacker.has_acted or view._battle_over)


## Everything the exchange may legitimately change, plus presentation residue
## that must be gone once it returns.
func _state(view: BattleView) -> Dictionary:
	var units := []
	for u: Unit in view._units:
		if not is_instance_valid(u):
			continue
		var uses := []
		for item in u.inventory.items:
			uses.append(item.uses)
		units.append([u.unit_id(), u.team, u.current_hp, u.cell, u.has_acted, u.xp, u.level,
			u._stat_bonus, uses, u.position.round(), u.visible, u.modulate, u.scale, u.rotation])
	var payload := view.make_save_payload()
	var campaign_units := {}
	for u: Unit in view._units:
		if is_instance_valid(u) and u.team == 0:
			campaign_units[u.unit_id()] = Campaign.get_unit_state(u.unit_id())
	return {
		"units": var_to_str(units),
		"battle": JSON.stringify(payload["battle"]),
		"roster": JSON.stringify(payload["roster"]),
		"supports": JSON.stringify(payload["supports"]),
		"campaign_units": JSON.stringify(campaign_units),
		"last_result": Campaign.last_result,
		"rng": str(view._rng.state_value()),
		"busy": view._busy,
		"phase": view._phase,
		"over": view._battle_over,
		"victory": view._battle_victory,
		"result_shown": view._result_screen.is_shown(),
		"ui_layer": view._ui_layer.visible,
		"cursor_active": view._cursor.active,
		"cam_active": view._combat_cam_active,
		"zoom": view._camera.zoom,
		"camera_offset": view._camera.offset,
		"time_scale": Engine.time_scale,
		"splash": view._splash.is_active(),
		"popup": view._battle_popup._root.visible,
		"popup_bursts": view._battle_popup._bursts.size(),
		"stage": view._illustrated_combat._stage.visible,
		"stage_busy": view._illustrated_combat.busy,
		"stage_actors": view._illustrated_combat.actors.size(),
		"level_up": view._level_up_screen.visible,
	}


func _assert_same(actual: Dictionary, expected: Dictionary, label: String) -> void:
	for key in expected:
		assert_eq(actual[key], expected[key], "%s: %s matches normal playback" % [label, key])


## Nothing may keep animating or mutating after the exchange has returned.
func _assert_settled(view: BattleView, label: String) -> void:
	await get_tree().process_frame
	var settled := _state(view)
	assert_eq(settled["time_scale"], 1.0, "%s: no hit-stop freeze left behind" % label)
	assert_false(settled["splash"], "%s: no splash left on the map" % label)
	assert_eq(settled["camera_offset"], Vector2.ZERO, "%s: no camera shake left" % label)
	assert_eq(settled["popup_bursts"], 0, "%s: no popup effects left" % label)
	assert_eq(view._illustrated_combat.effects.get_child_count(), 0, "%s: no illustrated effects left" % label)
	var numbers := 0
	for child in view._units_root.get_children():
		# Juice damage/miss numbers; map _pop_text notices (Yields!/+N) are not
		# exchange presentation and keep their ordinary lifetime.
		if child is Label and ((child.text.is_valid_int() and not child.text.begins_with("+")) or child.text.begins_with("CRIT") or child.text == "Miss"):
			numbers += 1
	assert_eq(numbers, 0, "%s: no floating combat numbers left" % label)
	await get_tree().create_timer(0.9).timeout
	_assert_same(_state(view), settled, label + " (0.9 s later)")


func _record_contacts(view: BattleView) -> Array:
	var log := []
	view._illustrated_combat.impact_applied.connect(func(source: Unit, strike: StrikeResult) -> void:
		log.append([source.unit_id(), str(strike), source.current_hp]))
	return log


# Compare real input and native state, not a synthetic clock alone.
func _run_speed(view: BattleView, attacker: Unit, defender: Unit, fast: bool, release_ms := -1) -> Dictionary:
	var start := _now()
	var pressed := -1
	var released := false
	var hp_trace := []
	_command_attack(view, attacker, defender)
	while not _attack_done(view, attacker).call() and _now() - start < 30000:
		if fast and pressed < 0 and _armed(view):
			_key(view, KEY_SPACE, true)
			pressed = _now()
		if pressed >= 0 and release_ms >= 0 and not released and _now() - pressed >= release_ms:
			_key(view, KEY_SPACE, false)
			released = true
		var hp := [attacker.current_hp, defender.current_hp] if is_instance_valid(defender) else [attacker.current_hp, 0]
		if hp_trace.is_empty() or hp_trace[-1] != hp:
			hp_trace.append(hp)
		await get_tree().process_frame
	var final_hp := [attacker.current_hp, defender.current_hp] if is_instance_valid(defender) else [attacker.current_hp, 0]
	if hp_trace.is_empty() or hp_trace[-1] != final_hp:
		hp_trace.append(final_hp)
	_key(view, KEY_SPACE, false)
	assert_true(_attack_done(view, attacker).call())
	return {"ms": _now() - start, "state": _state(view), "hp_trace": hp_trace}


func test_held_speed_preserves_native_results_all_attack_routes():
	for route in ["illustrated", "map", "popup"]:
		var runs := []
		var logs := []
		for fast in [false, true]:
			var view := _illustrated() if route == "illustrated" else _kitted(route == "popup")
			var attacker := view.unit_by_id("kai" if route == "illustrated" else "kael")
			var defender := view._boss_unit if route == "illustrated" else view.unit_by_id("osric")
			var log := _record_contacts(view)
			view._rng = CombatRNG.new(1)
			runs.append(await _run_speed(view, attacker, defender, fast))
			logs.append(str(log))
		print("GH-75 ", route, " normal/held ms: ", runs[0]["ms"], "/", runs[1]["ms"])
		assert_lt(runs[1]["ms"], int(runs[0]["ms"] * 0.78), route + ": held playback is substantially faster")
		assert_gt(runs[1]["ms"], int(runs[0]["ms"] * 0.32), route + ": retains motion, never immediate skip")
		_assert_same(runs[1]["state"], runs[0]["state"], route)
		assert_eq(logs[1], logs[0], route + ": contact order and HP")
		assert_eq(runs[1]["hp_trace"], runs[0]["hp_trace"], route + ": native HP changes stay in order")
	if DisplayServer.get_name() == "headless":
		assert_engine_error_count(4, "popup readback only")


func test_release_during_exchange_restores_remaining_pace():
	var runs := []
	for release_ms in [-2, -1, 80, 650]:
		var view := _illustrated()
		runs.append(await _run_speed(view, view.unit_by_id("kai"), view._boss_unit, release_ms != -2, release_ms))
	for index in [2, 3]:
		_assert_same(runs[index]["state"], runs[0]["state"], "released")
		assert_gt(runs[index]["ms"], int(runs[1]["ms"] * 1.35), "release restores normal remainder")
		assert_lt(abs(runs[index]["ms"] - (runs[0]["ms"] - [0, 0, 80, 650][index])), 450, "only held interval removed")


func test_real_map_heal_and_declared_popup_heal_match_normal():
	for popup_fixture in [false, true]:
		var states := []
		var durations := []
		for fast in [false, true]:
			var view := _mock(popup_fixture)
			var healer := view.unit_by_id("wren")
			var ally := view.unit_by_id("kael")
			_place(view, healer, Vector2i(5, 12))
			_place(view, ally, Vector2i(6, 12))
			ally.current_hp = 5
			# Declared art-only fixture: a kit alias without a map rig, exercising
			# the executor's otherwise gated popup-heal branch with a real staff.
			if popup_fixture:
				healer.unit_def = healer.unit_def.duplicate()
				healer.unit_def.id = "tm_mage"
				assert_false(CombatRig.has_rig(healer.unit_id()))
				assert_true(BattlePopup.has_kit(healer.unit_id()))
			var finished := [false]
			var start := _now()
			var run := func() -> void:
				await view._execute_heal(healer, ally)
				finished[0] = true
			run.call()
			if fast:
				_key(view, KEY_SPACE, true)
			while not finished[0] and _now() - start < 10000:
				await get_tree().process_frame
			assert_true(finished[0])
			_key(view, KEY_SPACE, false)
			assert_gt(ally.current_hp, 5)
			states.append(_state(view))
			durations.append(_now() - start)
		assert_lt(durations[1], int(durations[0] * 0.8), "heal presentation shortened")
		assert_gt(durations[1], int(durations[0] * 0.3), "heal motion retained")
		_assert_same(states[1], states[0], "heal")
	if DisplayServer.get_name() == "headless":
		assert_engine_error_count(4, "popup readback only")


func test_focus_loss_disarm_echo_and_acceleration_to_skip():
	var view := _illustrated()
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	_command_attack(view, kai, serra)
	assert_true(_armed(view))
	var layer = view._combat_exec._skip_input
	var pace = layer._pace
	_key(view, KEY_SPACE, true)
	assert_eq(pace.speed, 2.0)
	await get_tree().create_timer(0.15, true, false, true).timeout
	layer.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_eq(pace.speed, 1.0, "focus loss restores speed during existing fade")
	_key(view, KEY_SPACE, true, true)
	assert_eq(pace.speed, 1.0, "held echo cannot reactivate after focus loss")
	_key(view, KEY_SPACE, false)
	_key(view, KEY_SPACE, true)
	assert_eq(pace.speed, 2.0)
	_key(view, KEY_ESCAPE, true)
	await get_tree().process_frame
	var deadline := _now() + 4000
	while not _attack_done(view, kai).call() and _now() < deadline:
		await get_tree().process_frame
	assert_true(_attack_done(view, kai).call(), "accelerate then skip completes")
	assert_eq(pace.speed, 1.0, "skip/disarm clear rate")
	await _assert_settled(view, "speed then skip")
	# Held Space and Esc echoes into a separately armed next exchange.
	var finished := [false]
	var start := _now()
	var run := func() -> void:
		await view._execute_attack(serra, kai)
		finished[0] = true
	run.call()
	var next = layer._pace
	while not finished[0] and _now() - start < 15000:
		_key(view, KEY_SPACE, true, true)
		_key(view, KEY_ESCAPE, true, true)
		await get_tree().process_frame
	assert_true(finished[0])
	assert_gt(_now() - start, 1800, "held echoes leave next exchange at ordinary pace")
	assert_eq(next.speed, 1.0)
	_key(view, KEY_SPACE, false)
	_key(view, KEY_ESCAPE, false)
	var kael := view.unit_by_id("kael")
	view._cursor.move_to(kael.cell)
	_tap(view, KEY_SPACE)
	assert_eq(view._phase, BattleView.Phase.SELECTED, "idle Space retains existing confirm binding")
	_tap(view, KEY_ESCAPE)
	_tap(view, KEY_ENTER)
	assert_eq(view._phase, BattleView.Phase.SELECTED)
	_tap(view, KEY_ESCAPE)
	_click(view, kael.cell)
	assert_eq(view._selected, kael, "ordinary pointer continuation")


func test_hint_fits_compact_and_default_with_clear_active_state_and_teardown():
	for size in [Vector2i(1280, 720), Vector2i(640, 360)]:
		var view := _kitted(false)
		_command_attack(view, view.unit_by_id("kael"), view.unit_by_id("osric"))
		var layer = view._combat_exec._skip_input
		view.get_viewport().size = size
		await get_tree().process_frame
		_key(view, KEY_SPACE, true)
		assert_true(layer.hint_visible())
		assert_true(view.get_viewport().get_visible_rect().encloses(layer.hint_rect()))
		assert_eq(layer._pace.speed, 2.0)
		var old = layer._pace
		layer.disarm()
		assert_eq(old.speed, 1.0, "disarm resets active effects")
		layer.arm(old)
		_key(view, KEY_SPACE, true, true)
		assert_eq(old.speed, 1.0, "new arm requires fresh press")
		_key(view, KEY_SPACE, true)
		view.remove_child(layer)
		assert_eq(old.speed, 1.0, "teardown restores speed")
		layer.free()
		old.request()
		while view._busy:
			await get_tree().process_frame


func _advance_dialogues(view: BattleView) -> void:
	var accept := InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	var deadline := _now() + 30000
	while is_instance_valid(view) and not view._result_screen.is_shown() and _now() < deadline:
		for node in view.find_children("*", "", true, false):
			if node is DialogueScene and not node.is_finished():
				if not _dialogue_scripts.has(node._script):
					_dialogue_scripts.append(node._script)
				node._unhandled_key_input(accept)  # fixture: dialogue advance is not under test
		await get_tree().create_timer(0.04).timeout


func test_fast_lethal_yield_level_up_objective_and_result_match_normal():
	var states := []
	var gains := []
	for fast in [false, true]:
		var view := _illustrated()
		var kai := view.unit_by_id("kai")
		var serra := view._boss_unit
		for unit in view._units.duplicate():
			if unit.team != 0 and unit != serra:
				view._remove_unit_without_events(unit)  # fixture: only the final rival remains
		serra.current_hp = 1
		kai.xp = 95
		var seed_value := _seed_for(view, kai, serra, func(r: CombatResult) -> bool:
			return r.defender_defeated() and r.strikes[0].connected)
		view._rng = CombatRNG.new(seed_value)
		view.dialogue_enabled = true
		_dialogue_scripts = []
		var deaths := [0]
		var on_died := func(_unit: Node) -> void: deaths[0] += 1
		EventBus.unit_died.connect(on_died)
		var level_ups := [0]
		view._level_up_screen.finished.connect(func() -> void: level_ups[0] += 1)
		var finished := [false]
		_advance_dialogues(view)
		var info := await _play(view, func() -> void:
				await view._execute_attack(kai, serra)
				finished[0] = true,
			func() -> bool: return finished[0] and view._result_screen.is_shown(),
			(func() -> bool: return view._illustrated_combat.current_beat == "contact") if fast else Callable())
		EventBus.unit_died.disconnect(on_died)
		assert_eq(info["pressed"], fast)
		assert_eq(deaths[0], 1, "exactly one yield/removal")
		assert_eq(level_ups[0], 1, "exactly one level-up presentation")
		assert_eq(_dialogue_scripts.size(), 3, "boss quote, yield and outro each run once")
		assert_eq(Campaign.last_result, "victory")
		assert_true(view._defeated_unit_ids.has("serra"))
		gains.append(kai._stat_bonus.duplicate())
		states.append(_state(view))
		if fast:
			# A still-held Space (echo) must not dismiss the result screen.
			for i in range(5):
				_key(view, KEY_SPACE, true, true)
				await get_tree().process_frame
			assert_true(view._result_screen.is_shown(), "held/echo Space leaves results up")
			_key(view, KEY_SPACE, false)
	assert_eq(gains[1], gains[0], "same level-up gains from the same RNG")
	_assert_same(states[1], states[0], "lethal yield")




func test_fast_contacts_and_fresh_save_reload():
	var view := _illustrated()
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	var seed_value := _seed_for(view, kai, serra, func(r: CombatResult) -> bool:
		return r.strikes.size() >= 2 and r.strikes[0].connected and not r.defender_defeated() and not r.attacker_defeated())
	view._rng = CombatRNG.new(seed_value)
	var expected: CombatResult = CombatResolver.resolve(view._combatant_for(kai, kai.cell),
		view._combatant_for(serra, serra.cell), 1, CombatRNG.new(seed_value))
	var at_press := {}
	# Press INSIDE the first contact callback: the HP boundary itself.
	view._illustrated_combat.impact_applied.connect(func(source: Unit, strike: StrikeResult) -> void:
		if at_press.is_empty():
			at_press["hp"] = source.current_hp
			at_press["after"] = strike.defender_hp_after
			at_press["other"] = kai.current_hp
			_key(view, KEY_SPACE, true))
	await _play(view, func() -> void: _command_attack(view, kai, serra), _attack_done(view, kai))
	assert_eq(at_press["hp"], at_press["after"], "first contact already applied its native HP")
	assert_eq(at_press["other"], kai.max_hp(), "the counter had not landed yet at the press")
	assert_eq(kai.current_hp, expected.attacker_hp_after)
	assert_eq(serra.current_hp, expected.defender_hp_after)
	# Save → fresh Mock Battle load reproduces the accelerated exchange's state.
	var saves := SaveSystem.new("user://test_exchange_speed_%d" % _now())
	view._save_system = saves
	var before := view.make_save_payload()
	assert_true(view.save_to_slot(0))
	var loaded: BattleView = load(MOCK).instantiate()
	loaded.dialogue_enabled = false
	add_child_autofree(loaded)
	loaded._save_system = saves
	assert_true(loaded.load_from_slot(0))
	var after := loaded.make_save_payload()
	assert_eq(JSON.stringify(after["battle"]), JSON.stringify(before["battle"]), "battle state reloads")
	assert_eq(JSON.stringify(after["roster"]), JSON.stringify(before["roster"]), "roster/HP/uses/XP reload")
	assert_eq(loaded.unit_by_id("kai").current_hp, expected.attacker_hp_after)
	assert_eq(loaded._boss_unit.current_hp, expected.defender_hp_after)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))




func test_map_hitstop_release_and_popup_animation_release_keep_native_state():
	for popup in [false, true]:
		var normal := _kitted(popup)
		var expected := await _run_speed(normal, normal.unit_by_id("kael"), normal.unit_by_id("osric"), false)
		var view := _kitted(popup)
		var attacker := view.unit_by_id("kael")
		var defender := view.unit_by_id("osric")
		_command_attack(view, attacker, defender)
		var start := _now()
		var press := -1
		var release := -1
		while not _attack_done(view, attacker).call() and _now() - start < 20000:
			var active_animation: bool = view._battle_popup._left_sprite.animation != "idle"
			if press < 0 and ((popup and active_animation) or (not popup and Engine.time_scale == 0.0)):
				_key(view, KEY_SPACE, true)
				press = _now()
			if press >= 0 and release < 0 and _now() - press >= 35:
				_key(view, KEY_SPACE, false)
				release = _now()
			await get_tree().process_frame
		assert_gte(press, 0, "pressed inside animation / real hit-stop")
		assert_gte(release, press)
		_assert_same(_state(view), expected["state"], "mid-animation/hit-stop release")
		assert_lt(abs((_now() - start) - (expected["ms"] - (release - press))), 400, "remaining presentation uses normal pace")
		await _assert_settled(view, "mid release")
	if DisplayServer.get_name() == "headless":
		assert_engine_error_count(4, "popup readback only")


func test_unrelated_scene_timer_keeps_ordinary_pace_while_exchange_accelerates():
	var view := _illustrated()
	var kai := view.unit_by_id("kai")
	# Let fixture construction leave the timer-creation frame first. Native
	# SceneTreeTimers subtract that whole frame, including synchronous setup.
	await get_tree().process_frame
	await get_tree().process_frame
	var start := _now()
	var ordinary := get_tree().create_timer(0.25)
	_command_attack(view, kai, view._boss_unit)
	_key(view, KEY_SPACE, true)
	await ordinary.timeout
	assert_gte(_now() - start, 210, "unrelated scene time never runs at 2×")
	assert_lt(_now() - start, 600)
	assert_true(_armed(view), "exchange still visibly playing")
	assert_eq(kai.current_hp, kai.max_hp(), "counter has not been collapsed into a skip")
	_key(view, KEY_ESCAPE, true)
	while not _attack_done(view, kai).call():
		await get_tree().process_frame
	_key(view, KEY_SPACE, false)
	_key(view, KEY_ESCAPE, false)


func test_enemy_initiated_crit_fast_matches_normal_playback():
	var states := []
	var contacts := []
	for fast in [false, true]:
		var view := _illustrated()
		var kai := view.unit_by_id("kai")
		var serra := view._boss_unit
		var seed_value := _seed_for(view, serra, kai, func(r: CombatResult) -> bool:
			return _crits(r) >= 1 and not r.defender_defeated() and not r.attacker_defeated())
		view._rng = CombatRNG.new(seed_value)
		view._busy = true  # the enemy phase owns the busy flag
		var log := _record_contacts(view)
		var finished := [false]
		var info := await _play(view, func() -> void:
				await view._execute_attack(serra, kai)
				finished[0] = true,
			func() -> bool: return finished[0],
			(func() -> bool: return view._illustrated_combat.current_beat == "windup") if fast else Callable())
		assert_eq(info["pressed"], fast)
		assert_true(view._busy, "the enemy phase keeps its busy flag")
		view._busy = false
		states.append(_state(view))
		contacts.append(str(log))
		if fast:
			await _assert_settled(view, "enemy initiation")
	assert_eq(contacts[1], contacts[0], "enemy-initiated contacts identical")
	_assert_same(states[1], states[0], "enemy initiation")




func test_map_strike_lethal_yield_fast_matches_normal():
	var states := []
	for fast in [false, true]:
		var view := _kitted(false)
		var kael := view.unit_by_id("kael")
		var osric := view.unit_by_id("osric")
		# Survive the first blow, counter, then fall to the follow-up.
		osric.current_hp = _hit_damage(view, kael, osric) + 1
		var seed_value := _seed_for(view, kael, osric, func(r: CombatResult) -> bool:
			return r.defender_defeated() and _counters(r) >= 1 and not r.strikes[0].was_crit)
		view._rng = CombatRNG.new(seed_value)
		var info := await _play(view, func() -> void: _command_attack(view, kael, osric), _attack_done(view, kael),
			(func() -> bool: return _armed(view) and view._camera.zoom.x > view._combat_base_zoom * 1.5) if fast else Callable())
		assert_eq(info["pressed"], fast)
		assert_null(view.unit_by_id("osric"), "yielded rival removed")
		assert_true(view._defeated_unit_ids.has("osric"))
		states.append(_state(view))
		if fast:
			await _assert_settled(view, "map lethal")
	_assert_same(states[1], states[0], "map lethal yield")


