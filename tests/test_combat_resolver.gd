extends GutTest
## WO-1.1: the combat resolver — combat order, counters, doubling, death handling,
## crits, and seeded determinism. Structural cases use sure-hit / no-crit weapons
## (hit 999, crit 0) so outcomes are fixed regardless of seed.

func _sure(wtype: WeaponDef.WeaponType, might: int, weight := 5) -> WeaponDef:
	return CombatTestHelpers.weapon(wtype, might, 999, 0, weight, 1, 1)


func test_order_is_attacker_then_counter_when_both_melee():
	var atk := CombatTestHelpers.combatant("A", _sure(WeaponDef.WeaponType.SWORD, 10),
		{"str": 10, "spd": 10, "def": 5, "hp": 30})
	var dfn := CombatTestHelpers.combatant("D", _sure(WeaponDef.WeaponType.SWORD, 5),
		{"str": 8, "spd": 10, "def": 5, "hp": 30})
	var res := CombatResolver.resolve(atk, dfn, 1, CombatRNG.new(1))
	assert_eq(res.strikes.size(), 2)
	assert_false(res.strikes[0].is_counter)
	assert_eq(res.strikes[0].damage, 15)             # 10+10 - 5
	assert_eq(res.strikes[0].defender_hp_after, 15)
	assert_true(res.strikes[1].is_counter)
	assert_eq(res.strikes[1].damage, 8)              # 8+5 - 5
	assert_eq(res.attacker_hp_after, 22)
	assert_eq(res.defender_hp_after, 15)


func test_lethal_first_strike_prevents_the_counter():
	var atk := CombatTestHelpers.combatant("A", _sure(WeaponDef.WeaponType.SWORD, 40),
		{"str": 10, "spd": 10, "hp": 30})
	var dfn := CombatTestHelpers.combatant("D", _sure(WeaponDef.WeaponType.SWORD, 5),
		{"spd": 10, "def": 5, "hp": 30})
	var res := CombatResolver.resolve(atk, dfn, 1, CombatRNG.new(1))
	assert_eq(res.strikes.size(), 1, "dead defender does not counter")
	assert_true(res.defender_defeated())
	assert_eq(res.defender_hp_after, 0)
	assert_eq(res.attacker_hp_after, 30, "attacker untouched")


func test_doubling_adds_a_third_attacker_strike():
	var atk := CombatTestHelpers.combatant("Fast", _sure(WeaponDef.WeaponType.SWORD, 5, 3),
		{"str": 10, "spd": 18, "def": 5, "hp": 30})
	var dfn := CombatTestHelpers.combatant("Slow", _sure(WeaponDef.WeaponType.AXE, 8, 12),
		{"str": 4, "spd": 6, "def": 5, "hp": 100})
	var res := CombatResolver.resolve(atk, dfn, 1, CombatRNG.new(1))
	assert_eq(res.strikes.size(), 3)
	# order: attacker, counter, attacker follow-up
	assert_false(res.strikes[0].is_counter)
	assert_true(res.strikes[1].is_counter)
	assert_false(res.strikes[2].is_counter)
	assert_eq(res.strikes[0].damage, 11)   # sword>axe: 10+5 +1 -5
	assert_eq(res.strikes[1].damage, 6)    # axe<sword: 4+8 -1 -5
	assert_eq(res.strikes[2].damage, 11)
	assert_eq(res.defender_hp_after, 78)   # 100 - 11 - 11
	assert_eq(res.attacker_hp_after, 24)   # 30 - 6


func test_bow_attacks_at_range_2_without_a_counter():
	var atk := CombatTestHelpers.combatant("Archer", CombatTestHelpers.weapon(WeaponDef.WeaponType.BOW, 6, 999, 0, 5, 2, 2),
		{"str": 8, "spd": 10, "hp": 30})
	var dfn := CombatTestHelpers.combatant("Sword", _sure(WeaponDef.WeaponType.SWORD, 5),
		{"spd": 10, "def": 5, "hp": 30})
	var res := CombatResolver.resolve(atk, dfn, 2, CombatRNG.new(1))
	assert_eq(res.strikes.size(), 1, "sword cannot counter at range 2")
	assert_eq(res.strikes[0].damage, 9)     # 8+6 - 5, no triangle
	assert_eq(res.attacker_hp_after, 30)


