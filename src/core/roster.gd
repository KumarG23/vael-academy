class_name Roster
extends RefCounted
## The player's House Emberwing roster (§4), built once and shared by the battle
## scene and the Academy Hub so both see the same units. Progression that changes
## between visits (XP/level/inventory) lives in Campaign, keyed by unit id; this is
## just the base definitions + slice deploy cells.
##
## (A formal data-driven deployment/roster lands with WO-4.1; this shared builder
## keeps the slice's four units in one place until then.)

const PLAYER_IDS: Array[String] = ["ash", "kael", "brenna", "wren"]


## Fresh UnitDefs for the four Emberwing units, in roster order.
static func player_units() -> Array[UnitDef]:
	var myrmidon: ClassDef = load("res://data/classes/myrmidon.tres")
	var knight: ClassDef = load("res://data/classes/knight.tres")
	var sword: WeaponDef = load("res://data/weapons/iron_sword.tres")
	var lance: WeaponDef = load("res://data/weapons/iron_lance.tres")
	var axe: WeaponDef = load("res://data/weapons/iron_axe.tres")
	var heal_staff: WeaponDef = load("res://data/weapons/heal.tres")
	var vulnerary: ItemDef = load("res://data/items/vulnerary.tres")
	var seal: ItemDef = load("res://data/items/promotion_seal.tres")

	var ash := _unit("ash", "Ash", myrmidon, sword, 6, {"spd": 10, "skl": 9, "str": 8, "hp": 26})
	ash.starting_items = [vulnerary]

	var kael := _unit("kael", "Kael", myrmidon, sword, 6, {"spd": 12, "skl": 12, "str": 8})
	kael.is_lord = true  # slice lord: his death is a game over (§3)
	kael.extra_weapons = [axe]
	kael.starting_items = [vulnerary, seal]

	var brenna := _unit("brenna", "Brenna", knight, lance, 5, {"def": 10, "hp": 28, "spd": 5})
	brenna.starting_items = [vulnerary]

	var wren := _unit("wren", "Wren", cleric_class(), heal_staff, 5, {"mag": 6, "hp": 20, "def": 3})

	return [ash, kael, brenna, wren]


## Slice deploy positions on the Mock Battle map (formalized in WO-4.1).
static func deploy_cells() -> Dictionary:
	return {
		"ash": Vector2i(2, 7),
		"kael": Vector2i(3, 7),
		"brenna": Vector2i(4, 9),
		"wren": Vector2i(3, 9),
	}


## Placeholder healer class (a real Cleric ClassDef .tres lands with the roster WOs).
static func cleric_class() -> ClassDef:
	var c := ClassDef.new()
	c.id = "cleric"
	c.display_name = "Cleric"
	c.token_letter = "C"
	c.movement_type = ClassDef.MovementType.FOOT
	return c


static func _unit(
	id: String, disp: String, cls: ClassDef, wpn: WeaponDef, mov: int, overrides: Dictionary
) -> UnitDef:
	var d := UnitDef.new()
	d.id = id
	d.display_name = disp
	d.char_class = cls
	d.weapon = wpn
	d.team = 0
	d.house_id = "emberwing"
	d.movement = mov
	d.max_hp = overrides.get("hp", 24)
	d.strength = overrides.get("str", 7)
	d.skill = overrides.get("skl", 7)
	d.speed = overrides.get("spd", 8)
	d.luck = overrides.get("lck", 4)
	d.defense = overrides.get("def", 5)
	d.resistance = overrides.get("res", 2)
	return d
