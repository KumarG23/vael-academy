extends GutTest
## Regression (playtest 2): the battle camera was pinned to the map's NW
## corner because it followed the cursor NODE's position — and the cursor
## node never moves; it draws at its cell. The camera must follow the cell,
## and the battle must open framed on the player's team.


func before_each():
	Campaign.reset_new_game(false)
	Campaign.set_house("emberwing")


func _make_view():
	var ps: PackedScene = load("res://scenes/battle/mock_battle.tscn")
	var view = ps.instantiate()
	add_child_autofree(view)
	await wait_frames(10)
	return view


func test_battle_opens_on_the_player_team():
	var view = await _make_view()
	var cur = view.get("_cursor")
	var on_player := false
	for u in view.get("_units"):
		if u.team == 0 and u.cell == cur.cell:
			on_player = true
	assert_true(on_player, "cursor starts on a player unit, not the map center")


func test_camera_follows_the_cursor_cell():
	var view = await _make_view()
	var cur = view.get("_cursor")
	var cam: Camera2D = view.get("_camera")
	var cs := float(view.get("_grid").cell_size)
	cur.move_to(Vector2i(19, 10))
	for i in 60:
		view._process(0.05)
	var target: Vector2 = view._camera_clamp(Vector2(cur.cell) * cs + Vector2(cs, cs) * 0.5)
	assert_lt(cam.position.distance_to(target), cs, "camera converges on the cursor's cell")
