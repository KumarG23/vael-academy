extends GutTest
## WO-4.1: Chapter 1 — The Mock Battle. Chapter data sanity, authored spawns,
## the DEFEAT_BOSS objective, non-lethal yields (nobody can permanently die),
## fort healing, and the intro dialogue hook.

const SCENE := "res://scenes/battle/mock_battle.tscn"
const CHAPTER := "res://data/chapters/mock_battle.tres"

var _view: Node2D


func before_each() -> void:
	Campaign.reset_new_game(false)  # classic mode: the strictest permadeath rules
	var scene: PackedScene = load(SCENE)
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 5
	_view.dialogue_enabled = false
	add_child_autofree(_view)
	await wait_physics_frames(2)


func after_each() -> void:
	Campaign.reset_new_game(false)


# --- chapter data ----------------------------------------------------------------

func test_chapter_data_is_authored_correctly():
	var chapter: ChapterDef = load(CHAPTER)
	assert_eq(chapter.id, "mock_battle")
	assert_eq(chapter.width, 20)
	assert_eq(chapter.height, 15)
	assert_eq(chapter.terrain.size(), 300, "full terrain grid")
	assert_eq(chapter.objective, ChapterDef.Objective.DEFEAT_BOSS)
	assert_eq(chapter.boss_unit_id, "serra")
	assert_true(chapter.non_lethal, "the Mock Battle is non-lethal")
	assert_eq(chapter.enemy_spawns.size(), 7, "6 Tidemark students + Serra")
	assert_eq(chapter.deploy_cells.size(), 20, "cells for every fieldable unit across all houses + Sable (WO-5.4/5.5)")


func test_chapter_terrain_uses_landmarks_meaningfully():
	var chapter: ChapterDef = load(CHAPTER)
	var counts := {}
	for t in chapter.terrain:
		counts[t] = int(counts.get(t, 0)) + 1
	assert_gt(int(counts.get(Terrain.Type.FOREST, 0)), 5, "forest cover present")
	assert_gt(int(counts.get(Terrain.Type.MOUNTAIN, 0)), 4, "mountain ridge present")
	assert_gt(int(counts.get(Terrain.Type.FORT, 0)), 1, "Serra's fort + a waypoint fort")
	assert_gt(int(counts.get(Terrain.Type.WALL, 0)), 0, "wall chokepoint present")
	# Serra stands on a fort; every spawn and deploy cell is on passable ground.
	var db := TerrainDB.create_default()
	for spawn in chapter.enemy_spawns:
		var t := chapter.get_terrain(spawn.cell.x, spawn.cell.y)
		assert_false(db.is_impassable(t), "%s spawns on passable terrain" % spawn.unit.id)
		if spawn.unit.id == "serra":
			assert_eq(t, Terrain.Type.FORT, "Serra holds the fort")
	for id in chapter.deploy_cells:
		var c: Vector2i = chapter.deploy_cells[id]
		assert_eq(chapter.get_terrain(c.x, c.y), Terrain.Type.PLAINS, "%s deploys on plains" % id)


func test_a_foot_unit_can_reach_the_boss():
	var chapter: ChapterDef = load(CHAPTER)
	var ctx := BattleMoveContext.new(chapter, TerrainDB.create_default(), ClassDef.MovementType.FOOT)
	var path := Pathfinder.find_path(Vector2i(2, 12), Vector2i(17, 3), ctx)
	assert_gt(path.size(), 0, "deploy zone connects to the tile below Serra's fort")


func test_dialogue_scripts_exist_and_parse():
	var chapter: ChapterDef = load(CHAPTER)
	for path in [chapter.intro_dialogue, chapter.outro_dialogue,
			chapter.boss_quote_dialogue, chapter.boss_yield_dialogue]:
		assert_ne(path, "", "dialogue path authored")
		var script := DialogueScript.from_file(path)
		assert_true(script.ok(), "%s parses: %s" % [path, script.error])
		assert_gt(script.size(), 0, "%s has content" % path)


# --- spawns & objective ------------------------------------------------------------

func test_forces_spawn_from_chapter_data():
	assert_eq(_view._living_units_on_team(0).size(), 7, "the Emberwing house + Kai (WO-5.2)")
	assert_eq(_view._living_units_on_team(1).size(), 7, "seven Tidemark units")
	var kai: Unit = _view.unit_by_id("kai")
	assert_eq(kai.cell, Vector2i(2, 12), "Kai at his authored deploy cell")
	assert_true(kai.is_lord(), "Kai is the lord (§4)")
	assert_eq(_view._lord_unit, kai)
	var serra: Unit = _view.unit_by_id("serra")
	assert_eq(serra.cell, Vector2i(17, 2))
	assert_eq(_view._boss_unit, serra, "Serra tracked as the objective boss")
	assert_eq(serra.ai_behavior(), AIBrain.Behavior.BOSS)


