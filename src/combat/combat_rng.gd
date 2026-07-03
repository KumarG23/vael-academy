class_name CombatRNG
extends RefCounted
## The single seedable RNG service all combat rolls flow through (§3), so battles
## are replayable in tests. Hit uses the 2RN (GBA) system; crit uses 1RN.
##
## Roll order within a strike is fixed: hit first (two rolls), then — only if the
## hit connects — one crit roll. Keep this order stable or seeded tests drift.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func seed_value() -> int:
	return int(_rng.seed)


func state_value() -> int:
	return int(_rng.state)


func set_state(value: int) -> void:
	_rng.state = value


## One roll in [0, 99].
func roll() -> int:
	return _rng.randi() % 100


## 2RN hit: average two rolls, hit if the average is below displayed hit.
## displayed_hit of 100 always hits; 0 never hits.
func rolls_hit(displayed_hit: int) -> bool:
	var a := roll()
	var b := roll()
	@warning_ignore("integer_division")
	var avg := (a + b) / 2
	return avg < displayed_hit


## 1RN crit: hit if a single roll is below displayed crit.
func rolls_crit(displayed_crit: int) -> bool:
	return roll() < displayed_crit
