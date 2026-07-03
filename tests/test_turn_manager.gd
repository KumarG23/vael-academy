extends GutTest
## WO-1.3: turn/phase bookkeeping.


func test_starts_on_player_phase_round_one():
	var t := TurnManager.new()
	assert_true(t.is_player_phase())
	assert_eq(t.round_number, 1)


func test_advance_toggles_and_counts_rounds():
	var t := TurnManager.new()
	t.advance()  # -> enemy
	assert_true(t.is_enemy_phase())
	assert_eq(t.round_number, 1, "round only increments back at player")
	t.advance()  # -> player, round 2
	assert_true(t.is_player_phase())
	assert_eq(t.round_number, 2)
	t.advance()
	t.advance()
	assert_eq(t.round_number, 3)


func test_phase_name():
	var t := TurnManager.new()
	assert_eq(t.phase_name(), "Player Phase")
	t.advance()
	assert_eq(t.phase_name(), "Enemy Phase")
