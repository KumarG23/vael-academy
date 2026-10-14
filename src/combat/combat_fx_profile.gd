class_name CombatFxProfile
extends RefCounted
## CP-1: the combat rig's look for one attacker + weapon, resolved from DATA
## (WeaponDef / UnitDef `fx_*` fields) instead of the per-unit / per-weapon-id
## `match` tables that used to live in combat_rig.gd. Pure — no nodes.
##
## Resolution order (unchanged from AW-31): the WEAPON wins (so a generic Fire
## tome and Liora's Soulflame share fire), then the CASTER, then the default.
## A Color with alpha 0 means "unset" — fall through to the next layer.

const DEFAULT_MELEE_COLOR := Color(0.85, 1.0, 0.9)    # steel gleam
const DEFAULT_MAGIC_STYLE := "flame"
const DEFAULT_MAGIC_COLOR := Color(1.0, 0.42, 0.9)
const DEFAULT_HEAL_STYLE := "arcs"
const DEFAULT_HEAL_COLOR := Color(0.42, 1.0, 0.56)

var melee_color := DEFAULT_MELEE_COLOR
var magic_style := DEFAULT_MAGIC_STYLE
var magic_color := DEFAULT_MAGIC_COLOR
var heal_style := DEFAULT_HEAL_STYLE
var heal_color := DEFAULT_HEAL_COLOR
## Bow delivery: "arrow" (default) or "beam" (Rina's spellbow).
var ranged_style := "arrow"
## False for natural weapons (Nilu's claws) — the lunge + slash arc read as a
## swipe with no weapon sprite drawn.
var show_weapon := true


static func build(unit_def: UnitDef, weapon: WeaponDef) -> CombatFxProfile:
	var p := CombatFxProfile.new()
	if unit_def != null:
		if unit_def.fx_magic_style != "":
			p.magic_style = unit_def.fx_magic_style
		if unit_def.fx_magic_color.a > 0.0:
			p.magic_color = unit_def.fx_magic_color
		if unit_def.fx_heal_style != "":
			p.heal_style = unit_def.fx_heal_style
		if unit_def.fx_heal_color.a > 0.0:
			p.heal_color = unit_def.fx_heal_color
	if weapon != null:
		# weapon layer overrides the caster layer
		if weapon.fx_color.a > 0.0:
			p.melee_color = weapon.fx_color
		match weapon.weapon_type:
			WeaponDef.WeaponType.TOME:
				match weapon.school:
					"ember":
						p.magic_style = "flame"
						p.magic_color = Color(1.0, 0.45, 0.15)
					"gale":
						p.magic_style = "swirl"
						p.magic_color = Color(0.55, 1.0, 0.55)
					"tide":
						p.magic_style = "crystal"
						p.magic_color = Color(0.35, 0.70, 1.0)
					"reason":
						p.magic_style = "rays"
						p.magic_color = Color(0.82, 0.55, 1.0)
					"crown":
						p.magic_style = "crown"
						p.magic_color = Color(0.45, 1.0, 0.60)
				if weapon.fx_style != "":
					p.magic_style = weapon.fx_style
				if weapon.fx_color.a > 0.0:
					p.magic_color = weapon.fx_color
			WeaponDef.WeaponType.BOW:
				if weapon.fx_style != "":
					p.ranged_style = weapon.fx_style
			WeaponDef.WeaponType.STAFF:
				if weapon.fx_style != "":
					p.heal_style = weapon.fx_style
				if weapon.fx_color.a > 0.0:
					p.heal_color = weapon.fx_color
		p.show_weapon = not weapon.fx_hide_sprite
	return p
