extends GutTest
## WO-2.1: XP integration through battle_view — a unit levels mid-battle from a
## kill, and the healer gains XP from healing.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 2468
	add_child_autofree(_view)
	await wait_physics_frames(2)


func _wait_idle(max_frames := 400) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func _move_and_pick(select: Vector2i, dest: Vector2i, action_id: String, mover: Unit) -> void:
	_view._on_cursor_confirmed(select)
	_view._handle_selected_confirm(dest)
	await _wait_idle()
	var guard := 0
	while mover.is_moving() and guard < 240:
		await wait_physics_frames(1)
		guard += 1
	var idx: int = _view._menu_actions.find(action_id)
	assert_true(idx >= 0, "menu offers '%s'" % action_id)
	await _view._on_menu_chosen(idx)


func _sure_hit(u: Unit) -> void:
	var w := WeaponDef.new()
	var cur := u.weapon()
	w.weapon_type = cur.weapon_type
	w.might = cur.might
	w.hit = 999
	w.weight = cur.weight
	w.min_range = cur.min_range
	w.max_range = cur.max_range
	u.equip_weapon(w)


func test_unit_levels_up_mid_battle_from_a_kill():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	_sure_hit(kael)
	enemy.current_hp = 1          # a hit will kill and grant kill XP
	kael.xp = 95                  # poised to level from this exchange
	assert_eq(kael.level, 1)

	await _move_and_pick(Vector2i(3, 7), Vector2i(5, 7), "attack", kael)
	_view._handle_targeting_confirm(Vector2i(6, 7))
	await _wait_idle()

	assert_eq(kael.level, 2, "Kael leveled up mid-battle")
	assert_true(kael.xp < 100, "XP wrapped past the level")


func test_healer_gains_xp_from_healing():
	var wren: Unit = _view.unit_at(Vector2i(3, 9))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	assert_not_null(wren, "Wren present")
	assert_not_null(brenna, "Brenna present (heal target)")
	brenna.current_hp = 5         # damaged, so Wren can heal her
	assert_eq(wren.xp, 0)

	# Wren is already adjacent to Brenna; select, stay put, choose Heal from the menu.
	await _move_and_pick(Vector2i(3, 9), Vector2i(3, 9), "heal", wren)
	assert_true(_view._targeting_heal, "healer is in heal-targeting mode")
	assert_true(_view._targets.has(brenna), "Brenna is a heal target")

	_view._handle_targeting_confirm(Vector2i(4, 9))
	await _wait_idle()

	assert_gt(brenna.current_hp, 5, "Brenna was healed")
	assert_gt(wren.xp, 0, "Wren earned XP for healing")
