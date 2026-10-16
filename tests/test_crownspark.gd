extends GutTest
## AW-51: Kai's awakened spell — Crownspark, the First Crown's royal magic.
## VS-1B: manifestation is involuntary. Controlled use requires the Vision flag;
## the bound inventory entry is inert before then, including in older saves.


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


func test_bound_crownspark_inventory_entry_is_not_permission_to_cast():
	var kai: UnitDef = load("res://data/units/kai.tres")
	var u := Unit.new()
	u.setup(kai.duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	var tomes: Array = []
	for item in u.inventory.items:
		var w: WeaponDef = item.weapon()
		if w != null and w.weapon_type == WeaponDef.WeaponType.TOME:
			tomes.append(w.id)
	assert_has(tomes, "crownspark", "inventory preserves bound ownership")
	assert_false(u.can_use_weapon(load("res://data/weapons/crownspark.tres")))
	u.free()


## Ownership stays innate; control needs an independent story unlock.
func test_innate_spell_requires_vision_permission_but_not_a_school_flag():
	Campaign.reset_new_game(false)
	var spark: WeaponDef = load("res://data/weapons/crownspark.tres")
	assert_true(spark.innate, "Crownspark is innate")
	var kai := Unit.new()
	kai.setup((load("res://data/units/kai.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	assert_false(bool(Campaign.flags.get("school_crown", false)), "no story flag set")
	assert_false(kai.can_use_weapon(spark), "awakening alone gives no controlled spell")
	Campaign.flags["kai_awakened"] = true
	Campaign.flags["school_crown"] = true
	assert_false(kai.can_use_weapon(spark), "neither mark nor school bypasses the Vision")
	Campaign.flags["crownspark_unlocked"] = true
	Campaign.flags.erase("school_crown")
	assert_true(kai.can_use_weapon(spark), "explicit story permission opens his own magic")
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


func before_each() -> void:
	Campaign.reset_new_game(false)


func after_each() -> void:
	Campaign.reset_new_game(false)


func test_legacy_equipped_spark_falls_back_without_losing_items_uses_or_progress():
	var kai := Unit.new()
	autofree(kai)
	kai.setup((load("res://data/units/kai.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	kai.equip_weapon(load("res://data/weapons/crownspark.tres"))
	assert_null(kai.weapon(), "direct equip cannot bypass eligibility or counter with magic")
	var state := kai.save_state()
	state["level"] = 4
	state["xp"] = 37
	state["current_hp"] = 13
	state["has_acted"] = true
	state["inventory"] = [
		{"type": "weapon", "path": "res://data/weapons/crownspark.tres", "uses": 991},
		{"type": "weapon", "path": "res://data/weapons/sig_kai.tres", "uses": 17},
		{"type": "item", "path": "res://data/items/vulnerary.tres", "uses": 2},
	]
	kai.apply_save_state(state)
	assert_eq(kai.weapon().id, "sig_kai", "old equipped spell selects the carried sword")
	assert_eq(kai.current_hp, 13)
	assert_eq(kai.level, 4)
	assert_eq(kai.xp, 37)
	assert_true(kai.has_acted)
	assert_eq(kai.inventory.items.size(), 3, "nothing deleted or granted")
	kai.spend_weapon_use()
	assert_eq(kai.inventory.items[0].uses, 16, "durability spends the actual sword")
	assert_eq(kai.inventory.items[1].uses, 991, "bound spell's uses stay intact")
	assert_eq(kai.to_combatant(0, 0).weapon.id, "sig_kai")
	Campaign.flags["crownspark_unlocked"] = true
	var unlocked := Campaign.to_dict()
	Campaign.reset_new_game(false)
	Campaign.from_dict(unlocked)
	assert_true(kai.can_use_weapon(load("res://data/weapons/crownspark.tres")), "permission saves normally")


func test_legacy_save_with_only_locked_spell_is_unarmed_until_story_unlock():
	var kai := Unit.new()
	autofree(kai)
	kai.setup((load("res://data/units/kai.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	kai.apply_save_state({"inventory": [{"type": "weapon", "path": "res://data/weapons/crownspark.tres", "uses": 980}]})
	assert_null(kai.weapon())
	assert_false(kai.can_attack())
	assert_null(kai.to_combatant(0, 0).weapon, "native counters/AI cannot acquire locked magic")
	kai.spend_weapon_use()
	assert_eq(kai.inventory.items[0].uses, 980)
	Campaign.flags["crownspark_unlocked"] = true
	assert_eq(kai.weapon().id, "crownspark", "no inventory destruction or replacement")
