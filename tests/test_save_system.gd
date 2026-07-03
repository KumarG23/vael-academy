extends GutTest
## WO-3.3: pure JSON save-slot IO.


func test_save_load_and_list_slot():
	var saves := SaveSystem.new("user://test_saves_%d" % Time.get_ticks_usec())
	var payload := {
		"campaign": {"current_chapter_id": "test_map", "casual_mode": true},
		"battle": {"round_number": 2},
	}

	assert_true(saves.save_slot(1, payload), "slot writes")
	assert_true(saves.has_slot(1), "slot exists")

	var loaded := saves.load_slot(1)
	assert_eq(int(loaded["version"]), SaveSystem.VERSION)
	assert_eq(int(loaded["slot"]), 1)
	assert_eq(loaded["campaign"]["current_chapter_id"], "test_map")
	assert_true(bool(loaded["campaign"]["casual_mode"]))

	var slots := saves.list_slots(3)
	assert_eq(slots.size(), 1)
	assert_eq(int(slots[0]["slot"]), 1)
	assert_eq(slots[0]["chapter_id"], "test_map")
