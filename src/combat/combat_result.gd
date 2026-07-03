class_name CombatResult
extends RefCounted
## The full outcome of one combat exchange: the ordered list of strikes plus the
## final HP of both participants. Returned by CombatResolver; consumed by the
## execution/presentation layer (WO-1.2) and win/loss checks (WO-1.4).

var attacker_name: String = ""
var defender_name: String = ""
var strikes: Array[StrikeResult] = []
var attacker_hp_after: int = 0
var defender_hp_after: int = 0


func attacker_defeated() -> bool:
	return attacker_hp_after <= 0


func defender_defeated() -> bool:
	return defender_hp_after <= 0


func total_damage_to_defender() -> int:
	var sum := 0
	for s in strikes:
		if not s.is_counter:
			sum += s.damage
	return sum


func total_damage_to_attacker() -> int:
	var sum := 0
	for s in strikes:
		if s.is_counter:
			sum += s.damage
	return sum
