extends GutTest
## WO-3.5: the hub → battle → hub handoff. The battle applies campaign progression
## on deploy and captures it back when the battle ends.

var _view: Node2D


func before_each() -> void:
	Campaign.reset_new_game(false, 3)
	Campaign.begin_hub_visit()
	Campaign.train_unit("kai")   # Kai carries +10 XP into the battle
	Campaign.deploy()
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 9
	add_child_autofree(_view)
	await wait_physics_frames(2)


func after_each() -> void:
	Campaign.reset_new_game(false)  # leave the autoload inert for other suites


func _wait_idle(max_frames := 600) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func test_campaign_progression_is_applied_on_deploy():
	var kai: Unit = _view.unit_by_id("kai")
	assert_not_null(kai, "Kai deployed")
	assert_eq(kai.xp, 10, "trained XP carried into the battle")
	assert_eq(kai.current_hp, kai.max_hp(), "deploys at full HP")


func test_victory_captures_the_roster_back_to_campaign():
	# Rout the enemy to win.
	for enemy in _view._living_units_on_team(1).duplicate():
		_view._kill(enemy)
	_view._check_objective()
	await _wait_idle()
	assert_true(_view._battle_over)
	assert_eq(Campaign.last_result, "victory")
	# Kai's progression (with the trained XP) is now in the campaign.
	assert_eq(int(Campaign.get_unit_state("kai").get("xp", -1)), 10)


func test_standalone_battle_ignores_campaign_when_not_deployed():
	# A battle loaded directly (not via the hub) must not pick up campaign state.
	Campaign.reset_new_game(false)
	Campaign.set_unit_state("kai", {"level": 9, "xp": 44})
	# active is false, so a fresh battle should ignore it.
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	var v: Node2D = scene.instantiate()
	v.strike_delay = 0.0
	add_child_autofree(v)
	await wait_physics_frames(2)
	var kai: Unit = v.unit_by_id("kai")
	assert_eq(kai.level, 1, "standalone battle uses base roster, not campaign state")
