class_name WeaponTriangle
extends RefCounted
## Weapon triangle (§3): Sword > Axe > Lance > Sword.
## Advantage: +15 hit, +1 damage. Disadvantage: the mirror. Bow/Tome/Staff are
## outside the triangle (no bonus either way).

const HIT_BONUS := 15
const DMG_BONUS := 1


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


static func _beats(a: WeaponDef.WeaponType, b: WeaponDef.WeaponType) -> bool:
	return (
		(a == WeaponDef.WeaponType.SWORD and b == WeaponDef.WeaponType.AXE)
		or (a == WeaponDef.WeaponType.AXE and b == WeaponDef.WeaponType.LANCE)
		or (a == WeaponDef.WeaponType.LANCE and b == WeaponDef.WeaponType.SWORD)
	)
