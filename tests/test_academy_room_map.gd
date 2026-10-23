extends GutTest
## GH-69: exercise the production castle via viewport input, real room resources
## and world simulation. No renderer/time-scale changes or duplicate geometry.

var _viewport: SubViewport
var _castle: CastleScene


func before_each() -> void:
	Campaign.reset_new_game(false)
	Campaign.week = 2
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	_viewport.add_child(_castle)
	await wait_process_frames(2)


func after_each() -> void:
	Input.action_release("ui_right")
	Campaign.reset_new_game(false)


func _key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	_viewport.push_input(event, true)


func test_discoverable_toggle_consumes_echo_release_and_escape_without_menu_leak():
	assert_true(_castle._map_hint.visible)
	assert_string_contains(_castle._map_hint.text, "M")
	_key(KEY_M, false)
	_key(KEY_M, true, true)
	assert_null(_castle._room_map, "only a fresh press opens")
	_key(KEY_M)
	var first := _castle._room_map
	assert_not_null(first)
	assert_true(_castle.busy())
	_key(KEY_M, true, true)
	_key(KEY_M, false)
	_key(KEY_ESCAPE, false)
	_key(KEY_ESCAPE, true, true)
	assert_eq(_castle._room_map, first, "held/released toggle or cancel cannot close")
	_key(KEY_ESCAPE)
	assert_null(_castle._room_map)
	assert_true(first.is_queued_for_deletion())
	assert_eq(_castle._menu_context, "", "closing Escape consumed before menu")
	_key(KEY_ESCAPE)
	assert_eq(_castle._menu_context, "system", "fresh Escape still opens ordinary menu")
	_castle._close_menu()
	_key(KEY_M)
	assert_not_null(_castle._room_map)
	_key(KEY_M)
	assert_null(_castle._room_map, "M closes without reopening")
	_key(KEY_J)
	assert_not_null(_castle._journal, "Journal continues normally")
	_key(KEY_ESCAPE)
	assert_null(_castle._journal)
	assert_eq(_castle._menu_context, "")


func test_opening_is_blocked_by_every_existing_modal_and_transition():
	_key(KEY_ESCAPE)
	_key(KEY_M)
	assert_null(_castle._room_map, "choices/menu")
	_castle._close_menu()
	_key(KEY_J)
	_key(KEY_M)
	assert_null(_castle._room_map, "Journal")
	_key(KEY_J)
	# Real dialogue owns input while present.
	_castle._play_dialogue("res://data/dialogue/castle_callan.json")
	_key(KEY_M)
	assert_null(_castle._room_map, "dialogue")
	_castle._dialogue.queue_free()
	_castle._dialogue = null
	await wait_process_frames(1)
	_castle._play_dialogue_json('[{"choice":"Test fixture","options":[{"text":"Continue"}]},{"text":"Done"}]')
	assert_true(_castle._dialogue.awaiting_choice())
	_key(KEY_M)
	assert_null(_castle._room_map, "dialogue choices")
	_castle._dialogue.queue_free()
	_castle._dialogue = null
	await wait_process_frames(1)
	_castle._start_fishing()
	_key(KEY_M)
	assert_null(_castle._room_map, "fishing")
	_castle._fishing.queue_free()
	_castle._fishing = null
	await wait_process_frames(1)
	_castle._start_class()
	assert_not_null(_castle._quiz)
	_key(KEY_M)
	assert_null(_castle._room_map, "quiz")
	_castle._quiz.queue_free()
	_castle._quiz = null
	await wait_process_frames(1)
	_key(KEY_QUOTELEFT)
	assert_true(_castle._editor.active)
	_key(KEY_M)
	assert_null(_castle._room_map, "editor")
	_key(KEY_QUOTELEFT)
	_castle._leaving = true
	_key(KEY_M)
	assert_null(_castle._room_map, "committed deferred transition")
	_castle._leaving = false
	_key(KEY_M)
	assert_not_null(_castle._room_map, "all gates cleared")


