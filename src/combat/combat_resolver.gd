class_name CombatResolver
extends RefCounted
## The pure combat resolver (§3): given an attacker, a defender, their range, and a
## seeded CombatRNG, produces the full combat script — an ordered list of strikes
## with results. Zero engine/render dependencies (§2 rule 2); the most-tested code
## in the project.
##
## Combat order (§3): attacker -> defender counter (if in range) -> follow-up by
## whichever side qualifies for doubling. A participant reduced to 0 HP stops
## striking and is not struck again.


## One planned strike: who hits whom, and whether it's the defender's counter.
class _Step:
	extends RefCounted
	var striker: Combatant
	var target: Combatant
	var is_counter: bool

	func _init(p_striker: Combatant, p_target: Combatant, p_is_counter: bool) -> void:
		striker = p_striker
		target = p_target
		is_counter = p_is_counter


static func resolve(
	attacker: Combatant, defender: Combatant, distance: int, rng: CombatRNG
) -> CombatResult:
	var result := CombatResult.new()
	result.attacker_name = attacker.display_name
	result.defender_name = defender.display_name

	var atk_hp := attacker.current_hp
	var def_hp := defender.current_hp

	for step in _build_plan(attacker, defender, distance):
		var striker_hp := atk_hp if step.striker == attacker else def_hp
		var target_hp := def_hp if step.target == defender else atk_hp
		if striker_hp <= 0 or target_hp <= 0:
			continue  # a dead combatant neither strikes nor is struck

		var sr := _execute_strike(step, target_hp, rng)
		if step.target == defender:
			def_hp = sr.defender_hp_after
		else:
			atk_hp = sr.defender_hp_after
		result.strikes.append(sr)

	result.attacker_hp_after = atk_hp
	result.defender_hp_after = def_hp
	return result


static func _execute_strike(step: _Step, target_hp: int, rng: CombatRNG) -> StrikeResult:
	var stats := CombatForecast.strike_stats(step.striker, step.target)
	var sr := StrikeResult.new()
	sr.attacker_name = step.striker.display_name
	sr.defender_name = step.target.display_name
	sr.is_counter = step.is_counter
	sr.displayed_hit = stats["hit"]
	sr.displayed_crit = stats["crit"]
	sr.defender_hp_before = target_hp

	var hp := target_hp
	if rng.rolls_hit(stats["hit"]):
		sr.connected = true
		var dmg: int = stats["damage"]
		if rng.rolls_crit(stats["crit"]):
			sr.was_crit = true
			dmg = CombatMath.crit_damage(dmg)
		sr.damage = dmg
		hp = maxi(0, target_hp - dmg)
	sr.defender_hp_after = hp
	return sr


## Ordered strike plan per §3: initiating hit, counter, then a single follow-up by
## whichever side is fast enough. Liveness is enforced later, at execution time.
static func _build_plan(attacker: Combatant, defender: Combatant, distance: int) -> Array:
	var plan: Array = []
	var atk_can := attacker.can_strike_at(distance)
	var def_can := defender.can_strike_at(distance)

	if atk_can:
		plan.append(_Step.new(attacker, defender, false))
	if def_can:
		plan.append(_Step.new(defender, attacker, true))

	var atk_as := attacker.attack_speed()
	var def_as := defender.attack_speed()
	if atk_can and CombatMath.doubles(atk_as, def_as):
		plan.append(_Step.new(attacker, defender, false))
	elif def_can and CombatMath.doubles(def_as, atk_as):
		plan.append(_Step.new(defender, attacker, true))

	return plan
