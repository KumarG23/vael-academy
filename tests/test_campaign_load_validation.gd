extends GutTest
## Issue #11: exercise real slot IO before restoring campaign-only saves.

var _sys: SaveSystem
var _title: TitleScreen


func before_each() -> void:
	_sys = SaveSystem.new("user://test_campaign_validation")
	_title = load("res://scenes/title/title.tscn").instantiate()
	add_child_autofree(_title)
	await wait_physics_frames(1)
	_seed_live()


func after_each() -> void:
	Campaign.reset_new_game(false)
	BattleView.next_resume = {}
	BattleView.next_prep = false
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	var dir := DirAccess.open(_sys.save_dir)
	if dir != null:
		for file: String in dir.get_files():
			dir.remove(file)


func _seed_live(skip_reset: bool = false, active: bool = false) -> void:
	Campaign.reset_new_game(true, 17)
	Campaign.set_house("tidemark")
	Campaign.house_locked = true
	Campaign.week = 3
	Campaign.flags = {"gold": 37, "prologue_done": true}
	Campaign.fish_log = {"Lakeperch": 2}
	Campaign.support_save = {"points": {"kai_kael": 20}}
	Campaign.set_unit_state("kai", {"level": 2, "xp": 17})
	Campaign.training_used = true
	Campaign.grade_samples["quiz_scores"] = [75]
	Campaign.report_cards = [{"semester": 1}]
	Campaign.active = active
	Campaign._skip_next_hub_reset = skip_reset
	BattleView.next_resume = {"existing_resume": true}
	BattleView.next_prep = true
	CastleScene.next_room = "library"
	CastleScene.next_spawn = Vector2i(2, 3)


func _different_save() -> Dictionary:
	var saved := Campaign.to_dict()
	saved["unit_states"] = {"kai": {"level": 5, "xp": 83}}
	saved["support_save"] = {}
	saved["casual"] = false
	saved["house_id"] = "thornrook"
	saved["fish_log"] = {}
	saved["week"] = 8
	saved["flags"] = {"saved_flag": true}
	saved["training_used"] = false
	saved["grade_samples"] = {}
	saved["report_cards"] = []
	return saved


func _assert_rejected(use_title: bool) -> void:
	var before := Campaign.to_dict()
	var active: bool = Campaign.active
	var house: String = Roster.active_house
	var skip_reset: bool = Campaign._skip_next_hub_reset
	var staged: Dictionary = BattleView.next_resume
	var staged_before := staged.duplicate(true)
	var file_before := FileAccess.get_file_as_string(_sys.slot_path(0))
	var loaded := _title.prepare_load(0, _sys) if use_title else Campaign.load_from_slot(0, _sys)
	assert_false(loaded, "malformed slot must return false")
	assert_eq(Campaign.to_dict(), before, "rejection preserves the entire campaign, including RNG")
	assert_eq(Campaign.active, active)
	assert_eq(Roster.active_house, house)
	assert_eq(Campaign._skip_next_hub_reset, skip_reset)
	assert_eq(BattleView.next_resume, staged_before)
	assert_true(is_same(BattleView.next_resume, staged), "staging identity is preserved")
	assert_true(BattleView.next_prep)
	assert_eq(CastleScene.next_room, "library")
	assert_eq(CastleScene.next_spawn, Vector2i(2, 3))
	assert_eq(_title._context, "main")
	assert_eq(FileAccess.get_file_as_string(_sys.slot_path(0)), file_before, "save is untouched")


func _check_malformed_collections(use_title: bool) -> void:
	for key: String in ["unit_states", "support_save", "fish_log", "flags", "grade_samples", "report_cards", "report_card_deliveries"]:
		var invalid: Array = [null, [], "broken", 42, 1.5, false, true]
		if key in ["report_cards", "report_card_deliveries"]:
			invalid[1] = {}
		for value: Variant in invalid:
			for pending_load: bool in [false, true]:
				_seed_live(pending_load, pending_load)
				var saved := _different_save()
				saved[key] = value
				assert_true(_sys.save_slot(0, {"campaign": saved}))
				_assert_rejected(use_title)


func test_campaign_slot_rejects_wrong_collection_types_atomically() -> void:
	_check_malformed_collections(false)


func test_title_prepare_load_rejects_wrong_collection_types_atomically() -> void:
	_check_malformed_collections(true)


func test_missing_invalid_json_and_invalid_campaign_sections_are_safe() -> void:
	for use_title: bool in [false, true]:
		for text: String in ["", "{broken", "[]", "null", "{}", '{"campaign": null}',
				'{"campaign": []}', '{"campaign": "broken"}', '{"campaign": 42}', '{"campaign": true}']:
			_seed_live()
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_sys.save_dir))
			var file := FileAccess.open(_sys.slot_path(0), FileAccess.WRITE)
			file.store_string(text)
			file.close()
			_assert_rejected(use_title)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_sys.slot_path(0)))
		var before := Campaign.to_dict()
		assert_false(_title.prepare_load(0, _sys) if use_title else Campaign.load_from_slot(0, _sys))
		assert_eq(Campaign.to_dict(), before)
		assert_false(Campaign._skip_next_hub_reset)


