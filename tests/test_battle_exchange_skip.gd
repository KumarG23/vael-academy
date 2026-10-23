extends GutTest
## GH-65 / WO-9.5: Esc skips the REST of the exchange that is playing.
## Production BattleView/executor/presenters with real viewport input. Each skip
## is compared with a same-seed normal playback in a fresh view: the native
## resolver result, contacts, HP, deaths/yields, uses, XP/level-ups, RNG,
## objectives, Campaign capture and save payload must be identical; only the
## presentation time differs. (This file deliberately names no new class, so it
## also runs — and fails on behavior — against the pre-skip baseline.)

const MOCK := "res://scenes/battle/mock_battle.tscn"
const SKIP_LATENCY_MS := 600  # press → presentation closed (headless, generous)

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


## Starts an exchange and presses Esc once, the first frame `when` is true.
## Returns {pressed, start, press, done} in ms.
func _play(view: BattleView, start: Callable, done: Callable, when: Callable = Callable()) -> Dictionary:
	var info := {"pressed": false, "start": _now(), "press": -1, "done": -1}
	start.call()
	var deadline := _now() + 30000
	while not done.call() and _now() < deadline:
		if when.is_valid() and not info["pressed"] and when.call():
			_key(view, KEY_ESCAPE, true)
			_key(view, KEY_ESCAPE, false)
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


# --- illustrated encounter (CP-8) ------------------------------------------------

func test_illustrated_skip_early_mid_late_matches_normal_playback():
	var normal := _illustrated()
	var kai := normal.unit_by_id("kai")
	var serra := normal._boss_unit
	var seed_value := _seed_for(normal, kai, serra, func(r: CombatResult) -> bool:
		return r.strikes.size() >= 3 and _counters(r) >= 1 and r.strikes[0].connected \
			and not r.defender_defeated() and not r.attacker_defeated())
	normal._rng = CombatRNG.new(seed_value)
	var normal_contacts := _record_contacts(normal)
	var reference := await _play(normal, func() -> void: _command_attack(normal, kai, serra), _attack_done(normal, kai))
	var expected := _state(normal)
	var normal_ms: int = reference["done"] - reference["start"]
	assert_gt(normal_ms, 1500, "normal illustrated playback takes real time")
	assert_gte(normal_contacts.size(), 3, "attack, counter and follow-up all made contact")

	var cases := {
		"early": func(v: BattleView) -> bool: return _armed(v),
		"mid (at first contact)": func(v: BattleView) -> bool: return v._illustrated_combat.current_beat == "contact",
		"late (settle)": func(v: BattleView) -> bool: return v._illustrated_combat.current_beat == "settle",
	}
	for label: String in cases:
		var view := _illustrated()
		view._rng = CombatRNG.new(seed_value)
		var contacts := _record_contacts(view)
		var hint_seen := [false]
		var when: Callable = cases[label]
		var info := await _play(view, func() -> void: _command_attack(view, view.unit_by_id("kai"), view._boss_unit),
			_attack_done(view, view.unit_by_id("kai")), func() -> bool:
				if _armed(view) and view._combat_exec._skip_input.hint_visible():
					hint_seen[0] = true
				return when.call(view))
		assert_true(info["pressed"], "%s: Esc was pressed during the exchange" % label)
		assert_true(hint_seen[0], "%s: the skip hint was shown while playing" % label)
		assert_lt(info["done"] - info["press"], SKIP_LATENCY_MS, "%s: returned at once after Esc" % label)
		assert_eq(str(contacts), str(normal_contacts), "%s: every native contact applied once, in order" % label)
		_assert_same(_state(view), expected, label)
		assert_true(view._ui_layer.visible, "%s: map UI restored" % label)
		await _assert_settled(view, label)


func test_illustrated_skip_at_contact_keeps_contact_hp_and_save_reload():
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
			_key(view, KEY_ESCAPE, true)
			_key(view, KEY_ESCAPE, false))
	await _play(view, func() -> void: _command_attack(view, kai, serra), _attack_done(view, kai))
	assert_eq(at_press["hp"], at_press["after"], "first contact already applied its native HP")
	assert_eq(at_press["other"], kai.max_hp(), "the counter had not landed yet at the press")
	assert_eq(kai.current_hp, expected.attacker_hp_after)
	assert_eq(serra.current_hp, expected.defender_hp_after)
	# Save → fresh Mock Battle load reproduces the skipped exchange's state.
	var saves := SaveSystem.new("user://test_exchange_skip_%d" % _now())
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


