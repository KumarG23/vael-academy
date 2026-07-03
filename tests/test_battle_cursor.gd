extends GutTest
## WO-0.3: cursor movement, clamping, selection state, and input mapping.

var _grid: Grid
var _cursor: BattleCursor


func before_each() -> void:
	_grid = Grid.new(20, 15)
	_cursor = BattleCursor.new()
	add_child_autofree(_cursor)
	_cursor.setup(_grid, Vector2i(5, 5))


func test_starts_at_requested_cell():
	assert_eq(_cursor.cell, Vector2i(5, 5))
	assert_false(_cursor.is_selection_active())


func test_try_move_shifts_one_cell():
	_cursor.try_move(Vector2i.RIGHT)
	assert_eq(_cursor.cell, Vector2i(6, 5))
	_cursor.try_move(Vector2i.UP)
	assert_eq(_cursor.cell, Vector2i(6, 4))


func test_clamps_at_left_edge():
	_cursor.setup(_grid, Vector2i(0, 3))
	_cursor.try_move(Vector2i.LEFT)
	assert_eq(_cursor.cell, Vector2i(0, 3))


func test_clamps_at_bottom_right():
	_cursor.setup(_grid, Vector2i(19, 14))
	_cursor.try_move(Vector2i.RIGHT)
	_cursor.try_move(Vector2i.DOWN)
	assert_eq(_cursor.cell, Vector2i(19, 14))


func test_move_to_out_of_bounds_clamps():
	_cursor.move_to(Vector2i(100, -5))
	assert_eq(_cursor.cell, Vector2i(19, 0))


func test_cell_changed_emitted_on_move():
	watch_signals(_cursor)
	_cursor.try_move(Vector2i.RIGHT)
	assert_signal_emitted_with_parameters(_cursor, "cell_changed", [Vector2i(6, 5)])


func test_no_signal_on_noop_move():
	_cursor.setup(_grid, Vector2i(0, 0))
	watch_signals(_cursor)
	_cursor.try_move(Vector2i.LEFT)  # clamped, no change
	assert_signal_not_emitted(_cursor, "cell_changed")


func test_confirm_sets_selection_and_emits():
	watch_signals(_cursor)
	_cursor.confirm()
	assert_true(_cursor.is_selection_active())
	assert_eq(_cursor.selected_cell, Vector2i(5, 5))
	assert_signal_emitted_with_parameters(_cursor, "confirmed", [Vector2i(5, 5)])
	assert_signal_emitted(_cursor, "selection_changed")


func test_cancel_clears_selection_and_emits():
	_cursor.confirm()
	watch_signals(_cursor)
	_cursor.cancel()
	assert_false(_cursor.is_selection_active())
	assert_signal_emitted(_cursor, "cancelled")


func test_selection_follows_cursor_on_reconfirm():
	_cursor.confirm()
	_cursor.try_move(Vector2i.RIGHT)
	_cursor.confirm()
	assert_eq(_cursor.selected_cell, Vector2i(6, 5))


func test_held_key_first_frame_moves_immediately():
	_cursor.step_repeat(Vector2i.RIGHT, 0.016)
	assert_eq(_cursor.cell, Vector2i(6, 5))


func test_held_key_waits_initial_delay_before_repeating():
	_cursor.step_repeat(Vector2i.RIGHT, 0.016)  # immediate move -> (6,5)
	_cursor.step_repeat(Vector2i.RIGHT, 0.016)  # still within initial delay -> no move
	assert_eq(_cursor.cell, Vector2i(6, 5))


func test_held_key_repeats_after_delay_elapses():
	_cursor.step_repeat(Vector2i.RIGHT, 0.016)  # -> (6,5)
	_cursor.step_repeat(Vector2i.RIGHT, 1.0)    # exceeds initial delay -> repeat to (7,5)
	assert_eq(_cursor.cell, Vector2i(7, 5))


func test_releasing_direction_resets_repeat():
	_cursor.step_repeat(Vector2i.RIGHT, 0.016)  # -> (6,5)
	_cursor.step_repeat(Vector2i.ZERO, 0.016)   # release
	_cursor.step_repeat(Vector2i.RIGHT, 0.016)  # fresh press -> immediate move to (7,5)
	assert_eq(_cursor.cell, Vector2i(7, 5))


func test_cursor_actions_registered():
	for a in [
		"cursor_up", "cursor_down", "cursor_left", "cursor_right",
		"cursor_confirm", "cursor_cancel",
	]:
		assert_true(InputMap.has_action(a), "missing action: %s" % a)


func test_key_events_map_to_actions():
	var cases := {
		KEY_RIGHT: "cursor_right",
		KEY_D: "cursor_right",
		KEY_W: "cursor_up",
		KEY_ENTER: "cursor_confirm",
		KEY_SPACE: "cursor_confirm",
		KEY_ESCAPE: "cursor_cancel",
	}
	for keycode in cases:
		var e := InputEventKey.new()
		e.physical_keycode = keycode
		e.pressed = true
		assert_true(
			InputMap.event_is_action(e, cases[keycode]),
			"key %d should trigger %s" % [keycode, cases[keycode]],
		)
