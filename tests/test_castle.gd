extends GutTest
## WO-6.1: the walkable castle shell — rooms load, doors carry between rooms
## both ways, and interaction spots trigger.

var _castle: CastleScene


func before_each() -> void:
	CastleScene.next_room = ""
	CastleScene.next_spawn_x = -1.0
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(_castle)


func test_starts_in_the_entrance_hall():
	assert_eq(_castle.room.id, "entrance")
	assert_not_null(_castle.room.backdrop, "the painted backdrop is wired")


func test_every_exit_leads_to_a_real_room_and_back():
	for rid in _castle._rooms:
		var r: RoomDef = _castle._rooms[rid]
		for e in r.exits:
			assert_true(_castle._rooms.has(e.to_room), "%s -> %s exists" % [rid, e.to_room])
			var target: RoomDef = _castle._rooms[e.to_room]
			var back := false
			for e2 in target.exits:
				if e2.to_room == rid:
					back = true
			assert_true(back, "%s <- %s returns" % [rid, e.to_room])


func test_doors_carry_between_rooms():
	var events: Array = []
	_castle.room_changed.connect(func(id): events.append(id))
	_castle.enter_room("common_hall", 0.5)
	assert_eq(_castle.room.id, "common_hall")
	assert_eq(events, ["common_hall"])


func test_spot_activation_triggers():
	_castle.enter_room("library", 0.5)
	var hits: Array = []
	_castle.spot_activated.connect(func(id): hits.append(id))
	var vp := _castle.get_viewport_rect().size
	_castle._avatar_pos = Vector2(vp.x * 0.5, vp.y * 0.8)
	_castle._update_prompt(vp)
	_castle.activate_nearest()
	assert_eq(hits, ["lore_shelf"])


func test_all_spot_dialogues_exist():
	for rid in _castle._rooms:
		for s in _castle._rooms[rid].spots:
			if s.dialogue != "":
				assert_true(FileAccess.file_exists(s.dialogue), s.id)


# --- WO-6.2a: room functions -------------------------------------------------

func test_function_spots_live_in_their_rooms():
	var expect := {"training": "fn_train", "war_room": "fn_deploy",
		"common_hall": "fn_supports"}
	for rid in expect:
		var found := false
		for s in _castle._rooms[rid].spots:
			if s.id == expect[rid]:
				found = true
		assert_true(found, "%s hosts %s" % [rid, expect[rid]])


func test_training_from_the_castle_grants_xp():
	Campaign.reset_new_game(false)
	Campaign.begin_hub_visit()
	var first: UnitDef = _castle._roster_defs[0]
	_castle._open_training()
	assert_eq(_castle._menu_context, "training")
	_castle._do_train(0)
	assert_eq(int(Campaign.get_unit_state(first.id).get("xp", -1)), 10)
	assert_false(Campaign.can_train(), "one training per visit, castle edition")
	Campaign.reset_new_game(false)


func test_mission_menu_opens_and_stand_down_closes():
	_castle._open_function("fn_deploy")
	assert_eq(_castle._menu_context, "mission")
	_castle._do_mission(1)  # stand down
	assert_eq(_castle._menu_context, "", "menu released")
	assert_false(Campaign.active, "no deploy on stand-down")


func test_system_menu_replaces_leave():
	_castle._open_system_menu()
	assert_eq(_castle._menu_context, "system")
	_castle._do_system(2)  # Back
	assert_eq(_castle._menu_context, "")


# --- WO-6.2b: remaining rooms --------------------------------------------------

func test_quartermaster_inspects_units():
	_castle._open_function("fn_roster")
	assert_eq(_castle._menu_context, "quarter")
	_castle._inspect_unit(0)
	assert_not_null(_castle._stats_panel, "the stats panel opened")


func test_house_oath_from_the_entrance():
	_castle._open_function("fn_house")
	assert_eq(_castle._menu_context, "house")
	_castle._choose_house(1)
	assert_eq(Campaign.house_id, "tidemark")
	Campaign.set_house("emberwing")


# --- WO-6.3: NPCs in rooms -----------------------------------------------------

func test_three_npcs_stand_in_their_rooms():
	var npcs := {}
	for rid in _castle._rooms:
		for s in _castle._rooms[rid].spots:
			if s.npc_unit != "":
				npcs[s.npc_unit] = rid
				assert_true(FileAccess.file_exists(s.dialogue), s.npc_unit + " talks")
	assert_gte(npcs.size(), 3, "at least three housemates placed: " + str(npcs))


func test_npc_sprites_spawn_with_the_room():
	_castle.enter_room("training", 0.5)
	assert_gt(_castle._npc_sprites.size(), 0, "Brenna stands at the grounds")


func test_support_scene_launches_from_the_castle():
	Campaign.support_save = {"points": {"kai_kael": 25}, "ranks": {"kai_kael": "C"}, "viewed": {}}
	var c2: CastleScene = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(c2)
	c2._open_hall_archive()
	assert_eq(c2._menu_context, "hall")
	assert_gt(c2._hall_entries.size(), 0, "the C scene is unlocked")
	c2._view_hall_entry(0)
	assert_not_null(c2._dialogue, "the support scene is playing in the castle")
	Campaign.support_save = {}
