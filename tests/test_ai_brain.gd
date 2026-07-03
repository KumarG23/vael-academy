extends GutTest
## WO-1.3: Aggressor AI. Scoring (evaluate) is table-tested pure; decide() is
## tested on a small fixture board with real Unit nodes + the test map's terrain.


func _exchange(atk_hit, atk_dmg, def_can_counter, def_hit, def_dmg, atk_dbl := false, def_dbl := false) -> Dictionary:
	return {
		"attacker": {"hit": atk_hit, "crit": 0, "damage": atk_dmg},
		"defender": {"hit": def_hit, "crit": 0, "damage": def_dmg},
		"attacker_can_attack": true,
		"defender_can_counter": def_can_counter,
		"attacker_doubles": atk_dbl,
		"defender_doubles": def_dbl,
	}


# --- evaluate (pure scoring) --------------------------------------------------

func test_evaluate_expected_damage_and_score():
	var ev := AIBrain.evaluate(_exchange(100, 10, true, 50, 6), 30)
	assert_almost_eq(ev["dealt"], 10.0, 0.001)
	assert_almost_eq(ev["received"], 3.0, 0.001)   # 0.5 * 6
	assert_almost_eq(ev["score"], 7.0, 0.001)
	assert_false(ev["kills"])


func test_evaluate_no_counter_means_zero_received():
	var ev := AIBrain.evaluate(_exchange(80, 12, false, 90, 20), 40)
	assert_almost_eq(ev["received"], 0.0, 0.001)
	assert_almost_eq(ev["score"], 9.6, 0.001)      # 0.8 * 12


func test_evaluate_credits_a_kill_when_all_hits_would_drop_target():
	# 2 strikes * 12 = 24 >= 20 -> kill.
	var ev := AIBrain.evaluate(_exchange(70, 12, false, 0, 0, true), 20)
	assert_true(ev["kills"])


func test_evaluate_doubling_scales_dealt_and_received():
	var ev := AIBrain.evaluate(_exchange(100, 5, true, 100, 4, true, true), 100)
	assert_almost_eq(ev["dealt"], 10.0, 0.001)     # 5 * 2
	assert_almost_eq(ev["received"], 8.0, 0.001)   # 4 * 2


# --- decide (fixture board) ---------------------------------------------------

var _grid: Grid
var _chapter: ChapterDef
var _db: TerrainDB
var _units: Array[Unit] = []


func before_each() -> void:
	_db = TerrainDB.create_default()
	_chapter = ChapterDef.new()
	_chapter.width = 12
	_chapter.height = 3
	_chapter.fill(Terrain.Type.PLAINS)
	_grid = _chapter.make_grid()
	_units = []


func _spawn(name: String, wpn: WeaponDef, team: int, cell: Vector2i, mov := 5, hp := 24) -> Unit:
	var d := UnitDef.new()
	d.id = name
	d.display_name = name
	d.char_class = _foot()
	d.weapon = wpn
	d.team = team
	d.movement = mov
	d.max_hp = hp
	d.strength = 8
	d.speed = 8
	d.defense = 3
	var u := Unit.new()
	add_child_autofree(u)
	u.setup(d, _grid, cell)
	_units.append(u)
	return u


func _foot() -> ClassDef:
	var c := ClassDef.new()
	c.movement_type = ClassDef.MovementType.FOOT
	c.token_letter = "F"
	return c


func test_decide_moves_adjacent_and_attacks_a_reachable_player():
	var enemy := _spawn("enemy", CombatTestHelpers.sword(6, 90), 1, Vector2i(1, 1), 5)
	var player := _spawn("player", CombatTestHelpers.sword(5, 90), 0, Vector2i(6, 1), 5)
	var d := AIBrain.decide(enemy, _units, _chapter, _db)
	assert_true(d.has_attack(), "should choose to attack the reachable player")
	assert_eq(d.target, player)
	assert_eq(BattleView_manhattan(d.move_to, player.cell), 1, "stands adjacent to strike")


func test_decide_advances_when_no_target_in_reach():
	var enemy := _spawn("enemy", CombatTestHelpers.sword(6, 90), 1, Vector2i(0, 1), 4)
	var player := _spawn("player", CombatTestHelpers.sword(5, 90), 0, Vector2i(11, 1), 4)
	var d := AIBrain.decide(enemy, _units, _chapter, _db)
	assert_false(d.has_attack(), "too far to attack this turn")
	assert_gt(d.move_to.x, enemy.cell.x, "advances toward the distant player")
	assert_lte(BattleView_manhattan(enemy.cell, d.move_to), 4, "within movement budget")


