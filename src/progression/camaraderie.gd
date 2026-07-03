class_name Camaraderie
extends RefCounted
## The House Camaraderie passive (§4): +5 hit/avoid when within 2 tiles of a
## housemate. Pure logic — the caller supplies the unit's house and the cells of
## its living same-house allies. Returns a combat-bonus dict shaped like the
## support bonus so both fold into the same Combatant inputs.

const ZERO := {"hit": 0, "avoid": 0, "damage": 0, "crit": 0}


## Bonus for a unit standing at `unit_cell` given its house and the cells of its
## same-house living allies (excluding itself). Presence of any housemate in range
## grants the flat bonus once (it doesn't stack per housemate).
static func bonus(house: HouseDef, unit_cell: Vector2i, housemate_cells: Array) -> Dictionary:
	if house == null:
		return ZERO.duplicate()
	for c in housemate_cells:
		if _manhattan(unit_cell, c) <= house.camaraderie_range:
			return {"hit": house.camaraderie_hit, "avoid": house.camaraderie_avoid, "damage": 0, "crit": 0}
	return ZERO.duplicate()


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