func test_enemy_initiated_crit_skip_matches_normal_playback():
	var states := []
	var contacts := []
	for skip in [false, true]:
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
			(func() -> bool: return view._illustrated_combat.current_beat == "windup") if skip else Callable())
		assert_eq(info["pressed"], skip)
		assert_true(view._busy, "the enemy phase keeps its busy flag")
		view._busy = false
		states.append(_state(view))
		contacts.append(str(log))
		if skip:
			await _assert_settled(view, "enemy initiation")
	assert_eq(contacts[1], contacts[0], "enemy-initiated contacts identical")
	_assert_same(states[1], states[0], "enemy initiation")


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


func test_lethal_yield_level_up_and_result_match_normal_and_ignore_held_echo():
	var states := []
	var gains := []
	for skip in [false, true]:
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
			(func() -> bool: return view._illustrated_combat.current_beat == "contact") if skip else Callable())
		EventBus.unit_died.disconnect(on_died)
		assert_eq(info["pressed"], skip)
		assert_eq(deaths[0], 1, "exactly one yield/removal")
		assert_eq(level_ups[0], 1, "exactly one level-up presentation")
		assert_eq(_dialogue_scripts.size(), 3, "boss quote, yield and outro each run once")
		assert_eq(Campaign.last_result, "victory")
		assert_true(view._defeated_unit_ids.has("serra"))
		gains.append(kai._stat_bonus.duplicate())
		states.append(_state(view))
		if skip:
			# A still-held Esc (echo) must not dismiss the result screen.
			for i in range(5):
				_key(view, KEY_ESCAPE, true, true)
				await get_tree().process_frame
			assert_true(view._result_screen.is_shown(), "held/echo Esc leaves results up")
			_key(view, KEY_ESCAPE, false)
	assert_eq(gains[1], gains[0], "same level-up gains from the same RNG")
	_assert_same(states[1], states[0], "lethal yield")


# --- map-strike fallback ------------------------------------------------------------

func test_map_strike_skip_early_mid_hitstop_late_matches_normal():
	var normal := _kitted(false)
	var kael := normal.unit_by_id("kael")
	var osric := normal.unit_by_id("osric")
	assert_false(normal._illustrated_combat.supports_exchange(kael, osric), "map path, not the illustrated pair")
	var seed_value := _seed_for(normal, kael, osric, func(r: CombatResult) -> bool:
		return r.strikes.size() >= 3 and _counters(r) >= 1 and _misses(r) >= 1 and r.strikes[0].connected \
			and not r.defender_defeated() and not r.attacker_defeated())
	normal._rng = CombatRNG.new(seed_value)
	var reference := await _play(normal, func() -> void: _command_attack(normal, kael, osric), _attack_done(normal, kael))
	var expected := _state(normal)
	var normal_ms: int = reference["done"] - reference["start"]
	assert_gt(normal_ms, 1000, "normal map playback takes real time")
	var hp0 := osric.max_hp()
	var cases := {
		"early": func(v: BattleView, _t0: int) -> bool: return _armed(v),
		"mid (first contact)": func(v: BattleView, _t0: int) -> bool: return v.unit_by_id("osric").current_hp != hp0,
		"during hit-stop": func(_v: BattleView, _t0: int) -> bool: return Engine.time_scale == 0.0,
		"late": func(_v: BattleView, t0: int) -> bool: return _now() - t0 > normal_ms * 0.8,
	}
	for label: String in cases:
		var view := _kitted(false)
		view._rng = CombatRNG.new(seed_value)
		var t0 := _now()
		var when: Callable = cases[label]
		var info := await _play(view, func() -> void: _command_attack(view, view.unit_by_id("kael"), view.unit_by_id("osric")),
			_attack_done(view, view.unit_by_id("kael")), func() -> bool: return _armed(view) and when.call(view, t0))
		assert_true(info["pressed"], "%s: pressed while playing" % label)
		assert_lt(info["done"] - info["press"], SKIP_LATENCY_MS, "%s: returned at once" % label)
		_assert_same(_state(view), expected, label)
		await _assert_settled(view, label)


func test_map_strike_lethal_yield_skip_matches_normal():
	var states := []
	for skip in [false, true]:
		var view := _kitted(false)
		var kael := view.unit_by_id("kael")
		var osric := view.unit_by_id("osric")
		# Survive the first blow, counter, then fall to the follow-up.
		osric.current_hp = _hit_damage(view, kael, osric) + 1
		var seed_value := _seed_for(view, kael, osric, func(r: CombatResult) -> bool:
			return r.defender_defeated() and _counters(r) >= 1 and not r.strikes[0].was_crit)
		view._rng = CombatRNG.new(seed_value)
		var info := await _play(view, func() -> void: _command_attack(view, kael, osric), _attack_done(view, kael),
			(func() -> bool: return _armed(view) and view._camera.zoom.x > view._combat_base_zoom * 1.5) if skip else Callable())
		assert_eq(info["pressed"], skip)
		assert_null(view.unit_by_id("osric"), "yielded rival removed")
		assert_true(view._defeated_unit_ids.has("osric"))
		states.append(_state(view))
		if skip:
			await _assert_settled(view, "map lethal")
	_assert_same(states[1], states[0], "map lethal yield")


