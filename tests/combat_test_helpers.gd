class_name CombatTestHelpers
extends RefCounted
## Builders for combat tests: weapons and combatants without .tres files.


static func weapon(
	wtype: WeaponDef.WeaponType,
	might: int = 5,
	hit: int = 90,
	crit: int = 0,
	weight: int = 5,
	min_range: int = 1,
	max_range: int = 1,
) -> WeaponDef:
	var w := WeaponDef.new()
	w.weapon_type = wtype
	w.display_name = "test_weapon"
	w.might = might
	w.hit = hit
	w.crit = crit
	w.weight = weight
	w.min_range = min_range
	w.max_range = max_range
	return w


static func sword(might := 5, hit := 90, crit := 0, weight := 5) -> WeaponDef:
	return weapon(WeaponDef.WeaponType.SWORD, might, hit, crit, weight, 1, 1)


static func lance(might := 7, hit := 80, crit := 0, weight := 8) -> WeaponDef:
	return weapon(WeaponDef.WeaponType.LANCE, might, hit, crit, weight, 1, 1)


static func axe(might := 8, hit := 75, crit := 0, weight := 10) -> WeaponDef:
	return weapon(WeaponDef.WeaponType.AXE, might, hit, crit, weight, 1, 1)


static func bow(might := 6, hit := 85, crit := 0, weight := 5) -> WeaponDef:
	return weapon(WeaponDef.WeaponType.BOW, might, hit, crit, weight, 2, 2)


static func tome(might := 5, hit := 85, crit := 0, weight := 4) -> WeaponDef:
	return weapon(WeaponDef.WeaponType.TOME, might, hit, crit, weight, 1, 2)


static func staff() -> WeaponDef:
	return weapon(WeaponDef.WeaponType.STAFF, 0, 100, 0, 3, 1, 1)


## Build a combatant. `overrides` may set any of hp/current_hp/str/mag/skl/spd/lck/def/res.
static func combatant(
	name: String,
	w: WeaponDef,
	overrides: Dictionary = {},
	terrain_def: int = 0,
	terrain_avoid: int = 0,
) -> Combatant:
	var stats := {
		"hp": 30, "str": 8, "mag": 8, "skl": 8, "spd": 10, "lck": 4, "def": 5, "res": 3,
	}
	for k in overrides:
		stats[k] = overrides[k]
	return Combatant.make(name, stats, w, terrain_def, terrain_avoid)
