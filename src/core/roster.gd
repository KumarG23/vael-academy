class_name Roster
extends RefCounted
## The player's House Emberwing roster (§4), built once and shared by the battle
## scene and the Academy Hub so both see the same units. Progression that changes
## between visits (XP/level/inventory) lives in Campaign, keyed by unit id.
##
## WO-4.1: units are formal .tres data under data/units/ (§2 rule 4). Defs are
## duplicated per call so runtime/test mutation never leaks into the cached
## resources. Kai is the lord (§4): his death is a game over.

const PLAYER_IDS: Array[String] = ["kai", "kael", "brenna", "wren"]


## Fresh UnitDefs for the four Emberwing units, in roster order.
static func player_units() -> Array[UnitDef]:
	var out: Array[UnitDef] = []
	for id in PLAYER_IDS:
		var def: UnitDef = load("res://data/units/%s.tres" % id)
		out.append(def.duplicate())
	return out


## Fallback deploy positions for chapters that don't author their own (the
## WO-0.2 test map). Real chapters carry deploy_cells in their ChapterDef.
static func deploy_cells() -> Dictionary:
	return {
		"kai": Vector2i(2, 7),
		"kael": Vector2i(3, 7),
		"brenna": Vector2i(4, 9),
		"wren": Vector2i(3, 9),
	}
