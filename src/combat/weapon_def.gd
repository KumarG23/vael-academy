class_name WeaponDef
extends Resource
## A weapon (§3). Data-driven per §2 rule 4 — weapons are .tres, not code.
## Slice weapon set: Sword/Axe/Lance (triangle), Bow (range 2), Tome (magical), Staff.

enum WeaponType { SWORD, AXE, LANCE, BOW, TOME, STAFF }

@export var id: String = ""
@export var display_name: String = ""
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var might: int = 5
@export var hit: int = 90
@export var crit: int = 0
@export var weight: int = 5
@export var min_range: int = 1
@export var max_range: int = 1
@export var max_uses: int = 40


## Tomes deal magical damage (MAG vs RES); everything else is physical (STR vs DEF).
func is_magical() -> bool:
	return weapon_type == WeaponType.TOME


## Staves never deal combat damage (healer support only, WO-2.1).
func can_attack() -> bool:
	return weapon_type != WeaponType.STAFF


## True if this weapon can strike a target at Manhattan `distance`.
func in_range(distance: int) -> bool:
	return distance >= min_range and distance <= max_range
