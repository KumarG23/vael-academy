extends GutTest
## ChoiceMenu mouse support: the control's rect matches the drawn panel, hover
## highlights a row, left-click chooses it, right-click cancels. Keyboard flow
## and width fitting are covered in test_battle_polish.gd.

var _menu: ChoiceMenu


func before_each() -> void:
	# Keep layout deterministic regardless of the GUT runner window size.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.handle_input_locally = true
	add_child_autofree(viewport)
	_menu = ChoiceMenu.new()
	viewport.add_child(_menu)
	_menu.open("Pick", ["Alpha", "Beta", "Gamma"], Vector2(40, 50))


func _row_point(row: int) -> Vector2:
	return Vector2(60, ChoiceMenu.PAD + ChoiceMenu.ROW_H * (row + 1) + ChoiceMenu.ROW_H * 0.5)


func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = pos
	_menu._gui_input(ev)


func test_rect_matches_the_drawn_panel():
	assert_eq(_menu.position, Vector2(40, 50))
	assert_eq(_menu.size, Vector2(_menu._width, ChoiceMenu.PAD * 2 + ChoiceMenu.ROW_H * 4))
	_menu.open("", ["Only"], Vector2.ZERO)
	assert_eq(_menu.size.y, ChoiceMenu.PAD * 2 + ChoiceMenu.ROW_H, "no title row when untitled")


func test_row_at_skips_title_and_padding():
	assert_eq(_menu.row_at(_row_point(0)), 0)
	assert_eq(_menu.row_at(_row_point(2)), 2)
	assert_eq(_menu.row_at(Vector2(60, ChoiceMenu.PAD + 4)), -1, "title row is not an option")
	assert_eq(_menu.row_at(_row_point(3)), -1, "below the last option")
	assert_eq(_menu.row_at(Vector2(4, _row_point(1).y)), -1, "left of the rows")


func test_hover_moves_the_highlight():
	var ev := InputEventMouseMotion.new()
	ev.position = _row_point(2)
	_menu._gui_input(ev)
	assert_eq(_menu._index, 2)


func test_left_click_chooses_the_clicked_row():
	watch_signals(_menu)
	_click(_row_point(1))
	assert_signal_emitted_with_parameters(_menu, "chosen", [1])
	assert_eq(_menu._index, 1)


func test_click_outside_the_rows_does_nothing():
	watch_signals(_menu)
	_click(Vector2(60, ChoiceMenu.PAD + 4))
	assert_signal_not_emitted(_menu, "chosen")
	assert_eq(_menu._index, 0)


func test_right_click_cancels():
	watch_signals(_menu)
	_click(_row_point(0), MOUSE_BUTTON_RIGHT)
	assert_signal_emitted(_menu, "cancelled")
	assert_signal_not_emitted(_menu, "chosen")


func test_closed_menu_ignores_the_mouse():
	_menu.close()
	watch_signals(_menu)
	_click(_row_point(1))
	assert_signal_not_emitted(_menu, "chosen")