func test_staff_wielder_cannot_counter():
	var atk := CombatTestHelpers.combatant("A", _sure(WeaponDef.WeaponType.SWORD, 10),
		{"str": 10, "spd": 10, "hp": 30})
	var healer := CombatTestHelpers.combatant("Healer", CombatTestHelpers.staff(), {"spd": 10, "def": 5, "hp": 30})
	var res := CombatResolver.resolve(atk, healer, 1, CombatRNG.new(1))
	assert_eq(res.strikes.size(), 1)
	assert_false(res.strikes[0].is_counter)


func test_crit_triples_damage():
	var atk := CombatTestHelpers.combatant("A", CombatTestHelpers.weapon(WeaponDef.WeaponType.SWORD, 10, 999, 999, 5, 1, 1),
		{"str": 10, "spd": 10, "hp": 30})
	var dfn := CombatTestHelpers.combatant("D", _sure(WeaponDef.WeaponType.SWORD, 5),
		{"spd": 10, "def": 5, "hp": 60})
	var res := CombatResolver.resolve(atk, dfn, 1, CombatRNG.new(1))
	assert_true(res.strikes[0].was_crit)
	assert_eq(res.strikes[0].damage, 45, "15 base * 3")
	assert_eq(res.strikes[0].defender_hp_after, 15)


func test_seeded_determinism_full_exchange():
	# Realistic sub-100 hit / non-zero crit so RNG actually matters.
	var make_atk := func() -> Combatant:
		return CombatTestHelpers.combatant("A", CombatTestHelpers.sword(8, 85, 10, 6),
			{"str": 9, "skl": 9, "spd": 10, "lck": 5, "def": 5, "hp": 30})
	var make_dfn := func() -> Combatant:
		return CombatTestHelpers.combatant("D", CombatTestHelpers.lance(7, 80, 5, 8),
			{"str": 8, "skl": 6, "spd": 9, "lck": 4, "def": 6, "hp": 32})
	var r1 := CombatResolver.resolve(make_atk.call(), make_dfn.call(), 1, CombatRNG.new(42))
	var r2 := CombatResolver.resolve(make_atk.call(), make_dfn.call(), 1, CombatRNG.new(42))
	assert_eq(r1.strikes.size(), r2.strikes.size(), "same seed -> same strike count")
	for i in range(r1.strikes.size()):
		var a := r1.strikes[i]
		var b := r2.strikes[i]
		assert_eq(a.connected, b.connected, "strike %d connected" % i)
		assert_eq(a.was_crit, b.was_crit, "strike %d crit" % i)
		assert_eq(a.damage, b.damage, "strike %d damage" % i)
		assert_eq(a.defender_hp_after, b.defender_hp_after, "strike %d hp" % i)
	assert_eq(r1.attacker_hp_after, r2.attacker_hp_after)
	assert_eq(r1.defender_hp_after, r2.defender_hp_after)


func test_result_damage_tallies_split_by_side():
	var atk := CombatTestHelpers.combatant("A", _sure(WeaponDef.WeaponType.SWORD, 10),
		{"str": 10, "spd": 10, "def": 5, "hp": 30})
	var dfn := CombatTestHelpers.combatant("D", _sure(WeaponDef.WeaponType.SWORD, 5),
		{"str": 8, "spd": 10, "def": 5, "hp": 30})
	var res := CombatResolver.resolve(atk, dfn, 1, CombatRNG.new(1))
	assert_eq(res.total_damage_to_defender(), 15)
	assert_eq(res.total_damage_to_attacker(), 8)
