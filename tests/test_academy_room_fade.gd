extends GutTest
## GH-95: real viewport dispatch with deterministic production fade frames.

var _viewport: SubViewport
var _castle: CastleScene


func before_each() -> void:
	Campaign.reset_new_game(false, 9501)
	Campaign.week = 2
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	_viewport.add_child(_castle)
	_castle.set_process(false)
	await wait_process_frames(2)


func after_each() -> void:
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		Input.action_release(action)
	Campaign.reset_new_game(false)


func _key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	_viewport.push_input(event, true)


func _click(position: Vector2, button := MOUSE_BUTTON_LEFT, pressed := true) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = position
	_viewport.push_input(event, true)


func _door(target := "entrance") -> CastleDoor:
	for door: CastleDoor in _castle.room.doors:
		if door.to_room == target:
			return door
	return null


func _start_door(target := "entrance") -> void:
	var door := _door(target)
	_castle._avatar.position = _castle._grid.cell_center(door.cell)
	_castle._door_armed = true
	_castle._check_door()


func _conceal_and_switch() -> void:
	_castle._process(CastleScene.ROOM_FADE_HALF)
	assert_eq(_castle._fade_cover.modulate.a, 1.0)
	_castle._process(0.016)


func _reveal() -> void:
	_castle._process(CastleScene.ROOM_FADE_HALF)
	assert_false(_castle.busy())
	assert_false(_castle._fade_cover.visible)
	assert_eq(_castle._fade_cover.modulate.a, 0.0)


func _open_travel(target: String) -> void:
	_key(KEY_M)
	_key(KEY_TAB)
	var map := _castle._room_map
	for i in range(map.destinations.size()):
		if map.destinations[map.selected].id == target:
			return
		_key(KEY_DOWN)
	fail_test("Missing destination " + target)


func test_physical_trip_switches_once_under_cover_then_full_title_and_continuation():
	var changed: Array[String] = []
	_castle.room_changed.connect(func(id: String):
		assert_eq(_castle._fade_cover.modulate.a, 1.0, "switch fully concealed")
		changed.append(id))
	var before := Campaign.to_dict().duplicate(true)
	_start_door()
	assert_eq(_castle.room.id, "campus", "source remains until concealment")
	assert_null(_castle._nearest_point)
	assert_false(_castle._prompt.visible)
	assert_false(_castle._title_card.visible)
	assert_true(_castle.busy())
	_castle._process(CastleScene.ROOM_FADE_HALF / 2.0)
	assert_almost_eq(_castle._fade_cover.modulate.a, 0.5, 0.001)
	assert_eq(_castle.room.id, "campus")
	_conceal_and_switch()
	assert_eq(_castle.room.id, "entrance")
	assert_eq(changed, ["entrance"])
	assert_false(_castle._door_armed)
	_reveal()
	assert_true(_castle._title_card.visible)
	assert_eq(_castle._title_card._alpha, 1.0, "full original title hold starts at reveal")
	assert_string_contains(_castle._title_card._text, _castle.room.display_name)
	before["academy_visits"] = ["campus", "entrance"]
	assert_eq(Campaign.to_dict(), before, "only supported earned visit changes")
	_castle._check_door()
	assert_eq(changed.size(), 1, "no arrival bounce")
	_key(KEY_J)
	assert_not_null(_castle._journal)
	_key(KEY_J)
	assert_null(_castle._journal)
	assert_eq(_castle._menu_context, "", "Journal close consumed")


func test_keyboard_and_pointer_confirm_share_path_and_preserve_complete_state_and_files():
	var saves := SaveSystem.new("user://fade_95_%d" % Time.get_ticks_usec())
	for slot in range(3):
		assert_true(saves.save_slot(slot, {"campaign": Campaign.to_dict(), "marker": slot}))
	var bytes: Array[PackedByteArray] = []
	for slot in range(3):
		bytes.append(FileAccess.get_file_as_bytes(saves.slot_path(slot)))
	# Independent sentinel also detects accidental checkpoint IO in this directory.
	var checkpoint := saves.save_dir.path_join("autosave.json")
	var file := FileAccess.open(checkpoint, FileAccess.WRITE)
	file.store_string("prior checkpoint")
	file.close()
	var old_override := Campaign.save_system_override
	Campaign.save_system_override = saves
	_castle.enter_room("entrance")
	_castle.enter_room("campus")
	Campaign.training_used = true
	Campaign.flags["gold"] = 73
	var before := Campaign.to_dict().duplicate(true)
	var supports := _castle._support_state.save_state().duplicate(true)
	for pointer: bool in [false, true]:
		_open_travel("entrance")
		await wait_process_frames(2)
		if pointer:
			var map := _castle._room_map
			_click(map._destination_labels[map.selected].get_global_rect().get_center())
		else:
			_key(KEY_ENTER)
		assert_null(_castle._room_map, "accepted map closes immediately")
		assert_eq(_castle.room.id, "campus")
		assert_true(_castle.busy())
		_conceal_and_switch()
		_reveal()
		assert_eq(_castle.room.id, "entrance")
		assert_eq(Campaign.to_dict(), before)
		assert_eq(_castle._support_state.save_state(), supports)
		_castle.enter_room("campus")
	for slot in range(3):
		assert_eq(FileAccess.get_file_as_bytes(saves.slot_path(slot)), bytes[slot])
		DirAccess.remove_absolute(saves.slot_path(slot))
	assert_eq(FileAccess.get_file_as_string(checkpoint), "prior checkpoint")
	DirAccess.remove_absolute(checkpoint)
	DirAccess.remove_absolute(saves.save_dir)
	Campaign.save_system_override = old_override


