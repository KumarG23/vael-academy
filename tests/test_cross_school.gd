extends GutTest
## WO-8.2: Kai's cross-school magic — schools open via scripted story beats;
## the forecast/resolver reflect the unlocked tome through the existing
## magic-weapon path.


func before_each() -> void:
	Campaign.reset_new_game(false)


func after_each() -> void:
	Campaign.reset_new_game(false)


func _kai_with_fire() -> Unit:
	var u := Unit.new()
	u.unit_def = (load("res://data/units/kai.tres") as UnitDef).duplicate()
	var tome := InventoryItem.from_weapon(load("res://data/weapons/fire.tres"))
	u.inventory.add(tome)
	autofree(u)
	return u


func test_kai_cannot_wield_a_locked_school():
	var kai := _kai_with_fire()
	var fire: WeaponDef = load("res://data/weapons/fire.tres")
	assert_false(kai.can_use_weapon(fire), "Ember is closed until the story opens it")


func test_house_students_are_unaffected():
	var liora := Unit.new()
	liora.unit_def = (load("res://data/units/liora.tres") as UnitDef).duplicate()
	autofree(liora)
	assert_true(liora.can_use_weapon(load("res://data/weapons/fire.tres")),
		"Liora was born to her lane")


func test_the_first_spark_opens_ember():
	Campaign.flags["festival_seen"] = true
	var castle: CastleScene = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(castle)
	castle.enter_room("library", Vector2i(9, 10))
	var beat: CastlePoint = null
	for p in castle.room.points:
		if p.id == "beat_first_spark":
			beat = p
	castle._avatar.position = castle._grid.cell_center(beat.cell)
	castle._update_prompt()
	castle.activate_nearest()
	# drive the scene through the beat (events fire as lines advance)
	var guard := 0
	while castle._dialogue != null and not castle._dialogue.is_finished() and guard < 40:
		castle._dialogue.advance()
		guard += 1
	assert_true(bool(Campaign.flags.get("school_ember", false)), "the beat opened Ember")


func test_unlocked_school_reaches_the_resolver():
	var kai := _kai_with_fire()
	Campaign.flags["school_ember"] = true
	assert_true(kai.can_use_weapon(load("res://data/weapons/fire.tres")))
	kai.inventory.equip(kai.inventory.items[kai.inventory.size() - 1])
	var c := kai.to_combatant(0, 0)
	assert_true(c.weapon.is_magical(), "Kai fights with magic now — MAG drives the forecast")


func test_school_unlock_survives_saves():
	Campaign.flags["school_ember"] = true
	var payload := Campaign.to_dict()
	Campaign.reset_new_game(false)
	Campaign.from_dict(payload)
	assert_true(bool(Campaign.flags.get("school_ember", false)))


func test_directly_equipped_locked_school_cannot_attack_counter_or_spend_uses():
	var kai := _kai_with_fire()
	var tome := kai.inventory.equipped_weapon_item()
	var uses_before := tome.uses
	var campaign_before := Campaign.to_dict().duplicate(true)
	assert_null(kai.weapon(), "inventory ownership cannot bypass the school gate")
	assert_false(kai.can_attack())
	assert_null(kai.to_combatant(0, 0).weapon, "native counters stay unarmed")
	assert_null(kai.spend_weapon_use())
	assert_eq(tome.uses, uses_before, "ineligible magic spends no durability")
	assert_eq(Campaign.to_dict(), campaign_before, "eligibility checks do not unlock anything")
	Campaign.flags["school_ember"] = true
	assert_same(kai.weapon(), tome.weapon(), "the existing spell becomes usable after its unlock")
	assert_null(kai.spend_weapon_use())
	assert_eq(tome.uses, uses_before - 1)


func test_native_weapon_enforces_the_existing_mage_lane():
	Campaign.flags["school_ember"] = true
	var fire: WeaponDef = load("res://data/weapons/fire.tres")
	for id in ["perrin", "liora"]:
		var unit := Unit.new()
		autofree(unit)
		unit.unit_def = load("res://data/units/%s.tres" % id)
		unit.equip_weapon(fire)
		assert_eq(unit.weapon() != null, id == "liora", "native equipment respects %s's lane" % id)
		assert_eq(unit.to_combatant(0, 0).weapon != null, id == "liora")


func test_saved_locked_school_falls_back_to_carried_gear_on_both_restore_paths():
	for progression_only in [false, true]:
		var kai := _kai_with_fire()
		var state := {"level": 4, "xp": 37, "inventory": [
			{"path": "res://data/weapons/fire.tres", "uses": 19},
			{"path": "res://data/items/vulnerary.tres", "uses": 2},
			{"path": "res://data/weapons/sig_kai.tres", "uses": 17},
		]}
		if progression_only:
			kai.apply_progression_state(state)
		else:
			kai.apply_save_state(state)
		assert_not_null(kai.weapon(), "restore selects usable carried gear")
		if kai.weapon() == null:
			continue
		assert_eq(kai.weapon().id, "sig_kai")
		assert_eq(kai.level, 4)
		assert_eq(kai.xp, 37)
		assert_eq(kai.inventory.items[0].uses, 17)
		assert_eq(kai.inventory.items[1].def.id, "fire")
		assert_eq(kai.inventory.items[1].uses, 19, "the locked spell is retained intact")
		assert_eq(kai.inventory.items[2].uses, 2, "the consumable is retained intact")
		assert_false(bool(Campaign.flags.get("school_ember", false)))


func test_weapon_break_skips_locked_school_and_equips_usable_backup():
	var kai := _kai_with_fire()
	kai.inventory = Inventory.from_starting([
		load("res://data/weapons/sig_kai.tres"),
		load("res://data/weapons/fire.tres"),
		load("res://data/weapons/iron_axe.tres"),
	], [])
	var sword := kai.inventory.items[0]
	var tome := kai.inventory.items[1]
	var backup := kai.inventory.items[2]
	sword.uses = 1
	var tome_uses := tome.uses
	var backup_uses := backup.uses
	assert_same(kai.spend_weapon_use(), sword)
	assert_same(kai.inventory.equipped_weapon_item(), backup, "break fallback skips ineligible magic")
	assert_same(kai.to_combatant(0, 0).weapon, backup.weapon())
	assert_eq(tome.uses, tome_uses)
	assert_eq(backup.uses, backup_uses, "fallback does not spend the newly equipped weapon")
	assert_eq(kai.inventory.size(), 2, "only the broken weapon was removed")
