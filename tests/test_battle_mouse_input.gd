extends GutTest
## Issue #9 / WO-0.3: exercise the viewport's real input dispatch under a
## Camera2D, including mapped mouse actions and clicks without prior motion.

var _viewport: SubViewport
var _map: Node2D
var _camera: Camera2D
var _grid: Grid
var _cursor: BattleCursor
var _mouse_bindings: Dictionary = {}


func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(960, 540)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_map = Node2D.new()
	_map.position = Vector2(137, 83)
	_map.scale = Vector2(1.2, 0.85)
	_viewport.add_child(_map)
	_grid = Grid.new(20, 15)
	_cursor = BattleCursor.new()
	_map.add_child(_cursor)
	_cursor.setup(_grid, Vector2i(5, 5))
	_camera = Camera2D.new()
	_viewport.add_child(_camera)
	_frame_cell(Vector2i(6, 5), Vector2(0.625, 0.8))
	# Mouse buttons are currently handled directly in production, but settings
	# can also map them to actions. Both paths must resolve/bounds-check first.
	for action in ["cursor_confirm", "cursor_cancel"]:
		var binding := InputEventMouseButton.new()
		binding.button_index = MOUSE_BUTTON_LEFT if action == "cursor_confirm" else MOUSE_BUTTON_RIGHT
		if not InputMap.action_has_event(action, binding):
			InputMap.action_add_event(action, binding)
			_mouse_bindings[action] = binding


func after_each() -> void:
	for action in _mouse_bindings:
		InputMap.action_erase_event(action, _mouse_bindings[action])
	_mouse_bindings.clear()


func _frame_cell(cell: Vector2i, zoom: Vector2) -> void:
	_camera.position = _map.to_global(_grid.cell_center(cell))
	_camera.zoom = zoom
	_camera.make_current()
	_camera.force_update_scroll()


func _viewport_point(cell: Vector2i) -> Vector2:
	return _cursor.get_global_transform_with_canvas() * _grid.cell_center(cell)


func _motion(cell: Vector2i) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _viewport_point(cell)
	# Window/global coordinates need not equal the receiving viewport's point.
	event.global_position = event.position + Vector2(73, 41)
	_viewport.push_input(event, true)


