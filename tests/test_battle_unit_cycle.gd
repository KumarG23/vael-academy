extends GutTest
## GH-63 / WO-9.5: production battle + cursor, dispatched via a live viewport.

var _viewport: SubViewport
var _view: BattleView


func before_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_make_view("emberwing")
	await wait_physics_frames(2)


func after_each() -> void:
	BattleView.next_resume = {}
	BattleView.next_prep = false
	Campaign.reset_new_game(false)


func _make_view(house: String) -> void:
	Campaign.reset_new_game(false)
	Campaign.set_house(house)
	Campaign.deploy()
	_view = load(ChapterRegistry.scene_for("mock_battle", house)).instantiate()
	_view.dialogue_enabled = false
	_view.strike_delay = 0.0
	_view.combat_seed = 12345
	_viewport.add_child(_view)


func _key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	_viewport.push_input(event, true)


func _players() -> Array[Unit]:
	var out := _view._living_units_on_team(0)
	out.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.cell.y * _view._grid.width + a.cell.x < b.cell.y * _view._grid.width + b.cell.x)
	return out


func _assert_field_unchanged(snapshot: Dictionary, selected_cell := BattleCursor.INVALID) -> void:
	assert_eq(_view.make_save_payload(), snapshot, "campaign, units, HP/XP/uses/supports, objectives/turn and RNG unchanged")
	assert_null(_view._selected)
	assert_eq(_view._cursor.selected_cell, selected_cell)
	assert_eq(_view._phase, BattleView.Phase.IDLE)
	assert_false(_view._menu.visible)
	assert_false(_view._forecast_panel.visible)
	assert_eq(_view._range_overlay._move_tiles.size(), 0)


func test_both_directions_wrap_and_hover_without_acting() -> void:
	var players := _players()
	# Reverse spawn storage: cycle order comes from the board, not roster order.
	_view._units.reverse()
	_view._cursor.move_to(players[0].cell)
	var snapshot := _view.make_save_payload()
	for i in range(1, players.size() + 1):
		_key(KEY_PAGEDOWN)
		assert_eq(_view._cursor.cell, players[i % players.size()].cell)
		assert_eq(_view._hover_unit, players[i % players.size()])
		assert_true(_view._hover_info.visible)
		assert_true(_viewport.is_input_handled())
		_assert_field_unchanged(snapshot)
	for i in range(players.size() - 1, -1, -1):
		_key(KEY_PAGEUP)
		assert_eq(_view._cursor.cell, players[i].cell)
		_assert_field_unchanged(snapshot)


func test_off_unit_strict_board_successor_predecessor_and_wrap() -> void:
	var players := _players()
	var positions := [Vector2i.ZERO, Vector2i(_view._grid.width - 1, _view._grid.height - 1)]
	# Include empty cells between units, and same-row cells on both sides.
	for y in _view._grid.height:
		for x in _view._grid.width:
			var cell := Vector2i(x, y)
			if _view.unit_at(cell) == null:
				positions.append(cell)
	for origin in positions:
		var index: int = origin.y * _view._grid.width + origin.x
		var next: Unit = players[0]
		var previous: Unit = players[-1]
		for unit in players:
			if unit.cell.y * _view._grid.width + unit.cell.x > index:
				next = unit
				break
		for i in range(players.size() - 1, -1, -1):
			if players[i].cell.y * _view._grid.width + players[i].cell.x < index:
				previous = players[i]
				break
		_view._cursor.move_to(origin)
		_key(KEY_PAGEDOWN)
		assert_eq(_view._cursor.cell, next.cell, "strict next from %s" % origin)
		_view._cursor.move_to(origin)
		_key(KEY_PAGEUP)
		assert_eq(_view._cursor.cell, previous.cell, "strict previous from %s" % origin)


func test_acted_dead_queued_freed_and_both_rivals_filtered_one_and_none() -> void:
	var players := _players()
	for unit in players:
		unit.has_acted = true
	var only: Unit = players[0]
	only.has_acted = false
	players[1].has_acted = false
	players[1].current_hp = 0
	# Match production yield removal: erase from the force before freeing.
	var freed: Unit = players[2]
	_view._units.erase(freed)
	freed.free()
	var queued: Unit = players[3]
	queued.has_acted = false
	queued.queue_free()
	assert_eq(_view._nonplayer_teams(), [1, 2])
	for code in [KEY_PAGEDOWN, KEY_PAGEUP]:
		_view._cursor.move_to(Vector2i.ZERO)
		_key(code)
		assert_eq(_view._cursor.cell, only.cell)
		_key(code)
		assert_eq(_view._cursor.cell, only.cell, "one candidate stays put")
	only.has_acted = true
	var original := _view._cursor.cell
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	assert_eq(_view._cursor.cell, original, "no candidates safely stays put")
	# Remove queued reference before normal frame processing, as production does.
	_view._units.erase(queued)


