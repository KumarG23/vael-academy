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


func _total_hp(team: int) -> int:
	var sum := 0
	for u in _view._living_units_on_team(team):
		sum += u.current_hp
	return sum
