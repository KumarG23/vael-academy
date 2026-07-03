extends GutTest
## WO-1.1: forecast math — the RNG-free strike/exchange numbers the UI will show.

func test_strike_stats_fold_in_triangle_and_terrain():
	# Sword attacker vs Axe defender: +15 hit, +1 dmg triangle.
	# Attacker: str 8, skl 8, lck 4, sword might 5 hit 90.
	# Defender: spd 10, str 8, axe weight 10 -> AS = 10 - (10-8) = 8; avoid = 16+lck; in forest.
	var atk := CombatTestHelpers.combatant("A", CombatTestHelpers.sword(5, 90, 0, 5), {"str": 8, "skl": 8, "lck": 4})
	var dfn := CombatTestHelpers.combatant("D", CombatTestHelpers.axe(8, 75, 0, 10), {"spd": 10, "str": 8, "lck": 4},
		1, 20)  # forest: +1 def, +20 avoid
	var s := CombatForecast.strike_stats(atk, dfn)
	# hit = 90 + 16 + 2 + 15(tri) = 123; avoid = 8*2 + 4 + 20 = 40; displayed = 83
	assert_eq(s["hit"], 83, "displayed hit")
	# attack = 8 + 5 = 13; dmg = 13 + 1(tri) - (5 def + 1 terrain) = 8
	assert_eq(s["damage"], 8, "displayed damage")
	# crit = 0 + 8/2 = 4; crit avoid = lck 4 -> 0
	assert_eq(s["crit"], 0, "displayed crit")


func test_magical_attack_reads_resistance_not_defense():
	var atk := CombatTestHelpers.combatant("Mage", CombatTestHelpers.tome(6, 90), {"mag": 10})
	var dfn := CombatTestHelpers.combatant("Knight", CombatTestHelpers.lance(), {"def": 12, "res": 2})
	var s := CombatForecast.strike_stats(atk, dfn)
	# attack = mag 10 + might 6 = 16; dmg = 16 - (res 2) = 14 (ignores def 12)
	assert_eq(s["damage"], 14, "tome hits RES, not DEF")


func test_exchange_flags_doubling_and_counter_at_range_1():
	var fast := CombatTestHelpers.combatant("Fast", CombatTestHelpers.sword(5, 100, 0, 3), {"spd": 15})
	var slow := CombatTestHelpers.combatant("Slow", CombatTestHelpers.axe(8, 75, 0, 12), {"spd": 6, "str": 4})
	var ex := CombatForecast.exchange(fast, slow, 1)
	assert_true(ex["attacker_can_attack"])
	assert_true(ex["defender_can_counter"], "both melee at range 1")
	# fast AS = 15 - max(0,3-8)=15; slow AS = 6 - (12-4)= -2; 15 >= -2+4 -> doubles
	assert_true(ex["attacker_doubles"])
	assert_false(ex["defender_doubles"])


func test_exchange_bow_cannot_counter_at_range_1():
	var melee := CombatTestHelpers.combatant("Sword", CombatTestHelpers.sword(), {})
	var archer := CombatTestHelpers.combatant("Archer", CombatTestHelpers.bow(), {})
	var ex := CombatForecast.exchange(melee, archer, 1)
	assert_true(ex["attacker_can_attack"])
	assert_false(ex["defender_can_counter"], "bow (range 2) cannot hit back at range 1")


func test_exchange_melee_cannot_counter_a_bow_at_range_2():
	var archer := CombatTestHelpers.combatant("Archer", CombatTestHelpers.bow(), {})
	var melee := CombatTestHelpers.combatant("Sword", CombatTestHelpers.sword(), {})
	var ex := CombatForecast.exchange(archer, melee, 2)
	assert_true(ex["attacker_can_attack"], "bow attacks at range 2")
	assert_false(ex["defender_can_counter"], "sword cannot reach range 2")


func test_support_bonus_changes_forecast_numbers():
	var atk := CombatTestHelpers.combatant("A", CombatTestHelpers.sword(5, 90, 0, 5), {"str": 8, "skl": 8, "lck": 4})
	var dfn := CombatTestHelpers.combatant("D", CombatTestHelpers.axe(8, 75, 0, 10), {"spd": 10, "str": 8, "lck": 4})
	var base := CombatForecast.strike_stats(atk, dfn)

	atk.apply_support_bonus({"hit": 5, "damage": 1, "crit": 5})
	dfn.apply_support_bonus({"avoid": 5})
	var boosted := CombatForecast.strike_stats(atk, dfn)

	assert_eq(boosted["hit"], base["hit"], "attacker +5 hit and defender +5 avoid cancel out")
	assert_eq(boosted["damage"], base["damage"] + 1, "support damage adds before defense")
	assert_eq(boosted["crit"], base["crit"] + 5, "support crit changes displayed crit")
