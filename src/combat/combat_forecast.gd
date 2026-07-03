class_name CombatForecast
extends RefCounted
## Pure, RNG-free combat math shared by the resolver and the forecast UI (WO-1.2).
## Given an attacker and defender snapshot, computes the displayed hit / crit /
## damage of a single strike (attacker -> defender), plus whole-exchange info like
## doubling and whether the defender can counter.


## Displayed hit/crit/damage for one strike direction (attacker hits defender),
## with weapon triangle and terrain folded in. Returns
## { "hit": int, "crit": int, "damage": int }.
static func strike_stats(attacker: Combatant, defender: Combatant) -> Dictionary:
	# Attacker must be armed to strike; a defender may be unarmed (e.g. its last
	# weapon broke) — then there is no weapon-triangle interaction.
	if attacker.weapon == null:
		return {"hit": 0, "crit": 0, "damage": 0}
	var magical := attacker.weapon.is_magical()
	var tri_hit := 0
	var tri_dmg := 0
	if defender.weapon != null:
		tri_hit = WeaponTriangle.hit_bonus(attacker.weapon.weapon_type, defender.weapon.weapon_type)
		tri_dmg = WeaponTriangle.dmg_bonus(attacker.weapon.weapon_type, defender.weapon.weapon_type)

	var hr := CombatMath.hit_rate(attacker.weapon.hit, attacker.skill, attacker.luck, tri_hit + attacker.support_hit)
	var av := CombatMath.avoid_rate(defender.attack_speed(), defender.luck, defender.terrain_avoid + defender.support_avoid)
	var hit := CombatMath.displayed_hit(hr, av)

	var cr := CombatMath.crit_rate(attacker.weapon.crit + attacker.support_crit, attacker.skill)
	var ca := CombatMath.crit_avoid(defender.luck)
	var crit := CombatMath.displayed_crit(cr, ca)

	var atk := CombatMath.attack_power(magical, attacker.strength, attacker.magic, attacker.weapon.might)
	var dmg := CombatMath.damage(atk, tri_dmg + attacker.support_damage, defender.defense_against(magical), defender.terrain_def)

	return {"hit": hit, "crit": crit, "damage": dmg}


## Whole-exchange forecast for the UI at a given range. Includes both sides' strike
## stats, whether each can act, and who doubles.
static func exchange(attacker: Combatant, defender: Combatant, distance: int) -> Dictionary:
	var atk_can := attacker.can_strike_at(distance)
	var def_can := defender.can_strike_at(distance)
	var atk_as := attacker.attack_speed()
	var def_as := defender.attack_speed()
	return {
		"attacker": strike_stats(attacker, defender) if atk_can else _no_strike(),
		"defender": strike_stats(defender, attacker) if def_can else _no_strike(),
		"attacker_can_attack": atk_can,
		"defender_can_counter": def_can,
		"attacker_doubles": atk_can and CombatMath.doubles(atk_as, def_as),
		"defender_doubles": def_can and CombatMath.doubles(def_as, atk_as),
	}


static func _no_strike() -> Dictionary:
	return {"hit": 0, "crit": 0, "damage": 0}
