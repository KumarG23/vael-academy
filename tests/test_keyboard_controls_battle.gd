extends GutTest
## Issue #89: additional keys in the production battle — held cursor movement,
## select/deselect, command menu, targeting/forecast, commit and the existing
## cursor_cancel exchange skip — compared against the same flow on shipped keys.

const MOCK := "res://scenes/battle/mock_battle.tscn"
const SHIPPED := {"up": KEY_UP, "down": KEY_DOWN, "confirm": KEY_ENTER, "cancel": KEY_ESCAPE}
const CUSTOM := {"up": KEY_I, "down": KEY_N, "confirm": KEY_O, "cancel": KEY_P}

var _original_path := ""
var _prefs_path := ""


func before_each() -> void:
	_original_path = KeyboardPreferences.prefs_path
	_prefs_path = "user://test_keyboard_battle_%d.cfg" % Time.get_ticks_usec()
	KeyboardPreferences.prefs_path = _prefs_path
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	var picks := {"cursor_up": KEY_I, "cursor_down": KEY_N, "cursor_left": KEY_G,
		"cursor_right": KEY_L, "cursor_confirm": KEY_O, "cursor_cancel": KEY_P}
	for action: String in picks:
		assert_eq(KeyboardPreferences.assign(action, _ev(picks[action], true)), "")


func after_each() -> void:
	for code in [KEY_I, KEY_W, KEY_L]:
		Input.parse_input_event(_ev(code, false))
	Input.flush_buffered_events()
	KeyboardPreferences._unapply()
	KeyboardPreferences._extras.clear()
	KeyboardPreferences.prefs_path = _original_path
	for suffix in ["", ".tmp"]:
		if FileAccess.file_exists(_prefs_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(_prefs_path + suffix))
	Campaign.reset_new_game(false)
	Engine.time_scale = 1.0


