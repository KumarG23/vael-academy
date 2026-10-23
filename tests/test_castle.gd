extends GutTest
## WO-9.1 (castle v2): top-down walkable rooms — bidirectional door graph,
## terrain collision, visible-door data, NPCs at cells, and the room
## functions carried over from v1.

var _castle: CastleScene
var _save_override_before: SaveSystem
var _castle_save_system: SaveSystem


func before_each() -> void:
	_save_override_before = Campaign.save_system_override
	_castle_save_system = null
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(_castle)


func after_each() -> void:
	Campaign.save_system_override = _save_override_before
	if _castle_save_system != null:
		var dir := DirAccess.open(_castle_save_system.save_dir)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			for child_name in dir.get_directories():
				DirAccess.remove_absolute(ProjectSettings.globalize_path(
					_castle_save_system.save_dir.path_join(child_name)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_castle_save_system.save_dir))


func _choose_escape_save() -> void:
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	_castle._unhandled_input(escape)
	assert_eq(_castle._menu_context, "system", "Escape opens the system menu")
	var confirm := InputEventAction.new()
	confirm.action = "cursor_confirm"
	confirm.pressed = true
	_castle._menu._unhandled_input(confirm)


func _activate_war_room_save() -> void:
	_castle.enter_room("war_room")
	for point in _castle.room.points:
		if point.id == "fn_save":
			_castle._avatar.position = _castle._grid.cell_center(point.cell)
			_castle._update_prompt()
			var interact := InputEventAction.new()
			interact.action = "ui_accept"
			interact.pressed = true
			_castle._unhandled_input(interact)
			return


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
	await wait_until(func(): return not _castle.busy(), 2.0)
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
		"emberwing_hall": "fn_rest", "waterside": "fn_fish", "entrance": "fn_house"}
	for rid in expect:
		var found := false
		for p in _castle._rooms[rid].points:
			if p.id == expect[rid]:
				found = true
		assert_true(found, "%s hosts %s" % [rid, expect[rid]])


## AW-46: every room must sit on a base the tile renderer actually has atlases
## for (PLAINS or FLOOR) — a FOREST base drew no grass and rendered GREY (the
## Sealed Grove bug). This guard stops any room shipping grey again.
func test_every_room_base_is_a_renderable_ground():
	for rid in _castle._rooms:
		var base: int = _castle._rooms[rid].chapter.base_terrain
		assert_true(base == Terrain.Type.PLAINS or base == Terrain.Type.FLOOR,
			"%s base terrain (%d) is grass or floor, not a bare/grey base" % [rid, base])


## AW-46: the Sealed Grove is grass now, and lush — a mix of tree types plus the
## Wardtree centrepiece.
func test_the_grove_is_grass_and_lush():
	var grove: CastleRoomDef = _castle._rooms["grove"]
	assert_eq(grove.chapter.base_terrain, Terrain.Type.PLAINS, "the grove floor is grass")
	var kinds := {}
	var has_wardtree := false
	for d in grove.chapter.decor:
		if d == null or d.texture == null:
			continue
		var f := d.texture.resource_path.get_file().get_basename()
		kinds[f] = true
		if f == "great_wardtree":
			has_wardtree = true
	assert_true(has_wardtree, "the pulsing Wardtree stands at its heart")
	var tree_types := 0
	for k in ["magic_tree", "pine_tree", "blossom_tree", "willow_tree", "dead_tree"]:
		if kinds.has(k):
			tree_types += 1
	assert_gte(tree_types, 4, "several kinds of tree fill the wood: " + str(kinds.keys()))


## AW-60: campus dress code — school uniform in term time, party wear on
## festival weeks; anyone without variant art falls back to the battle set.
func test_campus_variant_follows_the_calendar():
	Campaign.week = 1
	var normal := _castle._campus_variant()
	assert_eq(normal, "school", "term time = the school uniform")
	for e in Campaign.calendar():
		if e.kind == CalendarEventDef.Kind.HOLIDAY:
			Campaign.week = e.week
			assert_eq(_castle._campus_variant(), "party", "festival week = party wear")
			break
	Campaign.week = 1
	# no variant art installed for the warden -> resolve falls back to the root set
	assert_eq(Unit.resolve_sprite_dir("brenna", "school"),
		"res://assets/sprites/units/brenna", "missing variant art falls back safely")


## AW-47: per-area music — a room with its own track plays it; others fall back
## to the shared campus bed.
func test_rooms_can_have_their_own_music():
	assert_eq(_castle._music_for_room("library"),
		"res://assets/audio/music/rooms/library.mp3", "the library has its own theme")
	assert_eq(_castle._music_for_room("campus"),
		"res://assets/audio/music/campus_chill.mp3", "roomless areas play the campus bed")


