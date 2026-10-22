extends GutTest
## WO-3.3: pure JSON save-slot IO.

var _regression_saves: Array[SaveSystem] = []


func after_each() -> void:
	for saves in _regression_saves:
		var dir := DirAccess.open(saves.save_dir)
		if dir != null:
			for file_name in dir.get_files():
				dir.remove(file_name)
			# The replacement-failure test deliberately blocks a slot with a directory.
			for child_name in dir.get_directories():
				var child := DirAccess.open(saves.save_dir.path_join(child_name))
				for file_name in child.get_files():
					child.remove(file_name)
				dir.remove(child_name)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))
	_regression_saves.clear()


func _new_regression_saves() -> SaveSystem:
	var saves := SaveSystem.new("user://test_save_regression_%d_%d" % [
		Time.get_ticks_usec(), _regression_saves.size()])
	_regression_saves.append(saves)
	return saves


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


func test_list_slots_tolerates_malformed_campaign_sections():
	var saves := SaveSystem.new("user://test_malformed_saves_%d" % Time.get_ticks_usec())
	for invalid in [null, [], "broken", 42, true]:
		assert_true(saves.save_slot(0, {"campaign": invalid}))
		var slots := saves.list_slots(1)
		assert_eq(slots.size(), 1, "the occupied slot remains visible")
		if slots.size() == 1:
			assert_eq(slots[0]["chapter_id"], "")
			assert_false(slots[0]["casual_mode"])
			assert_false(slots[0]["in_battle"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))


func test_corrupt_files_load_safely_without_rewriting_or_hiding_other_slots():
	var saves := _new_regression_saves()
	assert_true(saves.save_slot(1, {"campaign": {"chapter_id": "mock_battle"}}))
	var healthy_bytes := FileAccess.get_file_as_bytes(saves.slot_path(1))
	# Write directly: save_slot always produces a dictionary, so cannot exercise
	# damaged JSON or a valid JSON value of the wrong top-level type.
	for raw in ["", "{\"campaign\":", "null", "[]", "\"broken\"", "42", "true"]:
		var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
		assert_not_null(file)
		if file == null:
			return
		file.store_string(raw)
		file.close()
		assert_eq(saves.load_slot(0), {}, "invalid save data is not a payload: %s" % raw)
		var slots := saves.list_slots(2)
		assert_eq(slots.size(), 2, "the occupied corrupt slot and healthy neighbor remain visible")
		if slots.size() == 2:
			assert_eq(slots[0], {"slot": 0, "version": 0, "in_battle": false,
				"chapter_id": "", "casual_mode": false}, "safe metadata for corrupt data")
			assert_eq(slots[1]["slot"], 1)
			assert_eq(slots[1]["chapter_id"], "mock_battle")
		assert_eq(FileAccess.get_file_as_string(saves.slot_path(0)), raw,
			"browsing and loading do not repair or erase the corrupt file")
		assert_eq(FileAccess.get_file_as_bytes(saves.slot_path(1)), healthy_bytes,
			"the neighboring save stays intact")
	assert_false(saves.has_slot(2))
	assert_eq(saves.load_slot(2), {}, "a missing slot loads safely")
	assert_false(saves.has_slot(2), "reading a missing slot does not create it")


func test_slot_metadata_distinguishes_live_finished_and_malformed_battles():
	var saves := _new_regression_saves()
	var cases := [
		{"battle": null, "live": false},
		{"battle": [], "live": false},
		{"battle": "broken", "live": false},
		{"battle": 42, "live": false},
		{"battle": true, "live": false},
		{"battle": {}, "live": false},
		{"battle": {"round_number": 2}, "live": true},
		{"battle": {"round_number": 2, "battle_over": false}, "live": true},
		{"battle": {"round_number": 2, "battle_over": true}, "live": false},
	]
	for case in cases:
		assert_true(saves.save_slot(0, {
			"campaign": {"current_chapter_id": "prologue", "chapter_id": "mock_battle",
				"casual_mode": false, "casual": true},
			"battle": case["battle"],
		}))
		var slots := saves.list_slots(1)
		assert_eq(slots.size(), 1)
		if slots.size() == 1:
			assert_eq(slots[0]["in_battle"], case["live"], "battle metadata: %s" % [case["battle"]])
			assert_eq(slots[0]["chapter_id"], "prologue", "battle chapter metadata takes precedence")
			assert_false(slots[0]["casual_mode"], "explicit Classic overrides the legacy Casual key")


func test_save_snapshot_does_not_mutate_or_share_the_callers_nested_payload():
	var saves := _new_regression_saves()
	var payload := {
		"campaign": {"flags": {"opening_started": true}, "fish_log": ["lakeperch"]},
		"battle": {"units": [{"id": "kai", "current_hp": 9}]},
	}
	var before := payload.duplicate(true)
	# JSON decodes numbers as floats; compare nested state in its stored form.
	var stored_before: Dictionary = JSON.parse_string(JSON.stringify(before))
	assert_true(saves.save_slot(0, payload))
	assert_eq(payload, before, "save metadata is added to a copy of the caller's payload")
	assert_false(payload.has("slot"))
	assert_false(payload.has("version"))
	payload["campaign"]["flags"]["opening_started"] = false
	payload["campaign"]["fish_log"].append("silver_dace")
	payload["battle"]["units"][0]["current_hp"] = 1
	var loaded := saves.load_slot(0)
	assert_eq(loaded.get("campaign"), stored_before["campaign"], "later campaign edits cannot change the save")
	assert_eq(loaded.get("battle"), stored_before["battle"], "later battle edits cannot change the save")
	loaded["campaign"]["flags"].clear()
	loaded["battle"]["units"].clear()
	var reloaded := saves.load_slot(0)
	assert_eq(reloaded.get("campaign"), stored_before["campaign"], "editing loaded data does not rewrite the slot")
	assert_eq(reloaded.get("battle"), stored_before["battle"])


