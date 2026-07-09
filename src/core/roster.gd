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

## WO-5.3a: rosters per house, keyed by data/units FILE basenames. Emberwing is
## final (5.2); Tidemark/Thornrook are PROVISIONAL single-member rosters until
## WO-5.4/5.5 author their students. The active house is set by Campaign.
const HOUSE_ROSTERS := {
	"emberwing": ["perrin", "kael", "brenna", "wren", "dain", "liora"],
	"tidemark": ["serra_prologue", "osric", "elowen", "isolde", "fenn", "bertram"],
	"thornrook": ["rina", "thessaly", "corvin", "marlow", "vesper", "rurik", "sable"],
}
static var active_house := "emberwing"


## Roster file basenames for the active house.
static func roster_files() -> Array:
	return HOUSE_ROSTERS.get(active_house, HOUSE_ROSTERS["emberwing"])


## Roster ids + the protagonist appended (§4) — every id the player fields.
static func all_player_ids() -> Array[String]:
	var ids: Array[String] = []
	for f in roster_files():
		var def: UnitDef = load("res://data/units/%s.tres" % f)
		ids.append(def.id)
	ids.append(PROTAGONIST_ID)
	return ids


## Fresh UnitDefs for the fielded units: the house roster, then Kai appended.
static func player_units() -> Array[UnitDef]:
	var out: Array[UnitDef] = []
	for f in roster_files():
		var def: UnitDef = load("res://data/units/%s.tres" % f)
		out.append(def.duplicate())
	var kai: UnitDef = load("res://data/units/%s.tres" % PROTAGONIST_ID)
	out.append(kai.duplicate())
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
		"serra": Vector2i(3, 8),
		"rina": Vector2i(4, 8),
		"osric": Vector2i(2, 6), "elowen": Vector2i(3, 6),
		"isolde": Vector2i(4, 6), "fenn": Vector2i(2, 5), "bertram": Vector2i(3, 5),
		"thessaly": Vector2i(2, 6), "corvin": Vector2i(3, 6),
		"marlow": Vector2i(4, 6), "vesper": Vector2i(2, 5), "rurik": Vector2i(3, 5),
		"sable": Vector2i(4, 5),
	}
