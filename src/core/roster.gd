class_name Roster
extends RefCounted
## The player's House Emberwing roster (§4), built once and shared by the battle
## scene and the Academy Hub so both see the same units. Progression that changes
## between visits (XP/level/inventory) lives in Campaign, keyed by unit id.
##
## WO-4.1: units are formal .tres data under data/units/ (§2 rule 4). Defs are
## duplicated per call so runtime/test mutation never leaks into the cached
## resources.
##
## WO-5.2: Kai is NOT a roster member — he's the house-agnostic protagonist
## slot (§4), appended to whichever house roster is chosen (5.3 parameterizes
## the house; Emberwing is the only roster until then). He stays the lord:
## his death is a game over.

## The full Emberwing house roster per CHARACTER_BIBLE_EMBERWING (heir + five).
const PLAYER_IDS: Array[String] = ["perrin", "kael", "brenna", "wren", "dain", "liora"]
const PROTAGONIST_ID := "kai"


## Roster ids + the protagonist appended (§4) — every id the player fields.
static func all_player_ids() -> Array[String]:
	var ids := PLAYER_IDS.duplicate()
	ids.append(PROTAGONIST_ID)
	return ids


## Fresh UnitDefs for the fielded units: the house roster, then Kai appended.
static func player_units() -> Array[UnitDef]:
	var out: Array[UnitDef] = []
	for id in all_player_ids():
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
		"perrin": Vector2i(2, 8),
		"dain": Vector2i(4, 7),
		"liora": Vector2i(2, 9),
	}
