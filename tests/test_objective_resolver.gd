extends GutTest
## WO-1.4: pure win/loss evaluation.

const ROUT := ChapterDef.Objective.ROUT
const SEIZE := ChapterDef.Objective.SEIZE
const SEIZE_CELL := Vector2i(16, 4)

const ONGOING := ObjectiveResolver.Outcome.ONGOING
const VICTORY := ObjectiveResolver.Outcome.VICTORY
const DEFEAT := ObjectiveResolver.Outcome.DEFEAT


func test_rout_ongoing_while_enemies_remain():
	var o := ObjectiveResolver.evaluate(ROUT, SEIZE_CELL, true, true, Vector2i(3, 3), 2, 3)
	assert_eq(o, ONGOING)


func test_rout_victory_when_no_enemies_left():
	var o := ObjectiveResolver.evaluate(ROUT, SEIZE_CELL, true, true, Vector2i(3, 3), 2, 0)
	assert_eq(o, VICTORY)


func test_defeat_when_lord_dies_regardless_of_objective():
	# Even if enemies are also wiped, lord death is game over (§3) — defeat wins.
	var o := ObjectiveResolver.evaluate(ROUT, SEIZE_CELL, true, false, Vector2i(-1, -1), 1, 0)
	assert_eq(o, DEFEAT)


func test_defeat_when_all_player_units_lost():
	var o := ObjectiveResolver.evaluate(ROUT, SEIZE_CELL, true, true, Vector2i(3, 3), 0, 2)
	assert_eq(o, DEFEAT)


func test_seize_victory_when_lord_on_the_cell():
	var o := ObjectiveResolver.evaluate(SEIZE, SEIZE_CELL, true, true, SEIZE_CELL, 2, 3)
	assert_eq(o, VICTORY, "lord standing on the seize tile wins")


func test_seize_ongoing_when_lord_elsewhere():
	var o := ObjectiveResolver.evaluate(SEIZE, SEIZE_CELL, true, true, Vector2i(5, 5), 2, 3)
	assert_eq(o, ONGOING)


func test_seize_does_not_win_if_lord_is_dead():
	var o := ObjectiveResolver.evaluate(SEIZE, SEIZE_CELL, true, false, Vector2i(-1, -1), 1, 3)
	assert_eq(o, DEFEAT)


func test_no_lord_defined_only_loses_on_full_wipe():
	# has_lord false: lord-death rule doesn't apply.
	assert_eq(ObjectiveResolver.evaluate(ROUT, SEIZE_CELL, false, false, Vector2i(-1, -1), 2, 3), ONGOING)
	assert_eq(ObjectiveResolver.evaluate(ROUT, SEIZE_CELL, false, false, Vector2i(-1, -1), 0, 3), DEFEAT)
	assert_eq(ObjectiveResolver.evaluate(ROUT, SEIZE_CELL, false, false, Vector2i(-1, -1), 2, 0), VICTORY)
