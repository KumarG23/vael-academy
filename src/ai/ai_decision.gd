class_name AIDecision
extends RefCounted
## The output of AIBrain.decide(): where the unit moves this turn and, optionally,
## whom it attacks from there.

var move_to: Vector2i
## The unit to attack after moving, or null to just move/wait.
var target: Unit = null
## Debug/inspection: the evaluated (dealt − received) score of the chosen attack.
var score: float = 0.0


func has_attack() -> bool:
	return target != null


static func wait_at(cell: Vector2i) -> AIDecision:
	var d := AIDecision.new()
	d.move_to = cell
	return d
