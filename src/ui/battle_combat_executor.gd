class_name BattleCombatExecutor
extends RefCounted
## WO-4.5: combat execution slice extracted from battle_view (zero behavior
## change). Runs an attack or heal end to end — resolve, animate strikes,
## durability, XP — against the owning view's state. The view keeps
## thin same-name delegates so tests and signal wiring are untouched.

var _v  # BattleView (untyped to avoid a class_name reference cycle)
## WO-9.5 (#65): Esc/cancel skips the rest of the exchange being presented.
var _skip_input: ExchangeSkipInput


func _init(view) -> void:
	_v = view


func execute_attack(attacker: Unit, defender: Unit) -> void:
	var was_busy: bool = _v._busy  # keep busy set if we're inside the enemy phase
	_v._busy = true
	_v._forecast_panel.hide_panel()
	# Boss quote (WO-4.1): once, the first time the boss enters combat.
	if not _v._boss_quote_played and _v._boss_unit != null and (attacker == _v._boss_unit or defender == _v._boss_unit):
		_v._boss_quote_played = true
		await _v._play_dialogue(_v.chapter.boss_quote_dialogue)
	var dist: int = _v._manhattan(attacker.cell, defender.cell)
	var atk_level := attacker.level
	var def_level := defender.level
	var atk_c: Combatant = _v._combatant_for(attacker, attacker.cell)
	var def_c: Combatant = _v._combatant_for(defender, defender.cell)
	var result := CombatResolver.resolve(atk_c, def_c, dist, _v._rng)
	# Only presentation time is skippable: the result above is final, and the
	# durability/XP/objective tail below runs identically either way.
	var pace := _arm_skip()

	# WO-4.9: FE-style combat cut-in when both sides have a hand-authored kit.
	# Every combat unit is meant to have its own — see the kit rollout.
	# Tests run strike_delay = 0 and never enter this path.
	if _v.strike_delay > 0.0 and _v._illustrated_combat != null \
			and _v._illustrated_combat.supports_exchange(attacker, defender):
		# CP-8: replay the SAME result; contact applies real map HP. Progression,
		# durability and chapter completion remain below, shared by all players.
		_v._illustrated_combat.pace = pace
		await _v._illustrated_combat.play_exchange(attacker, defender, result, _v._ui_layer)
		_v._illustrated_combat.pace = ExchangeSkip.new()
		for unit: Unit in [attacker, defender]:
			if not unit.is_alive():
				_v._kill(unit)
	elif _v.strike_delay > 0.0 and _v.battle_popups_enabled and _v._battle_popup != null \
			and BattlePopup.has_kit(attacker.unit_id()) and BattlePopup.has_kit(defender.unit_id()):
		# v3: forecast numbers drive the chrome; the map itself (captured just
		# before the cut-in) becomes the washed backdrop, FE field-battle style.
		var ex := CombatForecast.exchange(atk_c, def_c, dist)
		_v._battle_popup.stage_terrain = _v.chapter.get_terrain(defender.cell.x, defender.cell.y)
		var shot := ImageTexture.create_from_image(_v.get_viewport().get_texture().get_image())
		# XP the player attacker will earn — shown filling in the popup after the blow
		var atk_xp := 0
		if attacker.team == 0:
			atk_xp = CombatXP.award(attacker.level, def_level,
				side_connected(result, false), result.defender_defeated())
		_v._battle_popup.pace = pace
		await _v._battle_popup.play_exchange(attacker, defender, result.strikes, ex, shot, dist,
			attacker.xp, atk_xp)
		_v._battle_popup.pace = ExchangeSkip.new()
		for strike in result.strikes:
			var target := attacker if strike.is_counter else defender
			if strike.connected:
				target.set_hp(strike.defender_hp_after)
			if not target.is_alive():
				_v._kill(target)
	else:
		# ON-MAP combat (battle direction v2): push the camera in on the clash,
		# play each strike on the tile via the juice controller, then pull back.
		var cinematic: bool = _v.strike_delay > 0.0 and _v._juice != null
		if cinematic:
			_v._juice.pace = pace
			await _v._begin_combat_cam(attacker, defender, pace)
		for strike in result.strikes:
			# Route by the counter flag, not the display name (names aren't unique —
			# e.g. multiple "Tidemark Soldier"). A counter strike hits the attacker.
			var striker := defender if strike.is_counter else attacker
			var target := attacker if strike.is_counter else defender
			var lethal: bool = strike.connected and strike.defender_hp_after <= 0
			if cinematic:
				await _v._juice.play_strike(striker, target, strike, lethal)  # applies hp at impact
			else:
				play_strike(strike, target)
				await _v.get_tree().process_frame
			if not target.is_alive():
				if cinematic:
					await _v._juice.play_death(target)
				_v._kill(target)
		if cinematic:
			await _v._end_combat_cam(pace)
			_v._juice.settle_skip()
			_v._juice.pace = ExchangeSkip.new()
	_disarm_skip()

	# Weapon durability: 1 use per combat per side that swung — GBA-accurate
	# (a doubling unit still spends only one use, not one per strike). The attacker
	# always swung; the defender swung only if it countered.
	var defender_countered := false
	for s in result.strikes:
		if s.is_counter:
			defender_countered = true
			break
	if is_instance_valid(attacker):
		spend_weapon(attacker)
	if is_instance_valid(defender) and defender_countered:
		spend_weapon(defender)

	# XP: attacker for its strikes, defender for its counter (players only, §3/§4).
	# A slain combatant has been freed by now — guard before passing it on.
	if is_instance_valid(attacker):
		await award_combat_xp(attacker, def_level, side_connected(result, false), result.defender_defeated())
	if is_instance_valid(defender):
		await award_combat_xp(defender, atk_level, side_connected(result, true), result.attacker_defeated())

	_v._busy = was_busy
	_v._check_objective()


