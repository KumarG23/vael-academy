extends GutTest
## WO-2.1: per-unit XP/level state on the Unit node.

var _grid: Grid


func before_each() -> void:
	_grid = Grid.new(10, 10)


func _unit(growth_all: int, level := 1) -> Unit:
	var cls := ClassDef.new()
	cls.movement_type = ClassDef.MovementType.FOOT
	var d := UnitDef.new()
	d.display_name = "Cadet"
	d.char_class = cls
	d.level = level
	d.max_hp = 20
	d.strength = 5
	d.growth_hp = growth_all
	d.growth_str = growth_all
	d.growth_mag = growth_all
	d.growth_skl = growth_all
	d.growth_spd = growth_all
	d.growth_lck = growth_all
	d.growth_def = growth_all
	d.growth_res = growth_all
	var u := Unit.new()
	add_child_autofree(u)
	u.setup(d, _grid, Vector2i(1, 1))
	return u


func test_gain_xp_below_100_does_not_level():
	var u := _unit(50)
	var results := u.gain_xp(40, CombatRNG.new(1))
	assert_eq(results.size(), 0)
	assert_eq(u.level, 1)
	assert_eq(u.xp, 40)


func test_crossing_100_levels_up_once():
	var u := _unit(0)  # no growths -> deterministic: level rises, stats don't
	var results := u.gain_xp(100, CombatRNG.new(1))
	assert_eq(results.size(), 1)
	assert_eq(u.level, 2)
	assert_eq(u.xp, 0)


func test_guaranteed_growths_raise_every_stat_and_current_hp():
	var u := _unit(100)  # every stat grows
	var hp_before := u.current_hp
	var str_before := u.stat("str")
	u.gain_xp(100, CombatRNG.new(5))
	assert_eq(u.level, 2)
	assert_eq(u.stat("str"), str_before + 1, "STR grew")
	assert_eq(u.max_hp(), 21, "HP stat grew")
	assert_eq(u.current_hp, hp_before + 1, "HP growth also raised current HP")


func test_applied_gains_match_a_seeded_roll():
	var u := _unit(50)
	var seed := 909
	var expected := LevelUp.roll(u.unit_def.growths(), CombatRNG.new(seed))
	u.gain_xp(100, CombatRNG.new(seed))
	assert_eq(u.stat("str"), u.unit_def.strength + int(expected["str"]))
	assert_eq(u.stat("def"), u.unit_def.defense + int(expected["def"]))


func test_overflow_xp_carries_into_the_next_level():
	var u := _unit(0)
	u.gain_xp(130, CombatRNG.new(1))
	assert_eq(u.level, 2)
	assert_eq(u.xp, 30, "leftover XP carries over")


func test_level_cap_stops_growth():
	var u := _unit(0, CombatXP.LEVEL_CAP)
	var results := u.gain_xp(100, CombatRNG.new(1))
	assert_eq(results.size(), 0, "no level-up at the cap")
	assert_eq(u.level, CombatXP.LEVEL_CAP)


func test_heal_restores_up_to_max_and_reports_amount():
	var u := _unit(0)
	u.current_hp = 5
	assert_eq(u.heal(10), 10)
	assert_eq(u.current_hp, 15)
	assert_eq(u.heal(100), 5, "clamped to max, healed only the remainder")
	assert_eq(u.current_hp, u.max_hp())
