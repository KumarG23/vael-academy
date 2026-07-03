extends GutTest
## WO-2.1: level-up stat rolls — seeded determinism and the growth rule (§3).


func _growths(v: int) -> Dictionary:
	var g := {}
	for stat in LevelUp.STAT_ORDER:
		g[stat] = v
	return g


func test_growth_100_always_gains_and_0_never():
	var all := LevelUp.roll(_growths(100), CombatRNG.new(3))
	for stat in LevelUp.STAT_ORDER:
		assert_eq(all[stat], 1, stat + " at 100%% must gain")
	var none := LevelUp.roll(_growths(0), CombatRNG.new(3))
	for stat in LevelUp.STAT_ORDER:
		assert_eq(none[stat], 0, stat + " at 0%% must not gain")


func test_same_seed_gives_identical_gains():
	var g := _growths(50)
	assert_eq(LevelUp.roll(g, CombatRNG.new(777)), LevelUp.roll(g, CombatRNG.new(777)))


func test_gains_match_the_roll_sequence_in_stat_order():
	var g := {"hp": 70, "str": 40, "mag": 10, "skl": 55, "spd": 45, "lck": 30, "def": 35, "res": 20}
	var result := LevelUp.roll(g, CombatRNG.new(2024))
	# Reproduce the exact roll stream and compare per stat.
	var rng := CombatRNG.new(2024)
	for stat in LevelUp.STAT_ORDER:
		var expected := 1 if rng.roll() < int(g[stat]) else 0
		assert_eq(result[stat], expected, "stat %s" % stat)


func test_total_gained_counts_ones():
	assert_eq(LevelUp.total_gained(LevelUp.roll(_growths(100), CombatRNG.new(1))), LevelUp.STAT_ORDER.size())
	assert_eq(LevelUp.total_gained(LevelUp.roll(_growths(0), CombatRNG.new(1))), 0)