func test_valid_existing_campaign_restores_entire_state_and_training_visit() -> void:
	var saved := Campaign.to_dict()
	assert_true(_sys.save_slot(0, {"campaign": saved}))
	for use_title: bool in [false, true]:
		Campaign.reset_new_game(false)
		assert_true(_title.prepare_load(0, _sys) if use_title else Campaign.load_from_slot(0, _sys))
		# JSON numbers become floats inside untyped nested collections. Compare
		# the entire serialized state after the same JSON round trip on both sides.
		assert_eq(JSON.parse_string(JSON.stringify(Campaign.to_dict())),
			JSON.parse_string(JSON.stringify(saved)))
		assert_eq(Roster.active_house, "tidemark")
		assert_eq(Campaign.active, use_title)
		Campaign.begin_hub_visit()
		assert_false(Campaign.can_train(), "loaded visit keeps spent training")
		Campaign.begin_hub_visit()
		assert_true(Campaign.can_train(), "next real visit refreshes training")


func test_legacy_optional_collections_keep_loader_defaults() -> void:
	for use_title: bool in [false, true]:
		_seed_live()
		assert_true(_sys.save_slot(0, {"campaign": {"house_id": "emberwing", "week": 2}}))
		assert_true(_title.prepare_load(0, _sys) if use_title else Campaign.load_from_slot(0, _sys))
		assert_eq(Campaign.week, 2)
		assert_eq(Roster.active_house, "emberwing")
		for value: Dictionary in [Campaign.unit_states, Campaign.support_save, Campaign.fish_log, Campaign.flags]:
			assert_eq(value, {})
		assert_eq(Campaign.grade_samples,
			{"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0})
		assert_eq(Campaign.report_cards, [])
		assert_false(Campaign.training_used)


func test_completed_road_and_oath_saves_keep_title_continuations() -> void:
	for sworn: bool in [false, true]:
		var saved := _different_save()
		saved["flags"] = {"opening_started": true, "prologue_done": true, "road_aftermath_seen": true}
		saved["house_locked"] = sworn
		assert_true(_sys.save_slot(0, {"campaign": saved,
			"battle": {"chapter_id": "prologue", "battle_over": true}, "roster": []}))
		assert_true(_title.prepare_load(0, _sys))
		assert_true(Campaign.active)
		assert_eq(_title.next_campaign_scene(),
			"res://scenes/castle/castle.tscn" if sworn else "res://scenes/flow/house_choice.tscn")


func _check_ui_rejection(route: String) -> void:
	var output: Array = []
	var result := OS.execute(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/fixtures/campaign_load_rejection.gd", "--", route,
	]), output, true)
	assert_eq(result, 0, "UI callback must keep the current flow: %s" % output)
	assert_string_contains(str(output), "Campaign UI load rejection: %s passed" % route)
	assert_false(str(output).contains("SCRIPT ERROR"), "no runtime errors: %s" % output)


func test_title_slot_callback_rejects_without_scheduling_a_transition() -> void:
	_check_ui_rejection("title")


func test_journal_system_row_rejects_without_scheduling_a_transition() -> void:
	_check_ui_rejection("journal")


func test_academy_visit_collection_and_members_reject_atomically_on_all_campaign_routes():
	for invalid: Variant in [null, {}, 1, false, "campus", [null], [1], [false], [{}], [[]], [""], ["../library"], ["Campus"]]:
		for use_title: bool in [false, true]:
			_seed_live(true, true)
			Campaign.academy_visits = ["library"]
			var saved := _different_save()
			saved["academy_visits"] = invalid
			assert_true(_sys.save_slot(0, {"campaign": saved}))
			_assert_rejected(use_title)


func test_academy_visits_slot_roundtrip_legacy_unknown_dedup_and_new_game():
	var rooms := AcademyTravel.public_rooms()
	Campaign.record_academy_entry(rooms["campus"])
	Campaign.record_academy_entry(rooms["library"])
	var expected := Campaign.academy_visits.duplicate()
	assert_true(Campaign.save_to_slot(0, _sys))
	Campaign.reset_new_game(false)
	assert_eq(Campaign.academy_visits.size(), 0)
	assert_true(_title.prepare_load(0, _sys))
	assert_eq(Campaign.academy_visits, expected)
	var payload := _sys.load_slot(0)
	payload["campaign"]["academy_visits"] = ["library", "unknown_room", "grove", "vael_square", "library"]
	assert_true(_sys.save_slot(0, payload))
	assert_true(Campaign.load_from_slot(0, _sys))
	assert_eq(Campaign.academy_visits, ["library"], "unknown and excluded IDs never expose destinations")
	payload["campaign"].erase("academy_visits")
	assert_true(_sys.save_slot(0, payload))
	assert_true(_title.prepare_load(0, _sys))
	assert_eq(Campaign.academy_visits.size(), 0, "legacy has no inferred unlocks")
	Campaign.record_academy_entry(rooms["campus"])
	assert_eq(Campaign.academy_visits, ["campus"], "normal entry earns only current room")
	_title.prepare_new_game(false)
	assert_eq(Campaign.academy_visits.size(), 0)