func test_all_press_echo_release_pointer_and_held_input_are_modal_in_both_halves():
	var hits: Array[String] = []
	_castle.spot_activated.connect(func(id: String): hits.append(id))
	_start_door()
	for half in range(2):
		var before := Campaign.to_dict().duplicate(true)
		var position := _castle._avatar.position
		for key: Key in [KEY_J, KEY_M, KEY_QUOTELEFT, KEY_ESCAPE, KEY_ENTER, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_TAB]:
			_key(key)
			_key(key, true, true)
			_key(key, false)
		for button: MouseButton in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_WHEEL_DOWN]:
			_click(Vector2(100, 100), button)
			_click(Vector2(100, 100), button, false)
		Input.action_press("ui_right")
		_castle._process(0.02)
		_castle.activate_nearest()
		_castle._travel_to("campus")
		_castle._check_door()
		assert_eq(_castle._avatar.position, position)
		assert_null(_castle._journal)
		assert_null(_castle._room_map)
		assert_false(_castle._editor.active)
		assert_eq(_castle._menu_context, "")
		assert_null(_castle._dialogue)
		assert_eq(hits.size(), 0)
		assert_eq(Campaign.to_dict(), before)
		if half == 0:
			_conceal_and_switch()
	_reveal()
	var position := _castle._avatar.position
	_castle._process(0.02)
	assert_gt(_castle._avatar.position.x, position.x, "held movement resumes normally")
	assert_eq(_castle.room.id, "entrance")
	Input.action_release("ui_right")


func test_current_invalid_excluded_locked_and_cancel_never_start_fade():
	_castle.enter_room("entrance")
	_open_travel("entrance")
	var before := Campaign.to_dict().duplicate(true)
	var map := _castle._room_map
	_key(KEY_ENTER)
	for target: String in ["unknown", "grove", "vael_square", "library"]:
		_castle._travel_to(target)
	assert_eq(_castle._room_map, map)
	assert_false(_castle._fade_cover.visible)
	assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE)
	assert_eq(Campaign.to_dict(), before)
	_key(KEY_ESCAPE)
	assert_eq(_castle._menu_context, "")
	_castle._leaving = true
	_start_door("campus")
	assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE)
	_castle._leaving = false
	# A now-blocked physical spawn must fail without starting presentation.
	var original := _castle._rooms
	_castle._rooms = original.duplicate()
	var campus: CastleRoomDef = original["campus"].duplicate(true)
	campus.chapter.terrain.fill(Terrain.Type.WALL)
	_castle._rooms["campus"] = campus
	_start_door("campus")
	assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE)
	assert_eq(Campaign.to_dict(), before)
	_castle._rooms = original


func test_revalidation_at_concealment_rejects_changed_access_without_retry():
	_castle.enter_room("entrance")
	_castle.enter_room("campus")
	_open_travel("entrance")
	_key(KEY_ENTER)
	var before := Campaign.to_dict().duplicate(true)
	Campaign.academy_visits.erase("entrance")
	before["academy_visits"] = Campaign.academy_visits.duplicate()
	_conceal_and_switch()
	assert_eq(_castle.room.id, "campus")
	_reveal()
	assert_eq(Campaign.to_dict(), before)
	Campaign.academy_visits.append("entrance")
	_castle._process(0.3)
	assert_eq(_castle.room.id, "campus", "no delayed retry")


func test_cover_tracks_default_compact_and_live_resize_above_hud():
	_start_door()
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(800, 450), Vector2i(1280, 720)]:
		_viewport.size = size
		await wait_process_frames(2)
		assert_eq(_castle._fade_cover.get_global_rect(), Rect2(Vector2.ZERO, Vector2(size)))
		assert_gt((_castle._fade_cover.get_parent() as CanvasLayer).layer, _castle._ui.layer)
	_conceal_and_switch()
	_reveal()


