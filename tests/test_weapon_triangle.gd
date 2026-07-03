extends GutTest
## WO-1.1: weapon triangle — Sword > Axe > Lance > Sword; Bow/Tome/Staff neutral.

const SWORD := WeaponDef.WeaponType.SWORD
const AXE := WeaponDef.WeaponType.AXE
const LANCE := WeaponDef.WeaponType.LANCE
const BOW := WeaponDef.WeaponType.BOW
const TOME := WeaponDef.WeaponType.TOME


func test_advantage_pairs_give_plus_15_hit_plus_1_dmg():
	for pair in [[SWORD, AXE], [AXE, LANCE], [LANCE, SWORD]]:
		assert_eq(WeaponTriangle.hit_bonus(pair[0], pair[1]), 15, str(pair))
		assert_eq(WeaponTriangle.dmg_bonus(pair[0], pair[1]), 1, str(pair))


func test_disadvantage_is_the_mirror():
	for pair in [[AXE, SWORD], [LANCE, AXE], [SWORD, LANCE]]:
		assert_eq(WeaponTriangle.hit_bonus(pair[0], pair[1]), -15, str(pair))
		assert_eq(WeaponTriangle.dmg_bonus(pair[0], pair[1]), -1, str(pair))


func test_same_type_is_neutral():
	assert_eq(WeaponTriangle.hit_bonus(SWORD, SWORD), 0)
	assert_eq(WeaponTriangle.dmg_bonus(LANCE, LANCE), 0)


func test_bow_and_tome_sit_outside_the_triangle():
	for other in [SWORD, AXE, LANCE, TOME]:
		assert_eq(WeaponTriangle.hit_bonus(BOW, other), 0, "bow vs %d" % other)
		assert_eq(WeaponTriangle.hit_bonus(other, BOW), 0, "%d vs bow" % other)
		assert_eq(WeaponTriangle.hit_bonus(TOME, other), 0, "tome vs %d" % other)
