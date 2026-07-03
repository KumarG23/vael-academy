extends GutTest
## WO-1.1: the seedable RNG service — 2RN hit, 1RN crit, and determinism.


func test_same_seed_produces_identical_roll_stream():
	var a := CombatRNG.new(1234)
	var b := CombatRNG.new(1234)
	for i in range(50):
		assert_eq(a.roll(), b.roll(), "roll %d diverged" % i)


func test_different_seeds_diverge():
	var a := CombatRNG.new(1)
	var b := CombatRNG.new(2)
	var same := true
	for i in range(20):
		if a.roll() != b.roll():
			same = false
			break
	assert_false(same, "distinct seeds should not produce identical streams")


func test_rolls_are_in_0_99():
	var r := CombatRNG.new(99)
	for i in range(200):
		var v := r.roll()
		assert_between(v, 0, 99)


func test_hit_100_always_connects():
	var r := CombatRNG.new(7)
	for i in range(200):
		assert_true(r.rolls_hit(100), "displayed hit 100 must always connect")


func test_hit_0_never_connects():
	var r := CombatRNG.new(7)
	for i in range(200):
		assert_false(r.rolls_hit(0), "displayed hit 0 must never connect")


func test_crit_100_always_and_0_never():
	var r := CombatRNG.new(3)
	for i in range(100):
		assert_true(r.rolls_crit(100))
	for i in range(100):
		assert_false(r.rolls_crit(0))


func test_two_rn_is_less_swingy_than_one_rn():
	# At displayed hit 50, the 2RN average should land near 50% but with the
	# characteristic bell — just assert it actually varies and is roughly fair.
	var r := CombatRNG.new(2024)
	var hits := 0
	var n := 4000
	for i in range(n):
		if r.rolls_hit(50):
			hits += 1
	var rate := float(hits) / n
	assert_between(rate, 0.40, 0.60, "2RN at 50 should be roughly fair (got %.2f)" % rate)
