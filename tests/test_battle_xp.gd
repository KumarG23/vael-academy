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
	assert_false(_view._busy, "battle action completed within the frame budget")


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
	# AW-26: Attack/Magic pick a weapon first when the unit carries more than one;
	# the equipped weapon is index 0.
	if _view._menu_context in ["attack_weapon", "magic_spell"]:
		await _view._on_menu_chosen(0)


func _sure_hit(u: Unit) -> void:
	var w := WeaponDef.new()
	var cur := u.weapon()
	w.weapon_type = cur.weapon_type
	w.might = cur.might
	w.hit = 999
	w.crit = -999  # keep hit/counter fixtures independent of lucky criticals
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
	assert_eq(kael.xp, 25, "one equal-level kill awards 30 XP, retaining the overflow")


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


func test_heal_xp_counts_only_hp_restored_and_can_level_the_healer():
	var wren: Unit = _view.unit_at(Vector2i(3, 9))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	brenna.current_hp = brenna.max_hp() - 1
	wren.xp = 95
	var staff: InventoryItem = wren.inventory.equipped_weapon_item()
	var uses_before := staff.uses

	await _move_and_pick(wren.cell, wren.cell, "heal", wren)
	await _view._handle_targeting_confirm(brenna.cell)
	await _wait_idle()

	assert_eq(brenna.current_hp, brenna.max_hp(), "healing caps at the target's maximum HP")
	assert_eq(wren.level, 2, "healing crosses the level threshold")
	assert_eq(wren.xp, 6, "one restored HP earns 11 XP, regardless of staff power")
	assert_eq(staff.uses, uses_before - 1, "the heal spends one staff use")
	assert_true(wren.has_acted, "healing spends the healer's action")


func test_off_target_heal_confirmation_spends_no_xp_or_staff_uses():
	var wren: Unit = _view.unit_at(Vector2i(3, 9))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	brenna.current_hp = 5
	wren.xp = 95
	var staff: InventoryItem = wren.inventory.equipped_weapon_item()
	var uses_before := staff.uses

	await _move_and_pick(wren.cell, wren.cell, "heal", wren)
	await _view._handle_targeting_confirm(wren.cell)  # self is not a heal target

	assert_eq(_view._menu_context, "action", "off-target confirmation returns to the action menu")
	assert_eq(brenna.current_hp, 5, "no ally was healed")
	assert_eq(wren.level, 1, "no level-up for an uncommitted heal")
	assert_eq(wren.xp, 95, "XP is unchanged")
	assert_eq(staff.uses, uses_before, "the staff is unchanged")
	assert_false(wren.has_acted, "the healer can still choose an action")


func test_missed_attack_earns_no_xp_even_when_the_enemy_counter_connects():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	var miss_weapon: WeaponDef = kael.weapon().duplicate()
	miss_weapon.hit = -999
	kael.equip_weapon(miss_weapon)
	_sure_hit(enemy)
	kael.xp = 95
	var hp_before := kael.current_hp
	var enemy_hp_before := enemy.current_hp

	await _move_and_pick(kael.cell, Vector2i(5, 7), "attack", kael)
	await _view._handle_targeting_confirm(enemy.cell)
	await _wait_idle()

	assert_eq(enemy.current_hp, enemy_hp_before, "all initiating strikes missed")
	assert_lt(kael.current_hp, hp_before, "the enemy counter connected")
	assert_eq(kael.xp, 95, "the enemy's hit cannot award XP to the attacker")
	assert_eq(kael.level, 1, "a miss cannot cause a level-up")
	assert_eq(enemy.xp, 0, "enemy units do not earn combat XP")


func test_player_counterattack_earns_xp_during_enemy_initiated_combat():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	_sure_hit(kael)
	_sure_hit(enemy)
	# Place the player in melee range without spending a player action.
	kael.cell = Vector2i(5, 7)
	kael.position = _view._grid.cell_center(kael.cell)
	var enemy_hp_before := enemy.current_hp

	await _view._execute_attack(enemy, kael)
	await _wait_idle()

	assert_true(enemy.is_alive(), "the counter target survived")
	assert_lt(enemy.current_hp, enemy_hp_before, "the player's counter connected")
	assert_eq(kael.xp, 10, "counter hits award XP once per exchange")
	assert_eq(enemy.xp, 0, "the enemy initiator earns no XP")
	assert_false(kael.has_acted, "countering preserves the player's next action")
