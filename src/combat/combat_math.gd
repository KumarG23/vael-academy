class_name CombatMath
extends RefCounted
## The §3 combat formulas, as pure integer functions. Each is table-testable in
## isolation. Integer division floors (GBA convention) — intentional throughout.
##
## Implement exactly; tune via data, not by editing these.


## AttackSpeed = SPD − max(0, WeaponWeight − STR). Burden only if the weapon is
## heavier than the wielder's strength.
static func attack_speed(spd: int, strength: int, weapon_weight: int) -> int:
	return spd - maxi(0, weapon_weight - strength)


## Attack = STR + Might (physical) | MAG + Might (magical). Triangle damage is
## applied later in damage(), not here.
static func attack_power(is_magical: bool, strength: int, magic: int, might: int) -> int:
	var base := magic if is_magical else strength
	return base + might


## Damage = max(0, Attack + TriangleDmgBonus − (DEF + TerrainDef)). Pass RES as
## `defense_stat` for magical attacks.
static func damage(attack: int, triangle_dmg: int, defense_stat: int, terrain_def: int) -> int:
	return maxi(0, attack + triangle_dmg - (defense_stat + terrain_def))


## HitRate = WeaponHit + SKL*2 + LCK/2 + TriangleHitBonus.
@warning_ignore("integer_division")
static func hit_rate(weapon_hit: int, skill: int, luck: int, triangle_hit: int) -> int:
	return weapon_hit + skill * 2 + luck / 2 + triangle_hit


## AvoidRate = AS*2 + LCK + TerrainAvoid.
static func avoid_rate(attack_speed_value: int, luck: int, terrain_avoid: int) -> int:
	return attack_speed_value * 2 + luck + terrain_avoid


## CritRate = WeaponCrit + SKL/2.
@warning_ignore("integer_division")
static func crit_rate(weapon_crit: int, skill: int) -> int:
	return weapon_crit + skill / 2


## CritAvoid = LCK.
static func crit_avoid(luck: int) -> int:
	return luck


## DisplayedHit = clamp(HitRate − AvoidRate, 0, 100).
static func displayed_hit(hit_rate_value: int, avoid_value: int) -> int:
	return clampi(hit_rate_value - avoid_value, 0, 100)


## DisplayedCrit = clamp(CritRate − CritAvoid, 0, 100).
static func displayed_crit(crit_rate_value: int, crit_avoid_value: int) -> int:
	return clampi(crit_rate_value - crit_avoid_value, 0, 100)


## CritDamage = Damage * 3.
static func crit_damage(base_damage: int) -> int:
	return base_damage * 3


## Follow-up: attacker strikes twice if AS ≥ defender AS + 4.
static func doubles(attacker_as: int, defender_as: int) -> bool:
	return attacker_as >= defender_as + 4