func _assert_fit() -> void:
	var map := _castle._room_map
	assert_eq(map.room, _castle.room, "uses loaded resource")
	assert_eq(map.grid, _castle._grid)
	assert_eq(map.terrain_db, _castle._terrain_db, "same collision classification")
	assert_string_contains(map._title.text, _castle.room.display_name)
	var view := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	assert_true(view.encloses(map.map_rect.grow(20)), "entire terrain and marker margin fit")
	assert_gte(map._title.position.y, 60.0, "header clears the ornate top frame")
	assert_false(map._title.get_global_rect().intersects(map.map_rect), "header clears terrain")
	assert_false(map._title.get_global_rect().intersects(map._legend.get_global_rect()), "header clears legend")
	assert_true(view.encloses(map._title.get_global_rect()), "title fits %s: %s" % [_castle.room.id, map._title.get_global_rect()])
	assert_lte(map._exits.get_global_rect().end.y, float(_viewport.size.y - 50), "exit text clears bottom ornament")
	var legend_font := map._legend.get_theme_font("font")
	var legend_text_size := legend_font.get_multiline_string_size(map._legend.text, HORIZONTAL_ALIGNMENT_LEFT, map._legend.size.x, 14)
	assert_true(legend_text_size.x <= map._legend.size.x + 0.5 and legend_text_size.y <= map._legend.size.y + 0.5, "legend text fits its layout")
	assert_true(view.encloses(map._legend.get_global_rect()), "legend fits: %s" % map._legend.get_global_rect())
	assert_true(view.encloses(map._exits.get_global_rect()), "list fits: %s" % map._exits.get_global_rect())
	assert_false(map.map_rect.intersects(map._exits.get_global_rect()), "labels never cover markers")
	assert_eq(map._exit_labels.size(), _castle.room.doors.size())
	assert_almost_eq(map.map_rect.size.x / map.map_rect.size.y,
		float(_castle._grid.width) / _castle._grid.height, 0.001, "uniform scale")
	for i in range(_castle.room.doors.size()):
		var door := _castle.room.doors[i]
		var expected := map.map_rect.position + (Vector2(door.cell) + Vector2.ONE * 0.5) * map.cell_size
		assert_almost_eq(map.map_position(_castle._grid.cell_center(door.cell)), expected,
			Vector2.ONE * 0.001, "exit at real cell")
		assert_true(map.map_rect.has_point(expected), "exit fits: %s" % expected)
		assert_eq(map._exit_labels[i].text, "%d  %s" % [i + 1, door.label], "existing label unchanged")
		assert_true(map._exit_labels[i].size.x <= map._exits.size.x, "wrapped label fits list")
	assert_almost_eq(map.map_position(_castle._avatar.position),
		map.map_rect.position + _castle._avatar.position / _castle._grid.cell_size * map.cell_size,
		Vector2.ONE * 0.001, "live sub-cell avatar position")


func test_real_campus_and_small_rooms_fit_resize_and_keep_every_exit_label():
	for room_id in ["campus", "entrance", "library", "quartermaster"]:
		_castle.enter_room(room_id)
		_key(KEY_M)
		assert_not_null(_castle._room_map)
		for dimensions in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(800, 450), Vector2i(1280, 720)]:
			_viewport.size = dimensions
			await wait_process_frames(3)
			_assert_fit()
		_key(KEY_M)


func test_map_does_not_expose_hidden_points_other_interiors_or_town_maps():
	_key(KEY_M)
	assert_eq(_castle._room_map.get_children().size(), 3, "title, legend, exit list only")
	assert_eq(_castle._room_map.room, _castle.room)
	assert_eq(_castle._room_map._exit_labels.size(), 10, "existing campus exits, not other rooms")
	_key(KEY_M)
	for room_id in ["grove", "vael_square", "vael_tavern", "vael_castle_gate"]:
		_castle.enter_room(room_id)
		_key(KEY_M)
		assert_null(_castle._room_map, "excluded room %s" % room_id)
		await wait_process_frames(1)
		assert_false(_castle._map_hint.visible)


