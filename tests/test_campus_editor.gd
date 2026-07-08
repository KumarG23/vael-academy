extends GutTest
## AW-44: the in-game visual room editor — toggle, brush resolution, and the
## place/delete/nudge ops on the live room decor. (Place+delete are paired so the
## shared campus resource is left as it was found.)

var _castle: CastleScene
var _ed: CampusEditor


func before_each() -> void:
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(_castle)
	_ed = _castle._editor


func test_editor_exists_and_toggles():
	assert_not_null(_ed, "the castle wires up a CampusEditor")
	assert_false(_ed.active)
	_ed.toggle()
	assert_true(_ed.active, "backtick-equivalent toggle turns it on")
	assert_true(_castle.busy(), "editing gates walking")
	_ed.toggle()
	assert_false(_ed.active)


func test_every_brush_resolves_to_a_real_asset():
	for i in range(_ed._palette().size()):
		_ed._brush = i
		var path := _ed._brush_path()
		assert_true(ResourceLoader.exists(path), "brush %d -> %s exists" % [i, path])


func test_place_then_delete_a_prop():
	_ed.toggle()
	_ed._mode = "prop"
	_ed._brush = 0  # tree_big
	var decor: Array = _castle.room.chapter.decor
	var before := decor.size()
	_ed._place_brush(Vector2i(6, 6))
	assert_eq(decor.size(), before + 1, "a prop appears")
	assert_eq(_ed._selected.cell, Vector2i(6, 6), "and is picked up for dragging")
	_ed._nudge(Vector2i(1, 0))
	assert_eq(_ed._selected.cell, Vector2i(7, 6), "arrows nudge it a cell")
	_ed._delete_at(Vector2i(7, 6))
	assert_eq(decor.size(), before, "delete removes it, leaving the room as it was")


func test_terrain_paint_changes_a_cell():
	_ed.toggle()
	_ed._mode = "terrain"
	var c := Vector2i(9, 9)
	var was: int = _castle.room.chapter.get_terrain(c.x, c.y)
	# find the "Blocker" (SITE) brush
	for i in range(_ed.TERRAINS.size()):
		if _ed.TERRAINS[i][1] == Terrain.Type.SITE:
			_ed._terrain = i
	_castle.room.chapter.set_terrain(c.x, c.y, _ed.TERRAINS[_ed._terrain][1])
	assert_eq(_castle.room.chapter.get_terrain(c.x, c.y), Terrain.Type.SITE, "painted a blocker")
	_castle.room.chapter.set_terrain(c.x, c.y, was)  # restore the shared resource
