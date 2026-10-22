extends GutTest
## WO-0.4: pure Pathfinder — Dijkstra reachable-tiles and A* pathing on fixture maps.
##
## Fixtures are built with BattleMoveContext over a hand-made ChapterDef so the
## §3 terrain costs and occupancy rules are exercised, not mocked.

const FOOT := ClassDef.MovementType.FOOT
const ARMORED := ClassDef.MovementType.ARMORED

var _db: TerrainDB


func before_each() -> void:
	_db = TerrainDB.create_default()


func _plains_map(w: int, h: int) -> ChapterDef:
	var c := ChapterDef.new()
	c.width = w
	c.height = h
	c.fill(Terrain.Type.PLAINS)
	return c


func _ctx(
	chapter: ChapterDef, mt := FOOT, occ := {}, team := 0
) -> BattleMoveContext:
	return BattleMoveContext.new(chapter, _db, mt, occ, team)


# --- reachable (Dijkstra) -----------------------------------------------------

func test_reachable_on_open_plains_is_a_diamond():
	# Budget 2 on all-plains (cost 1 each) => Manhattan-distance<=2 diamond = 13 cells.
	var c := _plains_map(11, 11)
	var reached := Pathfinder.reachable(Vector2i(5, 5), 2, _ctx(c))
	assert_eq(reached.size(), 13)
	assert_true(reached.has(Vector2i(5, 5)))
	assert_eq(reached[Vector2i(5, 5)], 0)
	assert_eq(reached[Vector2i(7, 5)], 2)
	assert_false(reached.has(Vector2i(8, 5)))  # distance 3 > budget


func test_reachable_clamps_at_map_edges():
	var c := _plains_map(3, 3)
	var reached := Pathfinder.reachable(Vector2i(0, 0), 5, _ctx(c))
	# 3x3 all reachable within budget 5.
	assert_eq(reached.size(), 9)
	assert_eq(reached[Vector2i(2, 2)], 4)


func test_zero_budget_keeps_only_occupied_origin_without_charging_its_terrain():
	var c := _plains_map(3, 1)
	var origin := Vector2i(1, 0)
	c.set_terrain(origin.x, origin.y, Terrain.Type.MOUNTAIN)
	var ctx := _ctx(c, FOOT, {origin: 0})
	assert_eq(Pathfinder.reachable(origin, 0, ctx), {origin: 0})
	assert_eq(MovementRange.standable_tiles(origin, 0, ctx), [origin])
	var reached := Pathfinder.reachable(origin, 1, ctx)
	assert_eq(reached.get(Vector2i(0, 0), -1), 1, "leaving the mountain costs only plains entry")
	assert_eq(reached.get(Vector2i(2, 0), -1), 1)


func test_reachable_uses_cheaper_detour_at_exact_budget():
	# Direct route costs 13; either plains detour takes six steps and costs 6.
	var c := _plains_map(5, 3)
	for x in range(1, 4):
		c.set_terrain(x, 1, Terrain.Type.MOUNTAIN)
	var origin := Vector2i(0, 1)
	var goal := Vector2i(4, 1)
	var ctx := _ctx(c)
	assert_false(Pathfinder.reachable(origin, 5, ctx).has(goal), "one point short of detour cost")
	assert_eq(Pathfinder.reachable(origin, 6, ctx).get(goal, -1), 6,
		"a longer affordable route must remain reachable")


func test_forest_costs_two_to_enter():
	var c := _plains_map(5, 5)
	c.set_terrain(3, 2, Terrain.Type.FOREST)  # east of origin at (2,2)
	var reached := Pathfinder.reachable(Vector2i(2, 2), 2, _ctx(c))
	assert_eq(reached[Vector2i(3, 2)], 2, "forest entry costs 2")
	assert_false(reached.has(Vector2i(4, 2)), "no budget left past the forest")


func test_wall_is_impassable_and_blocks_pathing_around():
	# A vertical wall column at x=2 (rows 0..2) forces a detour.
	var c := _plains_map(5, 3)
	for y in range(3):
		c.set_terrain(2, y, Terrain.Type.WALL)
	var reached := Pathfinder.reachable(Vector2i(0, 1), 3, _ctx(c))
	assert_false(reached.has(Vector2i(2, 1)), "wall cell never entered")
	assert_false(reached.has(Vector2i(3, 1)), "wall fully seals a 3-tall gap")


