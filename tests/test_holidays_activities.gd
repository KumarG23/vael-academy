extends GutTest
## WO-7.2 + 7.3: scheduled set-pieces (festival, victory feast) and the
## diegetic cooking unlock.

var _castle: CastleScene


func before_each() -> void:
	Campaign.reset_new_game(false)
	CastleScene.next_room = ""
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(_castle)


func after_each() -> void:
	Campaign.reset_new_game(false)


func test_festival_fires_once_and_unlocks_cooking():
	assert_false(bool(Campaign.flags.get("cooking_unlocked", false)))
	Campaign.week = 4  # the Founding Festival
	_castle._refresh_date()
	assert_not_null(_castle._dialogue, "the festival set-piece is playing")
	assert_false(bool(Campaign.flags.get("festival_seen", false)), "unfinished festival remains pending")
	_castle._dialogue._finish()
	assert_true(bool(Campaign.flags.get("festival_seen", false)))
	assert_true(bool(Campaign.flags.get("cooking_unlocked", false)), "cooking unlocked diegetically")


func test_cooking_point_is_flag_gated():
	var hall: CastleRoomDef = load("res://data/castle_v2/common_hall.tres")
	var cook: CastlePoint = null
	for p in hall.points:
		if p.id == "fn_cook":
			cook = p
	assert_not_null(cook)
	assert_false(_castle._point_available(cook), "hidden before the festival")
	Campaign.flags["cooking_unlocked"] = true
	assert_true(_castle._point_available(cook), "present after")


func test_cooking_grows_a_bond_once_per_week():
	Campaign.flags["cooking_unlocked"] = true
	_castle._open_cooking()
	assert_eq(_castle._menu_context, "cooking")
	var before: int = _castle._support_state.points_for_units("kai", "kael")
	var kael_idx := -1
	var i := 0
	for def in _castle._roster_defs:
		if def.id == "kai":
			continue
		if def.id == "kael":
			kael_idx = i
		i += 1
	_castle._do_cook(kael_idx)
	assert_eq(_castle._support_state.points_for_units("kai", "kael"), before + 8)
	_castle._open_cooking()
	assert_eq(_castle._menu_context, "", "the pits are cold until next week")


func test_victory_feast_plays_when_the_year_ends():
	Campaign.week = 7  # past the closing rite
	Campaign.last_result = "victory"
	_castle._refresh_date()
	assert_not_null(_castle._dialogue, "the feast is playing")
	assert_false(bool(Campaign.flags.get("feast_seen", false)), "unfinished feast remains pending")
	_castle._dialogue._finish()
	assert_true(bool(Campaign.flags.get("feast_seen", false)))
	_castle._refresh_date()  # doesn't replay


func test_unlock_persists_through_saves():
	Campaign.flags["cooking_unlocked"] = true
	var payload := Campaign.to_dict()
	Campaign.reset_new_game(false)
	Campaign.from_dict(payload)
	assert_true(bool(Campaign.flags.get("cooking_unlocked", false)))
