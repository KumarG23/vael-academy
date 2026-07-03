class_name TerrainInfo
extends Resource
## Movement/combat modifiers for a single terrain type (§3 terrain table).

@export var display_name: String = ""
## Movement points to enter this tile (ignored when impassable).
@export var move_cost: int = 1
## Flat defense added to a unit standing here (§3 Damage formula).
@export var defense: int = 0
## Flat avoid added to a unit standing here (§3 AvoidRate formula).
@export var avoid: int = 0
## No unit may enter (Wall/Water).
@export var impassable: bool = false
## Fraction of max HP healed at turn start while standing here (Fort = 0.10).
@export var heal_pct: float = 0.0
## Armored/mounted classes cannot enter (Mountain). Foot units pay move_cost.
@export var blocks_armored_mounted: bool = false


func _init(
	p_display_name: String = "",
	p_move_cost: int = 1,
	p_defense: int = 0,
	p_avoid: int = 0,
	p_impassable: bool = false,
	p_heal_pct: float = 0.0,
	p_blocks_armored_mounted: bool = false,
) -> void:
	display_name = p_display_name
	move_cost = p_move_cost
	defense = p_defense
	avoid = p_avoid
	impassable = p_impassable
	heal_pct = p_heal_pct
	blocks_armored_mounted = p_blocks_armored_mounted