func test_armored_cannot_enter_mountain_but_foot_can():
	var c := _plains_map(5, 5)
	c.set_terrain(3, 2, Terrain.Type.MOUNTAIN)
	var foot := Pathfinder.reachable(Vector2i(2, 2), 4, _ctx(c, FOOT))
	assert_eq(foot[Vector2i(3, 2)], 4, "foot pays mountain cost 4")
	var armored := Pathfinder.reachable(Vector2i(2, 2), 4, _ctx(c, ARMORED))
	assert_false(armored.has(Vector2i(3, 2)), "armored blocked by mountain")


func test_enemy_unit_blocks_movement_ally_does_not():
	var c := _plains_map(5, 1)
	# Enemy (team 1) at (2,0) blocks a team-0 mover from passing.
	var enemy_occ := {Vector2i(2, 0): 1}
	var blocked := Pathfinder.reachable(Vector2i(0, 0), 5, _ctx(c, FOOT, enemy_occ, 0))
	assert_false(blocked.has(Vector2i(2, 0)))
	assert_false(blocked.has(Vector2i(3, 0)), "enemy seals the 1-tall corridor")
	# Ally (team 0) can be passed through.
	var ally_occ := {Vector2i(2, 0): 0}
	var through := Pathfinder.reachable(Vector2i(0, 0), 5, _ctx(c, FOOT, ally_occ, 0))
	assert_true(through.has(Vector2i(3, 0)), "ally is passable")


# --- standable filtering ------------------------------------------------------

func test_ally_tile_is_passable_but_not_standable():
	var c := _plains_map(5, 1)
	var ally_occ := {Vector2i(2, 0): 0}
	var ctx := _ctx(c, FOOT, ally_occ, 0)
	var stand := MovementRange.standable_tiles(Vector2i(0, 0), 5, ctx)
	assert_false(stand.has(Vector2i(2, 0)), "cannot stop on an ally")
	assert_true(stand.has(Vector2i(3, 0)), "can stop beyond an ally")
	assert_true(stand.has(Vector2i(0, 0)), "origin is always standable")


# --- A* pathing ---------------------------------------------------------------

func test_find_path_straight_line():
	var c := _plains_map(6, 1)
	var path := Pathfinder.find_path(Vector2i(0, 0), Vector2i(4, 0), _ctx(c))
	assert_eq(path, [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	])


func test_find_path_same_cell_is_singleton():
	var c := _plains_map(3, 3)
	assert_eq(Pathfinder.find_path(Vector2i(1, 1), Vector2i(1, 1), _ctx(c)), [Vector2i(1, 1)])


func test_find_path_routes_around_wall():
	var c := _plains_map(5, 3)
	for y in range(2):  # wall at x=2, rows 0..1; row 2 is the gap
		c.set_terrain(2, y, Terrain.Type.WALL)
	var path := Pathfinder.find_path(Vector2i(0, 0), Vector2i(4, 0), _ctx(c))
	assert_gt(path.size(), 5, "detour is longer than the blocked straight line")
	assert_eq(path.front(), Vector2i(0, 0))
	assert_eq(path.back(), Vector2i(4, 0))
	assert_false(path.has(Vector2i(2, 0)), "path avoids the wall")
	assert_true(path.has(Vector2i(2, 2)), "path uses the row-2 gap")


func test_find_path_prefers_plains_over_forest():
	# Two routes east; the middle row is cheap plains, flanks are forest.
	var c := _plains_map(4, 3)
	for x in range(1, 3):
		c.set_terrain(x, 0, Terrain.Type.FOREST)
		c.set_terrain(x, 2, Terrain.Type.FOREST)
	var path := Pathfinder.find_path(Vector2i(0, 1), Vector2i(3, 1), _ctx(c))
	for step in path:
		assert_ne(c.get_terrain(step.x, step.y), Terrain.Type.FOREST,
			"cheapest path stays on plains")