## AW-49: activating a point through the REAL input path marks the input handled
## BEFORE acting — fn_arena swaps the scene mid-call, and the old order crashed on
## a null get_viewport() (Neal's arena-entry crash). The weekly-gated branch runs
## the same reordered path without actually swapping the test's scene.
func test_accept_keypress_at_a_point_is_input_safe():
	Campaign.flags["arena_used_this_week"] = true  # gate → toast, no scene change
	_castle.enter_room("arena_grounds", Vector2i(11, 15))
	_castle._avatar.position = _castle._grid.cell_center(Vector2i(11, 13))
	_castle._update_prompt()
	assert_eq(_castle._nearest_point.id, "fn_arena", "standing at the spire door")
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	_castle._unhandled_input(ev)  # the old order dereferenced a null viewport here
	assert_true(_castle._toast_label.visible, "the weekly gate answers with a toast")
	Campaign.flags.erase("arena_used_this_week")


## AW-47: y-sort occlusion — standing on a prop's NORTH side (feet above its
## base) and overlapping it puts the actor behind it; standing south is in front.
func test_actor_occludes_behind_a_tall_prop():
	_castle.enter_room("grove", Vector2i(10, 2))
	var grove: CastleRoomDef = _castle._rooms["grove"]
	var tree: MapDecor = null
	for d in grove.chapter.decor:
		if d != null and d.texture != null and d.texture.resource_path.contains("great_wardtree"):
			tree = d
	assert_not_null(tree, "the Wardtree is in the grove")
	var cs := float(_castle._grid.cell_size)
	# a cell well NORTH of (above) the trunk, overlapping the canopy → behind it
	var north := _castle._grid.cell_center(Vector2i(tree.cell.x, tree.cell.y - 4))
	assert_true(_castle._actor_behind_prop(north, tree, cs), "north of the trunk → drawn behind")
	# a cell SOUTH of (below) the base → in front of it
	var south := _castle._grid.cell_center(Vector2i(tree.cell.x, tree.cell.y + 4))
	assert_false(_castle._actor_behind_prop(south, tree, cs), "south of the base → drawn in front")


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


func test_castle_save_entry_points_report_real_io_and_allow_retry():
	_castle_save_system = SaveSystem.new("user://test_castle_saves_%d" % Time.get_ticks_usec())
	Campaign.save_system_override = _castle_save_system
	# The War Room save point goes through the castle's nearest-interaction input.
	_activate_war_room_save()
	assert_eq(_castle._toast_label.text, "Game saved.", "successful interaction confirms the write")
	assert_eq(_castle._menu_context, "", "the save point does not open a menu")

	# Retain ordinary JSON IO and byte-for-byte existing-save semantics. A directory
	# at the sibling .tmp path deterministically prevents opening the temp file.
	assert_true(_castle_save_system.save_slot(0, {"campaign": {"marker": "prior"}}))
	assert_true(_castle_save_system.save_slot(1, {"campaign": {"marker": "neighbor"}}))
	var prior_bytes := FileAccess.get_file_as_bytes(_castle_save_system.slot_path(0))
	var neighbor_bytes := FileAccess.get_file_as_bytes(_castle_save_system.slot_path(1))
	var live_campaign := Campaign.to_dict().duplicate(true)
	var stored_live_campaign: Dictionary = JSON.parse_string(JSON.stringify(live_campaign))
	var blocked_tmp := ProjectSettings.globalize_path(_castle_save_system.slot_path(0) + ".tmp")
	assert_eq(DirAccess.make_dir_recursive_absolute(blocked_tmp), OK)
	_activate_war_room_save()
	assert_eq(_castle._toast_label.text, "Save failed. Please try again.",
		"the War Room reports a failed ordinary slot write")
	assert_eq(FileAccess.get_file_as_bytes(_castle_save_system.slot_path(0)), prior_bytes,
		"failed save preserves slot 0 byte-for-byte")
	assert_eq(FileAccess.get_file_as_bytes(_castle_save_system.slot_path(1)), neighbor_bytes,
		"failed save leaves neighboring slots unchanged")
	assert_eq(Campaign.to_dict(), live_campaign, "failed save leaves live campaign state unchanged")
	DirAccess.remove_absolute(blocked_tmp)
	_activate_war_room_save()
	assert_eq(_castle._toast_label.text, "Game saved.", "the War Room save succeeds after retry")
	assert_eq(_castle_save_system.load_slot(0).get("campaign"), stored_live_campaign,
		"retry stores the current live campaign")
	assert_eq(FileAccess.get_file_as_bytes(_castle_save_system.slot_path(1)), neighbor_bytes)

	# Escape → system menu → its actual confirm input reaches the second handler.
	_choose_escape_save()
	assert_eq(_castle._menu_context, "", "the save choice dismisses the system menu")
	assert_eq(_castle._toast_label.text, "Game saved.", "the Escape save reports success")
	prior_bytes = FileAccess.get_file_as_bytes(_castle_save_system.slot_path(0))
	blocked_tmp = ProjectSettings.globalize_path(_castle_save_system.slot_path(0) + ".tmp")
	assert_eq(DirAccess.make_dir_recursive_absolute(blocked_tmp), OK)
	_choose_escape_save()
	assert_eq(_castle._toast_label.text, "Save failed. Please try again.",
		"the Escape save reports the failed ordinary slot write")
	assert_eq(_castle._menu_context, "", "failure still dismisses the system menu")
	assert_eq(FileAccess.get_file_as_bytes(_castle_save_system.slot_path(0)), prior_bytes,
		"failed Escape save preserves slot 0 byte-for-byte")
	assert_eq(FileAccess.get_file_as_bytes(_castle_save_system.slot_path(1)), neighbor_bytes)
	assert_eq(Campaign.to_dict(), live_campaign)
	DirAccess.remove_absolute(blocked_tmp)
	_choose_escape_save()
	assert_eq(_castle._toast_label.text, "Game saved.", "Escape save can be retried successfully")
	assert_eq(_castle_save_system.load_slot(0).get("campaign"), stored_live_campaign)
	assert_eq(FileAccess.get_file_as_bytes(_castle_save_system.slot_path(1)), neighbor_bytes)


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
	_castle.enter_room("emberwing_hall", Vector2i(7, 9))  # ON the exit door
	_castle._check_door()
	assert_eq(_castle.room.id, "emberwing_hall", "no instant bounce")