func test_read_only_state_save_rng_and_world_guards_through_input_resize_close():
	var save := SaveSystem.new("user://map_state_%d" % Time.get_ticks_usec())
	assert_true(Campaign.save_to_slot(0, save))
	var bytes := FileAccess.get_file_as_bytes(save.slot_path(0))
	var campaign := Campaign.to_dict().duplicate(true)
	var terrain_before := _castle.room.chapter.terrain.duplicate()
	var doors_before: Array = []
	for door in _castle.room.doors:
		doors_before.append([door.cell, door.to_room, door.spawn_cell, door.label])
	var position := _castle._avatar.position
	var camera := _castle._camera.position
	var zoom := _castle._camera.zoom
	var armed := _castle._door_armed
	seed(6901)
	var expected_rng := [randi(), randi()]
	seed(6901)
	_key(KEY_M)
	for key in [KEY_J, KEY_ENTER, KEY_SPACE, KEY_QUOTELEFT, KEY_RIGHT]:
		_key(key)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = _castle._room_map.map_position(position)
	_viewport.push_input(click, true)
	Input.action_press("ui_right")
	_castle._process(0.2)
	Input.action_release("ui_right")
	_castle._check_door()
	_castle.activate_nearest()
	_viewport.size = Vector2i(640, 360)
	await wait_process_frames(3)
	assert_eq(_castle._avatar.position, position)
	assert_eq(_castle._camera.position, camera)
	assert_eq(_castle._camera.zoom, zoom)
	assert_eq(_castle._door_armed, armed)
	assert_null(_castle._journal)
	assert_false(_castle._editor.active)
	assert_eq(_castle._menu_context, "")
	_key(KEY_ESCAPE)
	assert_eq(Campaign.to_dict(), campaign, "entire Campaign including RNG unchanged")
	assert_eq(FileAccess.get_file_as_bytes(save.slot_path(0)), bytes, "no save write")
	assert_eq([randi(), randi()], expected_rng, "global RNG unchanged")
	assert_eq(_castle.room.chapter.terrain, terrain_before, "terrain unchanged")
	var doors_after: Array = []
	for door in _castle.room.doors:
		doors_after.append([door.cell, door.to_room, door.spawn_cell, door.label])
	assert_eq(doors_after, doors_before, "door geometry and destinations unchanged")
	DirAccess.remove_absolute(save.slot_path(0))
	DirAccess.remove_absolute(save.save_dir)


func test_scrolling_long_exit_list_is_read_only_and_all_labels_remain_accessible():
	_viewport.size = Vector2i(640, 360)
	_key(KEY_M)
	await wait_process_frames(3)
	var map := _castle._room_map
	for i in range(20):
		_key(KEY_DOWN)
	await wait_process_frames(2)
	assert_gt(map._exits.scroll_vertical, 0, "compact list scrolls with keyboard")
	var last := map._exit_labels.back() as Label
	assert_true(map._exits.get_global_rect().intersects(last.get_global_rect()), "last exit reachable")
	for i in range(20):
		_key(KEY_UP)
	await wait_process_frames(2)
	assert_eq(map._exits.scroll_vertical, 0)
	assert_true(map._exits.get_global_rect().intersects(map._exit_labels[0].get_global_rect()))


func test_close_then_normal_walking_door_edge_guard_reopen_and_interaction():
	_castle.enter_room("entrance", Vector2i(11, 11))
	_key(KEY_M)
	_key(KEY_ESCAPE)
	var start := _castle._avatar.position
	Input.action_press("ui_right")
	_castle._process(0.04)
	Input.action_release("ui_right")
	assert_gt(_castle._avatar.position.x, start.x, "walking resumes")
	var door := _castle.room.doors[0]
	_castle._avatar.position = _castle._grid.cell_center(door.cell)
	_castle._door_armed = false
	_key(KEY_M)
	_castle._check_door()
	assert_eq(_castle.room.id, "entrance", "map cannot activate door")
	_key(KEY_ESCAPE)
	_castle._check_door()
	assert_eq(_castle.room.id, "entrance", "unarmed spawn guard preserved")
	_castle._avatar.position = start
	_castle._check_door()
	_castle._avatar.position = _castle._grid.cell_center(door.cell)
	_castle._check_door()
	assert_eq(_castle.room.id, door.to_room, "normal armed doorway transitions")
	_key(KEY_M)
	await wait_process_frames(2)
	_assert_fit()
	_key(KEY_M)
	_castle.enter_room("training")
	for point in _castle.room.points:
		if point.id == "fn_train":
			_castle._avatar.position = _castle._grid.cell_center(point.cell)
	_castle._update_prompt()
	_key(KEY_M)
	_key(KEY_ENTER)
	assert_eq(_castle._menu_context, "", "no interaction while map open")
	_key(KEY_ESCAPE)
	_key(KEY_ENTER)
	assert_eq(_castle._menu_context, "training", "normal interaction resumes")


func test_pointer_menu_continuation_after_closing_map():
	_key(KEY_M)
	_key(KEY_ESCAPE)
	_key(KEY_ESCAPE)
	assert_eq(_castle._menu_context, "system")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = _castle._menu.position + Vector2(40, 40)
	_viewport.push_input(click, true)
	assert_eq(_castle._menu_context, "", "ordinary pointer menu cancellation resumes immediately")
	assert_false(_castle.busy())
