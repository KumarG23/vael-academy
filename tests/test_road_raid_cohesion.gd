extends GutTest
## VS-1B.5: dressing must not alter the tutorial's playable contract.
func test_original_board_forces_objective_visits_and_dialogue_are_preserved():
	var road: ChapterDef = load("res://data/chapters/prologue.tres")
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/road_raid_vs1b_baseline.json"))
	assert_eq(road.width, int(baseline.width))
	assert_eq(road.height, int(baseline.height))
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(road.terrain.to_byte_array())
	assert_eq(hash.finish().hex_encode(), baseline.terrain_sha256, "every logical tile stays exactly VS-1B")
	for side: String in ["player_spawns", "enemy_spawns"]:
		var actual: Array = []
		var expected: Array = []
		for spawn: UnitSpawn in road.get(side):
			actual.append([spawn.unit.id, spawn.cell.x, spawn.cell.y])
		for spawn: Array in baseline[side]:
			var unit_id := str(spawn[0])
			var x := int(spawn[1])
			var y := int(spawn[2])
			# Issue #20 (separately authorized under MASTER_PLAN §3 terrain rules and
			# §6 WO-5.1a): the frozen VS-1B.5 baseline json is kept intact as the
			# historical record; only the two impassable starts—Perrin on SITE (2,6)->(3,6)
			# and bandit_b on WATER (8,7)->(7,7)—move one cell onto passable PLAINS.
			if side == "player_spawns" and unit_id == "perrin" and x == 2 and y == 6:
				x = 3
			elif side == "enemy_spawns" and unit_id == "bandit_b" and x == 8 and y == 7:
				x = 7
			expected.append([unit_id, x, y])
		assert_eq(actual, expected, "same original units, positions (with issue #20 passability correction) and order")
	assert_eq(road.objective, ChapterDef.Objective.DEFEAT_BOSS)
	assert_eq(road.boss_unit_id, "bandit_boss")
	assert_true(road.non_lethal)
	assert_eq(road.intro_dialogue, "res://data/dialogue/road_bandit_intro.json")
	assert_eq(road.outro_dialogue, "res://data/dialogue/road_bandit_outro.json")
	assert_eq(road.visits.size(), 2)
	assert_eq(road.visits[0].cell, Vector2i(2, 8))
	assert_eq(road.visits[1].cell, Vector2i(4, 3))

func test_flat_dressing_renders_below_upright_props_and_keeps_lanes_open():
	var low := {"cell": Vector2i(7, 10), "ground": true}
	var high := {"cell": Vector2i(0, 2)}
	assert_true(TerrainTiles._decor_before(low, high), "late-row ground cannot cover buildings")
	assert_false(TerrainTiles._decor_before(high, low))
	assert_true(TerrainTiles._decor_before({"cell": Vector2i(0, 2)}, {"cell": Vector2i(0, 7)}), "legacy row sorting retained")
	assert_false(MapDecor.new().ground_layer, "old chapters keep their rendering")
	var road: ChapterDef = load("res://data/chapters/prologue.tres")
	var upright: int = 0
	var ground: int = 0
	for prop: MapDecor in road.decor:
		assert_not_null(prop.texture)
		if not prop.resource_name.begins_with("VS1B5_"):
			continue
		if prop.ground_layer:
			ground += 1
		else:
			upright += 1
			var t: int = road.get_terrain(prop.cell.x, prop.cell.y)
			assert_true(t in [Terrain.Type.MOUNTAIN, Terrain.Type.SITE], "new upright scenery only on existing blockers")
	assert_eq(ground, 1)
	assert_eq(upright, 5)

func test_multiple_burn_sites_reuse_approved_pixel_export_without_new_state():
	var road: ChapterDef = load("res://data/chapters/prologue.tres")
	var fire: SpriteFrames = load("res://data/vfx/road_cottage_fire.tres")
	var smoke: SpriteFrames = load("res://data/vfx/road_cottage_smoke.tres")
	var fire_sites: int = 0
	var smoke_sites: int = 0
	for prop: MapDecor in road.decor:
		if prop.effect_frames == fire:
			fire_sites += 1
		if prop.effect_frames == smoke:
			smoke_sites += 1
	assert_eq(fire_sites, 2)
	assert_eq(smoke_sites, 1)
	assert_eq(smoke.get_frame_count("default"), 12)
	assert_eq(smoke.get_animation_speed("default"), 10.0)
	for i in range(12):
		var frame: AtlasTexture = smoke.get_frame_texture("default", i)
		assert_eq(frame.region, Rect2((i % 4) * 7, (i / 4) * 20, 7, 20), "effect-only native pack crop")
	var before := Campaign.to_dict()
	var board := road.terrain.duplicate()
	var tiles := TerrainTiles.new()
	add_child_autofree(tiles)
	tiles.setup(road.make_grid(), road)
	for i in range(20):
		tiles._process(0.13)
	assert_eq(Campaign.to_dict(), before)
	assert_eq(road.terrain, board)

func test_action_tableau_uses_existing_insets_without_leaking_to_aftermath():
	var scene := DialogueScene.new()
	add_child_autofree(scene)
	scene.typewriter_speed = 0.0
	scene.play(DialogueScript.from_file("res://data/dialogue/road_bandit_intro.json"))
	assert_eq(scene._portrait_layout, "standard")
	for i in range(5):
		scene.advance()
	while not scene.is_finished():
		assert_eq(scene._portrait_layout, "inset", "Kai, child and surroundings remain visible")
		scene.advance()
	scene.play(DialogueScript.from_file("res://data/dialogue/road_bandit_outro.json"))
	assert_eq(scene._portrait_layout, "standard", "next scene resets normally; bread owns its inset beat")
