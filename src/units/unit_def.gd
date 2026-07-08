class_name UnitDef
extends Resource
## Static definition of a unit: base stats, per-stat growth rates, class ref, and
## house tag. Instances become a `Unit` node at battle start. Data-driven per §2
## rule 4 — new units are new .tres files, not code.

@export var id: String = ""
@export var display_name: String = ""
@export var char_class: ClassDef
## Unique promotion target (§10 AW-8 ladder, Neal-approved 2026-07-05): no two
## characters share a promoted name, so promotions are per-CHARACTER. When
## null, the class's own promoted_class applies (generic units).
@export var promotion_class: ClassDef
## House membership (Emberwing/Tidemark/Thornrook); "" until WO-3.4 wires HouseDef.
@export var house_id: String = ""
## Team side for the slice: 0 = player, 1 = enemy.
@export var team: int = 0
## The lord/house leader. Their death is an instant game over (§3 permadeath) and
## they are the unit that seizes for a SEIZE objective.
@export var is_lord: bool = false
## Enemy AI tier (§5). Ignored for player units.
@export var ai_behavior: AIBrain.Behavior = AIBrain.Behavior.AGGRESSOR
## Primary/equipped weapon. Null = unarmed. Combined with `extra_weapons` and
## `starting_items` to build the unit's 5-slot inventory (WO-2.2).
@export var weapon: WeaponDef
## Additional starting weapons (inventory slots beyond the primary).
@export var extra_weapons: Array[WeaponDef] = []
## Starting consumables (Vulnerary, Promotion item).
@export var starting_items: Array[ItemDef] = []
## AW-27: signature skills carried by the CHARACTER, not their (often shared)
## class — the home for heir identity (Serra's protective aura, Corin & Sable's
## Pack Hunter) without polluting generic Knight/Mage. Folded into
## Unit.active_skills() alongside class skills; they persist across promotion.
@export var personal_skills: Array[SkillDef] = []
## AW-48: sprite alias — when set, this unit renders with another unit's sprite
## set (`assets/sprites/units/<sprite_id>/…`) instead of its own id. Lets
## code-built units (arena waves) borrow real art without authoring frames.
## "" = use `id` as always.
@export var sprite_id: String = ""

@export_group("Base Stats")
@export var level: int = 1
@export var max_hp: int = 20
@export var strength: int = 5
@export var magic: int = 0
@export var skill: int = 5
@export var speed: int = 5
@export var luck: int = 3
@export var defense: int = 5
@export var resistance: int = 0
@export var movement: int = 5

@export_group("Growth Rates (0-100)")
@export var growth_hp: int = 60
@export var growth_str: int = 40
@export var growth_mag: int = 10
@export var growth_skl: int = 40
@export var growth_spd: int = 40
@export var growth_lck: int = 30
@export var growth_def: int = 30
@export var growth_res: int = 20


## Combat stat snapshot keyed for Combatant.make().
func stats() -> Dictionary:
	return {
		"hp": max_hp,
		"str": strength,
		"mag": magic,
		"skl": skill,
		"spd": speed,
		"lck": luck,
		"def": defense,
		"res": resistance,
	}


## Growth rates keyed to match LevelUp.STAT_ORDER / Combatant stats.
func growths() -> Dictionary:
	return {
		"hp": growth_hp,
		"str": growth_str,
		"mag": growth_mag,
		"skl": growth_skl,
		"spd": growth_spd,
		"lck": growth_lck,
		"def": growth_def,
		"res": growth_res,
	}


func movement_type() -> ClassDef.MovementType:
	return char_class.movement_type if char_class != null else ClassDef.MovementType.FOOT


func token_letter() -> String:
	return char_class.token_letter if char_class != null else "?"