## AW-70: partner lists show where each bond stands.
func test_partner_labels_carry_bond_ranks():
	assert_eq(_castle._rank_tag("nobody_matches"), "", "no bond, no tag")
	_castle._support_state.add_points("kai", "liora", 25)  # past the C threshold (20)
	var tag := _castle._rank_tag("liora")
	assert_string_contains(tag, "[C]")


## AW-71: entering an area names it.
func test_area_title_card_shows_the_room_name():
	_castle.enter_room("grove", Vector2i(3, 3))
	assert_true(_castle._title_card.is_showing(), "the card is up")
	assert_string_contains(_castle._title_card._text, "The Sealed Grove")


## AW-76 (Codex finding #2): required battles can't be slept through — resting
## on a battle week refuses until the mission is answered.
func test_resting_through_a_battle_week_is_refused():
	Campaign.house_locked = true
	for e in Campaign.calendar():
		if e.kind == CalendarEventDef.Kind.BATTLE:
			Campaign.week = e.week
			break
	var before: int = Campaign.week
	_castle._rest_week()
	assert_eq(Campaign.week, before, "the week held")
	assert_true(_castle._toast_label.visible, "and the castle says why")
	Campaign.week = 1


## Resting out the first term lands on the Founding Festival: the report card
## and the festival must play one after the other, not stacked — and finishing
## the first must not tear down the second.
func test_term_close_and_festival_play_in_turn():
	Campaign.reset_new_game(false)
	Campaign.house_locked = true
	Campaign.week = Campaign.semester_end_week()
	_castle._rest_week()
	var e := Campaign.current_event()
	assert_true(e != null and e.kind == CalendarEventDef.Kind.HOLIDAY, "the new week is the festival")
	assert_eq(Campaign.semester, 2, "the term closed")
	var scenes := _dialogue_scenes()
	assert_eq(scenes.size(), 1, "one dialogue on screen at a time")
	var card := _castle._dialogue
	assert_not_null(card, "the report card plays first")
	assert_eq(_castle._dialogue_queue.size(), 1, "the festival waits its turn")
	card._finish()
	var festival := _castle._dialogue
	assert_not_null(festival, "the festival follows the ceremony")
	assert_ne(festival, card)
	assert_true(is_instance_valid(festival) and not festival.is_queued_for_deletion(),
		"finishing the card leaves the festival playing")
	assert_true(_castle._dialogue_queue.is_empty())
	festival._finish()
	assert_null(_castle._dialogue, "and the castle is free again")
	Campaign.reset_new_game(false)


func _dialogue_scenes() -> Array:
	var out: Array = []
	for c in _castle._ui.get_children():
		if c is DialogueScene and not c.is_queued_for_deletion():
			out.append(c)
	return out