func test_find_path_takes_longer_route_when_it_costs_less():
	var c := _plains_map(5, 3)
	for x in range(1, 4):
		c.set_terrain(x, 1, Terrain.Type.MOUNTAIN)
	var start := Vector2i(0, 1)
	var goal := Vector2i(4, 1)
	var ctx := _ctx(c)
	var path := Pathfinder.find_path(start, goal, ctx)
	assert_eq(path.size(), 7, "six plains steps beat four steps through mountains")
	if path.is_empty():
		return
	assert_eq(path.front(), start)
	assert_eq(path.back(), goal)
	var cost := 0
	for i in range(1, path.size()):
		var previous: Vector2i = path[i - 1]
		var cell: Vector2i = path[i]
		assert_eq(absi(cell.x - previous.x) + absi(cell.y - previous.y), 1,
			"each step must enter an orthogonally adjacent cell")
		assert_true(ctx.in_bounds(cell), "detour stays inside the map")
		cost += ctx.enter_cost(cell)
	assert_eq(cost, 6, "minimize movement cost rather than number of steps")
	assert_eq(cost, Pathfinder.reachable(start, 6, ctx).get(goal, -1),
		"path preview cost matches the reachable overlay")


func test_find_path_respects_mover_team_in_occupied_corridor():
	var c := _plains_map(5, 1)
	var start := Vector2i(0, 0)
	var occupied := Vector2i(2, 0)
	var goal := Vector2i(4, 0)
	for team in [0, 1]:
		var ally_ctx := _ctx(c, FOOT, {start: team, occupied: team}, team)
		assert_eq(Pathfinder.find_path(start, goal, ally_ctx), [
			start, Vector2i(1, 0), occupied, Vector2i(3, 0), goal,
		], "allied units allow passage for either team")
		var enemy_ctx := _ctx(c, FOOT, {occupied: 1 - team}, team)
		assert_eq(Pathfinder.find_path(start, occupied, enemy_ctx), [],
			"an enemy cannot be the destination")
		assert_eq(Pathfinder.find_path(start, goal, enemy_ctx), [],
			"an enemy blocks the route beyond its cell")


func test_find_path_rejects_goals_outside_each_map_edge():
	var c := _plains_map(3, 3)
	for goal in [Vector2i(-1, 1), Vector2i(3, 1), Vector2i(1, -1), Vector2i(1, 3)]:
		assert_eq(Pathfinder.find_path(Vector2i(1, 1), goal, _ctx(c)), [],
			"off-map destinations must not produce a path")


func test_find_path_returns_empty_when_goal_walled():
	var c := _plains_map(3, 1)
	c.set_terrain(2, 0, Terrain.Type.WALL)
	assert_eq(Pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 0), _ctx(c)), [])


func test_find_path_returns_empty_when_fully_sealed():
	var c := _plains_map(5, 3)
	for y in range(3):
		c.set_terrain(2, y, Terrain.Type.WALL)
	assert_eq(Pathfinder.find_path(Vector2i(0, 1), Vector2i(4, 1), _ctx(c)), [])


# --- attack range -------------------------------------------------------------

func test_attack_tiles_melee_ring_excludes_standable():
	var c := _plains_map(11, 11)
	var ctx := _ctx(c)
	var stand := MovementRange.standable_tiles(Vector2i(5, 5), 1, ctx)  # + shape, 5 tiles
	var attack := MovementRange.attack_tiles(stand, [1], ctx)
	for t in attack:
		assert_false(stand.has(t), "attack tiles never overlap move tiles")
	assert_true(attack.has(Vector2i(7, 5)), "reaches one beyond the move edge")


func test_attack_tiles_bow_range_two():
	var c := _plains_map(11, 11)
	var ctx := _ctx(c)
	var attack := MovementRange.attack_tiles([Vector2i(5, 5)], [2], ctx)
	assert_true(attack.has(Vector2i(7, 5)))
	assert_true(attack.has(Vector2i(5, 7)))
	assert_false(attack.has(Vector2i(6, 5)), "range-2-only skips adjacent")