func _ev(code: Key, pressed: bool, echo := false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _kitted() -> BattleView:
	Campaign.reset_new_game(false)
	Campaign.deploy()
	var host := SubViewport.new()
	host.size = Vector2i(1280, 720)
	host.handle_input_locally = true
	add_child_autofree(host)
	var view: BattleView = load(MOCK).instantiate()
	view.dialogue_enabled = false
	view.combat_seed = 1
	view.battle_popups_enabled = false
	host.add_child(view)
	view._cursor.set_process(false)
	for pair in [["kael", Vector2i(8, 10)], ["osric", Vector2i(9, 10)]]:
		var unit := view.unit_by_id(pair[0])
		unit.cell = pair[1]
		unit.position = view._grid.cell_center(pair[1])
	return view


func _tap(view: BattleView, code: Key) -> void:
	view.get_viewport().push_input(_ev(code, true), true)
	view.get_viewport().push_input(_ev(code, false), true)


func _menu_to(view: BattleView, keys: Dictionary, action: String) -> void:
	var want: int = view._menu_actions.find(action)
	assert_ne(want, -1, "%s offered" % action)
	for i in range(view._menu._options.size()):
		if view._menu._index == want:
			return
		_tap(view, keys["down"])
	assert_eq(view._menu._index, want, "menu reached %s" % action)


func _armed(view: BattleView) -> bool:
	var layer = view._combat_exec.get("_skip_input")
	return layer != null and is_instance_valid(layer) and layer.is_armed()


## The whole command flow on one key set; returns the post-exchange payload.
func _run(keys: Dictionary) -> Dictionary:
	var view := _kitted()
	await wait_process_frames(2)
	var kael := view.unit_by_id("kael")
	var osric := view.unit_by_id("osric")
	view._cursor.move_to(kael.cell)
	_tap(view, keys["confirm"])
	assert_eq(view._phase, BattleView.Phase.SELECTED, "confirm selects")
	_tap(view, keys["cancel"])
	assert_eq(view._phase, BattleView.Phase.IDLE, "cancel deselects")
	_tap(view, keys["confirm"])
	_tap(view, keys["confirm"])
	assert_eq(view._phase, BattleView.Phase.MENU, "confirm in place opens the command menu")
	_tap(view, keys["cancel"])
	assert_eq(view._phase, BattleView.Phase.IDLE, "cancel closes the menu, nothing spent")
	assert_false(kael.has_acted)
	_tap(view, keys["confirm"])
	_tap(view, keys["confirm"])
	_menu_to(view, keys, "attack")
	_tap(view, keys["up"])
	_menu_to(view, keys, "attack")
	_tap(view, keys["confirm"])
	if view._menu_context == "attack_weapon":
		_tap(view, keys["confirm"])
	assert_eq(view._phase, BattleView.Phase.TARGETING)
	assert_true(view._forecast_panel.visible, "forecast shown")
	_tap(view, keys["cancel"])
	assert_eq(view._phase, BattleView.Phase.MENU, "cancel backs out of targeting")
	assert_false(view._forecast_panel.visible)
	_menu_to(view, keys, "attack")
	_tap(view, keys["confirm"])
	if view._menu_context == "attack_weapon":
		_tap(view, keys["confirm"])
	view._cursor.move_to(osric.cell)
	_tap(view, keys["confirm"])  # commit from the forecast
	var skipped := false
	var deadline := Time.get_ticks_msec() + 30000
	while (view._busy or _armed(view) or not kael.has_acted) and Time.get_ticks_msec() < deadline:
		if _armed(view) and not skipped:
			_tap(view, keys["confirm"])  # busy-gated: must not select or act
			_tap(view, keys["cancel"])   # existing cursor_cancel skip semantics
			skipped = true
		await get_tree().process_frame
	assert_true(skipped, "the exchange was armed for skip")
	assert_true(kael.has_acted, "attack resolved")
	assert_eq(view._phase, BattleView.Phase.IDLE)
	assert_null(view._selected, "confirm during the exchange did not select")
	var payload := view.make_save_payload()
	view.get_parent().queue_free()
	await wait_process_frames(1)
	return payload


func test_custom_keys_drive_the_same_command_flow_and_outcome_as_shipped_keys() -> void:
	var shipped: Dictionary = await _run(SHIPPED)
	var custom: Dictionary = await _run(CUSTOM)
	assert_eq(custom, shipped, "same seed, same command path → identical campaign/units/RNG payload")


func test_held_custom_direction_moves_the_cursor_with_existing_repeat() -> void:
	var view := _kitted()
	await wait_process_frames(2)
	var cursor := view._cursor
	cursor.move_to(Vector2i(8, 8))
	Input.parse_input_event(_ev(KEY_I, true))
	Input.flush_buffered_events()
	assert_eq(cursor._poll_direction(), Vector2i(0, -1), "held custom Up polls as Up")
	cursor.step_repeat(cursor._poll_direction(), 0.0)
	assert_eq(cursor.cell, Vector2i(8, 7), "first frame moves once")
	cursor.step_repeat(cursor._poll_direction(), BattleCursor.INITIAL_REPEAT_DELAY * 0.5)
	assert_eq(cursor.cell, Vector2i(8, 7), "waits for the existing initial delay")
	cursor.step_repeat(cursor._poll_direction(), BattleCursor.INITIAL_REPEAT_DELAY)
	assert_eq(cursor.cell, Vector2i(8, 6), "then repeats")
	Input.parse_input_event(_ev(KEY_W, true))
	Input.flush_buffered_events()
	assert_eq(cursor._poll_direction(), Vector2i(0, -1), "custom + shipped Up together is still one step direction")
	Input.parse_input_event(_ev(KEY_I, false))
	Input.flush_buffered_events()
	assert_eq(cursor._poll_direction(), Vector2i(0, -1), "releasing the extra keeps the held shipped key")
	Input.parse_input_event(_ev(KEY_W, false))
	Input.flush_buffered_events()
	assert_eq(cursor._poll_direction(), Vector2i.ZERO, "released")
	Input.parse_input_event(_ev(KEY_L, true))
	Input.flush_buffered_events()
	assert_eq(cursor._poll_direction(), Vector2i(1, 0), "custom Right")
	var snapshot := view.make_save_payload()
	for code in [KEY_I, KEY_N, KEY_G, KEY_L]:
		_tap(view, code)
	assert_eq(view.make_save_payload(), snapshot, "direction keys alone never act")
	assert_eq(view._phase, BattleView.Phase.IDLE)