# --- authored pixel popup ------------------------------------------------------------

func test_pixel_popup_skip_matches_normal_and_resets_the_stage():
	var states := []
	var holders := []
	for when_label in ["", "establish", "first contact", "late"]:
		var view := _kitted(true)
		var kael := view.unit_by_id("kael")
		var osric := view.unit_by_id("osric")
		var popup := view._battle_popup
		var seed_value := _seed_for(view, kael, osric, func(r: CombatResult) -> bool:
			return r.strikes.size() >= 3 and _counters(r) >= 1 and _misses(r) >= 1 and not r.defender_defeated() and not r.attacker_defeated())
		view._rng = CombatRNG.new(seed_value)
		var hp_shown := [-1.0]
		var t0 := _now()
		var when := Callable()
		match when_label:
			"establish":
				when = func() -> bool: return _armed(view) and popup._root.visible
			"first contact":
				when = func() -> bool: return _armed(view) and (popup._bursts.size() > 0 or popup._miss_label.visible)
			"late":
				when = func() -> bool: return _armed(view) and popup._xp_panel.visible
		var info := await _play(view, func() -> void: _command_attack(view, kael, osric), _attack_done(view, kael), when)
		assert_eq(info["pressed"], when_label != "", "popup %s" % when_label)
		if when_label != "":
			assert_lt(info["done"] - info["press"], SKIP_LATENCY_MS, "popup %s: returned at once" % when_label)
			await _assert_settled(view, "popup " + when_label)
		assert_false(popup._root.visible)
		assert_eq(popup._root.position, Vector2.ZERO, "no shake offset left")
		assert_eq(popup._root.modulate.a, 0.0)
		assert_false(popup._miss_label.visible)
		states.append(_state(view))
		holders.append([popup._left_holder.position.round(), popup._right_holder.position.round()])
	# The headless dummy renderer cannot read back the production map screenshot
	# (two engine errors per popup); a real renderer has the texture.
	if DisplayServer.get_name() == "headless":
		assert_engine_error_count(8, "only the headless screenshot read-back errors")
	for index in range(1, states.size()):
		_assert_same(states[index], states[0], "popup case %d" % index)
		assert_eq(holders[index], holders[0], "battlers back home for the next popup")


# --- heal ---------------------------------------------------------------------------

func test_map_heal_skip_matches_normal():
	var states := []
	for skip in [false, true]:
		var view := _mock()
		var wren := view.unit_by_id("wren")
		var kael := view.unit_by_id("kael")
		_place(view, wren, Vector2i(5, 12))
		_place(view, kael, Vector2i(6, 12))
		kael.current_hp = 5
		var finished := [false]
		var info := await _play(view, func() -> void:
				await view._execute_heal(wren, kael)
				finished[0] = true,
			func() -> bool: return finished[0],
			(func() -> bool: return _armed(view)) if skip else Callable())
		assert_eq(info["pressed"], skip)
		assert_gt(kael.current_hp, 5, "the heal applied")
		states.append(_state(view))
		if skip:
			assert_lt(info["done"] - info["press"], SKIP_LATENCY_MS, "heal returned at once")
			await _assert_settled(view, "heal")
	_assert_same(states[1], states[0], "map heal")


func test_popup_heal_skip_closes_cleanly():
	# Fixture: production BattlePopup heal staging with the exchange's clock.
	var view := _mock(true)
	var popup := view._battle_popup
	var wren := view.unit_by_id("wren")
	var kael := view.unit_by_id("kael")
	kael.current_hp = kael.max_hp()
	var finished := [false]
	var played := func() -> void:
		popup.pace = popup.pace.get_script().new()
		var pace = popup.pace
		var run := func() -> void:
			await popup.play_heal(wren, kael, 5)
			finished[0] = true
		run.call()
		await get_tree().create_timer(0.3).timeout
		pace.request()
	var t0 := _now()
	await played.call()
	var deadline := _now() + 3000
	while not finished[0] and _now() < deadline:
		await get_tree().process_frame
	assert_true(finished[0])
	assert_lt(_now() - t0, 300 + SKIP_LATENCY_MS, "heal popup closed at once")
	assert_false(popup._root.visible)
	assert_eq(popup._root.modulate.a, 0.0)
	assert_eq(popup._right_hp.shown_hp, float(kael.current_hp), "ally bar landed on the healed HP")
	assert_eq(popup._bursts.size(), 0)


