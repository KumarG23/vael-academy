extends GutTest
## WO-9.1 (castle v2): top-down walkable rooms — bidirectional door graph,
## terrain collision, visible-door data, NPCs at cells, and the room
## functions carried over from v1.

var _castle: CastleScene


func before_each() -> void:
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(_castle)


func test_starts_on_the_campus():
	assert_eq(_castle.room.id, "campus")
	assert_gt(_castle.room.chapter.width, 22, "the campus is bigger than a screen")


func test_every_door_leads_somewhere_real_and_back():
	for rid in _castle._rooms:
		var r: CastleRoomDef = _castle._rooms[rid]
		for d in r.doors:
			assert_true(_castle._rooms.has(d.to_room), "%s -> %s exists" % [rid, d.to_room])
			var target: CastleRoomDef = _castle._rooms[d.to_room]
			var back := false
			for d2 in target.doors:
				if d2.to_room == rid:
					back = true
			assert_true(back, "%s <- %s returns" % [rid, d.to_room])


func test_door_cells_and_spawns_are_walkable():
	var db := TerrainDB.create_default()
	for rid in _castle._rooms:
		var r: CastleRoomDef = _castle._rooms[rid]
		for d in r.doors:
			assert_false(db.is_impassable(r.chapter.get_terrain(d.cell.x, d.cell.y)),
				"%s door at %s walkable" % [rid, d.cell])
			var target: CastleRoomDef = _castle._rooms[d.to_room]
			assert_false(db.is_impassable(target.chapter.get_terrain(d.spawn_cell.x, d.spawn_cell.y)),
				"%s spawn %s walkable" % [d.to_room, d.spawn_cell])


func test_walking_into_a_door_changes_rooms():
	var events: Array = []
	_castle.room_changed.connect(func(id): events.append(id))
	var door: CastleDoor = _castle.room.doors[0]
	_castle._door_armed = true  # as after any real step off a doorway
	_castle._avatar.position = _castle._grid.cell_center(door.cell)
	_castle._check_door()
	assert_eq(_castle.room.id, door.to_room, "walk-in transition, no button")
	assert_eq(events.size(), 1)


func test_walls_block_movement():
	_castle.enter_room("entrance", Vector2i(11, 11))
	assert_false(_castle._walkable(_castle._grid.cell_center(Vector2i(0, 0))), "wall blocks")
	assert_true(_castle._walkable(_castle._grid.cell_center(Vector2i(11, 11))), "floor walks")


func test_points_prompt_within_radius_and_activate():
	_castle.enter_room("library", Vector2i(9, 10))
	var hits: Array = []
	_castle.spot_activated.connect(func(id): hits.append(id))
	var shelf: CastlePoint = null
	for p in _castle.room.points:
		if p.id == "lore_shelf":
			shelf = p
	_castle._avatar.position = _castle._grid.cell_center(shelf.cell) + Vector2(60, 0)
	_castle._update_prompt()
	assert_not_null(_castle._nearest_point)
	_castle.activate_nearest()
	assert_eq(hits, ["lore_shelf"])


func test_npcs_stand_in_their_rooms():
	var npcs := {}
	for rid in _castle._rooms:
		for p in _castle._rooms[rid].points:
			if p.npc_unit != "":
				npcs[p.npc_unit] = rid
				assert_true(FileAccess.file_exists(p.dialogue), p.npc_unit + " talks")
	assert_gte(npcs.size(), 3, "at least three housemates placed: " + str(npcs))
	_castle.enter_room("training", Vector2i(2, 6))
	assert_gt(_castle._npc_sprites.size(), 0, "Brenna stands at the grounds")


# --- room functions (ported from v1 — same handlers) ----------------------------

func test_function_points_live_in_their_rooms():
	var expect := {"training": "fn_train", "war_room": "fn_deploy",
		"common_hall": "fn_supports", "quartermaster": "fn_roster",
		"dorm_hall": "fn_rest", "waterside": "fn_fish", "entrance": "fn_house"}
	for rid in expect:
		var found := false
		for p in _castle._rooms[rid].points:
			if p.id == expect[rid]:
				found = true
		assert_true(found, "%s hosts %s" % [rid, expect[rid]])


## AW-45: the Arena is its own sub-area (the Trial Spire) reached from the
## Training Grounds, not a building tucked on the campus lawn.
func test_arena_is_its_own_sub_area_off_the_training_yard():
	assert_true(_castle._rooms.has("arena_grounds"), "the Trial Spire has its own map")
	# the arena-entry function point lives in the grounds now, not on the campus
	var grounds_has_entry := false
	for p in _castle._rooms["arena_grounds"].points:
		if p.id == "fn_arena":
			grounds_has_entry = true
	assert_true(grounds_has_entry, "you enter the arena from inside the grounds")
	for p in _castle._rooms["campus"].points:
		assert_ne(p.id, "fn_arena", "the campus no longer hosts the arena directly")
	# the training yard gates through to the grounds, and the grounds gate back
	var train_to_arena := false
	for d in _castle._rooms["training"].doors:
		if d.to_room == "arena_grounds":
			train_to_arena = true
	assert_true(train_to_arena, "the training yard opens onto the Trial Spire")
	var arena_to_train := false
	for d in _castle._rooms["arena_grounds"].doors:
		if d.to_room == "training":
			arena_to_train = true
	assert_true(arena_to_train, "and the grounds lead back to the yard")


func test_training_from_the_castle_grants_xp():
	Campaign.reset_new_game(false)
	Campaign.begin_hub_visit()
	var first: UnitDef = _castle._roster_defs[0]
	_castle._open_training()
	assert_eq(_castle._menu_context, "training")
	_castle._do_train(0)
	assert_eq(int(Campaign.get_unit_state(first.id).get("xp", -1)), 10)
	assert_false(Campaign.can_train())
	Campaign.reset_new_game(false)


func test_mission_menu_and_system_menu():
	Campaign.week = 1
	_castle._open_function("fn_deploy")
	assert_eq(_castle._menu_context, "mission")
	_castle._do_mission(1)
	assert_eq(_castle._menu_context, "")
	_castle._open_system_menu()
	_castle._do_system(2)
	assert_eq(_castle._menu_context, "")


func test_quartermaster_and_house_oath():
	_castle._open_function("fn_roster")
	_castle._inspect_unit(0)
	assert_not_null(_castle._stats_panel)
	_castle._close_menu()
	_castle._open_function("fn_house")
	_castle._choose_house(1)
	assert_eq(Campaign.house_id, "tidemark")
	assert_true(Campaign.house_locked, "the oath binds (FE3H rule)")
	Campaign.set_house("thornrook")
	assert_eq(Campaign.house_id, "tidemark", "locked — no house hopping")
	Campaign.house_locked = false
	Campaign.set_house("emberwing")


func test_support_scene_launches_from_the_castle():
	Campaign.support_save = {"points": {"kai_kael": 25}, "ranks": {"kai_kael": "C"}, "viewed": {}}
	var c2: CastleScene = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(c2)
	c2._open_hall_archive()
	assert_gt(c2._hall_entries.size(), 0)
	c2._view_hall_entry(0)
	assert_not_null(c2._dialogue)
	Campaign.support_save = {}


func test_spawning_on_a_door_cannot_bounce_back():
	# the dorm-loop bug: doors stay disarmed until you step off them
	_castle.enter_room("dorm_hall", Vector2i(0, 4))  # ON the exit door
	_castle._check_door()
	assert_eq(_castle.room.id, "dorm_hall", "no instant bounce")