func test_detach_before_and_after_switch_clears_request_and_allows_normal_reentry():
	for switched: bool in [false, true]:
		_castle.enter_room("campus")
		_start_door()
		if switched:
			_conceal_and_switch()
		var expected := _castle.room.id
		var before := Campaign.to_dict().duplicate(true)
		_viewport.remove_child(_castle)
		await wait_process_frames(3)
		assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE)
		assert_true(_castle._fade_request.is_empty())
		assert_false(_castle._fade_cover.visible)
		assert_eq(_castle.room.id, expected)
		assert_eq(Campaign.to_dict(), before)
		_viewport.add_child(_castle)
		_key(KEY_M)
		assert_not_null(_castle._room_map, "no persistent input lock on reentry")
		_key(KEY_ESCAPE)


func test_synchronous_entry_supersedes_pending_fade_and_initial_entry_has_none():
	assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE)
	assert_false(_castle._fade_cover.visible)
	_start_door()
	_castle.enter_room("library")
	assert_eq(_castle.room.id, "library")
	assert_false(_castle.busy())
	_castle._process(0.4)
	assert_eq(_castle.room.id, "library")
	assert_true(_castle._title_card.is_showing())


func test_leaving_during_either_half_cancels_without_stale_switch():
	for switched: bool in [false, true]:
		_castle._leaving = false
		_castle.enter_room("campus")
		_start_door()
		if switched:
			_conceal_and_switch()
		var expected := _castle.room.id
		_castle._leaving = true
		_castle._process(0.5)
		assert_eq(_castle.room.id, expected)
		assert_false(_castle._fade_cover.visible)
		assert_true(_castle._fade_request.is_empty())
		_key(KEY_QUOTELEFT)
		assert_false(_castle._editor.active)
	_castle._leaving = false


func test_free_during_each_half_leaves_no_callbacks_or_viewport_input_lock():
	for switched: bool in [false, true]:
		_start_door()
		if switched:
			_conceal_and_switch()
		var before := Campaign.to_dict().duplicate(true)
		_castle.queue_free()
		await wait_process_frames(3)
		assert_false(is_instance_valid(_castle))
		assert_eq(Campaign.to_dict(), before)
		_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
		_viewport.add_child(_castle)
		_castle.set_process(false)
		_key(KEY_J)
		assert_not_null(_castle._journal, "new scene accepts native viewport input")
		_key(KEY_J)


func test_room_changed_listener_can_remove_castle_at_the_switch_boundary():
	_castle.room_changed.connect(func(_id: String): _viewport.remove_child(_castle), CONNECT_ONE_SHOT)
	_start_door()
	_conceal_and_switch()
	assert_false(_castle.is_inside_tree())
	assert_true(_castle._fade_request.is_empty())
	assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE)
	await wait_process_frames(3)
	assert_eq(_castle.room.id, "entrance")
	_viewport.add_child(_castle)
	_key(KEY_M)
	assert_not_null(_castle._room_map)


func test_excluded_physical_route_keeps_synchronous_behavior():
	var door := _door("grove")
	assert_not_null(door)
	_castle._avatar.position = _castle._grid.cell_center(door.cell)
	_castle._door_armed = true
	_castle._check_door()
	assert_eq(_castle.room.id, "grove")
	assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE)
	assert_false(_castle._fade_cover.visible)
	assert_eq(Campaign.academy_visits, ["campus"])


func test_external_synchronous_entry_at_concealment_supersedes_trip():
	_start_door()
	_castle._process(CastleScene.ROOM_FADE_HALF)
	_castle.enter_room("library")
	assert_eq(_castle.room.id, "library")
	assert_false(_castle.busy())
	assert_false(_castle._fade_cover.visible)
	_castle._process(0.5)
	assert_eq(_castle.room.id, "library")


func test_changed_destination_spawn_rejects_physical_and_travel_at_switch():
	for travel: bool in [false, true]:
		_castle.enter_room("entrance")
		_castle.enter_room("campus")
		if travel:
			_open_travel("entrance")
			_key(KEY_ENTER)
		else:
			_start_door()
		var before := Campaign.to_dict().duplicate(true)
		var original := _castle._rooms
		_castle._rooms = original.duplicate()
		var target: CastleRoomDef = original["entrance"].duplicate(true)
		target.chapter.terrain.fill(Terrain.Type.WALL)
		_castle._rooms["entrance"] = target
		var changed: Array[String] = []
		var receipt := func(id: String): changed.append(id)
		_castle.room_changed.connect(receipt)
		_conceal_and_switch()
		_reveal()
		assert_eq(changed.size(), 0, "invalid destination never rebuilds or emits")
		assert_eq(_castle.room.id, "campus")
		assert_eq(Campaign.to_dict(), before)
		_castle._rooms = original
		_castle._check_door()
		assert_eq(_castle._room_fade, CastleScene.RoomFade.IDLE, "rejected physical trip must re-arm before retry")
		_castle._process(0.5)
		assert_eq(_castle.room.id, "campus", "repaired data never retries the old request")
		_castle.room_changed.disconnect(receipt)
