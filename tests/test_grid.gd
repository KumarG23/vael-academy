extends GutTest
## WO-0.2: Grid cell<->world math.


func test_defaults_to_128px_cells():
	var g := Grid.new(20, 15)
	assert_eq(g.cell_size, 128)


func test_cell_to_world_is_top_left_corner():
	var g := Grid.new(20, 15)
	assert_eq(g.cell_to_world(Vector2i(0, 0)), Vector2(0, 0))
	assert_eq(g.cell_to_world(Vector2i(3, 2)), Vector2(384, 256))


func test_cell_center():
	var g := Grid.new(20, 15)
	assert_eq(g.cell_center(Vector2i(0, 0)), Vector2(64, 64))
	assert_eq(g.cell_center(Vector2i(1, 1)), Vector2(192, 192))


func test_world_to_cell_floors_within_a_cell():
	var g := Grid.new(20, 15)
	assert_eq(g.world_to_cell(Vector2(0, 0)), Vector2i(0, 0))
	assert_eq(g.world_to_cell(Vector2(127, 127)), Vector2i(0, 0))
	assert_eq(g.world_to_cell(Vector2(128, 0)), Vector2i(1, 0))
	assert_eq(g.world_to_cell(Vector2(400, 260)), Vector2i(3, 2))


func test_world_to_cell_handles_negative_positions():
	var g := Grid.new(20, 15)
	assert_eq(g.world_to_cell(Vector2(-1, -1)), Vector2i(-1, -1))


func test_round_trip_cell_center_back_to_cell():
	var g := Grid.new(20, 15)
	for cell in [Vector2i(0, 0), Vector2i(7, 4), Vector2i(19, 14)]:
		assert_eq(g.world_to_cell(g.cell_center(cell)), cell)


func test_in_bounds():
	var g := Grid.new(20, 15)
	assert_true(g.in_bounds(Vector2i(0, 0)))
	assert_true(g.in_bounds(Vector2i(19, 14)))
	assert_false(g.in_bounds(Vector2i(20, 14)))
	assert_false(g.in_bounds(Vector2i(0, 15)))
	assert_false(g.in_bounds(Vector2i(-1, 0)))


func test_pixel_size():
	var g := Grid.new(20, 15)
	assert_eq(g.pixel_size(), Vector2(2560, 1920))


func test_custom_cell_size():
	var g := Grid.new(4, 4, 64)
	assert_eq(g.cell_to_world(Vector2i(2, 1)), Vector2(128, 64))
	assert_eq(g.world_to_cell(Vector2(130, 10)), Vector2i(2, 0))
