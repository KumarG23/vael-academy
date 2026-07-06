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


func combat_bonus() -> Dictionary:
	return {"hit": hit, "avoid": avoid, "damage": damage, "crit": crit}
