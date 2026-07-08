extends GutTest
## WO-4.3: title screen & game flow — new-game setup (Classic/Casual), load-slot
## listing and loading, and the load-then-hub-visit state fix.

var _title: TitleScreen
var _sys: SaveSystem


func before_each() -> void:
	Campaign.reset_new_game(false)
	_sys = SaveSystem.new("user://test_title_saves")
	var scene: PackedScene = load("res://scenes/title/title.tscn")
	_title = scene.instantiate()
	add_child_autofree(_title)
	await wait_physics_frames(1)


func after_each() -> void:
	Campaign.reset_new_game(false)
	# Clean the test save dir so reruns are deterministic.
	var dir := DirAccess.open("user://test_title_saves")
	if dir != null:
		for f in dir.get_files():
			dir.remove(f)


func test_title_opens_on_the_main_menu():
	assert_eq(_title._context, "main")
	assert_true(_title._menu.visible, "main menu is up")


func test_new_game_classic_resets_the_campaign():
	Campaign.set_unit_state("kai", {"level": 5})
	_title.prepare_new_game(false)
	assert_false(Campaign.casual, "Classic")
	assert_false(Campaign.has_unit_state("kai"), "fresh campaign state")
	# AW-38: the campaign is live from the prologue onward (routes through the flow).
	assert_true(Campaign.active, "a new game is a live campaign run")


func test_new_game_casual_sets_the_flag():
	_title.prepare_new_game(true)
	assert_true(Campaign.casual, "Casual")


func test_load_restores_a_saved_campaign():
	# Build and save a campaign with progress.
	Campaign.begin_hub_visit()
	Campaign.train_unit("kai")
	assert_true(Campaign.save_to_slot(1, _sys))
	Campaign.reset_new_game(false)
	assert_false(Campaign.has_unit_state("kai"))

	assert_true(_title.prepare_load(1, _sys), "slot 1 loads")
	assert_eq(int(Campaign.get_unit_state("kai").get("xp", -1)), 10, "training XP restored")


func test_load_missing_slot_fails_gracefully():
	assert_false(_title.prepare_load(2, _sys), "empty slot refuses to load")


func test_list_slots_reads_campaign_saves():
	Campaign.casual = true
	Campaign.save_to_slot(0, _sys)
	var slots := _sys.list_slots()
	assert_eq(slots.size(), 1)
	assert_eq(str(slots[0]["chapter_id"]), "mock_battle", "campaign saves list their chapter")
	assert_true(bool(slots[0]["casual_mode"]), "campaign casual flag read")


func test_slot_labels_show_saves_or_placeholder():
	_title._slots = []
	var labels := _title._slot_labels()
	assert_eq(labels, ["(no saves found)", "Back"], "placeholder when no saves")
	_title._slots = [{"slot": 0, "chapter_id": "mock_battle", "casual_mode": true, "version": 1}]
	labels = _title._slot_labels()
	assert_eq(labels[0], "Slot 0 — mock_battle (Casual)")
	assert_eq(labels[-1], "Back")


func test_hub_visit_after_load_keeps_the_saved_training_state():
	# Train (spending the visit), save, wipe, load: the hub visit that follows the
	# load must NOT hand back a free training session.
	Campaign.begin_hub_visit()
	Campaign.train_unit("kai")
	assert_false(Campaign.can_train())
	Campaign.save_to_slot(1, _sys)
	Campaign.reset_new_game(false)
	assert_true(Campaign.load_from_slot(1, _sys))

	Campaign.begin_hub_visit()  # the hub _ready right after loading
	assert_false(Campaign.can_train(), "loaded visit resumes: training already spent")
	Campaign.begin_hub_visit()  # a genuine next visit (post-battle)
	assert_true(Campaign.can_train(), "next real visit refreshes training")