func test_release_echo_and_repeated_press_release_pairs() -> void:
	var players := _players()
	_view._cursor.move_to(players[0].cell)
	for code in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_key(code, false)
		_key(code, true, true)
		assert_eq(_view._cursor.cell, players[0].cell)
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEDOWN, true, true)
	_key(KEY_PAGEDOWN, false)
	assert_eq(_view._cursor.cell, players[1].cell, "one step per physical press")
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEDOWN, false)
	assert_eq(_view._cursor.cell, players[2].cell)


func test_all_field_control_gates() -> void:
	var original := _view._cursor.cell
	var snapshot := _view.make_save_payload()
	for phase in [BattleView.Phase.PREP, BattleView.Phase.SELECTED, BattleView.Phase.MENU, BattleView.Phase.TARGETING]:
		_view._phase = phase
		_key(KEY_PAGEDOWN)
		_key(KEY_PAGEUP)
		assert_eq(_view._cursor.cell, original)
		assert_eq(_view._phase, phase)
	_view._phase = BattleView.Phase.IDLE
	for flag in ["_busy", "_battle_over", "_dialogue_playing", "_prep_active", "_combat_cam_active"]:
		_view.set(flag, true)
		_key(KEY_PAGEDOWN)
		_key(KEY_PAGEUP)
		assert_eq(_view._cursor.cell, original, flag)
		_view.set(flag, false)
	_view._turn.active_team = TurnManager.Team.ENEMY
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	assert_eq(_view._cursor.cell, original)
	_view._turn.active_team = TurnManager.Team.PLAYER
	_view._cursor.active = false
	_key(KEY_PAGEDOWN)
	assert_eq(_view._cursor.cell, original)
	_view._cursor.active = true
	BattleView.next_resume = {"transition": true}
	_key(KEY_PAGEUP)
	assert_eq(_view._cursor.cell, original)
	BattleView.next_resume = {}
	_assert_field_unchanged(snapshot)


func test_real_selection_action_field_end_turn_and_save_menus_do_not_cycle() -> void:
	_key(KEY_ENTER)
	assert_eq(_view._phase, BattleView.Phase.SELECTED)
	var selected := _view._selected
	var original := _view._cursor.cell
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	assert_eq(_view._cursor.cell, original)
	assert_eq(_view._selected, selected)
	_key(KEY_ENTER)  # own tile -> action menu
	assert_eq(_view._phase, BattleView.Phase.MENU)
	var menu_index := _view._menu._index
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	assert_eq(_view._menu._index, menu_index)
	assert_false(selected.has_acted)
	_key(KEY_ESCAPE)
	_view._deselect()
	for code in [KEY_T, KEY_TAB]:
		_key(code)
		assert_eq(_view._menu_context, "end_turn")
		var snapshot := _view.make_save_payload()
		_key(KEY_PAGEDOWN)
		_key(KEY_PAGEUP)
		assert_eq(_view.make_save_payload(), snapshot)
		assert_eq(_view._menu_context, "end_turn")
		_key(KEY_ESCAPE)
	_view._open_save_menu("field")
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	assert_eq(_view._menu_context, "save_slot")
	assert_eq(_view._cursor.cell, original)


func test_forecast_stats_and_selected_unit_block_cycling() -> void:
	var original := _view._cursor.cell
	_view._forecast_panel.visible = true
	_key(KEY_PAGEDOWN)
	assert_eq(_view._cursor.cell, original)
	_view._forecast_panel.visible = false
	_view._open_stats_for(_players()[0])
	_key(KEY_PAGEDOWN)
	assert_true(_view._stats_panel.is_shown(), "cycling cannot dismiss an overlay")
	assert_eq(_view._cursor.cell, original)
	_view._stats_panel.close()
	_view._selected = _players()[0]
	_key(KEY_PAGEUP)
	assert_eq(_view._cursor.cell, original)


func test_all_house_routes_and_resume_recompute_eligibility() -> void:
	for house in ["emberwing", "tidemark", "thornrook"]:
		_view.free()
		_make_view(house)
		var players := _players()
		players[0].has_acted = true
		players[1].current_hp = 7
		var snapshot := _view.make_save_payload()
		_view.apply_save_payload(snapshot)
		# References were rebuilt; derive expected from the actual saved roster.
		var eligible: Array[Unit] = []
		for unit in _players():
			if not unit.has_acted:
				eligible.append(unit)
		_view._cursor.move_to(Vector2i.ZERO)
		for unit in eligible:
			_key(KEY_PAGEDOWN)
			assert_eq(_view._cursor.cell, unit.cell, house)
			assert_eq(_view._hover_unit.team, 0)
		_key(KEY_PAGEUP)
		assert_eq(_view._cursor.cell, eligible[-2].cell)
		_assert_field_unchanged(snapshot)


