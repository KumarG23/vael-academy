extends GutTest
## WO-3.4: the House Camaraderie passive (§4) — pure logic.

var _house: HouseDef


func before_each() -> void:
	_house = HouseDef.new()
	_house.camaraderie_hit = 5
	_house.camaraderie_avoid = 5
	_house.camaraderie_range = 2


func test_bonus_when_a_housemate_is_within_range():
	var b := Camaraderie.bonus(_house, Vector2i(5, 5), [Vector2i(5, 7)])  # distance 2
	assert_eq(b["hit"], 5)
	assert_eq(b["avoid"], 5)
	assert_eq(b["damage"], 0)
	assert_eq(b["crit"], 0)


func test_no_bonus_when_housemates_are_too_far():
	var b := Camaraderie.bonus(_house, Vector2i(5, 5), [Vector2i(5, 8)])  # distance 3
	assert_eq(b["hit"], 0)
	assert_eq(b["avoid"], 0)


func test_no_bonus_with_no_housemates():
	assert_eq(Camaraderie.bonus(_house, Vector2i(5, 5), []), Camaraderie.ZERO)


func test_does_not_stack_per_housemate():
	# Two housemates in range still grant the flat bonus once.
	var b := Camaraderie.bonus(_house, Vector2i(5, 5), [Vector2i(5, 6), Vector2i(4, 5)])
	assert_eq(b["hit"], 5, "flat, not additive per ally")


func test_null_house_is_safe():
	assert_eq(Camaraderie.bonus(null, Vector2i(0, 0), [Vector2i(0, 1)]), Camaraderie.ZERO)


func test_respects_a_custom_range():
	_house.camaraderie_range = 3
	var b := Camaraderie.bonus(_house, Vector2i(5, 5), [Vector2i(5, 8)])  # distance 3
	assert_eq(b["hit"], 5, "now in range at 3")
