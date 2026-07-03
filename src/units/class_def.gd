class_name ClassDef
extends Resource
## A unit class (Myrmidon, Knight, ...). Slice scope: identity + movement type.
## Usable weapon types, promotion targets, and class bonuses attach in later WOs.

enum MovementType { FOOT, ARMORED, MOUNTED }

@export var id: String = ""
@export var display_name: String = ""
## Single-letter tag drawn on the placeholder token (programmer art, §8 rule 1).
@export var token_letter: String = "?"
@export var movement_type: MovementType = MovementType.FOOT

## The class this one promotes into (§3). Null means it can't promote (either a
## base class with no path yet, or an already-promoted class).
@export var promoted_class: ClassDef

@export_group("Promotion Bonuses")
## Flat stats granted when a unit promotes INTO this class.
@export var promo_hp: int = 0
@export var promo_str: int = 0
@export var promo_mag: int = 0
@export var promo_skl: int = 0
@export var promo_spd: int = 0
@export var promo_lck: int = 0
@export var promo_def: int = 0
@export var promo_res: int = 0
@export var promo_mov: int = 0


## Terrain flagged blocks_armored_mounted (Mountain, §3) is impassable to these.
func is_blocked_by_rough_terrain() -> bool:
	return movement_type == MovementType.ARMORED or movement_type == MovementType.MOUNTED


func can_promote() -> bool:
	return promoted_class != null


## Combat-stat promotion bonuses keyed to match LevelUp.STAT_ORDER / Combatant stats.
func promotion_stat_bonuses() -> Dictionary:
	return {
		"hp": promo_hp, "str": promo_str, "mag": promo_mag, "skl": promo_skl,
		"spd": promo_spd, "lck": promo_lck, "def": promo_def, "res": promo_res,
	}
