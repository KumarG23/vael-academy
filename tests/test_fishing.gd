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


func test_bite_marker_tracks_the_bobbing_float():
	var g := _game()
	g.tick(5.0)  # enter the bite
	assert_eq(g.phase, FishingGame.Phase.BITE)
	assert_true(g._label.visible, "the bite marker appears")
	var marker_offset := g._label.position - g._bobber_position()
	g.tick(0.2)
	assert_gt(absf(g._bobber_position().y - g._water_y), 0.1,
		"the float moves during the bite window")
	assert_almost_eq(g._label.position.y - g._bobber_position().y, marker_offset.y, 0.001,
		"the marker keeps its offset above the bobbing float")


func test_bite_marker_stays_pinned_through_the_whole_window():
	var g := _game()
	g.tick(5.0)  # enter the bite
	assert_eq(g.phase, FishingGame.Phase.BITE)
	var rocked := false
	for i in range(20):
		var before := g._bobber_position()
		g.tick(0.05)
		if absf(g._bobber_position().y - before.y) > 0.05:
			rocked = true
		assert_almost_eq(g._label.position.y - g._bobber_position().y,
			FishingGame.MARKER_OFFSET.y, 0.001,
			"the marker keeps its offset above the float on every frame")
		if g.phase != FishingGame.Phase.BITE:
			break
	assert_true(rocked, "the float really rocks during the bite window")


func test_float_does_not_snap_when_the_bite_arrives():
	# The bite restarts the phase timer; the float's sway must not restart
	# with it, or the bobber jumps in the very frame the player must react.
	var g := _game()
	var step := 0.05
	var limit := FishingGame.BOB_AMPLITUDE * FishingGame.BOB_SPEED * step + 0.2
	var jump := 0.0
	var reached := false
	for i in range(400):
		var before := g._bobber_position()
		g.tick(step)
		if g.phase == FishingGame.Phase.BITE:
			jump = absf(g._bobber_position().y - before.y)
			reached = true
			break
	assert_true(reached, "the bite arrives")
	assert_lt(jump, limit, "the float keeps rocking when the bite arrives")


func test_bite_marker_disappears_when_the_cast_resolves():
	var g := _game()
	g.tick(5.0)
	assert_true(g._label.visible, "the marker shows while the fish is on")
	g.tick(FishingGame.BITE_WINDOW + 0.1)
	assert_eq(g.phase, FishingGame.Phase.DONE)
	assert_false(g._label.visible, "the marker goes when the fish is gone")
	assert_false(g._hint.visible, "the briefing goes with the cast")


func test_landing_a_fish_takes_the_bite_marker_with_it():
	var g := _game()
	g.tick(5.0)
	g.strike()
	assert_eq(g.phase, FishingGame.Phase.DONE)
	assert_false(g._label.visible, "a landed fish takes the marker with it")


func test_the_cast_tells_the_player_how_to_strike():
	var g := _game()
	assert_true(g._hint.visible, "the cast shows its keys while it waits")
	assert_false(g._hint.text.is_empty(), "the briefing says something")
	assert_true(g._hint.text.to_lower().contains("strike"), "the briefing names the action")


func test_the_cast_briefing_is_drawn_in_the_lower_left():
	var g := _game()
	var vp := g.get_viewport_rect().size
	assert_gt(g._hint.size.x, 0.0, "the briefing has a width to draw with")
	assert_gt(g._hint.size.y, 0.0, "the briefing has a height to draw with")
	assert_lt(g._hint.position.x, vp.x * 0.5, "the briefing sits on the left")
	assert_gt(g._hint.position.y, vp.y * 0.5, "the briefing sits low")


func test_the_cast_labels_never_eat_a_click():
	var g := _game()
	assert_eq(g._label.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the bite marker is not a click target")
	assert_eq(g._hint.mouse_filter, Control.MOUSE_FILTER_IGNORE,
		"the briefing is not a click target")


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
