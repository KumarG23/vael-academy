extends GutTest
## WO-1.1: every §3 formula, table-driven with hand-computed expectations.


func test_attack_speed_burdened_only_when_weapon_heavier_than_str():
	# [spd, str, weight, expected]
	var cases := [
		[10, 5, 8, 7],    # burden 3
		[10, 5, 3, 10],   # weapon lighter than str -> no burden
		[10, 5, 5, 10],   # equal -> no burden
		[8, 0, 12, -4],   # heavy weapon, weak wielder
	]
	for c in cases:
		assert_eq(CombatMath.attack_speed(c[0], c[1], c[2]), c[3],
			"AS(spd=%d,str=%d,wt=%d)" % [c[0], c[1], c[2]])


func test_attack_power_physical_vs_magical():
	assert_eq(CombatMath.attack_power(false, 7, 0, 5), 12, "physical = STR+Might")
	assert_eq(CombatMath.attack_power(true, 7, 6, 5), 11, "magical = MAG+Might")


func test_damage_floors_at_zero_and_folds_triangle_and_terrain():
	assert_eq(CombatMath.damage(12, 1, 5, 1), 7)     # 12+1-(5+1)
	assert_eq(CombatMath.damage(12, -1, 5, 0), 6)    # disadvantage
	assert_eq(CombatMath.damage(3, 0, 5, 2), 0)      # overkill defense -> 0, not negative
	assert_eq(CombatMath.damage(20, 0, 0, 0), 20)


func test_hit_rate_uses_integer_luck_halving():
	# 90 + 8*2 + 5/2 + 15 = 90+16+2+15 = 123
	assert_eq(CombatMath.hit_rate(90, 8, 5, 15), 123)
	# odd luck floors: 7/2 = 3
	assert_eq(CombatMath.hit_rate(80, 0, 7, 0), 83)


func test_avoid_rate():
	assert_eq(CombatMath.avoid_rate(7, 5, 20), 39)   # 14+5+20
	assert_eq(CombatMath.avoid_rate(0, 0, 0), 0)


func test_crit_rate_uses_integer_skill_halving():
	assert_eq(CombatMath.crit_rate(0, 9), 4)   # 9/2 floored
	assert_eq(CombatMath.crit_rate(10, 8), 14)


func test_crit_avoid_is_luck():
	assert_eq(CombatMath.crit_avoid(6), 6)


func test_displayed_hit_and_crit_clamp_0_100():
	assert_eq(CombatMath.displayed_hit(123, 39), 84)
	assert_eq(CombatMath.displayed_hit(10, 50), 0)
	assert_eq(CombatMath.displayed_hit(200, 0), 100)
	assert_eq(CombatMath.displayed_crit(30, 40), 0)
	assert_eq(CombatMath.displayed_crit(50, 5), 45)
	assert_eq(CombatMath.displayed_crit(120, 0), 100)


func test_crit_damage_is_triple():
	assert_eq(CombatMath.crit_damage(7), 21)
	assert_eq(CombatMath.crit_damage(0), 0)


func test_doubles_needs_four_or_more_attack_speed_lead():
	assert_true(CombatMath.doubles(11, 7))    # exactly +4
	assert_true(CombatMath.doubles(20, 7))
	assert_false(CombatMath.doubles(10, 7))   # +3
	assert_false(CombatMath.doubles(7, 7))
