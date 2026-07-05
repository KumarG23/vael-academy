extends GutTest
## Maps v3: FE-style village visits — a unit on a visit cell gets a "Visit"
## action; visiting plays the NPC dialogue, grants the reward, spends the
## action, and never repeats within the battle.

var _view: Node2D


func before_each() -> void:
	_view = (load("res://scenes/battle/prologue.tscn") as PackedScene).instantiate()
	_view.strike_delay = 0.0
	_view.dialogue_enabled = false
	add_child_autofree(_view)


func _kai() -> Unit:
	for u in _view._units:
		if u.unit_id() == "kai":
			return u
	return null


func _open_menu_on(unit: Unit, cell: Vector2i) -> void:
	unit.cell = cell
	unit.position = _view._grid.cell_to_world(cell)
	_view._selected = unit
	_view._menu_ctrl.open_action_menu()


func test_prologue_authored_visits():
	var c: ChapterDef = _view.chapter
	assert_eq(c.visits.size(), 2, "two hamlet visits")
	for spot in c.visits:
		assert_true(FileAccess.file_exists(spot.dialogue), "%s dialogue exists" % spot.id)


func test_visit_offered_on_the_door_cell():
	_open_menu_on(_kai(), Vector2i(2, 8))
	assert_true(_view._menu_actions.has("visit"), "Visit appears on the cottage door")


func test_visit_not_offered_elsewhere():
	_open_menu_on(_kai(), Vector2i(6, 5))
	assert_false(_view._menu_actions.has("visit"))


func test_visiting_grants_item_and_spends_action():
	var kai := _kai()
	var before := kai.inventory.size()
	_open_menu_on(kai, Vector2i(2, 8))
	await _view._menu_ctrl.do_visit()
	assert_eq(kai.inventory.size(), before + 1, "the villager's vulnerary was handed over")
	assert_true(kai.has_acted, "visiting spends the unit's action")
	assert_true(_view._visited_spot_ids.has("hamlet_cottage"))


func test_visit_is_once_per_battle():
	var kai := _kai()
	_open_menu_on(kai, Vector2i(2, 8))
	await _view._menu_ctrl.do_visit()
	kai.has_acted = false
	_open_menu_on(kai, Vector2i(2, 8))
	assert_false(_view._menu_actions.has("visit"), "the cottage is spent for this battle")
