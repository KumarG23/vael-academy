class_name AIBrain
extends RefCounted
## Enemy AI (§5), deterministic given a seed (only combat rolls consume RNG).
##
## Behaviors:
##  - AGGRESSOR: each phase, pick the reachable target maximizing expected
##    (damage dealt − damage received) via CombatForecast; prefer kills; if none is
##    reachable, advance toward the nearest.
##  - SENTINEL: hold position until a player enters its threat range, then act as an
##    Aggressor (waking is tracked on the Unit by the battle scene).
##  - BOSS: never leaves its tile; only attacks what it can reach from where it stands.
##
## Tiebreakers (§5): kill > lowest counter-damage > lowest-HP target, then a stable
## positional tiebreak so runs are reproducible.

enum Behavior { AGGRESSOR, SENTINEL, BOSS }


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
## A BOSS is pinned to its tile; other behaviors may move.
static func decide(
	actor: Unit, all_units: Array, chapter: ChapterDef, terrain_db: TerrainDB,
	behavior: Behavior = Behavior.AGGRESSOR
) -> AIDecision:
	var enemies := _living_enemies(actor, all_units)
	if enemies.is_empty():
		return AIDecision.wait_at(actor.cell)

	# A boss only ever attacks from where it stands; everyone else uses full movement.
	var standable := _reachable_tiles(actor, all_units, chapter, terrain_db, behavior)
	var best := _best_attack(actor, enemies, standable, chapter, terrain_db)

	if not best.is_empty():
		var d := AIDecision.new()
		d.move_to = best["tile"]
		d.target = best["target"]
		d.score = best["score"]
		return d

	# No target reachable. A boss holds; an aggressor advances on the nearest foe.
	if behavior == Behavior.BOSS:
		return AIDecision.wait_at(actor.cell)
	return _advance_toward_nearest(actor, enemies, standable)


## Tiles the actor could attack this turn (its threat range). BOSS-aware: a boss
## threatens only from its current tile. Used for the threat overlay and for
## waking sentinels.
static func threat_tiles(
	actor: Unit, all_units: Array, chapter: ChapterDef, terrain_db: TerrainDB,
	behavior: Behavior = Behavior.AGGRESSOR
) -> Array:
	if not actor.can_attack():
		return []
	var standable := _reachable_tiles(actor, all_units, chapter, terrain_db, behavior)
	var ranges: Array = []
	for r in range(actor.weapon().min_range, actor.weapon().max_range + 1):
		ranges.append(r)
	var occ := _occupancy(all_units)
	var ctx := BattleMoveContext.new(chapter, terrain_db, actor.movement_type(), occ, actor.team)
	return MovementRange.attack_tiles(standable, ranges, ctx)


## True if any living enemy of `actor` stands within its threat range (sentinel wake).
static func has_enemy_in_threat(
	actor: Unit, all_units: Array, chapter: ChapterDef, terrain_db: TerrainDB,
	behavior: Behavior = Behavior.AGGRESSOR
) -> bool:
	var threat := threat_tiles(actor, all_units, chapter, terrain_db, behavior)
	if threat.is_empty():
		return false
	var threatened := {}
	for t in threat:
		threatened[t] = true
	for e in _living_enemies(actor, all_units):
		if threatened.has(e.cell):
			return true
	return false


static func _reachable_tiles(
	actor: Unit, all_units: Array, chapter: ChapterDef, terrain_db: TerrainDB, behavior: Behavior
) -> Array:
	if behavior == Behavior.BOSS:
		return [actor.cell]
	var occ := _occupancy(all_units)
	var ctx := BattleMoveContext.new(chapter, terrain_db, actor.movement_type(), occ, actor.team)
	return MovementRange.standable_tiles(actor.cell, _mov(actor), ctx)


## Best (tile, target) attack option over `standable`, or {} if none.
static func _best_attack(
	actor: Unit, enemies: Array, standable: Array, chapter: ChapterDef, terrain_db: TerrainDB
) -> Dictionary:
	var best: Dictionary = {}
	if not actor.can_attack():
		return best
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
	return best


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
