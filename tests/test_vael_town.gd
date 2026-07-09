extends GutTest
## AW-66: the Town of Vael — the road from campus, working shops (gold → kit),
## the spellbook merchant, and the Gilded Stag tavern (meals = bond).

var _castle: CastleScene


func before_each() -> void:
	Campaign.reset_new_game(false)
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(_castle)


func after_each() -> void:
	Campaign.reset_new_game(false)


func test_the_town_stands_and_the_road_connects():
	for rid in ["vael_square", "vael_market", "vael_castle_gate", "vael_cathedral", "vael_riverside"]:
		assert_true(_castle._rooms.has(rid), rid + " exists")
	var road := false
	for d in _castle._rooms["campus"].doors:
		if d.to_room == "vael_square":
			road = true
	assert_true(road, "the campus gatehouse roads to town")


func test_smithy_sells_into_kais_kit():
	Campaign.flags["gold"] = 200
	_castle._open_shop("fn_shop_smith")
	assert_eq(_castle._menu_context, "shop")
	_castle._do_shop(0)  # Iron Sword, 80g
	assert_eq(_castle.gold(), 120, "the purse pays")
	var saved: Array = Campaign.get_unit_state("kai")["inventory"]
	var has := false
	for e in saved:
		if str(e.get("id", "")) == "iron_sword":
			has = true
	assert_true(has, "the sword lands in Kai's persisted kit")


func test_broke_students_buy_nothing():
	Campaign.flags["gold"] = 10
	_castle._open_shop("fn_shop_smith")
	_castle._do_shop(0)
	assert_eq(_castle.gold(), 10, "no gold moved")
	assert_false(Campaign.has_unit_state("kai"), "no sword either")


func test_spellbook_merchant_opens_a_school():
	Campaign.flags["gold"] = 1000
	_castle._open_shop("fn_shop_magic")
	assert_eq(_castle._shop_wares.size(), 3, "all three schools on the shelf")
	_castle._do_shop(0)  # Ember
	assert_true(bool(Campaign.flags.get("spellbook_ember", false)))
	assert_true(bool(Campaign.flags.get("school_ember", false)), "the school opens")
	assert_eq(_castle.gold(), 100, "spellbooks are expensive")
	# the shelf loses the sold school
	_castle._open_shop("fn_shop_magic")
	assert_eq(_castle._shop_wares.size(), 2)


func test_tavern_meal_deepens_the_bond_weekly():
	Campaign.flags["gold"] = 100
	var before: int = _castle._support_state.points_for_units("kai", "liora")
	_castle._open_tavern()
	assert_eq(_castle._menu_context, "tavern")
	# find Liora among the partners
	var partners: Array = []
	for def in _castle._roster_defs:
		if def.id != "kai":
			partners.append(def.id)
	var li := partners.find("liora")
	_castle._do_tavern(li)
	assert_eq(_castle._support_state.points_for_units("kai", "liora"), before + 8, "stew works")
	assert_eq(_castle.gold(), 100 - _castle.TAVERN_MEAL_COST)
	_castle._open_tavern()
	assert_eq(_castle._menu_context, "", "once a week — the kitchen closes")