# --- input boundaries ------------------------------------------------------------------

func test_held_echo_never_skips_and_the_next_exchange_plays_normally():
	var view := _kitted(false)
	var kael := view.unit_by_id("kael")
	var osric := view.unit_by_id("osric")
	var seed_value := _seed_for(view, kael, osric, func(r: CombatResult) -> bool:
		return not r.defender_defeated() and not r.attacker_defeated() and r.strikes.size() >= 2)
	view._rng = CombatRNG.new(seed_value)
	# 1) Skip the player's exchange with a fresh press, then KEEP holding Esc.
	var first := await _play(view, func() -> void: _command_attack(view, kael, osric), _attack_done(view, kael),
		func() -> bool: return _armed(view))
	assert_lt(first["done"] - first["press"], SKIP_LATENCY_MS)
	_key(view, KEY_ESCAPE, true)  # held again before the next exchange (a non-fresh hold)
	assert_eq(view._phase, BattleView.Phase.IDLE, "Esc after return reaches ordinary map control only")
	assert_false(view._menu.visible, "no menu opened")
	assert_true(kael.has_acted)
	# 2) Next exchange (enemy initiation) under a held key: only echoes arrive.
	var brenna := view.unit_by_id("brenna")
	_place(view, brenna, Vector2i(10, 10))
	var hp_trace := []
	var finished := [false]
	view._busy = true
	var second := await _play(view, func() -> void:
			await view._execute_attack(osric, brenna)
			finished[0] = true,
		func() -> bool:
			_key(view, KEY_ESCAPE, true, true)  # OS key-repeat echo every frame
			if hp_trace.is_empty() or hp_trace[-1] != brenna.current_hp:
				hp_trace.append(brenna.current_hp)
			return finished[0])
	view._busy = false
	_key(view, KEY_ESCAPE, false)
	assert_gt(second["done"] - second["start"], 1000, "held Esc did not skip the next exchange")
	assert_false(view._combat_exec._skip_input.is_armed())
	assert_eq(view._phase, BattleView.Phase.IDLE)
	assert_false(view._menu.visible)
	# 3) Idle Esc keeps its ordinary meaning (select → cancel back to idle).
	var kai := view.unit_by_id("kai")
	view._cursor.move_to(kai.cell)
	_tap(view, KEY_ENTER)
	assert_eq(view._phase, BattleView.Phase.SELECTED, "keyboard continuation selects")
	_tap(view, KEY_ESCAPE)
	assert_eq(view._phase, BattleView.Phase.IDLE, "an idle Esc still cancels selection")
	# 4) Pointer continuation still works after a skipped exchange.
	_click(view, kai.cell)
	assert_eq(view._phase, BattleView.Phase.SELECTED, "pointer continuation selects")
	assert_eq(view._selected, kai)


func test_hint_is_readable_inside_the_viewport_only_while_playing():
	var view := _illustrated()
	var kai := view.unit_by_id("kai")
	var serra := view._boss_unit
	view._rng = CombatRNG.new(_seed_for(view, kai, serra, func(r: CombatResult) -> bool:
		return not r.defender_defeated() and not r.attacker_defeated()))
	var seen := []
	var info := await _play(view, func() -> void: _command_attack(view, kai, serra), _attack_done(view, kai),
		func() -> bool:
			var layer = view._combat_exec.get("_skip_input")
			if layer != null and layer.is_armed() and seen.is_empty() and view._illustrated_combat._stage.visible:
				seen.append(layer.hint_rect())
				seen.append(layer.layer)
			return false)
	assert_false(info["pressed"])
	assert_eq(seen.size(), 2, "hint observed during the illustrated stage")
	if seen.size() == 2:
		var rect: Rect2 = seen[0]
		assert_true(view.get_viewport().get_visible_rect().encloses(rect), "hint fully on screen")
		assert_gt(rect.size.x, 60.0)
		assert_gt(seen[1], view._illustrated_combat.layer, "drawn above the illustrated stage")
		# Never over the illustrated HP plates (bottom band) or the top letterbox.
		assert_gt(rect.position.y, 48.0, "below the illustrated letterbox")
		assert_lt(rect.end.y, 568.0, "clear of the HP/name plate band")
	assert_false(view._combat_exec._skip_input.hint_visible(), "hint gone once the exchange returns")