func test_pan_zoom_camera_hover_then_pointer_confirm_cancel_continuation() -> void:
	var players := _players()
	_view._camera.position = Vector2(700, 500)
	_view._camera.zoom = Vector2(0.8, 0.8)
	_view._cursor.move_to(players[0].cell)
	_key(KEY_PAGEDOWN)
	var target: Unit = players[1]
	for i in 60:
		_view._process(0.05)
	var focus := _view._camera_clamp(_view._grid.cell_center(target.cell))
	assert_lt(_view._camera.position.distance_to(focus), 1.0)
	assert_eq(_view._hover_unit, target)
	_view._camera.force_update_scroll()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _view._cursor.get_global_transform_with_canvas() * _view._grid.cell_center(target.cell)
	_viewport.push_input(click, true)
	assert_eq(_view._selected, target)
	assert_has(_view._range_overlay._move_tiles, target.cell)
	_key(KEY_ESCAPE)
	assert_false(target.has_acted)
	assert_eq(_view._phase, BattleView.Phase.IDLE)
	_key(KEY_H)
	assert_true(_view._threat_overlay.is_shown())
	_key(KEY_ENTER)
	assert_eq(_view._selected, target)


func test_hint_readable_at_default_and_compact_sizes() -> void:
	for size in [Vector2i(1280, 720), Vector2i(640, 360)]:
		_viewport.size = size
		await wait_process_frames(2)
		var hint := _view._input_hint
		assert_true(hint.visible)
		assert_true(Rect2(Vector2.ZERO, Vector2(size)).encloses(hint.get_rect()))
		assert_false(hint.get_rect().intersects(_view._hover_info.get_rect()))
		assert_true(hint.text.contains("PageDown: Next Unit"))
		assert_true(hint.text.contains("PageUp: Previous Unit"))
		assert_true(hint.text.contains("T/Tab: end turn"))


func test_victory_and_defeat_overlays_cannot_dismiss_or_advance() -> void:
	var original := _view._cursor.cell
	watch_signals(_view._result_screen)
	for victory in [true, false]:
		_view._battle_over = true
		if victory:
			_view._result_screen.show_victory()
		else:
			_view._result_screen.show_defeat()
		var snapshot := _view.make_save_payload()
		_key(KEY_PAGEDOWN)
		_key(KEY_PAGEUP)
		assert_eq(_view.make_save_payload(), snapshot)
		assert_true(_view._result_screen.is_shown())
		assert_eq(_view._cursor.cell, original)
	assert_signal_not_emitted(_view._result_screen, "dismissed")


func test_wait_through_real_menu_then_skip_acted_unit() -> void:
	var players := _players()
	_view._cursor.move_to(players[1].cell)
	_key(KEY_ENTER)
	_key(KEY_ENTER)
	var wait_index: int = _view._menu_actions.find("wait")
	assert_gte(wait_index, 0)
	for i in wait_index:
		_key(KEY_DOWN)
	_key(KEY_ENTER)
	assert_true(players[1].has_acted)
	assert_eq(_view._phase, BattleView.Phase.IDLE)
	var snapshot := _view.make_save_payload()
	_key(KEY_PAGEUP)
	assert_eq(_view._cursor.cell, players[0].cell)
	_key(KEY_PAGEDOWN)
	assert_eq(_view._cursor.cell, players[2].cell)
	_assert_field_unchanged(snapshot, players[1].cell)


func test_dialogue_line_and_choice_input_remain_unchanged() -> void:
	var dialogue := DialogueScene.new()
	dialogue.typewriter_speed = 0.0
	_view._ui_layer.add_child(dialogue)
	_view._dialogue_playing = true
	_view._cursor.active = false
	var script := DialogueScript.from_json('[{"text":"Test line"},{"choice":"Test choice","options":[{"text":"First"},{"text":"Second"}]}]')
	dialogue.play(script)
	var original := _view._cursor.cell
	var snapshot := _view.make_save_payload()
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	assert_eq(dialogue.current_line().text, "Test line")
	_key(KEY_ENTER)
	assert_true(dialogue.awaiting_choice())
	_key(KEY_PAGEDOWN)
	_key(KEY_PAGEUP)
	assert_true(dialogue.awaiting_choice())
	assert_eq(dialogue._choice_index, 0)
	assert_eq(_view._cursor.cell, original)
	assert_eq(_view.make_save_payload(), snapshot)