func _click(cell: Vector2i, button: MouseButton, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = _viewport_point(cell)
	event.global_position = event.position + Vector2(73, 41)
	_viewport.push_input(event, true)


func test_hover_tracks_current_pan_zoom_and_map_transform() -> void:
	for zoom in [Vector2(0.625, 0.8), Vector2(1.5, 1.5)]:
		var target := Vector2i(7, 6) if zoom.x < 1.0 else Vector2i(12, 9)
		_frame_cell(target, zoom)
		_motion(target)
		assert_eq(_cursor.cell, target, "hover uses the current camera and map transform")
	assert_false(_cursor.is_selection_active(), "motion does not commit selection")


func test_mapped_left_click_moves_before_confirm_without_motion() -> void:
	var target := Vector2i(7, 6)
	var order: Array[String] = []
	_cursor.cell_changed.connect(func(_cell: Vector2i): order.append("hover"))
	_cursor.confirmed.connect(func(_cell: Vector2i): order.append("confirm"))
	_cursor.selection_changed.connect(func(_cell: Vector2i): order.append("selection"))
	watch_signals(_cursor)
	_click(target, MOUSE_BUTTON_LEFT)
	assert_eq(_cursor.cell, target)
	assert_eq(_cursor.selected_cell, target)
	assert_eq(order, ["hover", "confirm", "selection"], "one action, after updating hover")
	assert_signal_emitted_with_parameters(_cursor, "confirmed", [target])
	assert_true(_viewport.is_input_handled(), "the accepted click is consumed")


func test_mapped_right_click_moves_before_cancel_without_motion() -> void:
	_cursor.confirm()
	var target := Vector2i(7, 6)
	var order: Array[String] = []
	_cursor.cell_changed.connect(func(_cell: Vector2i): order.append("hover"))
	_cursor.cancelled.connect(func(_cell: Vector2i): order.append("cancel"))
	watch_signals(_cursor)
	_click(target, MOUSE_BUTTON_RIGHT)
	assert_eq(_cursor.cell, target)
	assert_false(_cursor.is_selection_active())
	assert_eq(order, ["hover", "cancel"])
	assert_signal_emitted_with_parameters(_cursor, "cancelled", [target])
	assert_true(_viewport.is_input_handled())


func test_outside_mapped_clicks_and_hover_preserve_selection_at_every_edge() -> void:
	_cursor.confirm()
	var original := _cursor.cell
	watch_signals(_cursor)
	for outside in [Vector2i(-1, 5), Vector2i(20, 5), Vector2i(5, -1), Vector2i(5, 15)]:
		# Keep the out-of-grid point inside the viewport, like a letterboxed map.
		_frame_cell(outside, Vector2(0.5, 0.5))
		_motion(outside)
		for button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_click(outside, button)
			assert_eq(_cursor.cell, original)
			assert_eq(_cursor.selected_cell, original)
	assert_signal_not_emitted(_cursor, "cell_changed")
	assert_signal_not_emitted(_cursor, "confirmed")
	assert_signal_not_emitted(_cursor, "cancelled")
	assert_signal_not_emitted(_cursor, "selection_changed")


func test_unmapped_mouse_buttons_still_target_the_pointed_cell() -> void:
	for action in _mouse_bindings:
		InputMap.action_erase_event(action, _mouse_bindings[action])
	_mouse_bindings.clear()
	var target := Vector2i(7, 6)
	watch_signals(_cursor)
	_click(target, MOUSE_BUTTON_LEFT)
	assert_eq(_cursor.selected_cell, target)
	assert_signal_emitted_with_parameters(_cursor, "confirmed", [target])
	target = Vector2i(6, 4)
	_click(target, MOUSE_BUTTON_RIGHT)
	assert_eq(_cursor.cell, target)
	assert_signal_emitted_with_parameters(_cursor, "cancelled", [target])
	assert_false(_cursor.is_selection_active())


func test_disabled_cursor_ignores_mouse_and_keyboard_dispatch() -> void:
	_cursor.confirm()
	_cursor.active = false
	watch_signals(_cursor)
	_motion(Vector2i(7, 6))
	_click(Vector2i(7, 6), MOUSE_BUTTON_LEFT)
	_click(Vector2i(7, 6), MOUSE_BUTTON_RIGHT)
	_key(KEY_ENTER)
	_key(KEY_ESCAPE)
	assert_eq(_cursor.cell, Vector2i(5, 5))
	assert_eq(_cursor.selected_cell, Vector2i(5, 5))
	for signal_name in ["cell_changed", "confirmed", "cancelled", "selection_changed"]:
		assert_signal_not_emitted(_cursor, signal_name)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	_viewport.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	_viewport.push_input(event, true)


func test_keyboard_confirm_cancel_keep_current_cell_after_mouse_hover() -> void:
	var target := Vector2i(7, 6)
	_motion(target)
	_cursor.try_move(Vector2i.RIGHT)
	target += Vector2i.RIGHT
	watch_signals(_cursor)
	_key(KEY_ENTER)
	assert_eq(_cursor.selected_cell, target)
	assert_signal_emitted_with_parameters(_cursor, "confirmed", [target])
	_key(KEY_ESCAPE)
	assert_false(_cursor.is_selection_active())
	assert_eq(_cursor.cell, target)
	assert_signal_emitted_with_parameters(_cursor, "cancelled", [target])


func test_released_and_other_mouse_buttons_do_not_act_or_move() -> void:
	watch_signals(_cursor)
	_click(Vector2i(7, 6), MOUSE_BUTTON_LEFT, false)
	_click(Vector2i(7, 6), MOUSE_BUTTON_RIGHT, false)
	_click(Vector2i(7, 6), MOUSE_BUTTON_MIDDLE)
	assert_eq(_cursor.cell, Vector2i(5, 5))
	assert_signal_not_emitted(_cursor, "confirmed")
	assert_signal_not_emitted(_cursor, "cancelled")


func test_stretched_viewport_applies_stretch_once_before_canvas_conversion() -> void:
	_viewport.size_2d_override = Vector2i(480, 270)
	_viewport.size_2d_override_stretch = true
	_frame_cell(Vector2i(7, 6), Vector2(0.625, 0.625))
	assert_eq(_viewport.get_stretch_transform().get_scale(), Vector2(2, 2))
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	# Feed the pre-stretch point, as external input does. Viewport dispatch
	# removes stretch; BattleCursor must then remove only the canvas/map transform.
	event.position = _viewport.get_final_transform() * _viewport_point(Vector2i(7, 6))
	event.global_position = event.position
	_viewport.push_input(event, false)
	assert_eq(_cursor.cell, Vector2i(7, 6))
	assert_eq(_cursor.selected_cell, Vector2i(7, 6))


func test_real_mock_battle_dispatch_selects_pointed_unit_and_cancels() -> void:
	Campaign.reset_new_game(false)
	_cursor.active = false
	_cursor.queue_free()
	_camera.enabled = false
	var scene: PackedScene = load("res://scenes/battle/mock_battle.tscn")
	var view: BattleView = scene.instantiate()
	view.dialogue_enabled = false
	view.strike_delay = 0.0
	_viewport.add_child(view)
	await wait_physics_frames(2)
	_cursor = view._cursor
	_camera = view._camera
	_map = view
	_grid = view._grid
	var kai: Unit = view.unit_by_id("kai")
	var kael: Unit = view.unit_by_id("kael")
	# Emulate keyboard hover; the opening cursor follows the first roster unit,
	# which need not be Kai. The regression needs Kai hovered before the click.
	_cursor.move_to(kai.cell)
	assert_ne(kai.cell, kael.cell)
	assert_ne(_camera.zoom, Vector2.ONE, "use the production zoomed camera")
	_camera.force_update_scroll()
	# No preceding mouse motion: select Kael while keyboard hover is on Kai.
	_click(kael.cell, MOUSE_BUTTON_LEFT)
	assert_eq(view._selected, kael, "the actual pointed unit receives selection")
	assert_eq(view._phase, BattleView.Phase.SELECTED)
	assert_eq(_cursor.cell, kael.cell)
	assert_eq(_cursor.selected_cell, kael.cell)
	assert_has(view._range_overlay._move_tiles, kael.cell, "normal move range is populated")
	# A fit/letterboxed view can expose space outside the logical map.
	_frame_cell(Vector2i(-1, 5), Vector2(0.5, 0.5))
	_click(Vector2i(-1, 5), MOUSE_BUTTON_LEFT)
	_click(Vector2i(-1, 5), MOUSE_BUTTON_RIGHT)
	assert_eq(view._selected, kael, "outside mapped clicks preserve battle selection")
	assert_eq(view._phase, BattleView.Phase.SELECTED)
	assert_eq(_cursor.selected_cell, kael.cell)
	# Pan/zoom as the battle does, then cancel at Kai's cell without motion.
	_frame_cell(kai.cell, Vector2(0.8, 0.8))
	_click(kai.cell, MOUSE_BUTTON_RIGHT)
	assert_eq(_cursor.cell, kai.cell)
	assert_null(view._selected)
	assert_eq(view._phase, BattleView.Phase.IDLE)
	assert_false(_cursor.is_selection_active())
	assert_eq(view._range_overlay._move_tiles.size(), 0, "cancel clears the move range")
	assert_false(kael.has_acted, "cancel spends no turn")
	Campaign.reset_new_game(false)
