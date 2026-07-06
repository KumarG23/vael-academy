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
