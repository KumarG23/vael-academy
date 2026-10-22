extends GutTest
## Roster browsing is separate from the validated pitch and binding oath.

var _scene: HouseChoiceScene


func before_each() -> void:
	Campaign.reset_new_game(true)
	Campaign.active = true
	Campaign.flags["road_aftermath_seen"] = true
	Campaign.set_unit_state("kai", {"level": 2, "xp": 17})
	_scene = load("res://scenes/flow/house_choice.tscn").instantiate()
	add_child_autofree(_scene)


func after_each() -> void:
	Campaign.reset_new_game(false)


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event


func test_preview_displays_every_native_member_class_and_complete_starting_equipment() -> void:
	for house: String in HouseChoiceScene.HOUSES:
		_scene.preview(house)
		assert_not_null(_scene._preview)
		var rows := HousePreview.members(house)
		var members := _scene._preview_scroll.get_child(0)
		assert_eq(members.get_child_count(), rows.size(), house)
		for i in range(rows.size()):
			var member := members.get_child(i)
			var identity: Label = member.get_child(0)
			var equipment: Label = member.get_child(1)
			assert_eq(identity.text, "%s — %s" % [rows[i]["name"], rows[i]["class_name"]])
			assert_eq(equipment.text, "Starting equipment: %s" % rows[i]["starting_weapon"])
			assert_eq(identity.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
			assert_eq(equipment.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
		_scene.close_preview()


func test_browsing_back_and_rejected_oaths_preserve_campaign_and_house_selection() -> void:
	var before := Campaign.to_dict()
	var flags: Dictionary = Campaign.flags
	var states: Dictionary = Campaign.unit_states
	var was_active: bool = Campaign.active
	var house_before := Roster.active_house
	var cursor_before := _scene._index
	for house: String in HouseChoiceScene.HOUSES:
		_scene.preview(house)
		_scene.pick(house)
		_scene.commit(house)
		_scene._move(1)
		_scene._unhandled_input(_action("cursor_confirm"))
		assert_null(_scene._dialogue, "preview cannot start a pitch or oath")
		assert_false(_scene._committing)
		_scene._input(_action("cursor_cancel"))
		assert_null(_scene._preview)
		assert_eq(_scene._index, cursor_before, "browsing never changes the highlighted house")
		assert_eq(Campaign.to_dict(), before)
		assert_true(is_same(Campaign.flags, flags))
		assert_true(is_same(Campaign.unit_states, states))
		assert_eq(Campaign.active, was_active)
		assert_eq(Roster.active_house, house_before)


func test_preview_button_back_button_and_shortcut_have_keyboard_focus() -> void:
	_scene._index = 1
	_scene._preview_button.pressed.emit()
	assert_not_null(_scene._preview)
	assert_false(_scene._actions.visible)
	var back: Button = _scene._preview.find_child("Back", true, false)
	assert_true(back.has_focus(), "keyboard activation can return immediately")
	assert_eq(back.focus_mode, Control.FOCUS_ALL)
	back.pressed.emit()
	assert_null(_scene._preview)
	assert_true(_scene._actions.visible)
	assert_true(_scene._preview_button.has_focus(), "focus returns to the opener")
	assert_eq(_scene._index, 1)
	_scene._unhandled_input(_key(KEY_R))
	assert_not_null(_scene._preview, "R opens the highlighted house roster")
	var heading: Label = _scene._preview.get_child(0).get_child(0).get_child(0)
	var house: HouseDef = load("res://data/houses/tidemark.tres")
	assert_eq(heading.text, house.display_name + " — Starting roster")
	_scene._input(_key(KEY_ESCAPE))
	assert_null(_scene._preview)
	assert_null(_scene._dialogue)
	_scene._input(_action("cursor_right"))
	assert_eq(_scene._index, 2, "house arrows still work after Back restores button focus")


func test_real_enter_on_preview_back_cannot_fall_through_to_an_oath() -> void:
	_scene.preview("thornrook")
	var before := Campaign.to_dict()
	get_viewport().push_input(_key(KEY_ENTER))
	get_viewport().push_input(_key(KEY_ENTER, false))
	assert_null(_scene._preview, "focused Back responds to Enter")
	assert_null(_scene._dialogue, "the same Enter does not start a pitch")
	assert_eq(Campaign.to_dict(), before)
	assert_eq(_scene._index, 0)


func test_long_roster_scrolls_with_keys_and_keeps_back_outside_the_scroll_area() -> void:
	# Fix the test's bounds before resizing the normally viewport-anchored scene.
	_scene.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_scene.size = Vector2(640, 480)
	_scene.preview("thornrook")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_scene.size, Vector2(640, 480), "small-window bounds survive layout")
	var scroll := _scene._preview_scroll
	var bar := scroll.get_v_scroll_bar()
	assert_gt(bar.max_value, bar.page, "all seven members remain reachable in a small window")
	assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	var back: Button = _scene._preview.find_child("Back", true, false)
	assert_false(scroll.is_ancestor_of(back), "Back stays visible while the roster scrolls")
	_scene._input(_action("cursor_down"))
	assert_gt(scroll.scroll_vertical, 0)
	_scene._input(_action("cursor_up"))
	assert_eq(scroll.scroll_vertical, 0)
	_scene._input(_key(KEY_PAGEDOWN))
	assert_gt(scroll.scroll_vertical, 0)
	_scene._input(_key(KEY_PAGEUP))
	assert_eq(scroll.scroll_vertical, 0)
	_scene._input(_action("cursor_cancel"))
	assert_null(_scene._preview)


func test_invalid_locked_and_pending_pitch_requests_do_not_open_a_preview() -> void:
	var before := Campaign.to_dict()
	for house in ["", "unknown", "../units/kai"]:
		_scene.preview(house)
		assert_null(_scene._preview)
	assert_eq(Campaign.to_dict(), before)
	Campaign.house_locked = true
	_scene.preview("tidemark")
	assert_null(_scene._preview)
	Campaign.house_locked = false
	_scene.pick("tidemark")
	var dialogue := _scene._dialogue
	assert_not_null(dialogue)
	_scene.preview("thornrook")
	assert_null(_scene._preview)
	assert_eq(_scene._dialogue, dialogue)
	assert_false(_scene._actions.visible, "buttons cannot cover or replace the pitch")
	assert_eq(Campaign.to_dict(), before)


func test_after_browsing_each_original_pitch_still_binds_and_routes_the_oath() -> void:
	for house: String in HouseChoiceScene.HOUSES:
		Campaign.reset_new_game(true)
		Campaign.flags["road_aftermath_seen"] = true
		Campaign.set_unit_state("kai", {"level": 2, "xp": 17})
		var choice := HouseChoiceScene.new()
		add_child(choice)
		choice.preview(house)
		choice.close_preview()
		# Keep the actual pitch/commit while avoiding a scene swap under GUT.
		remove_child(choice)
		autofree(choice)
		choice.pick(house)
		assert_not_null(choice._dialogue)
		if choice._dialogue == null:
			continue
		var dialogue := choice._dialogue
		for _step in range(32):
			if dialogue.is_finished():
				break
			dialogue.skip_reveal()
			dialogue.advance()
		assert_true(dialogue.is_finished())
		assert_true(Campaign.house_locked)
		assert_eq(Campaign.house_id, house)
		assert_eq(Roster.active_house, house)
		assert_true(Campaign.flags.get("prologue_done", false))
		assert_true(Campaign.flags.get("road_aftermath_seen", false))
		assert_eq(Campaign.get_unit_state("kai"), {"level": 2, "xp": 17})
		assert_eq(Campaign.week, 1)
		var title := TitleScreen.new()
		assert_eq(title.next_campaign_scene(), HouseChoiceScene.CASTLE)
		title.free()
		var before := Campaign.to_dict()
		dialogue.finished.emit()
		choice.preview("emberwing")
		assert_null(choice._preview)
		assert_eq(Campaign.to_dict(), before)
