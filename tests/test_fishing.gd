extends GutTest
## WO-6.4: the waterside fishing mini-game — deterministic timing state
## machine, weighted catch table, campaign fish log persistence.


func _game(seed_value := 7) -> FishingGame:
	var g := FishingGame.new(seed_value)
	add_child_autofree(g)
	return g


func test_bite_arrives_then_expires():
	var g := _game()
	assert_eq(g.phase, FishingGame.Phase.WAITING)
	g.tick(5.0)  # well past any bite time
	assert_eq(g.phase, FishingGame.Phase.BITE)
	g.tick(FishingGame.BITE_WINDOW + 0.1)
	assert_eq(g.phase, FishingGame.Phase.DONE, "missing the window ends the cast")


func test_striking_in_the_window_catches():
	var g := _game()
	var results: Array = []
	g.finished.connect(func(r): results.append(r))
	g.tick(5.0)
	g.strike()
	assert_true(results[0]["caught"])
	assert_true(FishingGame.CATCH_TABLE.has(results[0]["fish"]))


func test_striking_early_scares_it_off():
	var g := _game()
	var results: Array = []
	g.finished.connect(func(r): results.append(r))
	g.strike()
	assert_false(results[0]["caught"])


func test_catches_land_in_the_campaign_log():
	Campaign.fish_log = {}
	var g := _game()
	g.tick(5.0)
	g.strike()
	var total := 0
	for count in Campaign.fish_log.values():
		total += count
	assert_eq(total, 1, "one catch logged")
	Campaign.fish_log = {}


func test_fish_log_survives_save_round_trip():
	Campaign.fish_log = {"Vael Kingfish": 2}
	var payload := Campaign.to_dict()
	Campaign.fish_log = {}
	Campaign.from_dict(payload)
	assert_eq(int(Campaign.fish_log.get("Vael Kingfish", 0)), 2)
	Campaign.reset_new_game(false)


func test_waterside_hosts_the_fishing_spot():
	var ws: CastleRoomDef = load("res://data/castle_v2/waterside.tres")
	var found := false
	for p in ws.points:
		if p.id == "fn_fish":
			found = true
	assert_true(found)
