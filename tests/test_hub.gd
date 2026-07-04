extends GutTest
## WO-3.5: the Academy Hub scene wiring.

var _hub: HubScene


func before_each() -> void:
	Campaign.reset_new_game(false, 7)
	# Never let hub saves touch the player's real user://saves (WO-4.3 fix).
	Campaign.save_system_override = SaveSystem.new("user://test_hub_saves")
	var scene: PackedScene = load("res://scenes/hub/hub.tscn")
	_hub = scene.instantiate()
	add_child_autofree(_hub)
	await wait_physics_frames(1)


func after_each() -> void:
	Campaign.save_system_override = null
	Campaign.reset_new_game(false)


func test_hub_lists_the_full_roster():
	assert_eq(_hub._roster_defs.size(), 4, "Kai, Kael, Brenna, Wren")


func test_entering_the_hub_refreshes_training():
	# _ready called begin_hub_visit, so training is available.
	assert_true(Campaign.can_train())


func test_training_grounds_grants_xp_through_the_menu():
	_hub._open_training()
	assert_eq(_hub._context, "training")
	_hub._do_train(0)  # train the first roster unit (Kai)
	assert_eq(int(Campaign.get_unit_state("kai").get("xp", -1)), 10)
	assert_false(Campaign.can_train(), "one training per visit")


func test_mission_board_deploy_flags_the_campaign():
	# Call Campaign.deploy directly (the hub's deploy also changes scene).
	assert_false(Campaign.active)
	Campaign.deploy()
	assert_true(Campaign.active, "deploying arms the battle to load campaign state")


func test_quartermaster_builds_a_unit_summary_without_error():
	_hub._open_quartermaster()
	_hub._show_unit_detail(0)
	assert_gt(_hub._info.size(), 0, "unit detail populated")


func test_save_game_writes_a_slot():
	_hub._save_game()
	assert_true(Campaign.save_system_override.has_slot(0), "hub save writes slot 0")
