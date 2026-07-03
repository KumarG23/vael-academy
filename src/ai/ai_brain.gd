class_name AIBrain
extends RefCounted
## Enemy AI (§5). WO-1.3 implements the Aggressor tier: each enemy phase, pick the
## reachable target maximizing (expected damage dealt − expected damage received)
## using the same CombatForecast the player sees. Prefer kills. If no target is
## reachable, move toward the nearest one. Deterministic given a seed (this decision
## layer is fully deterministic; only the combat rolls consume RNG).
##
## Tiebreakers (§5): kill > lowest counter-damage > lowest-HP target, then a stable
## positional tiebreak so runs are reproducible.


## Evaluate one attack option from a forecast exchange. `atk_strikes`/`def_strikes`
## are 1 or 2 (doubling). Pure and table-testable.
static func evaluate(exchange: Dictionary, target_hp: int) -> Dictionary:
	var atk: Dictionary = exchange["attacker"]
	var def: Dictionary = exchange["defender"]
	var atk_strikes: int = 2 if exchange["attacker_doubles"] else 1
	var def_strikes: int = 2 if exchange["defender_doubles"] else 1

	var dealt: float = float(atk["hit"]) / 100.0 * float(atk["damage"]) * atk_strikes
	var received: float = 0.0
	if exchange["defender_can_counter"]:
		received = float(def["hit"]) / 100.0 * float(def["damage"]) * def_strikes
	# A kill is credited when every attacker strike landing would drop the target.
	var kills: bool = (int(atk["damage"]) * atk_strikes) >= target_hp
	return {
		"dealt": dealt,
		"received": received,
		"score": dealt - received,
		"kills": kills,
	}


## Decide this unit's action. `all_units` includes the actor and its enemies.
static func decide(
	actor: Unit, all_units: Array, chapter: ChapterDef, terrain_db: TerrainDB
) -> AIDecision:
	var enemies := _living_enemies(actor, all_units)
	if enemies.is_empty():
		return AIDecision.wait_at(actor.cell)

	var occ := _occupancy(all_units)
	var ctx := BattleMoveContext.new(chapter, terrain_db, actor.movement_type(), occ, actor.team)
	var standable := MovementRange.standable_tiles(actor.cell, _mov(actor), ctx)

	var best: Dictionary = {}
	if actor.can_attack():
		for target in enemies:
			for tile in standable:
				var dist := _manhattan(tile, target.cell)
				if not actor.weapon().in_range(dist):
					continue
				var ex := _forecast(actor, tile, target, chapter, terrain_db, dist)
				var ev := evaluate(ex, target.current_hp)
				var cand := {
					"tile": tile, "target": target,
					"kills": ev["kills"], "score": ev["score"], "received": ev["received"],
					"target_hp": target.current_hp,
				}
				if best.is_empty() or _is_better(cand, best):
					best = cand

	if not best.is_empty():
		var d := AIDecision.new()
		d.move_to = best["tile"]
		d.target = best["target"]
		d.score = best["score"]
		return d

	# No target reachable — move toward the nearest enemy (Aggressor advance).
	return _advance_toward_nearest(actor, enemies, standable)


# --- selection -----------------------------------------------------------------

## True if candidate `a` is strictly preferred over incumbent `b` per §5 tiebreakers.
static func _is_better(a: Dictionary, b: Dictionary) -> bool:
	if a["kills"] != b["kills"]:
		return a["kills"]
	if not is_equal_approx(a["score"], b["score"]):
		return a["score"] > b["score"]
	if not is_equal_approx(a["received"], b["received"]):
		return a["received"] < b["received"]
	if a["target_hp"] != b["target_hp"]:
		return a["target_hp"] < b["target_hp"]
	# Stable positional tiebreak for reproducibility.
	return _cell_key(a["tile"]) < _cell_key(b["tile"])


static func _advance_toward_nearest(
	actor: Unit, enemies: Array, standable: Array
) -> AIDecision:
	var nearest: Unit = null
	var best_d := 1 << 30
	for e in enemies:
		var d := _manhattan(actor.cell, e.cell)
		if d < best_d or (d == best_d and nearest != null and _cell_key(e.cell) < _cell_key(nearest.cell)):
			best_d = d
			nearest = e
	if nearest == null:
		return AIDecision.wait_at(actor.cell)
	# Step to the standable tile closest to that enemy (stable tiebreak).
	var goal := actor.cell
	var goal_d := _manhattan(actor.cell, nearest.cell)
	for tile in standable:
		var d := _manhattan(tile, nearest.cell)
		if d < goal_d or (d == goal_d and _cell_key(tile) < _cell_key(goal)):
			goal_d = d
			goal = tile
	return AIDecision.wait_at(goal)


# --- helpers -------------------------------------------------------------------

static func _forecast(
	actor: Unit, tile: Vector2i, target: Unit, chapter: ChapterDef, terrain_db: TerrainDB, dist: int
) -> Dictionary:
	var atk_c := actor.to_combatant(_tdef(chapter, terrain_db, tile), _tavoid(chapter, terrain_db, tile))
	var def_c := target.to_combatant(
		_tdef(chapter, terrain_db, target.cell), _tavoid(chapter, terrain_db, target.cell)
	)
	return CombatForecast.exchange(atk_c, def_c, dist)


static func _living_enemies(actor: Unit, all_units: Array) -> Array:
	var out: Array = []
	for u in all_units:
		if u.team != actor.team and u.is_alive():
			out.append(u)
	return out


static func _occupancy(all_units: Array) -> Dictionary:
	var occ := {}
	for u in all_units:
		if u.is_alive():
			occ[u.cell] = u.team
	return occ


static func _mov(u: Unit) -> int:
	return u.unit_def.movement if u.unit_def != null else 5


static func _tdef(chapter: ChapterDef, db: TerrainDB, cell: Vector2i) -> int:
	return db.defense(chapter.get_terrain(cell.x, cell.y))


static func _tavoid(chapter: ChapterDef, db: TerrainDB, cell: Vector2i) -> int:
	return db.avoid(chapter.get_terrain(cell.x, cell.y))


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Packs a cell into a single sortable int (y-major) for deterministic tiebreaks.
static func _cell_key(c: Vector2i) -> int:
	return c.y * 100000 + c.x
