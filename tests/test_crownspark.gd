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


## AW-53: Kai can cast his OWN awakened magic with no story school-flag — the
## innate flag bypasses the WO-8.2 gate (this is why the spell was invisible:
## nothing sets school_crown). Others can't wield it even if they held it.
func test_innate_spell_needs_no_school_flag():
	Campaign.reset_new_game(false)
	var spark: WeaponDef = load("res://data/weapons/crownspark.tres")
	assert_true(spark.innate, "Crownspark is innate")
	var kai := Unit.new()
	kai.setup((load("res://data/units/kai.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	assert_false(bool(Campaign.flags.get("school_crown", false)), "no story flag set")
	assert_true(kai.can_use_weapon(spark), "his own magic answers him regardless")
	var perrin := Unit.new()
	perrin.setup((load("res://data/units/perrin.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	assert_false(perrin.can_use_weapon(spark), "royal magic answers no one else")
	kai.free()
	perrin.free()


## AW-53: a saved inventory from BEFORE the spell existed (Neal's campaign)
## replaces the def kit on deploy — the innate merge restores it.
func test_stale_save_gains_the_innate_spell():
	var kai := Unit.new()
	kai.setup((load("res://data/units/kai.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	kai.apply_progression_state({"level": 3, "xp": 40, "inventory": [
		{"type": "weapon", "path": "res://data/weapons/sig_kai.tres", "id": "sig_kai", "uses": 38},
		{"type": "item", "path": "res://data/items/vulnerary.tres", "id": "vulnerary", "uses": 2},
	]})
	var names: Array = []
	for item in kai.inventory.items:
		names.append(item.display_name())
	assert_has(names, "Crownspark", "the pre-spell save was migrated: " + str(names))
	assert_has(names, "Verdant Blade", "and the saved gear survived")
	assert_eq(kai.inventory.items[0].uses, 38, "with its worn uses intact")
	kai.free()


func test_crownspark_has_its_own_fx_style():
	var rig := CombatRig.new()
	rig.set_spell_meta("crownspark", "crown")
	assert_eq(rig._magic_style(), "crown", "a unique cast style, not generic flame")
	var c: Color = rig._magic_color()
	assert_gt(c.g, c.r, "and it burns verdant — matching his blade")
	rig.free()
