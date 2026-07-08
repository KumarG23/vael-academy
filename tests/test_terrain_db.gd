extends GutTest
## WO-0.2: TerrainDB must reproduce the §3 terrain table exactly.


var _db: TerrainDB


func before_each() -> void:
	_db = TerrainDB.create_default()


func test_all_types_present():
	for t in [
		Terrain.Type.PLAINS, Terrain.Type.FOREST, Terrain.Type.MOUNTAIN,
		Terrain.Type.FORT, Terrain.Type.WALL, Terrain.Type.WATER,
	]:
		assert_not_null(_db.get_info(t), "TerrainDB missing type %d" % t)


func test_plains():
	var i := _db.get_info(Terrain.Type.PLAINS)
	assert_eq(i.move_cost, 1)
	assert_eq(i.defense, 0)
	assert_eq(i.avoid, 0)
	assert_false(i.impassable)


func test_forest():
	var i := _db.get_info(Terrain.Type.FOREST)
	assert_eq(i.move_cost, 2)
	assert_eq(i.defense, 1)
	assert_eq(i.avoid, 20)
	assert_false(i.impassable)


func test_mountain_blocks_armored_and_mounted():
	var i := _db.get_info(Terrain.Type.MOUNTAIN)
	assert_eq(i.move_cost, 4)
	assert_eq(i.defense, 2)
	assert_eq(i.avoid, 30)
	assert_true(i.blocks_armored_mounted)
	assert_false(i.impassable)


func test_fort_heals_ten_percent():
	var i := _db.get_info(Terrain.Type.FORT)
	assert_eq(i.move_cost, 2)
	assert_eq(i.defense, 2)
	assert_eq(i.avoid, 20)
	assert_almost_eq(i.heal_pct, 0.10, 0.0001)


func test_wall_and_water_impassable():
	assert_true(_db.get_info(Terrain.Type.WALL).impassable)
	assert_true(_db.get_info(Terrain.Type.WATER).impassable)


func test_helper_lookups():
	assert_eq(_db.move_cost(Terrain.Type.FOREST), 2)
	assert_eq(_db.defense(Terrain.Type.FORT), 2)
	assert_eq(_db.avoid(Terrain.Type.MOUNTAIN), 30)
	assert_true(_db.is_impassable(Terrain.Type.WATER))
	assert_false(_db.is_impassable(Terrain.Type.PLAINS))


# --- AW-29: hazard + debuff tiles --------------------------------------------

func test_embers_are_a_passable_hazard():
	var i := _db.get_info(Terrain.Type.EMBERS)
	assert_false(i.impassable, "you can walk through embers")
	assert_eq(i.defense, 0, "no cover")
	assert_eq(i.avoid, 0)
	assert_eq(i.damage_per_turn, 3, "chips 3 HP a turn")
	assert_eq(_db.damage_per_turn(Terrain.Type.EMBERS), 3)


func test_mire_is_a_debuff():
	var i := _db.get_info(Terrain.Type.MIRE)
	assert_false(i.impassable)
	assert_eq(i.move_cost, 4, "slows movement")
	assert_eq(i.defense, -1, "worse defense")
	assert_eq(i.avoid, -15, "easier to hit")
	assert_eq(i.damage_per_turn, 0, "not a hazard, a debuff")


func test_normal_terrain_deals_no_turn_damage():
	assert_eq(_db.damage_per_turn(Terrain.Type.PLAINS), 0)
	assert_eq(_db.damage_per_turn(Terrain.Type.FORT), 0)