func _press(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	_menu._unhandled_input(ev)


func test_empty_menu_can_be_cancelled_with_keyboard():
	_menu.open("Empty", [], Vector2.ZERO)
	watch_signals(_menu)
	_press("cursor_cancel")
	assert_signal_emitted(_menu, "cancelled")
	assert_signal_not_emitted(_menu, "chosen")


func test_empty_menu_can_be_cancelled_with_mouse():
	_menu.open("Empty", [], Vector2.ZERO)
	watch_signals(_menu)
	_click(Vector2(60, ChoiceMenu.PAD + 4), MOUSE_BUTTON_RIGHT)
	assert_signal_emitted(_menu, "cancelled")
	assert_signal_not_emitted(_menu, "chosen")


func test_empty_menu_ignores_navigation_and_selection():
	_menu.open("Empty", [], Vector2.ZERO)
	watch_signals(_menu)
	_press("cursor_up")
	_press("cursor_down")
	_press("cursor_confirm")
	_click(_row_point(0))
	assert_eq(_menu._index, 0)
	assert_signal_not_emitted(_menu, "chosen")
	assert_signal_not_emitted(_menu, "cancelled")


func test_closed_empty_menu_ignores_cancellation():
	_menu.open("Empty", [], Vector2.ZERO)
	_menu.close()
	watch_signals(_menu)
	_press("cursor_cancel")
	_click(Vector2(60, ChoiceMenu.PAD + 4), MOUSE_BUTTON_RIGHT)
	assert_signal_not_emitted(_menu, "cancelled")


func _open_tall_menu() -> SubViewport:
	var viewport := _menu.get_viewport() as SubViewport
	viewport.size = Vector2i(640, 300)
	_menu.open("Pick", ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta"],
		Vector2(40, -100))
	return viewport


func test_tall_menu_fits_inside_its_viewport():
	var viewport := _open_tall_menu()
	assert_gte(_menu.position.y, 0.0, "the title remains on screen")
	assert_lte(_menu.position.y + _menu.size.y, float(viewport.size.y), "rows fit on screen")
	assert_eq(_menu.row_at(_row_point(0)), 0, "the first visible row starts at the first option")
	assert_eq(_menu.row_at(Vector2(60, _menu.size.y - 1)), -1, "bottom padding is not clickable")


func test_keyboard_scroll_keeps_the_selected_option_clickable():
	var viewport := _open_tall_menu()
	_press("cursor_up")
	assert_eq(_menu._index, 7, "up wraps to the final option")
	var last_row := int((_menu.size.y - ChoiceMenu.PAD * 2) / ChoiceMenu.ROW_H) - 2
	assert_eq(_menu.row_at(_row_point(last_row)), 7, "the final option is visible after wrapping")
	var selections: Array[int] = []
	_menu.chosen.connect(func(index: int) -> void: selections.append(index))
	await get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _menu.position + _row_point(last_row)
	click.global_position = click.position
	viewport.push_input(click)
	await get_tree().process_frame
	assert_eq(selections, [7], "a real click emits the original option index exactly once")
	_press("cursor_down")
	assert_eq(_menu.row_at(_row_point(0)), 0, "wrapping down scrolls back to the beginning")
	_press("cursor_confirm")
	assert_eq(selections, [7, 0], "keyboard confirmation also emits the original option index")


func test_mouse_wheel_reaches_every_option_and_reopen_resets_scroll():
	_open_tall_menu()
	watch_signals(_menu)
	for i in range(7):
		_click(_row_point(0), MOUSE_BUTTON_WHEEL_DOWN)
	assert_eq(_menu._index, 7, "the wheel reaches the last choice")
	assert_signal_not_emitted(_menu, "chosen")
	assert_signal_not_emitted(_menu, "cancelled")
	_click(_row_point(0), MOUSE_BUTTON_WHEEL_UP)
	assert_eq(_menu._index, 6, "wheel up moves toward earlier choices")
	_menu.open("Pick", ["Alpha", "Beta"], Vector2(40, 250))
	assert_eq(_menu._index, 0)
	assert_eq(_menu.row_at(_row_point(0)), 0, "new menus reset the visible range")
	assert_eq(_menu.size.y, ChoiceMenu.PAD * 2 + ChoiceMenu.ROW_H * 3,
		"short menus retain their natural height")
	assert_lte(_menu.position.y + _menu.size.y, 300.0, "a short menu near the bottom moves up")


func test_viewport_resize_keeps_the_current_choice_visible():
	var viewport := _open_tall_menu()
	_press("cursor_up")
	viewport.size = Vector2i(640, 230)
	await get_tree().process_frame
	assert_lte(_menu.position.y + _menu.size.y, 230.0, "shrinking the window reduces visible rows")
	var last_row := int((_menu.size.y - ChoiceMenu.PAD * 2) / ChoiceMenu.ROW_H) - 2
	assert_eq(_menu.row_at(_row_point(last_row)), 7, "the selection stays in the visible range")
	viewport.size = Vector2i(640, 600)
	await get_tree().process_frame
	assert_eq(_menu.size.y, ChoiceMenu.PAD * 2 + ChoiceMenu.ROW_H * 9,
		"enlarging the window restores the full list")
	assert_eq(_menu.row_at(_row_point(0)), 0, "all choices are visible again")
	assert_eq(_menu._index, 7, "resizing preserves the chosen highlight")


func test_untitled_menu_scrolls_without_reserving_a_title_row():
	_open_tall_menu()
	_menu.open("", ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta"], Vector2.ZERO)
	assert_eq(_menu.row_at(Vector2(60, ChoiceMenu.PAD + ChoiceMenu.ROW_H * 6.5)), 6,
		"an untitled menu has room for another option")
	_press("cursor_up")
	watch_signals(_menu)
	_click(Vector2(60, ChoiceMenu.PAD + ChoiceMenu.ROW_H * 6.5))
	assert_signal_emitted_with_parameters(_menu, "chosen", [7])
