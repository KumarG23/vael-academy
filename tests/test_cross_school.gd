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
	castle.enter_room("library", 0.72)
	var vp := castle.get_viewport_rect().size
	castle._avatar_pos = Vector2(vp.x * 0.72, vp.y * 0.8)
	castle._update_prompt(vp)
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
