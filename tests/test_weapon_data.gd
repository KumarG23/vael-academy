extends GutTest
## WO-1.1: the authored slice weapon .tres load with the intended §3 values.

const DIR := "res://data/weapons/"


func _load(id: String) -> WeaponDef:
	return load(DIR + id + ".tres")


func test_iron_weapons_load_with_expected_stats():
	# id -> [type, might, hit, weight, min_range, max_range]
	var expected := {
		"iron_sword": [WeaponDef.WeaponType.SWORD, 5, 90, 5, 1, 1],
		"iron_lance": [WeaponDef.WeaponType.LANCE, 7, 80, 8, 1, 1],
		"iron_axe": [WeaponDef.WeaponType.AXE, 8, 75, 10, 1, 1],
		"iron_bow": [WeaponDef.WeaponType.BOW, 6, 85, 5, 2, 2],
		"fire": [WeaponDef.WeaponType.TOME, 5, 90, 4, 1, 2],
		"heal": [WeaponDef.WeaponType.STAFF, 0, 100, 3, 1, 1],
	}
	for id in expected:
		var w := _load(id)
		assert_not_null(w, "should load " + id)
		var e: Array = expected[id]
		assert_eq(w.weapon_type, e[0], id + " type")
		assert_eq(w.might, e[1], id + " might")
		assert_eq(w.hit, e[2], id + " hit")
		assert_eq(w.weight, e[3], id + " weight")
		assert_eq(w.min_range, e[4], id + " min_range")
		assert_eq(w.max_range, e[5], id + " max_range")


func test_tome_is_magical_and_bow_is_ranged_only():
	assert_true(_load("fire").is_magical(), "fire is magical")
	assert_false(_load("iron_bow").is_magical(), "bow is physical")
	assert_false(_load("iron_bow").in_range(1), "bow cannot strike at range 1")
	assert_true(_load("iron_bow").in_range(2))


func test_staff_cannot_attack():
	assert_false(_load("heal").can_attack(), "staff is support-only")
	assert_true(_load("iron_sword").can_attack())
