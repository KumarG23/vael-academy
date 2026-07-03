class_name Pathfinder
extends RefCounted
## Pure grid pathfinding: Dijkstra flood-fill for reachable tiles and A* for a
## concrete path. No node/render dependencies (§2 rule 2) — the caller supplies
## per-cell move cost and blocked/occupied state through a MoveContext, so this is
## fully testable headless.
##
## Costs are "cost to ENTER a cell". The origin costs nothing. A cell is reachable
## if the accumulated entry cost is <= budget (movement points).

const INF_COST := 1 << 30
const ORTHOGONAL := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


## Supplies terrain/occupancy knowledge to the pathfinder without coupling it to
## Grid/ChapterDef/Unit types. Subclass or duck-type: provide these three methods.
class MoveContext:
	extends RefCounted

	func in_bounds(_cell: Vector2i) -> bool:
		return false

	## Move points to ENTER cell. Return Pathfinder.INF_COST if impassable terrain.
	func enter_cost(_cell: Vector2i) -> int:
		return Pathfinder.INF_COST

	## True if a cell cannot be stopped-on or passed-through (e.g. enemy unit).
	## Allies may be passed through but not stopped on — handled by the caller via
	## reachable-tile filtering, not here.
	func is_blocked(_cell: Vector2i) -> bool:
		return false


## Dijkstra flood-fill. Returns { Vector2i cell -> int accumulated_cost } for every
## cell reachable within `budget` (including the origin at cost 0). Blocked cells
## are neither entered nor traversed.
static func reachable(origin: Vector2i, budget: int, ctx: MoveContext) -> Dictionary:
	var best := {origin: 0}
	# Frontier as array of [cost, cell]; small maps make a plain scan cheap enough.
	var frontier: Array = [[0, origin]]
	while not frontier.is_empty():
		var idx := _pop_min_index(frontier)
		var entry: Array = frontier[idx]
		frontier.remove_at(idx)
		var cost: int = entry[0]
		var cell: Vector2i = entry[1]
		if cost > best.get(cell, Pathfinder.INF_COST):
			continue
		for dir in ORTHOGONAL:
			var nb: Vector2i = cell + dir
			if not ctx.in_bounds(nb) or ctx.is_blocked(nb):
				continue
			var step: int = ctx.enter_cost(nb)
			if step >= Pathfinder.INF_COST:
				continue
			var nc: int = cost + step
			if nc <= budget and nc < best.get(nb, Pathfinder.INF_COST):
				best[nb] = nc
				frontier.append([nc, nb])
	return best


## A* shortest path from `start` to `goal` (inclusive of both). Returns [] if no
## path exists. Uses the same enter_cost model; tie-broken by Manhattan heuristic.
static func find_path(start: Vector2i, goal: Vector2i, ctx: MoveContext) -> Array:
	if start == goal:
		return [start]
	if not ctx.in_bounds(goal) or ctx.is_blocked(goal):
		return []
	var g := {start: 0}
	var came_from := {}
	var open: Array = [[_manhattan(start, goal), start]]
	while not open.is_empty():
		var idx := _pop_min_index(open)
		var cell: Vector2i = open[idx][1]
		open.remove_at(idx)
		if cell == goal:
			return _reconstruct(came_from, goal)
		for dir in ORTHOGONAL:
			var nb: Vector2i = cell + dir
			if not ctx.in_bounds(nb) or ctx.is_blocked(nb):
				continue
			var step: int = ctx.enter_cost(nb)
			if step >= Pathfinder.INF_COST:
				continue
			var tentative: int = g[cell] + step
			if tentative < g.get(nb, Pathfinder.INF_COST):
				g[nb] = tentative
				came_from[nb] = cell
				open.append([tentative + _manhattan(nb, goal), nb])
	return []


static func _reconstruct(came_from: Dictionary, goal: Vector2i) -> Array:
	var path: Array = [goal]
	var cur: Vector2i = goal
	while came_from.has(cur):
		cur = came_from[cur]
		path.push_front(cur)
	return path


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _pop_min_index(frontier: Array) -> int:
	var min_idx := 0
	var min_cost: int = frontier[0][0]
	for i in range(1, frontier.size()):
		if frontier[i][0] < min_cost:
			min_cost = frontier[i][0]
			min_idx = i
	return min_idx