func test_defeating_serra_wins_with_enemies_still_standing():
	var serra: Unit = _view.unit_by_id("serra")
	_view._kill(serra)
	_view._check_objective()
	assert_true(_view._battle_over, "battle ends when Serra yields")
	assert_true(_view._battle_victory, "defeating the boss is victory")
	assert_gt(_view._living_units_on_team(1).size(), 0, "other Tidemark students remain")


func test_rout_also_wins():
	for enemy in _view._living_units_on_team(1).duplicate():
		_view._kill(enemy)
	_view._check_objective()
	assert_true(_view._battle_over)
	assert_true(_view._battle_victory)


func test_lord_fall_still_loses_the_mock_battle():
	var kai: Unit = _view.unit_by_id("kai")
	_view._kill(kai)
	_view._check_objective()
	assert_true(_view._battle_over)
	assert_false(_view._battle_victory, "losing Kai loses the exercise")


# --- non-lethal yields (§6: nobody can permanently die) ----------------------------

func test_defeated_players_yield_and_are_never_permadead():
	var kael: Unit = _view.unit_by_id("kael")
	_view._kill(kael)  # classic mode — would permadeath on a lethal chapter
	assert_null(_view.unit_by_id("kael"), "yielded unit leaves the field")
	assert_true(_view._defeated_unit_ids.has("kael"), "yield is recorded")
	assert_false(_view._permadead_unit_ids.has("kael"), "but nobody permanently dies")
	assert_eq(_view._permadead_unit_ids.size(), 0)


func test_defeated_enemies_yield_without_permadeath_flags():
	var scout: Unit = _view.unit_by_id("tm_scout")
	_view._kill(scout)
	assert_true(_view._defeated_unit_ids.has("tm_scout"))
	assert_eq(_view._permadead_unit_ids.size(), 0)


# --- fort healing (§3: Fort heals 10% max HP per turn) -----------------------------

func test_fort_heals_its_occupant_at_phase_start():
	var serra: Unit = _view.unit_by_id("serra")
	serra.current_hp = serra.max_hp() - 10
	_view._apply_terrain_heal(1)
	assert_eq(serra.current_hp, serra.max_hp() - 10 + 3, "Serra heals ceil(30 * 10%) = 3 on her fort")
	# A unit on plains gets nothing.
	var kai: Unit = _view.unit_by_id("kai")
	kai.current_hp = 10
	_view._apply_terrain_heal(0)
	assert_eq(kai.current_hp, 10, "plains do not heal")


# --- AW-29: terrain hazards chip HP at phase start (never lethal) -----------------

func test_embers_chip_hp_but_never_kill():
	var kai: Unit = _view.unit_by_id("kai")
	var c := kai.cell
	var prev: int = _view.chapter.get_terrain(c.x, c.y)
	_view.chapter.set_terrain(c.x, c.y, Terrain.Type.EMBERS)
	kai.current_hp = kai.max_hp()
	_view._apply_terrain_hazard(0)
	assert_eq(kai.current_hp, kai.max_hp() - 3, "Embers chip 3 HP a turn")
	kai.current_hp = 1
	_view._apply_terrain_hazard(0)
	assert_eq(kai.current_hp, 1, "terrain never defeats a unit")
	_view.chapter.set_terrain(c.x, c.y, prev)  # restore the shared resource


# --- dialogue hooks -----------------------------------------------------------------

func _find_dialogue(node: Node) -> DialogueScene:
	if node is DialogueScene:
		return node
	for child in node.get_children():
		var found := _find_dialogue(child)
		if found != null:
			return found
	return null


func test_intro_dialogue_plays_then_battle_begins():
	Campaign.reset_new_game(false)
	var scene: PackedScene = load(SCENE)
	var view: Node2D = scene.instantiate()
	view.strike_delay = 0.0
	view.dialogue_enabled = true
	add_child_autofree(view)
	await wait_physics_frames(2)

	var dlg := _find_dialogue(view)
	assert_not_null(dlg, "intro dialogue overlay is up")
	assert_true(view._dialogue_playing, "battle input is gated during the intro")
	assert_false(view._cursor.active, "cursor is inactive during dialogue")
	# Drive the conversation to its end.
	var guard := 0
	while not dlg.is_finished() and guard < 100:
		dlg.advance()
		guard += 1
	await wait_physics_frames(2)
	assert_false(view._dialogue_playing, "dialogue released the battle")
	assert_true(view._cursor.active, "cursor control returns after the intro")


func test_boss_quote_plays_once_on_first_engagement():
	# Teleport Kael next to Serra and attack her; the quote flag flips once.
	var kael: Unit = _view.unit_by_id("kael")
	var serra: Unit = _view.unit_by_id("serra")
	kael.cell = Vector2i(17, 3)
	kael.position = _view._grid.cell_center(kael.cell)
	assert_false(_view._boss_quote_played)
	await _view._execute_attack(kael, serra)
	assert_true(_view._boss_quote_played, "first boss engagement marks the quote played")
