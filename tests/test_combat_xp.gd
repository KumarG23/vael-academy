extends GutTest
## WO-2.1: XP award formula (§3).


func test_no_xp_on_a_whiff():
	assert_eq(CombatXP.award(1, 1, false, false), 0)


func test_hit_is_about_ten_at_equal_level():
	assert_eq(CombatXP.award(5, 5, true, false), 10)


func test_kill_is_about_thirty_at_equal_level():
	assert_eq(CombatXP.award(5, 5, true, true), 30)


func test_higher_level_target_pays_more():
	assert_eq(CombatXP.award(5, 8, true, false), 13)   # 10 + 3
	assert_eq(CombatXP.award(5, 8, true, true), 39)     # 30 + 3*3


func test_lower_level_target_pays_less_but_at_least_one():
	assert_eq(CombatXP.award(10, 5, true, false), 5)    # 10 + (-5)
	assert_eq(CombatXP.award(20, 1, true, false), 1)    # clamped to 1, not negative


func test_award_clamps_to_100():
	assert_eq(CombatXP.award(1, 40, true, true), 100)   # 30 + 39*3 -> clamped


func test_heal_xp_scales_with_amount_healed():
	assert_eq(CombatXP.award_heal(0), 0)
	assert_eq(CombatXP.award_heal(16), 26)              # 10 + 16
	assert_eq(CombatXP.award_heal(200), 100)            # clamped
