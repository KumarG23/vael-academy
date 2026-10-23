extends GutTest
## GH-81: production room entry, modal input, data-derived safety, save isolation.

var _viewport: SubViewport
var _castle: CastleScene


func before_each() -> void:
	Campaign.reset_new_game(false, 8101)
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
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	for action: String in ["ui_up", "ui_down", "ui_left", "ui_right"]:
		Input.action_release(action)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	_viewport.push_input(event, true)


func _click(point: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.position = point
	_viewport.push_input(event, true)


## Fixture places the avatar one cell from an existing door; ordinary movement
## and the normal armed-door path earn the entry, without calling enter_room.
func _walk_through(target: String) -> void:
	for door: CastleDoor in _castle.room.doors:
		if door.to_room != target:
			continue
		var offsets: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]
		var actions: Array[String] = ["ui_up", "ui_down", "ui_right", "ui_left"]
		for i in range(offsets.size()):
			var start := door.cell + offsets[i]
			if not AcademyTravel.safe_cell(_castle.room, start, _castle._terrain_db):
				continue
			_castle._avatar.position = _castle._grid.cell_center(start)
			_castle._door_armed = false
			_castle._check_door()
			Input.action_press(actions[i])
			_castle._process(float(_castle._grid.cell_size) / CastleScene.WALK_SPEED)
			Input.action_release(actions[i])
			assert_eq(_castle.room.id, target, "ordinary movement crossed physical doorway")
			return
	fail_test("No usable physical door to " + target)


func _select(id: String) -> void:
	var map := _castle._room_map
	for i in range(map.destinations.size()):
		if map.destinations[map.selected].id == id:
			return
		_key(KEY_DOWN)
	fail_test("Destination absent: " + id)


func test_actual_entry_discovery_deduplication_and_excluded_rooms():
	assert_eq(Campaign.academy_visits, ["campus"])
	_key(KEY_M)
	assert_eq(_castle._room_map.destinations.size(), 1, "no undiscovered interiors")
	assert_eq(_castle._room_map.destinations[0].id, "campus")
	_key(KEY_ESCAPE)
	_walk_through("entrance")
	assert_eq(Campaign.academy_visits, ["campus", "entrance"])
	_walk_through("campus")
	assert_eq(Campaign.academy_visits, ["campus", "entrance"], "entry deduplicates")
	for id: String in ["grove", "vael_square"]:
		_castle.enter_room(id)
	assert_eq(Campaign.academy_visits, ["campus", "entrance"])


func test_cancel_current_room_keyboard_travel_state_invariance_and_continuation():
	_walk_through("entrance")
	Campaign.flags = {"gold": 43, "quest_fixture": true}
	Campaign.training_used = true
	var before := Campaign.to_dict().duplicate(true)
	var supports := _castle._support_state.save_state().duplicate(true)
	_key(KEY_M)
	_key(KEY_TAB)
	_select("entrance")
	var position := _castle._avatar.position
	var camera := _castle._camera.position
	_key(KEY_ENTER)
	assert_not_null(_castle._room_map, "current-room confirm is a no-op")
	assert_eq(_castle._avatar.position, position)
	assert_eq(_castle._camera.position, camera)
	_select("campus")
	_key(KEY_ESCAPE)
	assert_eq(_castle._avatar.position, position, "browsing and cancel never move")
	assert_eq(Campaign.to_dict(), before)
	_key(KEY_M)
	_key(KEY_TAB)
	_select("campus")
	_castle._nearest_point = _castle.room.points[0]
	_key(KEY_ENTER)
	assert_null(_castle._nearest_point, "previous room interaction invalidated synchronously")
	_key(KEY_ENTER)
	assert_null(_castle._room_map)
	assert_eq(_castle.room.id, "campus")
	var cell := _castle._grid.world_to_cell(_castle._avatar.position)
	assert_true(AcademyTravel.safe_cell(_castle.room, cell, _castle._terrain_db))
	assert_false(_castle._door_armed)
	assert_eq(Campaign.to_dict(), before, "whole campaign, training RNG, grades, resources and inventory unchanged")
	assert_eq(_castle._support_state.save_state(), supports)
	_castle._check_door()
	assert_eq(_castle.room.id, "campus", "safe arrival cannot bounce")
	_walk_through("entrance")
	assert_eq(Campaign.to_dict(), before, "ordinary continuation still deduplicates")
	_castle.enter_room("training")
	for point: CastlePoint in _castle.room.points:
		if point.id == "fn_train":
			_castle._avatar.position = _castle._grid.cell_center(point.cell)
	_castle._update_prompt()
	_key(KEY_ENTER)
	assert_eq(_castle._menu_context, "training", "ordinary activity input continues")


func test_pointer_switch_selection_confirm_and_compact_destination_bounds():
	_walk_through("entrance")
	var position := _castle._avatar.position
	_key(KEY_M)
	_click(Vector2(10, 10), MOUSE_BUTTON_RIGHT)
	assert_null(_castle._room_map)
	assert_eq(_castle._avatar.position, position, "pointer cancel never moves")
	_key(KEY_M)
	await wait_process_frames(2)
	_click(_castle._room_map._switch.get_global_rect().get_center())
	assert_true(_castle._room_map.showing_destinations)
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(800, 450)]:
		_viewport.size = dimensions
		await wait_process_frames(3)
		var map := _castle._room_map
		assert_false(map.map_rect.intersects(map._exits.get_global_rect()))
		assert_true(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(map._exits.get_global_rect()))
		var font := map._legend.get_theme_font("font")
		assert_lte(font.get_multiline_string_size(map._legend.text, HORIZONTAL_ALIGNMENT_LEFT, map._legend.size.x, 14).y, map._legend.size.y)
	var map := _castle._room_map
	for i in range(map.destinations.size()):
		if map.destinations[i].id == "campus":
			_click(map._destination_labels[i].get_global_rect().get_center())
			break
	assert_eq(_castle.room.id, "campus")
	assert_null(_castle._room_map)


