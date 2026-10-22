extends GutTest
## Only nonempty string flag names from current campaign playback may write.


func before_each() -> void:
	Campaign.reset_new_game(true)
	Campaign.active = true
	Campaign.flags["existing_progress"] = true
	Campaign.set_unit_state("kai", {"level": 2, "xp": 17})


func after_each() -> void:
	Campaign.reset_new_game(false)


func _start_opening(campaign_opening: bool = true) -> PrologueVN:
	var vn := PrologueVN.new()
	vn.campaign_opening = campaign_opening
	vn.exit_scene = ""
	add_child_autofree(vn)
	assert_eq(vn.load_error, "")
	assert_eq(vn._i, 0)
	assert_false(vn._ended)
	return vn


func test_malformed_flag_params_leave_active_campaign_and_playback_unchanged() -> void:
	var vn := _start_opening()
	var before := Campaign.to_dict()
	var was_active: bool = Campaign.active
	var script_index: int = vn._i
	var dialogue_index: int = vn._dialogue._index
	var invalid_params: Array[Dictionary] = [
		{}, {"flag": null}, {"flag": []}, {"flag": ["kai_awakened"]},
		{"flag": {}}, {"flag": {"name": "kai_awakened"}},
		{"flag": 0}, {"flag": 42}, {"flag": 1.5},
		{"flag": true}, {"flag": false}, {"flag": ""},
		{"flag": "   "}, {"flag": "\t\r\n"},
	]
	for params: Dictionary in invalid_params:
		vn._dialogue.event_triggered.emit("set_flag", params)
		assert_eq(Campaign.to_dict(), before, "invalid params must not write: %s" % [params])
		assert_eq(Campaign.active, was_active)
		assert_eq(vn._i, script_index)
		assert_eq(vn._dialogue._index, dialogue_index)
	assert_false(vn._ended)
	# Positive control: ignored malformed events must leave valid callbacks usable.
	vn._dialogue.event_triggered.emit("set_flag", {"flag": "kai_awakened"})
	before["flags"]["kai_awakened"] = true
	assert_eq(Campaign.to_dict(), before, "valid event sets exactly its named flag")
	assert_eq(Campaign.active, was_active)
	assert_eq(vn._i, script_index)
	assert_eq(vn._dialogue._index, dialogue_index)


func test_valid_string_flag_name_is_preserved_verbatim() -> void:
	var vn := _start_opening()
	var before := Campaign.to_dict()
	var flag_name: String = "  kai_awakened\t"
	vn._dialogue.event_triggered.emit("set_flag", {"flag": flag_name})
	before["flags"][flag_name] = true
	assert_eq(Campaign.to_dict(), before, "validation must not normalize nonempty names")
	assert_true(Campaign.flags.has(flag_name))
	assert_false(Campaign.flags.has("kai_awakened"))


func test_other_event_names_cannot_set_flags() -> void:
	var vn := _start_opening()
	var before := Campaign.to_dict()
	for event_name: String in ["", "give_item", "SET_FLAG", " set_flag "]:
		vn._dialogue.event_triggered.emit(event_name, {"flag": "kai_awakened"})
		vn._dialogue.event_triggered.emit(event_name, {})
	assert_eq(Campaign.to_dict(), before)
	assert_true(Campaign.active)


func test_preview_ignores_valid_and_malformed_flag_events() -> void:
	var vn := _start_opening(false)
	var before := Campaign.to_dict()
	var dialogue_index: int = vn._dialogue._index
	for params: Dictionary in [{"flag": "kai_awakened"}, {}, {"flag": null}, {"flag": []}]:
		vn._dialogue.event_triggered.emit("set_flag", params)
	assert_eq(Campaign.to_dict(), before, "preview callbacks cannot write campaign flags")
	assert_true(Campaign.active)
	assert_eq(vn._i, 0)
	assert_eq(vn._dialogue._index, dialogue_index)


func test_reset_campaign_rejects_stale_valid_and_malformed_flag_events() -> void:
	var vn := _start_opening()
	Campaign.reset_new_game(true)
	_assert_stale_flag_events_ignored(vn)


func test_loaded_campaign_rejects_stale_valid_and_malformed_flag_events() -> void:
	var vn := _start_opening()
	Campaign.from_dict(Campaign.to_dict())
	_assert_stale_flag_events_ignored(vn)


func _assert_stale_flag_events_ignored(vn: PrologueVN) -> void:
	var before := Campaign.to_dict()
	var was_active: bool = Campaign.active
	var flags: Dictionary = Campaign.flags
	var dialogue_index: int = vn._dialogue._index
	for params: Dictionary in [{"flag": "kai_awakened"}, {}, {"flag": null}, {"flag": 42}]:
		vn._dialogue.event_triggered.emit("set_flag", params)
	assert_eq(Campaign.to_dict(), before, "stale callbacks cannot write campaign flags")
	assert_true(is_same(Campaign.flags, flags))
	assert_eq(Campaign.active, was_active)
	assert_eq(vn._i, 0)
	assert_eq(vn._dialogue._index, dialogue_index)
