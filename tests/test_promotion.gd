extends GutTest
## WO-2.4: promotion — eligibility (pure) and the Unit's class change + bonuses.

var _grid: Grid


func before_each() -> void:
	_grid = Grid.new(10, 10)


func _swordmaster() -> ClassDef:
	var c := ClassDef.new()
	c.id = "swordmaster"
	c.display_name = "Swordmaster"
	c.token_letter = "W"
	c.promo_hp = 3
	c.promo_str = 2
	c.promo_skl = 3
	c.promo_spd = 2
	c.promo_def = 2
	c.promo_mov = 1
	return c


func _myrmidon(promoted: ClassDef) -> ClassDef:
	var c := ClassDef.new()
	c.id = "myrmidon"
	c.display_name = "Myrmidon"
	c.token_letter = "M"
	c.promoted_class = promoted
	return c


func _unit(cls: ClassDef, level: int) -> Unit:
	var d := UnitDef.new()
	d.display_name = "Kael"
	d.char_class = cls
	d.level = level
	d.max_hp = 24
	d.strength = 8
	d.skill = 10
	d.speed = 12
	d.defense = 5
	d.movement = 6
	var u := Unit.new()
	add_child_autofree(u)
	u.setup(d, _grid, Vector2i(1, 1))
	u.level = level
	return u


# --- eligibility (pure) -------------------------------------------------------

func test_eligible_only_at_level_10_with_a_promotion_path():
	var sm := _swordmaster()
	var myr := _myrmidon(sm)
	assert_false(Promotion.is_eligible(myr, 9), "level 9 too low")
	assert_true(Promotion.is_eligible(myr, 10), "level 10 qualifies")
	assert_true(Promotion.is_eligible(myr, 15))


func test_already_promoted_class_cannot_promote_again():
	assert_false(Promotion.is_eligible(_swordmaster(), 20), "no further promotion path")


# --- Unit.promote -------------------------------------------------------------

func test_unit_cannot_promote_before_level_10():
	var u := _unit(_myrmidon(_swordmaster()), 9)
	assert_false(u.can_promote())
	assert_eq(u.promote(), {}, "promote is a no-op when ineligible")
	assert_eq(u.current_class().id, "myrmidon")


func test_promotion_changes_class_and_applies_bonuses():
	var u := _unit(_myrmidon(_swordmaster()), 10)
	var str_before := u.stat("str")
	var spd_before := u.stat("spd")
	var mov_before := u.move_points()
	assert_true(u.can_promote())

	var result := u.promote()
	assert_eq(result["class_name"], "Swordmaster")
	assert_eq(u.current_class().id, "swordmaster", "class changed")
	assert_eq(u.movement_type(), ClassDef.MovementType.FOOT)
	assert_eq(u.token_letter(), "W", "token reflects the promoted class")
	assert_eq(u.stat("str"), str_before + 2, "STR bonus applied")
	assert_eq(u.stat("skl"), u.unit_def.skill + 3)
	assert_eq(u.stat("spd"), spd_before + 2)
	assert_eq(u.max_hp(), u.unit_def.max_hp + 3)
	assert_eq(u.move_points(), mov_before + 1, "movement bonus applied")


func test_promotion_resets_level_to_one_and_clears_xp():
	var u := _unit(_myrmidon(_swordmaster()), 12)
	u.xp = 40
	u.promote()
	assert_eq(u.level, 1, "level resets after promotion (cap stays 20)")
	assert_eq(u.xp, 0)


func test_promotion_bonus_hp_also_raises_current_hp():
	var u := _unit(_myrmidon(_swordmaster()), 10)
	u.current_hp = u.max_hp()
	var before := u.current_hp
	u.promote()
	assert_eq(u.current_hp, before + 3, "the +3 HP bonus heals as well")


func test_promoted_unit_can_still_level_up_afterward():
	var u := _unit(_myrmidon(_swordmaster()), 10)
	u.promote()
	var results := u.gain_xp(100, CombatRNG.new(1))
	assert_eq(results.size(), 1, "levels again after promotion")
	assert_eq(u.level, 2)
