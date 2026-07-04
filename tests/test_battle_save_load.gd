extends GutTest
## WO-3.3: battle snapshot/restore and permadeath save flags.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 13579
	add_child_autofree(_view)
	await wait_physics_frames(2)


func _fresh_view() -> Node2D:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	var view: Node2D = scene.instantiate()
	view.strike_delay = 0.0
	add_child_autofree(view)
	await wait_physics_frames(2)
	return view


func test_save_mid_battle_and_load_into_fresh_scene():
	var saves := SaveSystem.new("user://test_battle_saves_%d" % Time.get_ticks_usec())
	_view._save_system = saves
	_view.casual_mode = true
	_view._turn.round_number = 3
	_view._turn.active_team = TurnManager.Team.PLAYER
	_view._support_state.add_points("kai", "kael", 20)
	_view._rng.roll()  # prove RNG state, not only seed, is saved

	var kael: Unit = _view.unit_by_id("kael")
	kael.current_hp = 9
	kael.level = 4
	kael.xp = 37
	kael.has_acted = true
	kael.cell = Vector2i(5, 7)
	kael.position = _view._grid.cell_center(kael.cell)
	kael.inventory.items[0].uses = 12

	assert_true(_view.save_to_slot(0), "battle saved")

	var loaded: Node2D = await _fresh_view()
	loaded._save_system = saves
	assert_true(loaded.load_from_slot(0), "battle loaded")

	var loaded_kael: Unit = loaded.unit_by_id("kael")
	assert_not_null(loaded_kael)
	assert_eq(loaded_kael.cell, Vector2i(5, 7))
	assert_eq(loaded_kael.current_hp, 9)
	assert_eq(loaded_kael.level, 4)
	assert_eq(loaded_kael.xp, 37)
	assert_true(loaded_kael.has_acted)
	assert_eq(loaded_kael.inventory.items[0].uses, 12)
	assert_eq(loaded._turn.round_number, 3)
	assert_eq(loaded._support_state.rank_for_units("kai", "kael"), "C")
	assert_eq(loaded._rng.state_value(), _view._rng.state_value(), "RNG state round-trips")


func test_classic_permadeath_flags_dead_player_and_load_removes_them():
	_view.casual_mode = false
	var kai: Unit = _view.unit_by_id("kai")
	assert_not_null(kai)

	_view._kill(kai)
	var payload: Dictionary = _view.make_save_payload()
	assert_true(payload["battle"]["defeated_unit_ids"].has("kai"))
	assert_true(payload["battle"]["permadead_unit_ids"].has("kai"))

	var loaded: Node2D = await _fresh_view()
	loaded.apply_save_payload(payload)
	assert_null(loaded.unit_by_id("kai"), "dead classic unit is absent after load")
	assert_true(loaded._permadead_unit_ids.has("kai"), "permadeath flag survives load")
