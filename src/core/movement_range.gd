class_name MovementRange
extends RefCounted
## Computes the tiles a unit can stand on and the tiles it can attack, from a
## Dijkstra flood-fill. Pure logic — feeds both the blue/red overlays and the AI's
## reachability checks (one source of truth, §5).


## Reachable-and-stoppable tiles (blue overlay). Filters the raw Dijkstra result to
## cells the unit may actually END its move on (excludes allied-occupied pass-through).
static func standable_tiles(
	origin: Vector2i, budget: int, ctx: BattleMoveContext
) -> Array:
	var reached := Pathfinder.reachable(origin, budget, ctx)
	var out: Array = []
	for cell in reached:
		if ctx.can_stop_on(cell, origin):
			out.append(cell)
	return out


## Attack tiles (red overlay): every in-bounds cell at a weapon range-step (Manhattan
## distance in `ranges`, e.g. [1] melee, [2] bow, [1,2] mixed) from any standable
## tile, excluding the standable tiles themselves. Terrain passability is irrelevant
## for targeting — you can shoot across water.
static func attack_tiles(
	standable: Array, ranges: Array, ctx: BattleMoveContext
) -> Array:
	var stand_set := {}
	for c in standable:
		stand_set[c] = true
	var out_set := {}
	for cell in standable:
		for r in ranges:
			for target in _ring(cell, int(r)):
				if ctx.in_bounds(target) and not stand_set.has(target):
					out_set[target] = true
	return out_set.keys()


## Cells at exact Manhattan distance `radius` from center (a diamond ring).
static func _ring(center: Vector2i, radius: int) -> Array:
	if radius <= 0:
		return [center]
	var cells: Array = []
	for dx in range(-radius, radius + 1):
		var dy := radius - absi(dx)
		cells.append(center + Vector2i(dx, dy))
		if dy != 0:
			cells.append(center + Vector2i(dx, -dy))
	return cells
