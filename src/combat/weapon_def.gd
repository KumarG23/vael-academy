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
## HP a staff restores (base, before the healer's MAG). Ignored by non-staves.
@export var heal_amount: int = 0
## WO-8.2: the school of magic a tome belongs to ("" = mundane weapon).
## Kai — uniquely — can only wield tomes whose school his story has opened
## (Campaign flag `school_<name>`); house students are born to their lane.
@export var school: String = ""


## AW-27: a non-tome weapon can be flagged magical too — a SPELLBOW fires arrows
## (BOW type, in the Attack menu) but resolves as magic (MAG vs RES). Rina's
## Stagward Longbow sets this.
@export var magical: bool = false


## VS-1B: explicit story permission, separate from innate ownership / schools.
## Empty preserves other weapons. Crownspark waits for the later Vision.
@export var required_story_flag: String = ""


## AW-53: part of its bearer's BEING, not their baggage (Kai's Crownspark — his
## awakened royal magic). An innate weapon bypasses the school-gate (but not required_story_flag) for
## the unit whose kit lists it, is merged back into any saved inventory that
## predates it (stale-save migration), and can never be traded away.
@export var innate: bool = false


@export_group("Combat FX")
## CP-1: presentation data for the combat rig (resolved by CombatFxProfile —
## the weapon layer beats the caster's UnitDef fx_*). Purely cosmetic; never
## read by combat math.
## Style keyword by type — TOME: "flame"/"crystal"/"swirl"/"crown"/"rays";
## BOW: "arrow"/"beam" (spellbow); STAFF: "arcs"/"motes"/"rays"/"cross".
## "" = inherit from the caster / default.
@export var fx_style: String = ""
## Trail / bolt / bloom tint. Alpha 0 = unset (inherit).
@export var fx_color: Color = Color(0, 0, 0, 0)
## Natural weapons (claws): no weapon sprite is drawn — the lunge + slash arc
## read as a swipe. Replaces the old hardcoded `_unit_id == "nilu"` rule.
@export var fx_hide_sprite: bool = false


## Tomes deal magical damage (MAG vs RES); everything else is physical (STR vs
## DEF) unless flagged magical (spellbow).
func is_magical() -> bool:
	return weapon_type == WeaponType.TOME or magical


## Staves never deal combat damage (healer support only, WO-2.1).
func can_attack() -> bool:
	return weapon_type != WeaponType.STAFF


func is_staff() -> bool:
	return weapon_type == WeaponType.STAFF


## True if this weapon can strike a target at Manhattan `distance`.
func in_range(distance: int) -> bool:
	return distance >= min_range and distance <= max_range