func test_unknown_disconnected_and_broken_arrival_fail_without_partial_transition():
	_walk_through("entrance")
	_key(KEY_M)
	var map := _castle._room_map
	var before := Campaign.to_dict().duplicate(true)
	var position := _castle._avatar.position
	_castle._travel_to("library")
	_castle._travel_to("unknown_room")
	assert_eq(_castle.room.id, "entrance")
	# Duplicate resources so this failure fixture cannot edit cached production data.
	var rooms := _castle._rooms.duplicate()
	var campus: CastleRoomDef = rooms["campus"].duplicate(true)
	campus.chapter.terrain.fill(Terrain.Type.WALL)
	_castle._rooms = rooms.duplicate()
	_castle._rooms["campus"] = campus
	_castle._travel_to("campus")
	assert_eq(_castle._room_map, map)
	assert_eq(_castle._avatar.position, position)
	assert_eq(Campaign.to_dict(), before)
	campus.doors = []
	assert_eq(AcademyTravel.arrival({"entrance": _castle.room, "campus": campus}, "campus", "entrance", _castle._terrain_db), Vector2i(-1, -1), "no connecting door")
	_castle._rooms = rooms
	var destinations := _castle._travel_destinations()
	assert_eq(destinations.size(), 2)


func test_all_current_public_destinations_have_safe_authored_arrivals():
	var rooms := AcademyTravel.public_rooms()
	for id: String in AcademyTravel.reachable(rooms, "campus"):
		var arrival := AcademyTravel.arrival(rooms, "campus", id, _castle._terrain_db)
		assert_ne(arrival, Vector2i(-1, -1), id)
		assert_true(AcademyTravel.safe_cell(rooms[id], arrival, _castle._terrain_db), id)


func test_legacy_load_earns_only_normal_current_entry():
	var legacy := Campaign.to_dict()
	legacy.erase("academy_visits")
	assert_true(Campaign.restore_save(legacy))
	assert_eq(Campaign.academy_visits.size(), 0)
	_castle.enter_room("library")
	assert_eq(Campaign.academy_visits, ["library"])
	_key(KEY_M)
	assert_eq(_castle._room_map.destinations.size(), 1)
	assert_eq(_castle._room_map.destinations[0].id, "library")


func test_fresh_process_title_and_journal_load_callbacks_preserve_earned_visits():
	for route: String in ["title", "journal"]:
		var output: Array = []
		var result := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"-s", "res://tests/fixtures/academy_visit_load.gd", "--", route], output, true)
		assert_eq(result, 0, str(output))
		assert_string_contains(str(output), "Academy visit callback: %s passed" % route)


func test_compact_long_earned_destination_list_scrolls_and_wraps_without_world_changes():
	for id: String in AcademyTravel.public_rooms():
		_castle.enter_room(id)
	_castle.enter_room("campus")
	_viewport.size = Vector2i(640, 360)
	_key(KEY_M)
	_key(KEY_TAB)
	await wait_process_frames(3)
	var map := _castle._room_map
	var campaign := Campaign.to_dict().duplicate(true)
	var position := _castle._avatar.position
	assert_gt(map.destinations.size(), 10, "real earned list exceeds compact height")
	_key(KEY_UP)
	await wait_process_frames(2)
	assert_eq(map.selected, map.destinations.size() - 1)
	assert_gt(map._exits.scroll_vertical, 0)
	assert_true(map._exits.get_global_rect().intersects(map._destination_labels.back().get_global_rect()))
	_key(KEY_DOWN)
	await wait_process_frames(2)
	assert_eq(map.selected, 0)
	assert_true(map._exits.get_global_rect().intersects(map._destination_labels[0].get_global_rect()))
	_key(KEY_ESCAPE)
	assert_eq(Campaign.to_dict(), campaign)
	assert_eq(_castle._avatar.position, position)


func test_blocked_existing_door_is_an_access_gate_even_for_an_earned_room():
	_walk_through("entrance")
	_key(KEY_M)
	var map := _castle._room_map
	var before := Campaign.to_dict().duplicate(true)
	var position := _castle._avatar.position
	var original := _castle._rooms
	var source: CastleRoomDef = _castle.room.duplicate(true)
	for door: CastleDoor in source.doors:
		source.chapter.set_terrain(door.cell.x, door.cell.y, Terrain.Type.WALL)
	_castle._rooms = {"entrance": source, "campus": original["campus"]}
	_castle._travel_to("campus")
	assert_eq(_castle._room_map, map, "blocked physical doors cannot be bypassed")
	assert_eq(_castle.room.id, "entrance")
	assert_eq(_castle._avatar.position, position)
	assert_eq(Campaign.to_dict(), before)
	var eligible := _castle._travel_destinations()
	for destination: CastleRoomDef in eligible:
		assert_ne(destination.id, "campus", "currently gated visit is omitted")
	_castle._rooms = original
