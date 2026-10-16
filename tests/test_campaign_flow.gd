extends GutTest
## VS-1A: Awakening → road → oath → castle, including legacy save routing.

var _title


func before_each() -> void:
	Campaign.reset_new_game(false)
	_title = load("res://src/ui/title_screen.gd").new()  # not in tree; no _ready
	autofree(_title)


func after_each() -> void:
	Campaign.house_locked = false
	Campaign.reset_new_game(false)


func test_new_game_opens_on_the_awakening():
	_title.prepare_new_game(false)
	assert_eq(_title.next_campaign_scene(), TitleScreen.OPENING_SCENE)
	Campaign.flags["kai_awakened"] = true
	assert_eq(_title.next_campaign_scene(), TitleScreen.OPENING_SCENE,
		"the cave flag cannot skip the family and Director")
	Campaign.flags["opening_complete"] = true
	assert_eq(_title.next_campaign_scene(), TitleScreen.PROLOGUE_SCENE)


func test_legacy_pre_oath_save_does_not_retroactively_replay_awakening():
	assert_eq(_title.next_campaign_scene(), TitleScreen.PROLOGUE_SCENE,
		"older saves lack the explicit opening_started marker")


func test_after_the_prologue_comes_the_oath():
	_title.prepare_new_game(false)
	Campaign.flags["prologue_done"] = true
	assert_true(_title.next_campaign_scene().ends_with("house_choice.tscn"),
		"prologue done, house not yet sworn → the choice screen")


func test_a_sworn_house_goes_straight_to_the_castle():
	Campaign.set_house("thornrook")
	Campaign.house_locked = true
	assert_true(_title.next_campaign_scene().ends_with("castle.tscn"),
		"the year is underway → the castle")


func test_choosing_a_house_binds_locks_and_marks_the_prologue_done():
	var hc = load("res://src/flow/house_choice_scene.gd").new()
	autofree(hc)  # not in tree, so commit() skips the scene change
	hc.commit("thornrook")
	assert_eq(Campaign.house_id, "thornrook", "roster house set")
	assert_eq(Roster.active_house, "thornrook", "Roster follows")
	assert_true(Campaign.house_locked, "the oath binds")
	assert_true(bool(Campaign.flags.get("prologue_done", false)))


func test_the_house_choice_scene_loads():
	var scn: PackedScene = load("res://scenes/flow/house_choice.tscn")
	assert_not_null(scn, "scene resource loads")
	var node = scn.instantiate()
	autofree(node)
	assert_true(node is HouseChoiceScene, "root is the flow controller")


func test_opening_flags_round_trip_and_pre_oath_load_keeps_campaign_active():
	var sys := SaveSystem.new("user://test_opening_%d" % Time.get_ticks_usec())
	_title.prepare_new_game(true)
	Campaign.flags["kai_awakened"] = true
	Campaign.flags["opening_complete"] = true
	assert_true(Campaign.save_to_slot(0, sys))
	Campaign.reset_new_game(false)
	assert_true(_title.prepare_load(0, sys))
	assert_eq(_title.next_campaign_scene(), TitleScreen.PROLOGUE_SCENE)
	assert_true(Campaign.active, "road victory must route into the campaign")
	assert_true(Campaign.casual)
	assert_true(Campaign.flags.get("kai_awakened", false))
	assert_eq(Campaign.week, 1)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sys.slot_path(0)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sys.save_dir))


func test_each_oath_preserves_road_progress_and_continues_to_its_own_rite():
	for house: String in HouseChoiceScene.HOUSES:
		_title.prepare_new_game(false)
		Campaign.flags["kai_awakened"] = true
		Campaign.flags["opening_complete"] = true
		Campaign.set_unit_state("kai", {"level": 2, "xp": 17})
		Campaign.capture(Campaign.unit_states.duplicate(true), {}, "victory")
		Campaign.flags["prologue_done"] = true
		var hc := HouseChoiceScene.new()
		hc.commit(house)  # outside tree: no scene swap under GUT
		hc.free()
		var saved := Campaign.to_dict()
		Campaign.reset_new_game(false)
		Campaign.from_dict(saved)
		assert_eq(_title.next_campaign_scene(), TitleScreen.HUB_SCENE)
		assert_eq(Campaign.house_id, house)
		assert_eq(Roster.active_house, house)
		assert_true(Campaign.house_locked)
		assert_true(Campaign.flags.get("opening_complete", false))
		assert_eq(Campaign.get_unit_state("kai"), {"level": 2, "xp": 17})
		assert_eq(Campaign.week, 1, "road/oath do not consume the Opening Rite week")
		var scene := ChapterRegistry.scene_for(Campaign.current_event().chapter_id, house)
		var battle: BattleView = load(scene).instantiate()
		assert_eq(battle.chapter.id, "mock_battle" if house == "emberwing" else
			"mock_battle_vs_thornrook" if house == "tidemark" else "mock_battle_vs_emberwing")
		battle.free()
		Campaign.capture({}, {}, "victory")
		assert_eq(Campaign.week, 2, "a year battle still advances normally after the oath")


func test_road_snapshot_resumes_the_actual_prologue_without_replaying_the_vn():
	_title.prepare_new_game(true)
	Campaign.flags["kai_awakened"] = true
	Campaign.flags["opening_complete"] = true
	var road: BattleView = load(TitleScreen.PROLOGUE_SCENE).instantiate()
	road.dialogue_enabled = false
	road.strike_delay = 0.0
	add_child_autofree(road)
	road.unit_by_id("kai").current_hp = 13
	road.unit_by_id("kai").has_acted = true
	road._rng.roll()
	var payload := road.make_save_payload()
	Campaign.reset_new_game(false)
	assert_eq(Resume.stage(payload), TitleScreen.PROLOGUE_SCENE,
		"real chapter id is prologue; hamlet_cottage alias is insufficient")
	var resumed: BattleView = load(TitleScreen.PROLOGUE_SCENE).instantiate()
	resumed.dialogue_enabled = false
	resumed.strike_delay = 0.0
	add_child_autofree(resumed)
	assert_eq(BattleView.next_resume, {}, "payload consumed once")
	assert_eq(resumed.unit_by_id("kai").current_hp, 13)
	assert_true(resumed.unit_by_id("kai").has_acted)
	assert_eq(resumed._rng.state_value(), road._rng.state_value())
	assert_true(Campaign.flags.get("opening_complete", false))
	assert_false(Campaign.flags.has("prologue_done"))
	assert_true(Campaign.active)
	assert_true(Campaign.casual)
	assert_eq(Campaign.week, 1)


func test_new_game_clears_staged_scene_handoffs_from_previous_dev_or_load():
	CastleScene.next_room = "classroom"
	CastleScene.next_spawn = Vector2i(12, 5)
	BattleView.next_resume = {"battle": {"chapter_id": "mock_battle"}}
	BattleView.next_prep = true
	_title.prepare_new_game(false)
	assert_eq(CastleScene.next_room, "")
	assert_eq(CastleScene.next_spawn, Vector2i(-1, -1))
	assert_eq(BattleView.next_resume, {})
	assert_false(BattleView.next_prep)
