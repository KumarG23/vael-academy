extends GutTest
## WO-5.1a: the prologue battle mechanism — chapter-driven player/guest spawns
## (ChapterDef.player_spawns replaces the Roster when authored) and the
## prologue chapter itself: Kai + the three heir guests vs the bandit raid.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/prologue.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.dialogue_enabled = false
	add_child_autofree(_view)


func _unit(id: String) -> Unit:
	for u in _view._units:
		if u.unit_id() == id:
			return u
	return null


func test_prologue_chapter_data():
	var c: ChapterDef = _view.chapter
	assert_eq(c.id, "prologue")
	assert_eq(c.objective, ChapterDef.Objective.DEFEAT_BOSS)
	assert_eq(c.boss_unit_id, "bandit_boss")
	assert_true(c.non_lethal, "raiders are driven off, heirs have story armor")
	assert_eq(c.width, 16)
	assert_eq(c.height, 11)
	assert_eq(c.get_terrain(13, 5), Terrain.Type.FORT, "the raiders' camp")
	assert_eq(c.get_terrain(0, 0), Terrain.Type.MOUNTAIN, "north wall")


func test_player_spawns_replace_the_roster():
	var players: Array = []
	for u in _view._units:
		if u.team == 0:
			players.append(u.unit_id())
	players.sort()
	assert_eq(players, ["kai", "perrin", "rina", "serra"],
		"Kai + the three heir guests, not the Emberwing roster")
	assert_null(_unit("kael"), "roster units don't ride along")


func test_kai_is_the_lord():
	assert_eq(_view._lord_unit, _unit("kai"))


func test_heir_guests_match_their_bible_identities():
	assert_eq(_unit("perrin").unit_def.char_class.id, "paladin")
	assert_eq(_unit("perrin").unit_def.house_id, "emberwing")
	assert_eq(_unit("serra").unit_def.char_class.id, "knight")
	assert_true(_unit("serra").unit_def.weapon.display_name.contains("Lance"))
	assert_eq(_unit("rina").unit_def.char_class.id, "mage")
	assert_gt(_unit("rina").stat("mag"), _unit("rina").stat("str"),
		"Rina fights with reason magic")


func test_bandit_force_spawned():
	var bandits: Array = []
	for u in _view._units:
		if u.team == 1:
			bandits.append(u.unit_id())
	assert_eq(bandits.size(), 5, "four bandits + the chief")
	var boss := _unit("bandit_boss")
	assert_not_null(boss)
	assert_eq(boss.cell, Vector2i(13, 5), "the chief holds the camp")
	assert_eq(_view._boss_unit, boss, "wired as the objective boss")
	assert_eq(_unit("bandit_b").cell, Vector2i(7, 7),
		"southern bandit starts on the passable western shore rather than in water")


func test_prologue_player_and_enemy_spawns_are_unique_in_bounds_and_traversable():
	var c: ChapterDef = load("res://data/chapters/prologue.tres")
	var db := TerrainDB.create_default()
	var authored_spawns: Array = []
	for spawn: UnitSpawn in c.player_spawns:
		authored_spawns.append({"spawn": spawn, "team": 0})
	for spawn: UnitSpawn in c.enemy_spawns:
		var team := spawn.team_override if spawn.team_override >= 0 else spawn.unit.team
		authored_spawns.append({"spawn": spawn, "team": team})
	assert_eq(authored_spawns.size(), 9, "four allies + five foes")
	var seen_cells := {}
	for entry: Dictionary in authored_spawns:
		var spawn: UnitSpawn = entry["spawn"]
		var team: int = entry["team"]
		assert_not_null(spawn)
		assert_not_null(spawn.unit)
		assert_not_null(spawn.unit.char_class)
		var cell := spawn.cell
		assert_true(c.in_bounds(cell.x, cell.y),
			"%s spawn %s must be in bounds" % [spawn.unit.id, cell])
		assert_false(seen_cells.has(cell),
			"%s spawn %s must be unique" % [spawn.unit.id, cell])
		seen_cells[cell] = spawn.unit.id
		var mt := spawn.unit.char_class.movement_type
		var ctx := BattleMoveContext.new(c, db, mt, {}, team)
		var cost := ctx.enter_cost(cell)
		assert_lt(cost, Pathfinder.INF_COST,
			"%s (%s) spawn %s must be traversable under movement rules (terrain %d)" % [
				spawn.unit.id, ClassDef.MovementType.keys()[mt], cell, c.get_terrain(cell.x, cell.y)
			])
		var live := _unit(spawn.unit.id)
		assert_not_null(live, "%s spawned in live battle scene" % spawn.unit.id)
		assert_eq(live.cell, cell, "%s runtime cell matches authored spawn" % spawn.unit.id)
		var live_ctx := BattleMoveContext.new(c, _view._terrain_db, live.movement_type(), _view.occupancy(), live.team)
		assert_lt(live_ctx.enter_cost(live.cell), Pathfinder.INF_COST,
			"%s runtime cell %s must be traversable for its live movement_type()" % [live.unit_id(), live.cell])
		var standable := MovementRange.standable_tiles(live.cell, live.move_points(), live_ctx)
		assert_gt(standable.size(), 1,
			"%s at %s can traverse onto adjacent tiles in round 1" % [live.unit_id(), live.cell])
		_view._cursor.move_to(live.cell)
		assert_false(_view._debug_label.text.contains("impassable"),
			"%s HUD terrain readout at %s must not be impassable: %s" % [
				live.unit_id(), live.cell, _view._debug_label.text
			])


func test_defeating_the_chief_wins():
	var boss := _unit("bandit_boss")
	boss.set_hp(0)
	_view._kill(boss)
	_view._check_objective()
	assert_true(_view._battle_over, "the battle ended")
	assert_true(_view._battle_victory, "driving off the chief wins the prologue")


func test_mock_battle_roster_path_unaffected():
	var v: Node2D = load("res://scenes/battle/mock_battle.tscn").instantiate()
	v.strike_delay = 0.0
	v.dialogue_enabled = false
	add_child_autofree(v)
	var players: Array = []
	for u in v._units:
		if u.team == 0:
			players.append(u.unit_id())
	players.sort()
	assert_eq(players, ["brenna", "dain", "kael", "kai", "liora", "perrin", "wren"],
		"the Roster path fields the full Emberwing house + Kai (WO-5.2)")
