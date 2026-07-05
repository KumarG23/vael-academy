extends GutTest
## AW-2a: Wang-tile terrain rendering — signature math + asset wiring.

const WANG_JSON := "res://assets/art/pixellab/tilesets/wang_maps.json"


func _chapter_3x3(center: int) -> ChapterDef:
	# 3x3 plains with one `center` terrain cell in the middle
	var c := ChapterDef.new()
	c.width = 3
	c.height = 3
	var t := PackedInt32Array()
	for i in range(9):
		t.append(Terrain.Type.PLAINS)
	t[4] = center
	c.terrain = t
	return c


func test_wang_maps_load_all_sets_complete() -> void:
	var maps := TerrainTiles.load_wang_maps(WANG_JSON)
	assert_gte(maps.size(), 6, "at least the six field sets (indoor sets grow this)")
	for set_name in maps:
		assert_eq((maps[set_name] as Dictionary).size(), 16,
			"%s has all 16 wang signatures" % set_name)
		for sig in range(16):
			assert_true(maps[set_name].has(sig), "%s sig %d" % [set_name, sig])


func test_junction_signatures_around_single_water_cell() -> void:
	var ch := _chapter_3x3(Terrain.Type.WATER)
	# junction (1,1): its SE logical cell is (1,1) = the water center -> bit 8
	assert_eq(TerrainTiles.junction_signature(ch, 1, 1, Terrain.Type.WATER), 8)
	# junction (2,1): SW cell is (1,1) -> bit 4
	assert_eq(TerrainTiles.junction_signature(ch, 2, 1, Terrain.Type.WATER), 4)
	# junction (1,2): NE cell is (1,1) -> bit 2
	assert_eq(TerrainTiles.junction_signature(ch, 1, 2, Terrain.Type.WATER), 2)
	# junction (2,2): NW cell is (1,1) -> bit 1
	assert_eq(TerrainTiles.junction_signature(ch, 2, 2, Terrain.Type.WATER), 1)
	# far corner junction sees nothing
	assert_eq(TerrainTiles.junction_signature(ch, 0, 0, Terrain.Type.WATER), 0)


func test_junction_signature_out_of_bounds_is_not_overlay() -> void:
	var ch := _chapter_3x3(Terrain.Type.FOREST)
	# corner junction (0,0): only its SE cell (0,0) is in bounds (plains)
	assert_eq(TerrainTiles.junction_signature(ch, 0, 0, Terrain.Type.FOREST), 0)


func test_full_overlay_grid_gives_full_signature_interior() -> void:
	var c := ChapterDef.new()
	c.width = 2
	c.height = 2
	var t := PackedInt32Array()
	for i in range(4):
		t.append(Terrain.Type.MOUNTAIN)
	c.terrain = t
	# interior junction (1,1) touches all four mountain cells -> 15
	assert_eq(TerrainTiles.junction_signature(c, 1, 1, Terrain.Type.MOUNTAIN), 15)


func test_renderer_activates_when_assets_exist() -> void:
	var tiles := TerrainTiles.new()
	add_child_autofree(tiles)
	var ch := _chapter_3x3(Terrain.Type.WATER)
	tiles.setup(ch.make_grid(), ch)
	assert_true(tiles.is_active(), "atlases + wang maps are committed, so active")
