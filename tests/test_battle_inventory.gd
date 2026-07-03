extends GutTest
## WO-2.2: inventory / durability / trade integration through battle_view.

var _view: Node2D


func before_each() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle.tscn")
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.combat_seed = 999
	add_child_autofree(_view)
	await wait_physics_frames(2)


func _wait_idle(max_frames := 400) -> void:
	var n := 0
	while _view._busy and n < max_frames:
		await wait_physics_frames(1)
		n += 1


func _sure_hit_1use(u: Unit) -> void:
	var w := WeaponDef.new()
	var cur := u.weapon()
	w.weapon_type = cur.weapon_type
	w.might = cur.might
	w.hit = 999
	w.weight = cur.weight
	w.min_range = 1
	w.max_range = 1
	w.max_uses = 1
	u.equip_weapon(w)  # resets uses to max_uses (1)


func _move_and_pick(select: Vector2i, dest: Vector2i, action_id: String, mover: Unit) -> void:
	_view._on_cursor_confirmed(select)
	_view._handle_selected_confirm(dest)
	await _wait_idle()
	var guard := 0
	while mover.is_moving() and guard < 240:
		await wait_physics_frames(1)
		guard += 1
	assert_eq(_view._phase, _view.Phase.MENU, "command menu after moving")
	var idx: int = _view._menu_actions.find(action_id)
	assert_true(idx >= 0, "menu offers '%s'" % action_id)
	await _view._on_menu_chosen(idx)


func test_weapon_breaks_at_zero_uses_and_backup_equips():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	_sure_hit_1use(kael)
	var slots_before := kael.inventory.size()
	assert_eq(kael.weapon().weapon_type, WeaponDef.WeaponType.SWORD)

	await _move_and_pick(Vector2i(3, 7), Vector2i(5, 7), "attack", kael)
	_view._handle_targeting_confirm(Vector2i(6, 7))
	await _wait_idle()

	assert_eq(kael.inventory.size(), slots_before - 1, "the broken weapon left the inventory")
	assert_eq(kael.weapon().weapon_type, WeaponDef.WeaponType.AXE, "backup axe auto-equipped")


func test_vulnerary_heals_and_is_consumed():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	kael.current_hp = 5
	var vuln: InventoryItem = kael.inventory.consumables()[0]
	var uses_before := vuln.uses

	await _move_and_pick(Vector2i(3, 7), Vector2i(3, 7), "item", kael)  # stay put, open Item
	assert_eq(_view._menu_context, "item")
	await _view._on_menu_chosen(0)  # use the vulnerary
	await _wait_idle()

	assert_eq(kael.current_hp, 15, "healed by the vulnerary's 10 power")
	assert_eq(vuln.uses, uses_before - 1, "one use spent")


func test_item_action_hidden_at_full_hp():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	assert_eq(kael.current_hp, kael.max_hp(), "starts at full HP")
	# Stay put and open the command menu.
	_view._on_cursor_confirmed(Vector2i(3, 7))
	_view._handle_selected_confirm(Vector2i(3, 7))
	await _wait_idle()
	assert_eq(_view._phase, _view.Phase.MENU)
	assert_false(_view._menu_actions.has("item"), "no Item option at full HP")


func test_trade_gives_an_item_to_an_adjacent_ally():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	var brenna_slots := brenna.inventory.size()
	var kael_slots := kael.inventory.size()

	# Move Kael adjacent to Brenna (4,8 is next to 4,9), then Trade.
	await _move_and_pick(Vector2i(3, 7), Vector2i(4, 8), "trade", kael)
	assert_eq(_view._menu_context, "trade_ally")
	_view._on_menu_chosen(0)  # pick the (only) adjacent ally: Brenna
	assert_eq(_view._menu_context, "trade_give")
	# Give the first item.
	_view._on_menu_chosen(0)
	await _wait_idle()

	assert_eq(brenna.inventory.size(), brenna_slots + 1, "Brenna received an item")
	assert_eq(kael.inventory.size(), kael_slots - 1, "Kael gave one away")