func execute_heal(healer: Unit, ally: Unit) -> void:
	var was_busy: bool = _v._busy
	_v._busy = true
	var amount: int = healer.weapon().heal_amount + healer.stat("mag")
	var hp_before: int = ally.current_hp
	var healed: int = ally.heal(amount)
	AudioManager.play_sfx("heal")  # AW-36
	# On-map staff heal via the combat rig (battle direction v2): the healer
	# casts on its tile and a bloom lands on the ally. Falls back to the legacy
	# popup cut-in if that's still enabled, then to a floating "+N" (tests,
	# strike_delay 0, un-rigged units).
	if _v.strike_delay > 0.0 and _v._juice != null and CombatRig.has_rig(healer.unit_id()):
		var pace := _arm_skip()
		_v._juice.pace = pace
		await _v._begin_combat_cam(healer, ally, pace)
		await _v._juice.play_heal(healer, ally)
		_v._pop_text(ally.position, "+%d" % healed, Color(0.4, 0.9, 0.5))
		await _v._end_combat_cam(pace)
		_v._juice.settle_skip()
		_v._juice.pace = ExchangeSkip.new()
		_disarm_skip()
	elif _v.strike_delay > 0.0 and _v.battle_popups_enabled and _v._battle_popup != null \
			and BattlePopup.has_kit(healer.unit_id()) and BattlePopup.has_kit(ally.unit_id()):
		_v._battle_popup.stage_terrain = _v.chapter.get_terrain(ally.cell.x, ally.cell.y)
		var shot := ImageTexture.create_from_image(_v.get_viewport().get_texture().get_image())
		_v._battle_popup.pace = _arm_skip()
		await _v._battle_popup.play_heal(healer, ally, hp_before, shot)
		_v._battle_popup.pace = ExchangeSkip.new()
		_disarm_skip()
	else:
		_v._pop_text(ally.position, "+%d" % healed, Color(0.4, 0.9, 0.5))
	_v._accrue_support_points(healer, ally, SupportState.POINTS_HEAL)
	spend_weapon(healer)  # staves have uses too
	await award_heal_xp(healer, healed)
	_v._busy = was_busy
	_v._check_objective()


## WO-9.5 (#65): a fresh skip clock for one exchange, with Esc armed only while
## its presentation plays. Instant (strike_delay 0) exchanges have none to skip.
func _arm_skip() -> ExchangeSkip:
	var pace := ExchangeSkip.new()
	if _v.strike_delay <= 0.0:
		return pace
	if _skip_input == null or not is_instance_valid(_skip_input):
		_skip_input = ExchangeSkipInput.new()
		_v.add_child(_skip_input)
	_skip_input.arm(pace)
	return pace


func _disarm_skip() -> void:
	if _skip_input != null and is_instance_valid(_skip_input):
		_skip_input.disarm()


## Spend one use of `unit`'s equipped weapon and announce a break.
func spend_weapon(unit: Unit) -> void:
	var broke := unit.spend_weapon_use()
	if broke != null:
		_v._pop_text(unit.position, "%s broke!" % broke.display_name(), Color(0.9, 0.7, 0.3))


## Whether one side landed a hit. `counter_side` false = the initiating attacker's
## strikes; true = the defender's counter strikes.
func side_connected(result: CombatResult, counter_side: bool) -> bool:
	for s in result.strikes:
		if s.is_counter == counter_side and s.connected:
			return true
	return false


func award_combat_xp(unit: Unit, opponent_level: int, connected: bool, killed: bool) -> void:
	if not is_instance_valid(unit) or not unit.is_alive() or unit.team != 0:
		return
	var amount := CombatXP.award(unit.level, opponent_level, connected, killed)
	await apply_xp(unit, amount)


func award_heal_xp(unit: Unit, healed: int) -> void:
	if unit.team != 0:
		return
	await apply_xp(unit, CombatXP.award_heal(healed))


func apply_xp(unit: Unit, amount: int) -> void:
	for result in unit.gain_xp(amount, _v._rng):
		AudioManager.play_sfx("level_up")  # AW-36
		await _v._level_up_screen.play(unit.unit_def.display_name, result)


func play_strike(strike: StrikeResult, target: Unit) -> void:
	if not strike.connected:
		_v._pop_text(target.position, "Miss", Color(0.85, 0.85, 0.9))
		target.flash()
		return
	target.set_hp(strike.defender_hp_after)
	var text := ("CRIT " + str(strike.damage)) if strike.was_crit else str(strike.damage)
	var color := Color(1.0, 0.85, 0.2) if strike.was_crit else Color(1.0, 0.4, 0.35)
	_v._pop_text(target.position, text, color)
