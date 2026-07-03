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


## Terrain flagged blocks_armored_mounted (Mountain, §3) is impassable to these.
func is_blocked_by_rough_terrain() -> bool:
	return movement_type == MovementType.ARMORED or movement_type == MovementType.MOUNTED
