class_name SkillDef
extends Resource
## WO-8.1: a passive skill (§3 M8, passive/stat-modifier scope). Two kinds in
## one resource: combat modifiers ride the proven Combatant bonus path (the
## supports/camaraderie pattern) at resolve time; stat modifiers fold into
## Unit.stat(). Combat-order-altering skills (vantage/astra) are explicitly
## out of scope — they'd change the resolver.

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## The unit knows this skill from this level onward (per owning class).
@export var unlock_level: int = 1

@export_group("Combat Modifiers")
@export var hit: int = 0
@export var avoid: int = 0
@export var damage: int = 0
@export var crit: int = 0

@export_group("Stat Modifiers")
## Flat stat bonuses keyed like Unit.stat() ("str", "spd", "def", ...).
@export var stat_bonuses: Dictionary = {}

@export_group("Aura")
## AW-27: when > 0, this skill is an AURA — its stat AND combat modifiers apply
## to allied units within this many tiles of the owner (Manhattan), NOT to the
## owner. 0 = an ordinary personal skill that only affects its owner. Auras are
## recomputed from live positions each time a Combatant is built (battle_view).
@export var aura_range: int = 0


func combat_bonus() -> Dictionary:
	return {"hit": hit, "avoid": avoid, "damage": damage, "crit": crit}


## True if this skill projects onto nearby allies rather than its owner.
func is_aura() -> bool:
	return aura_range > 0
