extends GutTest
## WO-3.2: pure support point/rank state and rank-based combat bonuses.


func _chain() -> SupportChainDef:
	var c := SupportChainDef.new()
	c.id = "ash_kael"
	c.unit_a_id = "ash"
	c.unit_a_name = "Ash"
	c.unit_b_id = "kael"
	c.unit_b_name = "Kael"
	return c


func test_points_unlock_c_rank():
	var state := SupportState.new()
	state.add_chain(_chain())

	var result := state.add_points("ash", "kael", SupportState.POINTS_END_TURN)
	assert_false(result["ranked_up"], "10 points is below C")
	assert_eq(state.rank_for_units("ash", "kael"), "")

	result = state.add_points("kael", "ash", SupportState.POINTS_END_TURN)
	assert_true(result["ranked_up"], "20 points unlocks C")
	assert_eq(result["new_rank"], "C")
	assert_eq(state.rank_for_units("ash", "kael"), "C")


func test_rank_bonuses_require_nearby_partner():
	var state := SupportState.new()
	state.add_chain(_chain())
	state.add_points("ash", "kael", 20)

	var absent := state.bonus_for_unit("ash", [])
	assert_eq(absent["hit"], 0, "no partner in range means no bonus")

	var present := state.bonus_for_unit("ash", ["kael"])
	assert_eq(present["hit"], 5)
	assert_eq(present["avoid"], 5)
	assert_eq(present["damage"], 0)
	assert_eq(present["crit"], 0)


func test_unlocked_conversation_listing_tracks_rank():
	var state := SupportState.new()
	var chain := _chain()
	chain.c_conversation = "res://data/supports/ash_kael_c.json"
	state.add_chain(chain)
	state.add_points("ash", "kael", 20)

	var entries := state.unlocked_conversations_for_unit("kael")
	assert_eq(entries.size(), 1)
	assert_eq(entries[0]["label"], "Ash + Kael C")
	assert_eq(entries[0]["path"], "res://data/supports/ash_kael_c.json")
