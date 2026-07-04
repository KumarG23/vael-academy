extends GutTest
## WO-3.4: house theming + camaraderie through battle_view.

var _view: Node2D


func _make(player_house := "emberwing") -> Node2D:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	var v: Node2D = scene.instantiate()
	v.strike_delay = 0.0
	v.combat_seed = 5
	v.player_house_id = player_house
	add_child_autofree(v)
	return v


func before_each() -> void:
	_view = _make()
	await wait_physics_frames(2)


func test_all_three_houses_load_as_data():
	assert_eq(_view._houses.size(), 3, "emberwing/tidemark/thornrook authored")
	assert_not_null(_view.player_house())
	assert_eq(_view.player_house().id, "emberwing")


func test_camaraderie_changes_the_forecast():
	# Kael starts next to housemate Kai (2,7)/(3,7) -> camaraderie active.
	var kael: Unit = _view.unit_by_id("kael")
	var with_mate: Combatant = _view._combatant_for(kael, kael.cell)
	assert_eq(with_mate.support_avoid, 5, "camaraderie grants +5 avoid near a housemate")
	assert_eq(with_mate.support_hit, 5, "and +5 hit")
	# An isolated tile has no housemate in range.
	var alone: Combatant = _view._combatant_for(kael, Vector2i(18, 13))
	assert_eq(alone.support_avoid, 0, "no housemate in range -> no camaraderie")


func test_units_tint_to_their_house_color():
	var kael: Unit = _view.unit_by_id("kael")
	var enemy: Unit = _view.unit_by_id("tide_a")
	assert_eq(kael.house_color, _view.player_house().primary_color, "player unit uses Emberwing color")
	assert_eq(enemy.house_color, _view.enemy_house().primary_color, "enemy uses Tidemark color")
	assert_ne(kael.house_color, enemy.house_color, "the two houses read differently")


func test_swapping_the_player_house_rethemes_ui_with_no_code_change():
	# Same scene code, different player HouseDef -> different resolved UI chrome.
	var thorn := _make("thornrook")
	await wait_physics_frames(2)
	# Turn banner accent follows the active player house.
	assert_ne(_view._turn_banner.player_accent, thorn._turn_banner.player_accent)
	assert_eq(thorn._turn_banner.player_accent, thorn.player_house().primary_color)
	# Menu accent follows the active player house's secondary color.
	assert_eq(thorn._menu.accent, thorn.player_house().secondary_color)
	assert_ne(_view._menu.accent, thorn._menu.accent)
