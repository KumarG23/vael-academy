class_name WeaponTriangle
extends RefCounted
## Weapon triangle (§3): Sword > Axe > Lance > Sword.
## AW-28 anima triangle (§3): among tomes, Ember(fire) > Gale(wind) > Tide(water)
## > Ember, by `school` — the three house elements (Emberwing/Thornrook/Tidemark).
## Advantage: +15 hit, +1 damage. Disadvantage: the mirror. Bows/Staves and
## non-anima tomes (reason/ice/etc.) are outside any triangle.

const HIT_BONUS := 15
const DMG_BONUS := 1

## The anima cycle keyed by weapon school: each element beats the value it maps to.
const ANIMA_BEATS := {"ember": "gale", "gale": "tide", "tide": "ember"}


## Hit adjustment for `attacker` weapon type vs `defender` weapon type.
static func hit_bonus(attacker: WeaponDef.WeaponType, defender: WeaponDef.WeaponType) -> int:
	if _beats(attacker, defender):
		return HIT_BONUS
	if _beats(defender, attacker):
		return -HIT_BONUS
	return 0


## Damage adjustment for `attacker` weapon type vs `defender` weapon type.
static func dmg_bonus(attacker: WeaponDef.WeaponType, defender: WeaponDef.WeaponType) -> int:
	if _beats(attacker, defender):
		return DMG_BONUS
	if _beats(defender, attacker):
		return -DMG_BONUS
	return 0


## AW-28: full hit/damage adjustment between two actual weapons, folding in BOTH
## the physical triangle (by type) and the anima triangle (by school when both
## are anima tomes). Use these from combat — they see the weapon's element.
static func hit_bonus_for(attacker: WeaponDef, defender: WeaponDef) -> int:
	if attacker == null or defender == null:
		return 0
	if _is_anima(attacker) and _is_anima(defender):
		if _anima_beats(attacker.school, defender.school):
			return HIT_BONUS
		if _anima_beats(defender.school, attacker.school):
			return -HIT_BONUS
		return 0
	return hit_bonus(attacker.weapon_type, defender.weapon_type)


static func dmg_bonus_for(attacker: WeaponDef, defender: WeaponDef) -> int:
	if attacker == null or defender == null:
		return 0
	if _is_anima(attacker) and _is_anima(defender):
		if _anima_beats(attacker.school, defender.school):
			return DMG_BONUS
		if _anima_beats(defender.school, attacker.school):
			return -DMG_BONUS
		return 0
	return dmg_bonus(attacker.weapon_type, defender.weapon_type)


static func _is_anima(w: WeaponDef) -> bool:
	return w.weapon_type == WeaponDef.WeaponType.TOME and ANIMA_BEATS.has(w.school)


static func _anima_beats(a: String, b: String) -> bool:
	return ANIMA_BEATS.get(a, "") == b


static func _beats(a: WeaponDef.WeaponType, b: WeaponDef.WeaponType) -> bool:
	return (
		(a == WeaponDef.WeaponType.SWORD and b == WeaponDef.WeaponType.AXE)
		or (a == WeaponDef.WeaponType.AXE and b == WeaponDef.WeaponType.LANCE)
		or (a == WeaponDef.WeaponType.LANCE and b == WeaponDef.WeaponType.SWORD)
	)
