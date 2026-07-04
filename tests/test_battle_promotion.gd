extends GutTest
## WO-2.4: Kael promotes mid-battle via the Master Seal and gains class bonuses.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 7
	add_child_autofree(_view)
	await wait_physics_frames(2)


func _wait_idle(max_frames := 300) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func test_seal_hidden_until_level_10():
	var kael: Unit = _view.unit_by_id("kael")
	assert_eq(kael.level, 1)
	# Select and open the command menu in place.
	_view._on_cursor_confirmed(Vector2i(3, 7))
	_view._handle_selected_confirm(Vector2i(3, 7))
	await _wait_idle()
	# At level 1 the seal isn't usable, so "item" isn't offered (Kael is at full HP too).
	assert_false(_view._menu_actions.has("item"), "no usable items at level 1, full HP")


func test_kael_promotes_and_gains_class_bonuses():
	var kael: Unit = _view.unit_by_id("kael")
	assert_eq(kael.current_class().id, "myrmidon")
	kael.level = 10                       # eligible to promote
	assert_true(kael.can_promote())
	var str_before := kael.stat("str")
	var mov_before := kael.move_points()

	# Select Kael, stay put, open the command menu, choose Item.
	_view._on_cursor_confirmed(Vector2i(3, 7))
	_view._handle_selected_confirm(Vector2i(3, 7))
	await _wait_idle()
	var item_idx: int = _view._menu_actions.find("item")
	assert_true(item_idx >= 0, "Item is offered (Master Seal usable at level 10)")
	await _view._on_menu_chosen(item_idx)
	assert_eq(_view._menu_context, "item")
	# The only usable item is the Master Seal.
	await _view._on_menu_chosen(0)
	await _wait_idle()

	assert_eq(kael.current_class().id, "swordmaster", "Kael promoted")
	assert_eq(kael.level, 1, "level reset after promotion")
	assert_eq(kael.stat("str"), str_before + 2, "gained the STR class bonus")
	assert_eq(kael.move_points(), mov_before + 1, "gained the movement bonus")
	# The seal was consumed.
	var still_has_seal := false
	for it in kael.inventory.consumables():
		if it.item().is_promotion():
			still_has_seal = true
	assert_false(still_has_seal, "Master Seal consumed")
