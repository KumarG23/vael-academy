extends GutTest
## WO-5.3a: house-choice mechanism — choosing a house flips the roster and
## theming from data and survives save/load. Tidemark/Thornrook rosters are
## provisional single-member stand-ins until WO-5.4/5.5.


func after_each() -> void:
	Campaign.set_house("emberwing")
	Campaign.reset_new_game(false)


func _fielded_ids() -> Array:
	var out: Array = []
	for def in Roster.player_units():
		out.append(def.id)
	return out


func test_default_house_is_emberwing():
	Campaign.reset_new_game(false)
	assert_eq(Campaign.house_id, "emberwing")
	assert_eq(_fielded_ids().size(), 7, "full Emberwing house + Kai")


func test_choosing_thornrook_flips_the_roster():
	Campaign.set_house("thornrook")
	assert_eq(_fielded_ids(), ["rina", "thessaly", "corvin", "marlow", "vesper", "rurik", "sable", "kai"],
		"full Thornrook house + protagonist (WO-5.5)")


func test_choosing_tidemark_flips_the_roster():
	Campaign.set_house("tidemark")
	assert_eq(_fielded_ids(), ["serra", "osric", "elowen", "isolde", "fenn", "bertram", "kai"],
		"full Tidemark house + protagonist (WO-5.4)")


func test_unknown_house_is_rejected():
	Campaign.set_house("thornrook")
	Campaign.set_house("house_of_nonsense")
	assert_eq(Campaign.house_id, "thornrook", "bad ids don't change anything")


func test_house_survives_save_and_load():
	Campaign.set_house("tidemark")
	var payload := Campaign.to_dict()
	Campaign.set_house("emberwing")
	Campaign.from_dict(payload)
	assert_eq(Campaign.house_id, "tidemark")
	assert_eq(Roster.active_house, "tidemark", "the Roster follows the loaded house")


func test_every_house_has_a_def_and_deploy_cells():
	var chapter: ChapterDef = load("res://data/chapters/mock_battle.tres")
	for id in Roster.HOUSE_ROSTERS:
		assert_true(ResourceLoader.exists("res://data/houses/%s.tres" % id), id + " HouseDef")
		Campaign.set_house(id)
		for uid in Roster.all_player_ids():
			assert_true(chapter.deploy_cells.has(uid),
				"%s has a mock-battle deploy cell (%s)" % [uid, id])


func test_battle_theming_follows_the_campaign_house():
	Campaign.set_house("thornrook")
	Campaign.deploy()
	var v: Node2D = (load("res://scenes/battle/mock_battle.tscn") as PackedScene).instantiate()
	v.strike_delay = 0.0
	v.dialogue_enabled = false
	add_child_autofree(v)
	assert_eq(v.player_house_id, "thornrook")
	Campaign.active = false
