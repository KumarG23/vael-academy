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
