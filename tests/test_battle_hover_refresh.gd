extends GutTest
## GH-72 / WO-4.4 + WO-9.5 battle readability: the hover box and the header
## readout must re-read the hovered cell when an action or phase boundary changes
## HP/occupancy there. The cursor does not move for these changes, so the
## ordinary cell_changed refresh never fires unless the view refreshes itself.

var _viewport: SubViewport
var _view: BattleView
var _hover_draws := 0


func before_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	# Keep terrain mutations (the SPRING phase-heal fixture) out of the shared .tres.
	_view.chapter = _view.chapter.duplicate(true)
	_view.strike_delay = 0.0
	_view.combat_seed = 12345
	_viewport.add_child(_view)
	await wait_physics_frames(2)
	_hover_draws = 0
	_view._hover_info.draw.connect(_count_hover_draw)


func after_each() -> void:
	BattleView.next_resume = {}
	BattleView.next_prep = false
	Campaign.reset_new_game(false)


func _count_hover_draw() -> void:
	_hover_draws += 1


func _key(code: Key, pressed := true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	_viewport.push_input(event, true)


func _wait_until_idle(max_frames := 240) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func _make_sure_hit(u: Unit) -> void:
	var w := WeaponDef.new()
	var cur := u.weapon()
	w.weapon_type = cur.weapon_type
	w.might = cur.might
	w.hit = 999
	w.weight = cur.weight
	w.min_range = cur.min_range
	w.max_range = cur.max_range
	u.equip_weapon(w)


func _move_and_pick(select: Vector2i, dest: Vector2i, action_id: String, mover: Unit) -> void:
	_view._on_cursor_confirmed(select)
	_view._handle_selected_confirm(dest)
	await _wait_until_idle()
	var guard := 0
	while mover.is_moving() and guard < 240:
		await wait_physics_frames(1)
		guard += 1
	assert_eq(_view._phase, _view.Phase.MENU, "command menu opens after moving")
	var idx: int = _view._menu_actions.find(action_id)
	assert_true(idx >= 0, "menu offers '%s'" % action_id)
	await _view._on_menu_chosen(idx)
	if _view._menu_context in ["attack_weapon", "magic_spell"]:
		await _view._on_menu_chosen(0)


func _header_has(text: String) -> bool:
	return _view._debug_label.text.contains(text)


func test_stationary_cursor_heal_refreshes_hover_box_and_header() -> void:
	var wren: Unit = _view.unit_at(Vector2i(3, 9))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	assert_not_null(wren, "Wren present")
	assert_not_null(brenna, "Brenna present (heal target)")
	brenna.current_hp = 5
	await _move_and_pick(wren.cell, wren.cell, "heal", wren)
	assert_eq(_view._cursor.cell, brenna.cell, "targeting parked the cursor on the ally")
	var hp_before_confirm := brenna.current_hp
	assert_true(_header_has("%d/%d" % [hp_before_confirm, brenna.max_hp()]),
		"header starts on the pre-heal HP at the stationary cursor")
	await wait_physics_frames(2)
	_hover_draws = 0

	await _view._handle_targeting_confirm(brenna.cell)
	await _wait_until_idle()
	await wait_physics_frames(2)

	assert_eq(_view._cursor.cell, brenna.cell, "the heal left the cursor in place")
	assert_gt(brenna.current_hp, hp_before_confirm, "the heal actually restored HP")
	assert_eq(_view._hover_unit, brenna, "hover still points at the healed ally")
	assert_true(_view._hover_info.visible, "hover box remains shown")
	assert_gt(_hover_draws, 0, "the hover box repainted without a cursor-cell change")
	assert_true(_header_has("%d/%d" % [brenna.current_hp, brenna.max_hp()]),
		"header shows the healed HP at the stationary cursor")
	assert_false(_header_has("%d/%d" % [hp_before_confirm, brenna.max_hp()]),
		"header no longer shows the stale pre-heal HP")
	assert_true(wren.has_acted, "the healer's action is still spent normally")


func test_stationary_cursor_nonlethal_attack_refreshes_hp() -> void:
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	assert_not_null(kael, "Kael present")
	assert_not_null(enemy, "enemy present")
	_make_sure_hit(kael)
	var enemy_hp_before := enemy.current_hp

	await _move_and_pick(kael.cell, Vector2i(5, 7), "attack", kael)
	assert_eq(_view._cursor.cell, enemy.cell, "targeting parked the cursor on the enemy")
	assert_true(_header_has("%d/%d" % [enemy_hp_before, enemy.max_hp()]),
		"header starts on the pre-attack HP at the stationary cursor")
	await wait_physics_frames(2)
	_hover_draws = 0

	await _view._handle_targeting_confirm(enemy.cell)
	await _wait_until_idle()
	await wait_physics_frames(2)

	assert_eq(_view._cursor.cell, enemy.cell, "the attack left the cursor in place")
	assert_true(enemy.is_alive(), "the enemy survives this exchange")
	assert_lt(enemy.current_hp, enemy_hp_before, "the attack actually dealt damage")
	assert_eq(_view._hover_unit, enemy, "hover still points at the damaged enemy")
	assert_gt(_hover_draws, 0, "the hover box repainted without a cursor-cell change")
	assert_true(_header_has("%d/%d" % [enemy.current_hp, enemy.max_hp()]),
		"header shows the post-attack HP at the stationary cursor")
	assert_false(_header_has("%d/%d" % [enemy_hp_before, enemy.max_hp()]),
		"header no longer shows the stale pre-attack HP")


func test_stationary_cursor_lethal_attack_clears_departed_occupant() -> void:
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	assert_not_null(kael, "Kael present")
	assert_not_null(enemy, "enemy present")
	_make_sure_hit(kael)
	enemy.current_hp = 1
	var old_label := enemy.unit_def.display_name

	await _move_and_pick(kael.cell, Vector2i(5, 7), "attack", kael)
	assert_eq(_view._cursor.cell, enemy.cell, "targeting parked the cursor on the enemy")
	await _view._handle_targeting_confirm(enemy.cell)
	await _wait_until_idle()
	await wait_physics_frames(2)

	assert_eq(_view._cursor.cell, Vector2i(6, 7), "the kill left the cursor on the vacated cell")
	assert_null(_view.unit_at(Vector2i(6, 7)), "the defeated enemy left the board")
	assert_null(_view._hover_unit, "hover no longer points at a freed/queued unit")
	assert_false(_view._hover_info.visible, "the departed occupant's hover box is cleared")
	assert_false(_header_has("<%s " % old_label), "header no longer names the departed enemy")
	_view._draw_hover_info()  # must be a safe no-op after the refresh


func test_phase_start_terrain_heal_at_stationary_cursor_refreshes() -> void:
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	assert_not_null(brenna, "Brenna present")
	_view.chapter.set_terrain(brenna.cell.x, brenna.cell.y, Terrain.Type.SPRING)
	brenna.current_hp = 5
	_view._cursor.move_to(brenna.cell)
	await wait_physics_frames(2)
	assert_true(_header_has("5/%d" % brenna.max_hp()), "header starts on the damaged HP")
	_hover_draws = 0

	_view._begin_player_phase()
	await wait_physics_frames(2)

	assert_eq(_view._cursor.cell, brenna.cell, "the phase start did not move the cursor")
	assert_gt(brenna.current_hp, 5, "terrain healing restored HP at phase start")
	assert_true(_header_has("%d/%d" % [brenna.current_hp, brenna.max_hp()]),
		"header shows the phase-healed HP at the stationary cursor")
	assert_false(_header_has("5/%d" % brenna.max_hp()), "header dropped the stale damaged HP")
	assert_gt(_hover_draws, 0, "the hover box repainted at the phase boundary")


func test_refresh_does_not_move_spend_or_change_state() -> void:
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	assert_not_null(brenna, "Brenna present")
	_view._cursor.move_to(brenna.cell)
	await wait_physics_frames(2)
	var snapshot := _view.make_save_payload()
	var cursor_cell := _view._cursor.cell
	var selected := _view._selected
	var phase := _view._phase
	var rng_state: int = _view._rng.state_value()

	_view._refresh_cursor_info()

	assert_eq(_view.make_save_payload(), snapshot,
		"campaign/units/HP/XP/RNG/objectives are unchanged by a UI refresh")
	assert_eq(_view._cursor.cell, cursor_cell, "cursor cell is unchanged")
	assert_eq(_view._cursor.selected_cell, BattleCursor.INVALID, "no cell is selected")
	assert_eq(_view._selected, selected, "no unit becomes selected")
	assert_eq(_view._phase, phase, "phase is unchanged")
	assert_eq(_view._rng.state_value(), rng_state, "RNG state is unchanged")
	assert_false(_view._busy, "refresh does not enter a busy action state")


func test_real_keyboard_input_continues_normally_after_a_heal() -> void:
	var wren: Unit = _view.unit_at(Vector2i(3, 9))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	assert_not_null(wren, "Wren present")
	assert_not_null(brenna, "Brenna present (heal target)")
	brenna.current_hp = 5
	await _move_and_pick(wren.cell, wren.cell, "heal", wren)
	await _view._handle_targeting_confirm(brenna.cell)
	await _wait_until_idle()
	await wait_physics_frames(2)
	var healed_hp := brenna.current_hp
	var parked := _view._cursor.cell
	var snapshot := _view.make_save_payload()
	assert_eq(_view._phase, _view.Phase.IDLE, "ordinary control returned")

	_key(KEY_PAGEDOWN)
	await wait_physics_frames(2)

	assert_ne(_view._cursor.cell, parked, "real keyboard input still moves the cursor")
	assert_true(_viewport.is_input_handled(), "the continuation input was consumed normally")
	assert_eq(_view.make_save_payload(), snapshot, "continuing spends no action or resource")
	assert_eq(brenna.current_hp, healed_hp, "the healed HP is retained")
	assert_eq(_view._phase, _view.Phase.IDLE, "field control remains idle")


func test_unit_at_ignores_a_queued_for_deletion_occupant() -> void:
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	assert_not_null(enemy, "enemy present")
	enemy.queue_free()
	assert_true(is_instance_valid(enemy), "the queued unit is still a valid object")
	assert_true(enemy.is_queued_for_deletion(), "the unit is queued for deletion")
	assert_null(_view.unit_at(enemy.cell), "a queued-for-deletion unit is not a live occupant")
