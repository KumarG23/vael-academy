extends GutTest
## WO-1.3: turn loop integration — play several full rounds vs the demo enemies
## through battle_view, with the Aggressor AI acting on the enemy phase.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	add_child_autofree(_view)
	await wait_physics_frames(2)
	# This suite exercises the turn LOOP, not win/loss: make BOTH sides effectively
	# unkillable (players also counter enemies) so no rout/lord-death ends the
	# battle early (WO-1.4). Players still take damage, just never die.
	for u in _view._units:
		u.unit_def.max_hp = 9999
		u.current_hp = 9999


func _wait_idle(max_frames := 4000) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func test_five_full_rounds_vs_three_enemies_without_errors():
	assert_eq(_view._living_units_on_team(1).size(), 3, "three enemies on the field")
	assert_gt(_view._living_units_on_team(0).size(), 0, "player has units")

	var hp_before := _total_hp(0)

	for r in range(5):
		var round_before: int = _view._turn.round_number
		assert_true(_view._turn.is_player_phase(), "round %d starts on player phase" % r)
		# Skip player actions and hand the turn over; this runs the enemy phase.
		_view._end_player_phase()
		await _wait_idle()
		assert_true(_view._turn.is_player_phase(), "back to player after enemy phase")
		assert_eq(_view._turn.round_number, round_before + 1, "round advanced")

	# The Aggressor AI should have closed in and dealt damage over five rounds.
	assert_lt(_total_hp(0), hp_before, "enemies engaged and damaged the player side")
	# No crash reaching here is the core acceptance ("5 rounds without errors").
	assert_eq(_view._turn.round_number, 6)


func test_auto_advances_when_all_player_units_have_acted():
	# Mark every player unit as acted, then finishing an action should flip phases.
	for u in _view._living_units_on_team(0):
		u.has_acted = true
	# One unit still selectable path: force the auto-advance check via a no-op finish.
	_view._selected = _view._living_units_on_team(0)[0]
	_view._selected.has_acted = false
	_view._finish_action()  # marks it acted -> all acted -> enemy phase runs
	await _wait_idle()
	assert_true(_view._turn.is_player_phase(), "returned to player after auto enemy phase")
	assert_eq(_view._turn.round_number, 2)


func test_end_turn_shortcuts_warn_and_default_to_keep_playing():
	var players: Array = _view._living_units_on_team(0)
	var hp_before := _total_hp(0)
	for key in [KEY_T, KEY_TAB]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		_view._unhandled_input(event)
		assert_eq(_view._menu_context, "end_turn")
		assert_eq(_view._menu._title, "%d units can still act" % players.size())
		assert_eq(_view._menu._options, ["Keep playing", "End Turn"])
		assert_eq(_view._menu._index, 0, "repeated confirm defaults to keeping the turn")
		assert_false(_view._cursor.active, "map input pauses for the decision")
		assert_eq(_view._turn.round_number, 1)
		assert_true(_view._turn.is_player_phase())
		assert_eq(_total_hp(0), hp_before, "requesting the end does not run enemies")
		var accept := InputEventAction.new()
		accept.action = "cursor_confirm"
		accept.pressed = true
		_view._menu._unhandled_input(accept)
		assert_eq(_view._phase, _view.Phase.IDLE)
		assert_false(_view._menu.visible)
		assert_true(_view._cursor.active)
		for unit in players:
			assert_false(unit.has_acted, "declining preserves available actions")


func test_end_turn_warning_counts_only_living_unacted_allies():
	var players: Array = _view._living_units_on_team(0)
	assert_gt(players.size(), 1, "fixture has allies to exclude")
	for unit in players:
		unit.has_acted = true
	players[0].has_acted = false
	players[1].has_acted = false
	players[1].current_hp = 0
	_view._menu_ctrl.request_end_turn()
	assert_eq(_view._menu._title, "1 unit can still act")
	_view._on_menu_cancelled()
	assert_eq(_view._turn.round_number, 1)
	assert_eq(_view._phase, _view.Phase.IDLE)
	assert_true(_view._cursor.active)
	assert_false(_view._menu.visible)


func test_field_end_turn_cancel_returns_to_field_including_arena():
	# Arena adds a row; both versions must keep their existing field choices.
	_view.chapter = _view.chapter.duplicate(true)
	for arena in [false, true]:
		_view.chapter.is_arena = arena
		_view._menu_ctrl.open_field_menu()
		var field_options: Array = _view._menu._options.duplicate()
		_view._on_menu_chosen(0)
		assert_eq(_view._menu_context, "end_turn")
		var cancel := InputEventAction.new()
		cancel.action = "cursor_cancel"
		cancel.pressed = true
		_view._menu._unhandled_input(cancel)
		assert_eq(_view._menu_context, "field")
		assert_eq(_view._menu._options, field_options)
		assert_false(_view._cursor.active)
		assert_eq(_view._turn.round_number, 1)
		_view._on_menu_cancelled()


func test_confirming_manual_end_turn_advances_one_round():
	_view._menu_ctrl.open_field_menu()
	_view._on_menu_chosen(0)
	assert_eq(_view._turn.round_number, 1, "field choice first asks for confirmation")
	_view._on_menu_chosen(1)
	await _wait_idle()
	assert_eq(_view._turn.round_number, 2)
	assert_true(_view._turn.is_player_phase())
	assert_false(_view._menu.visible)
	assert_true(_view._cursor.active)


func test_manual_end_turn_without_available_actions_skips_warning():
	for unit in _view._living_units_on_team(0):
		unit.has_acted = true
	_view._menu_ctrl.request_end_turn()
	await _wait_idle()
	assert_eq(_view._turn.round_number, 2)
	assert_true(_view._turn.is_player_phase())
	assert_false(_view._menu.visible)


func test_end_turn_shortcut_does_not_interrupt_unit_selection_or_menu():
	var unit: Unit = _view._living_units_on_team(0)[0]
	_view._try_select(unit.cell)
	var event := InputEventKey.new()
	event.keycode = KEY_T
	event.pressed = true
	_view._unhandled_input(event)
	assert_eq(_view._phase, _view.Phase.SELECTED)
	assert_eq(_view._selected, unit)
	_view._deselect()
	_view._menu_ctrl.open_field_menu()
	_view._unhandled_input(event)
	assert_eq(_view._menu_context, "field")
	assert_eq(_view._turn.round_number, 1)


func _total_hp(team: int) -> int:
	var sum := 0
	for u in _view._living_units_on_team(team):
		sum += u.current_hp
	return sum
