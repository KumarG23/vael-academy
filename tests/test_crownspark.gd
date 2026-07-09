extends GutTest
## AW-51: Kai's awakened spell — Crownspark, the First Crown's royal magic.
## The story is that his magic manifesting is WHY he's at the academy, so he
## carries one unique spell from day one, with its own school and FX style.


func test_kai_carries_crownspark():
	var kai: UnitDef = load("res://data/units/kai.tres")
	var found: WeaponDef = null
	for w in kai.extra_weapons:
		if w != null and w.id == "crownspark":
			found = w
	assert_not_null(found, "Kai's awakened spell is in his kit")
	assert_eq(found.weapon_type, WeaponDef.WeaponType.TOME, "it casts as a tome")
	assert_eq(found.school, "crown", "royal magic — its own school")
	assert_eq(found.max_range, 2, "reaches to 2")
	assert_gt(kai.magic, 0, "the awakening gave him a real MAG stat")


func test_crown_school_sits_outside_the_anima_triangle():
	var spark: WeaponDef = load("res://data/weapons/crownspark.tres")
	var fire: WeaponDef = load("res://data/weapons/fire.tres")
	# royal magic predates the house elements — no bonus either way
	assert_eq(WeaponTriangle.hit_bonus_for(spark, fire), 0, "crown doesn't beat ember")
	assert_eq(WeaponTriangle.hit_bonus_for(fire, spark), 0, "and ember doesn't beat crown")
	assert_eq(WeaponTriangle.dmg_bonus_for(spark, fire), 0)


func test_crownspark_lists_under_the_magic_command():
	var kai: UnitDef = load("res://data/units/kai.tres")
	var u := Unit.new()
	u.setup(kai.duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	var tomes: Array = []
	for item in u.inventory.items:
		var w: WeaponDef = item.weapon()
		if w != null and w.weapon_type == WeaponDef.WeaponType.TOME:
			tomes.append(w.id)
	assert_has(tomes, "crownspark", "the Magic command will list it (AW-26 splits by tome)")
	u.free()


func test_crownspark_has_its_own_fx_style():
	var rig := CombatRig.new()
	rig.set_spell_meta("crownspark", "crown")
	assert_eq(rig._magic_style(), "crown", "a unique cast style, not generic flame")
	var c: Color = rig._magic_color()
	assert_gt(c.g, c.r, "and it burns verdant — matching his blade")
	rig.free()
