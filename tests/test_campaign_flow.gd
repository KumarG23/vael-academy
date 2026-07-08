extends GutTest
## AW-38: the campaign entry flow — New Game opens on the prologue raid, its
## victory leads to the house-choice oath, and choosing a house binds the roster
## and enters the castle year. Routing is by save state (prologue_done / locked).

var _title


func before_each() -> void:
	Campaign.reset_new_game(false)
	_title = load("res://src/ui/title_screen.gd").new()  # not in tree; no _ready
	autofree(_title)


func after_each() -> void:
	Campaign.house_locked = false
	Campaign.reset_new_game(false)


func test_new_game_opens_on_the_prologue():
	assert_true(_title.next_campaign_scene().ends_with("prologue.tscn"),
		"a fresh run starts with the raid")


func test_after_the_prologue_comes_the_oath():
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
