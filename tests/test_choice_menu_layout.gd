extends GutTest
## GH-122: variable-height pages use identical drawing and hit geometry.
var _viewport: SubViewport
var _menu: ChoiceMenu

func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_menu = ChoiceMenu.new()
	_viewport.add_child(_menu)
	_menu.open("Pick", ["Short", "Slot 2 — mock_battle_vs_thornrook (Classic)  ⚔ mid-battle",
		"Autosave — closing_rite_vs_emberwing W6 (Casual)", "Another short row", "Back"], Vector2(600, 300))

func _action(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_viewport.push_input(event, true)

func _assert_page() -> void:
	assert_true(Rect2(Vector2.ZERO, Vector2(_viewport.size)).encloses(Rect2(_menu.position, _menu.size)))
	assert_gt(_menu._visible_rows, 0)
	for i in range(_menu._options.size()):
		var row := _menu.row_rect(i)
		if row.has_area():
			assert_eq(_menu.row_at(row.position + Vector2(1, 0.01)), i, "first edge")
			assert_eq(_menu.row_at(row.end - Vector2(1, 0.01)), i, "final edge")
			assert_lte(row.end.y, _menu.size.y - ChoiceMenu.PAD, "no partial rows")
		else:
			assert_true(i < _menu._first_visible or i >= _menu._first_visible + _menu._visible_rows)
	assert_eq(_menu.row_at(Vector2(60, _menu.size.y - ChoiceMenu.PAD + 0.01)), -1, "padding never aliases hidden row")
	assert_eq(_menu.row_at(Vector2(_menu.size.x + 1, ChoiceMenu.PAD + 35)), -1)
	assert_true(_menu.row_rect(_menu._index).has_area(), "selected label is complete")

func test_variable_rows_reach_every_index_both_directions_and_wrap() -> void:
	assert_gt(_menu._row_heights[1], _menu._row_heights[0], "actual font requires wrapping")
	for direction in ["cursor_down", "cursor_up"]:
		for i in range(10):
			_assert_page()
			_action(direction)
	assert_eq(_menu._index, 0)

func test_wheel_hover_and_real_click_choose_original_index_once() -> void:
	await get_tree().process_frame
	var selections: Array[int] = []
	_menu.chosen.connect(func(index: int) -> void: selections.append(index))
	for i in range(4):
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = _menu.position + _menu.row_rect(_menu._index).get_center()
		_viewport.push_input(wheel, true)
		_assert_page()
	assert_eq(_menu._index, 4)
	var motion := InputEventMouseMotion.new()
	motion.position = _menu.position + _menu.row_rect(4).get_center()
	_viewport.push_input(motion, true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = motion.position
	_viewport.push_input(click, true)
	assert_eq(selections, [4])
	_action("cursor_down")
	assert_eq(_menu._index, 0)
	_assert_page()

func test_live_resize_remeasures_width_and_restores_requested_position() -> void:
	_action("cursor_up")
	for dimensions in [Vector2i(800, 450), Vector2i(640, 360), Vector2i(320, 300), Vector2i(1280, 720)]:
		_viewport.size = dimensions
		await get_tree().process_frame
		assert_eq(_menu._index, 4)
		_assert_page()
	assert_eq(_menu.position, Vector2(600, 300), "restore preferred anchor when there is room")
	assert_eq(_menu._first_visible, 0)

func test_partial_row_edges_are_not_drawn_or_clickable() -> void:
	_viewport.size = Vector2i(640, 220)
	_menu._layout_panel()
	for i in range(5):
		_assert_page()
		var bottom := _menu.row_rect(_menu._first_visible + _menu._visible_rows - 1).end.y
		assert_eq(_menu.row_at(Vector2(60, bottom + 0.01)), -1)
		_action("cursor_down")

func test_variable_row_hover_and_consumption_before_callbacks() -> void:
	await get_tree().process_frame
	_viewport.notify_mouse_entered()
	var row := _menu.row_rect(1)
	assert_true(row.has_area())
	var motion := InputEventMouseMotion.new()
	motion.position = _menu.position + row.get_center()
	_viewport.push_input(motion, true)
	assert_eq(_menu._index, 1, "hover resolves a wrapped row")
	var consumed: Array[bool] = []
	_menu.chosen.connect(func(_index: int) -> void: consumed.append(_viewport.is_input_handled()))
	_action("cursor_confirm")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = motion.position
	_viewport.push_input(click, true)
	assert_eq(consumed, [true, true], "both paths consume input before a scene-changing listener")
	_menu.cancelled.connect(func() -> void: consumed.append(_viewport.is_input_handled()))
	click.button_index = MOUSE_BUTTON_RIGHT
	_viewport.push_input(click, true)
	assert_eq(consumed, [true, true, true])