func test_decide_prefers_the_killable_target():
	var enemy := _spawn("enemy", CombatTestHelpers.sword(10, 100), 1, Vector2i(5, 1), 5)
	# Two adjacent-reachable players: one healthy, one at 1 HP (killable).
	var healthy := _spawn("healthy", CombatTestHelpers.sword(5, 90), 0, Vector2i(3, 1), 5, 24)
	var weak := _spawn("weak", CombatTestHelpers.sword(5, 90), 0, Vector2i(7, 1), 5, 24)
	weak.current_hp = 1
	var d := AIBrain.decide(enemy, _units, _chapter, _db)
	assert_eq(d.target, weak, "kill is preferred over the healthy target")


func test_decide_waits_when_no_enemies():
	var lone := _spawn("lone", CombatTestHelpers.sword(6, 90), 1, Vector2i(4, 1), 5)
	var d := AIBrain.decide(lone, _units, _chapter, _db)
	assert_false(d.has_attack())
	assert_eq(d.move_to, lone.cell, "no enemies -> stay put")


# --- boss / sentinel / threat (§5) --------------------------------------------

func test_boss_attacks_only_from_its_tile_never_moving():
	var boss := _spawn("boss", CombatTestHelpers.sword(6, 90), 1, Vector2i(5, 1), 5)
	var player := _spawn("player", CombatTestHelpers.sword(5, 90), 0, Vector2i(4, 1), 5)  # adjacent
	var d := AIBrain.decide(boss, _units, _chapter, _db, AIBrain.Behavior.BOSS)
	assert_true(d.has_attack(), "boss strikes an adjacent foe")
	assert_eq(d.move_to, boss.cell, "boss does not move to attack")


func test_boss_holds_when_no_one_is_adjacent():
	var boss := _spawn("boss", CombatTestHelpers.sword(6, 90), 1, Vector2i(5, 1), 5)
	var player := _spawn("player", CombatTestHelpers.sword(5, 90), 0, Vector2i(10, 1), 5)  # reachable but far
	var d := AIBrain.decide(boss, _units, _chapter, _db, AIBrain.Behavior.BOSS)
	assert_false(d.has_attack(), "no adjacent target")
	assert_eq(d.move_to, boss.cell, "boss holds the fort instead of advancing")


func test_aggressor_would_advance_where_a_boss_holds():
	# Same layout, but an aggressor closes in rather than holding.
	var unit := _spawn("agg", CombatTestHelpers.sword(6, 90), 1, Vector2i(5, 1), 5)
	var player := _spawn("player", CombatTestHelpers.sword(5, 90), 0, Vector2i(10, 1), 5)
	var d := AIBrain.decide(unit, _units, _chapter, _db, AIBrain.Behavior.AGGRESSOR)
	assert_gt(d.move_to.x, unit.cell.x, "aggressor advances toward the player")


func test_threat_tiles_include_reachable_attack_squares():
	var unit := _spawn("agg", CombatTestHelpers.sword(6, 90), 1, Vector2i(5, 1), 3)
	var threat := AIBrain.threat_tiles(unit, _units, _chapter, _db)
	# With move 3 + range 1, the tile 4 away in a straight line is threatened.
	assert_true(threat.has(Vector2i(9, 1)), "move 3 then strike range 1 reaches x=9")
	assert_false(threat.has(Vector2i(10, 1)), "one tile beyond reach is safe")


func test_boss_threat_is_only_its_attack_range():
	var boss := _spawn("boss", CombatTestHelpers.sword(6, 90), 1, Vector2i(5, 1), 5)
	var threat := AIBrain.threat_tiles(boss, _units, _chapter, _db, AIBrain.Behavior.BOSS)
	assert_true(threat.has(Vector2i(6, 1)), "adjacent tile threatened")
	assert_false(threat.has(Vector2i(8, 1)), "boss doesn't move, so distant tiles are safe")


func test_has_enemy_in_threat_detects_a_player_in_range():
	var sentinel := _spawn("sent", CombatTestHelpers.sword(6, 90), 1, Vector2i(5, 1), 3)
	var near := _spawn("near", CombatTestHelpers.sword(5, 90), 0, Vector2i(9, 1), 3)  # within reach
	assert_true(AIBrain.has_enemy_in_threat(sentinel, _units, _chapter, _db))
	near.cell = Vector2i(11, 1)  # step out of reach
	assert_false(AIBrain.has_enemy_in_threat(sentinel, _units, _chapter, _db))


## Small local Manhattan helper (kept out of production API).
func BattleView_manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