func test_failed_slot_replacement_cleans_temp_file_and_preserves_neighbor():
	var saves := _new_regression_saves()
	assert_true(saves.save_slot(1, {"campaign": {"chapter_id": "mock_battle"}}))
	var neighbor_bytes := FileAccess.get_file_as_bytes(saves.slot_path(1))
	# Unlike a blocked temp path, this allows the write and fails the final rename.
	var blocked_path := saves.slot_path(0)
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocked_path)), OK)
	var marker_path := blocked_path.path_join("keep.txt")
	var marker := FileAccess.open(marker_path, FileAccess.WRITE)
	assert_not_null(marker)
	if marker == null:
		return
	marker.store_string("keep")
	marker.close()
	assert_false(saves.save_slot(0, {"campaign": {"chapter_id": "prologue"}}),
		"failure to replace the destination is reported")
	assert_false(FileAccess.file_exists(blocked_path + ".tmp"), "failed replacement removes the temporary save")
	assert_eq(FileAccess.get_file_as_string(marker_path), "keep", "the blocking destination is preserved")
	assert_eq(FileAccess.get_file_as_bytes(saves.slot_path(1)), neighbor_bytes,
		"a failed replacement never touches another save slot")


func test_list_slots_accepts_campaign_save_metadata():
	var saves := SaveSystem.new("user://test_campaign_metadata_%d" % Time.get_ticks_usec())
	assert_true(saves.save_slot(0, {"campaign": {"chapter_id": "mock_battle", "casual": true}}))
	var slots := saves.list_slots(1)
	assert_eq(slots.size(), 1)
	if slots.size() == 1:
		assert_eq(slots[0]["chapter_id"], "mock_battle")
		assert_true(slots[0]["casual_mode"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))


func test_overwrite_replaces_slot_without_leaving_temp_file():
	var saves := SaveSystem.new("user://test_overwrite_saves_%d" % Time.get_ticks_usec())
	assert_true(saves.save_slot(0, {"campaign": {"chapter_id": "first"}}))
	assert_true(saves.save_slot(0, {"campaign": {"chapter_id": "second"}}))
	assert_eq(saves.load_slot(0)["campaign"]["chapter_id"], "second")
	assert_false(FileAccess.file_exists(saves.slot_path(0) + ".tmp"),
		"the temp file is swapped in, not left behind")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))


func test_failed_write_keeps_previous_save_intact():
	var saves := SaveSystem.new("user://test_failed_write_saves_%d" % Time.get_ticks_usec())
	assert_true(saves.save_slot(0, {"campaign": {"chapter_id": "kept"}}))
	# A directory squatting on the temp path makes the new write fail.
	var tmp_abs := ProjectSettings.globalize_path(saves.slot_path(0) + ".tmp")
	assert_eq(DirAccess.make_dir_recursive_absolute(tmp_abs), OK)
	assert_false(saves.save_slot(0, {"campaign": {"chapter_id": "lost"}}),
		"the failed write reports failure")
	assert_eq(saves.load_slot(0).get("campaign", {}).get("chapter_id"), "kept",
		"the player's existing save survives a failed write")
	DirAccess.remove_absolute(tmp_abs)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))


func test_list_slots_tolerates_wrongly_typed_metadata():
	var saves := SaveSystem.new("user://test_typed_metadata_%d" % Time.get_ticks_usec())
	assert_true(saves.save_slot(0, {
		"version": null,
		"campaign": {"current_chapter_id": null, "chapter_id": "fallback",
			"casual_mode": "yes", "casual": true},
		"battle": {"round_number": 1, "battle_over": null},
	}))
	assert_eq(int(saves.load_slot(0)["version"]), SaveSystem.VERSION,
		"a null version is stamped with the current one")
	var slots := saves.list_slots(1)
	assert_eq(slots.size(), 1)
	if slots.size() == 1:
		assert_eq(slots[0]["version"], SaveSystem.VERSION)
		assert_eq(slots[0]["chapter_id"], "fallback", "skips the null chapter key")
		assert_true(slots[0]["casual_mode"], "skips the non-bool casual key")
		assert_true(slots[0]["in_battle"], "a null battle_over is not a finished fight")

	assert_true(saves.save_slot(0, {"version": {}, "campaign": {"current_chapter_id": 7}}))
	slots = saves.list_slots(1)
	assert_eq(slots.size(), 1)
	if slots.size() == 1:
		assert_eq(slots[0]["version"], SaveSystem.VERSION)
		assert_eq(slots[0]["chapter_id"], "", "a numeric chapter id is not shown")
		assert_false(slots[0]["casual_mode"])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))
