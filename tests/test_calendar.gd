extends GutTest
## WO-7.1: the academy year — events fire by week, battles route through the
## registry, the week survives saves.


func after_each() -> void:
	Campaign.reset_new_game(false)


func test_year_one_is_bracketed_by_the_two_rites():
	Campaign.reset_new_game(false)
	var cal := Campaign.calendar()
	assert_gte(cal.size(), 6)
	assert_eq(cal[0].kind, CalendarEventDef.Kind.BATTLE, "opens with the rite")
	assert_eq(cal[cal.size() - 1].kind, CalendarEventDef.Kind.BATTLE, "closes with one")


func test_current_event_follows_the_week():
	Campaign.reset_new_game(false)
	assert_eq(Campaign.current_event().kind, CalendarEventDef.Kind.BATTLE)
	Campaign.advance_week()
	assert_eq(Campaign.current_event().label, "Term begins")


func test_victory_advances_the_year():
	Campaign.reset_new_game(false)
	Campaign.capture({}, {}, "victory")
	assert_eq(Campaign.week, 2)
	Campaign.capture({}, {}, "defeat")
	assert_eq(Campaign.week, 2, "defeat doesn't move the year")


func test_week_survives_save_round_trip():
	Campaign.reset_new_game(false)
	Campaign.week = 4
	var payload := Campaign.to_dict()
	Campaign.reset_new_game(false)
	Campaign.from_dict(payload)
	assert_eq(Campaign.week, 4)


func test_registry_routes_battle_chapters_by_house():
	assert_eq(ChapterRegistry.scene_for("mock_battle", "tidemark"),
		"res://scenes/battle/mock_battle_vs_thornrook.tscn")
	assert_eq(ChapterRegistry.scene_for("prologue"),
		"res://scenes/battle/prologue.tscn")
	assert_eq(ChapterRegistry.scene_for("nonexistent"), "")


func test_war_room_respects_free_weeks():
	var castle: CastleScene = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(castle)
	Campaign.week = 2  # Term begins — FREE
	castle._open_mission()
	assert_eq(castle._menu_context, "", "no mission on a free week")
	Campaign.week = 1
	castle._open_mission()
	assert_eq(castle._menu_context, "mission")
	castle._close_menu()
