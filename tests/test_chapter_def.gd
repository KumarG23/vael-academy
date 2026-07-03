extends GutTest
## WO-0.2: ChapterDef terrain indexing + the authored test map.

const TEST_MAP := "res://data/chapters/test_map.tres"


func test_fill_sets_every_cell():
	var c := ChapterDef.new()
	c.width = 4
	c.height = 3
	c.fill(Terrain.Type.FOREST)
	assert_eq(c.terrain.size(), 12)
	for y in range(c.height):
		for x in range(c.width):
			assert_eq(c.get_terrain(x, y), Terrain.Type.FOREST)


func test_set_and_get_are_row_major():
	var c := ChapterDef.new()
	c.width = 4
	c.height = 3
	c.fill(Terrain.Type.PLAINS)
	c.set_terrain(2, 1, Terrain.Type.FORT)
	assert_eq(c.get_terrain(2, 1), Terrain.Type.FORT)
	# Flat index of (2,1) in a width-4 grid is 1*4 + 2 = 6.
	assert_eq(c.terrain[6], int(Terrain.Type.FORT))
	assert_eq(c.get_terrain(0, 0), Terrain.Type.PLAINS)


func test_in_bounds():
	var c := ChapterDef.new()
	c.width = 20
	c.height = 15
	assert_true(c.in_bounds(0, 0))
	assert_true(c.in_bounds(19, 14))
	assert_false(c.in_bounds(20, 0))
	assert_false(c.in_bounds(0, 15))
	assert_false(c.in_bounds(-1, 0))


func test_make_grid_matches_dimensions():
	var c := ChapterDef.new()
	c.width = 20
	c.height = 15
	var g := c.make_grid()
	assert_eq(g.width, 20)
	assert_eq(g.height, 15)
	assert_eq(g.cell_size, 128)


func test_authored_test_map_loads_and_is_20x15():
	var c: ChapterDef = load(TEST_MAP)
	assert_not_null(c, "test_map.tres should load")
	assert_eq(c.width, 20)
	assert_eq(c.height, 15)
	assert_eq(c.terrain.size(), 300)


func test_authored_test_map_uses_every_terrain_type():
	var c: ChapterDef = load(TEST_MAP)
	var seen := {}
	for v in c.terrain:
		seen[v] = true
	for t in [
		Terrain.Type.PLAINS, Terrain.Type.FOREST, Terrain.Type.MOUNTAIN,
		Terrain.Type.FORT, Terrain.Type.WALL, Terrain.Type.WATER,
	]:
		assert_true(seen.has(int(t)), "test map should contain terrain type %d" % t)
