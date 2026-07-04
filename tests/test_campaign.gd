extends GutTest
## WO-3.5: the Campaign autoload — training, capture, and save/load persistence.

var _sys: SaveSystem


func before_each() -> void:
	Campaign.reset_new_game(false, 7)
	_sys = SaveSystem.new("user://test_hub_saves")


func after_each() -> void:
	Campaign.reset_new_game(false)  # leave the autoload inert for other suites


func test_training_grants_ten_xp_to_one_unit_per_visit():
	Campaign.begin_hub_visit()
	assert_true(Campaign.can_train())
	Campaign.train_unit("kai")
	assert_false(Campaign.can_train(), "training is spent for the visit")
	assert_eq(int(Campaign.get_unit_state("kai").get("xp", -1)), 10)
	# A second unit can't be trained this visit.
	Campaign.train_unit("kael")
	assert_false(Campaign.has_unit_state("kael"), "second unit untrained this visit")


func test_a_new_visit_refreshes_training():
	Campaign.begin_hub_visit()
	Campaign.train_unit("kai")
	Campaign.begin_hub_visit()
	assert_true(Campaign.can_train(), "new visit -> can train again")
	Campaign.train_unit("kael")
	assert_eq(int(Campaign.get_unit_state("kael").get("xp", -1)), 10)


func test_training_can_trigger_a_level_up():
	Campaign.set_unit_state("kai", {"level": 1, "xp": 95})
	Campaign.begin_hub_visit()
	Campaign.train_unit("kai")  # 95 + 10 = 105 -> level up
	var s := Campaign.get_unit_state("kai")
	assert_eq(int(s["level"]), 2, "crossed 100 XP")
	assert_eq(int(s["xp"]), 5, "overflow carried")


func test_training_persists_through_save_and_load():
	Campaign.begin_hub_visit()
	Campaign.train_unit("kai")
	assert_true(Campaign.save_to_slot(1, _sys))
	# Wipe and reload.
	Campaign.reset_new_game(false)
	assert_false(Campaign.has_unit_state("kai"), "cleared before load")
	assert_true(Campaign.load_from_slot(1, _sys))
	assert_eq(int(Campaign.get_unit_state("kai").get("xp", -1)), 10, "training XP restored")


func test_capture_stores_roster_and_result():
	Campaign.deploy()
	Campaign.capture({"kael": {"level": 3, "xp": 20}}, {"points": {}, "ranks": {}}, "victory")
	assert_eq(int(Campaign.get_unit_state("kael")["level"]), 3)
	assert_eq(Campaign.last_result, "victory")


func test_deploy_flag_gates_battle_application():
	assert_false(Campaign.active, "inert by default")
	Campaign.deploy()
	assert_true(Campaign.active)
	Campaign.begin_hub_visit()
	assert_false(Campaign.active, "back in the hub -> not deployed")
