class_name LevelUp
extends RefCounted
## Level-up stat rolls (§3): each stat rolls `randi() % 100 < growth` for +1.
## Rolls flow through the single seedable CombatRNG so gains are replayable in
## tests. The stat order is fixed — changing it changes what a given seed rolls.

## Canonical stat roll order. Keys match UnitDef growth fields / Combatant stats.
const STAT_ORDER: Array[String] = ["hp", "str", "mag", "skl", "spd", "lck", "def", "res"]


## Rolls one level's gains. `growths` maps each stat key to a 0–100 growth rate.
## Returns { stat_key -> 0 or 1 } for every stat in STAT_ORDER.
static func roll(growths: Dictionary, rng: CombatRNG) -> Dictionary:
	var gains := {}
	for stat in STAT_ORDER:
		var growth: int = growths.get(stat, 0)
		gains[stat] = 1 if rng.roll() < growth else 0
	return gains


## Convenience: total stats gained in a roll result.
static func total_gained(gains: Dictionary) -> int:
	var n := 0
	for stat in gains:
		n += int(gains[stat])
	return n
