extends GutTest
## WO-5.6: rival-force variants of the opening battle. Whichever house the
## player picks, they field their own roster AND face the correct rival —
## no house ever fights itself.

const CYCLE := {"emberwing": "tidemark", "tidemark": "thornrook", "thornrook": "emberwing"}


func after_each() -> void:
	Campaign.set_house("emberwing")
	Campaign.active = false


func _load_battle(house: String) -> Node2D:
	Campaign.set_house(house)
	Campaign.deploy()
	var path: String = HubScene.BATTLE_SCENE_FOR_HOUSE[house]
	var v: Node2D = (load(path) as PackedScene).instantiate()
	v.strike_delay = 0.0
	v.dialogue_enabled = false
	add_child_autofree(v)
	return v


func test_full_parity_for_every_house():
	for house in CYCLE:
		var v := _load_battle(house)
		var player_houses := {}
		var enemy_houses := {}
		for u in v._units:
			var hid: String = u.unit_def.house_id
			if u.team == 0:
				player_houses[hid] = true
			else:
				enemy_houses[hid] = true
		assert_true(player_houses.has(house), "%s fields its own units" % house)
		assert_false(enemy_houses.has(house), "%s never fights itself" % house)
		assert_true(enemy_houses.has(CYCLE[house]),
			"%s faces %s at the opening rite" % [house, CYCLE[house]])
		Campaign.active = false


func test_rival_bosses_are_the_heirs():
	var v := _load_battle("tidemark")
	assert_eq(v._boss_unit.unit_id(), "rina", "Tidemark route: Rina holds the fort")
	Campaign.active = false
	var v2 := _load_battle("thornrook")
	assert_eq(v2._boss_unit.unit_id(), "perrin", "Thornrook route: Perrin holds the fort")


func test_rival_units_spawn_as_enemies_with_brains():
	var v := _load_battle("tidemark")
	for u in v._units:
		if u.team == 1:
			assert_eq(u.unit_def.team, 1, u.unit_id() + " overridden to team 1")


func test_rival_dialogue_files_exist():
	for c in ["mock_battle_vs_emberwing", "mock_battle_vs_thornrook"]:
		var chapter: ChapterDef = load("res://data/chapters/%s.tres" % c)
		assert_true(FileAccess.file_exists(chapter.boss_quote_dialogue), c + " quote")
		assert_true(FileAccess.file_exists(chapter.boss_yield_dialogue), c + " yield")
