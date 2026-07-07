extends GutTest
## WO-5.2: the full Emberwing roster + the protagonist slot. Kai is not a
## roster member — he's house-agnostic (§4), appended to the chosen roster,
## and still the lord.


func test_roster_is_the_emberwing_house_without_kai():
	assert_eq(Roster.PLAYER_IDS, ["perrin", "kael", "brenna", "wren", "dain", "liora"] as Array[String],
		"heir + five per CHARACTER_BIBLE_EMBERWING")
	assert_false(Roster.PLAYER_IDS.has("kai"), "Kai is not a roster member")


func test_protagonist_is_appended_to_fielded_units():
	var ids: Array = []
	for def in Roster.player_units():
		ids.append(def.id)
	assert_eq(ids.size(), 7)
	assert_eq(ids.back(), "kai", "the protagonist slot is appended (§4)")


func test_kai_is_still_the_lord():
	var kai: UnitDef = null
	for def in Roster.player_units():
		if def.id == "kai":
			kai = def
	assert_not_null(kai)
	assert_true(kai.is_lord, "protagonist extraction keeps the lord flag")


func test_every_fielded_unit_has_a_deploy_fallback():
	var cells := Roster.deploy_cells()
	for id in Roster.all_player_ids():
		assert_true(cells.has(id), "%s has a fallback deploy cell" % id)


func test_new_units_match_their_bible_identities():
	var defs: Dictionary = {}
	for def in Roster.player_units():
		defs[def.id] = def
	assert_eq(defs["dain"].char_class.id, "fighter")
	assert_true(defs["dain"].weapon.display_name.contains("Axe"), "Dain swings an axe")
	assert_gt(defs["dain"].strength, 8, "STR bruiser")
	assert_eq(defs["liora"].char_class.id, "mage")
	assert_gt(defs["liora"].magic, defs["liora"].strength, "MAG glass cannon")
	assert_eq(defs["perrin"].char_class.id, "paladin")
