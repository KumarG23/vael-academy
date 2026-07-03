class_name StrikeResult
extends RefCounted
## One resolved strike within a combat exchange (the unit of the "combat script"
## §3 asks the resolver to return). Presentation (WO-1.2) replays these in order.

var attacker_name: String = ""
var defender_name: String = ""
## True if this strike is the defender's counter (or its follow-up), not the
## initiating attacker's.
var is_counter: bool = false
var displayed_hit: int = 0
var displayed_crit: int = 0
var connected: bool = false
var was_crit: bool = false
var damage: int = 0
var defender_hp_before: int = 0
var defender_hp_after: int = 0


func _to_string() -> String:
	if not connected:
		return "%s -> %s: MISS" % [attacker_name, defender_name]
	var tag := " CRIT" if was_crit else ""
	return "%s -> %s:%s %d dmg (%d -> %d)" % [
		attacker_name, defender_name, tag, damage, defender_hp_before, defender_hp_after,
	]
