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
	assert_false(_view._busy, "battle action completed within the frame budget")


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
	# AW-26: Attack/Magic pick a weapon first when the unit carries more than one
	# (Kael has a sword + an axe); the equipped weapon is index 0.
	if _view._menu_context in ["attack_weapon", "magic_spell"]:
		await _view._on_menu_chosen(0)


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


func test_tome_cannot_be_traded_in_battle():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	var spell := InventoryItem.from_weapon(load("res://data/weapons/fire.tres"))
	assert_true(kael.inventory.add(spell), "the test tome fits in Kael's pack")

	await _move_and_pick(Vector2i(3, 7), Vector2i(4, 8), "trade", kael)
	assert_eq(_view._menu_context, "trade_ally")
	_view._on_menu_chosen(0)  # pick Brenna
	assert_eq(_view._menu_context, "trade_give")
	var idx: int = _view._menu_items.find(spell)
	assert_true(idx >= 0, "the tome is listed so the refusal is visible")
	var brenna_slots := brenna.inventory.size()
	var kael_slots := kael.inventory.size()

	_view._on_menu_chosen(idx)
	await _wait_idle()

	assert_true(kael.inventory.has(spell), "magic stays with its learner")
	assert_eq(brenna.inventory.size(), brenna_slots, "the receiver gets nothing")
	assert_eq(kael.inventory.size(), kael_slots, "the giver keeps the tome")
	assert_eq(_view._menu_context, "trade_give", "the give menu lets you pick another item")


func test_last_vulnerary_use_caps_healing_and_removes_only_that_item():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	kael.current_hp = kael.max_hp() - 1
	var vuln: InventoryItem = kael.inventory.consumables()[0]
	vuln.uses = 1
	var other_items: Array = kael.inventory.items.duplicate()
	other_items.erase(vuln)
	var weapon_item: InventoryItem = kael.inventory.equipped_weapon_item()
	var weapon_uses := weapon_item.uses

	await _move_and_pick(kael.cell, kael.cell, "item", kael)
	var idx: int = _view._menu_items.find(vuln)
	assert_gte(idx, 0, "the vulnerary is available")
	await _view._on_menu_chosen(idx)
	await _wait_idle()

	assert_eq(kael.current_hp, kael.max_hp(), "the item cannot overheal")
	assert_eq(vuln.uses, 0, "the final use was spent")
	assert_false(kael.inventory.has(vuln), "the exhausted item is removed")
	assert_eq(kael.inventory.items, other_items, "all other items and their order survive")
	assert_eq(weapon_item.uses, weapon_uses, "using an item does not wear the weapon")
	assert_eq(kael.xp, 0, "consumable healing does not grant staff XP")
	assert_true(kael.has_acted, "using an item spends the action")


func test_cancelling_item_menu_preserves_hp_uses_and_action():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	kael.current_hp = 5
	var before: Dictionary = kael.save_state()

	await _move_and_pick(kael.cell, kael.cell, "item", kael)
	_view._on_menu_cancelled()

	assert_eq(_view._menu_context, "action", "cancel returns to the action menu")
	assert_eq(kael.save_state(), before, "browsing items spends no HP, uses, XP or action")
	_view._on_menu_cancelled()
	assert_eq(_view._phase, _view.Phase.IDLE, "a second cancel returns to the map")
	assert_eq(kael.save_state(), before, "leaving the action menu preserves the unit")


func test_full_trade_recipient_keeps_both_inventories_and_action_available():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	for slot in range(Inventory.MAX_SLOTS - brenna.inventory.size()):
		assert_true(brenna.inventory.add(InventoryItem.from_item(load("res://data/items/vulnerary.tres"))))
	assert_true(brenna.inventory.is_full(), "the recipient's pack starts full")
	var giver_before: Array = kael.inventory.items.duplicate()
	var receiver_before: Array = brenna.inventory.items.duplicate()
	var offered: InventoryItem = giver_before[0]
	var uses_before := offered.uses

	await _move_and_pick(kael.cell, Vector2i(4, 8), "trade", kael)
	await _view._on_menu_chosen(_view._menu_partners.find(brenna))
	assert_eq(_view._menu_context, "trade_give")
	await _view._on_menu_chosen(_view._menu_items.find(offered))

	assert_eq(kael.inventory.items, giver_before, "the full-pack refusal keeps the giver's items")
	assert_eq(brenna.inventory.items, receiver_before, "the receiver loses or gains nothing")
	assert_eq(offered.uses, uses_before, "the refused item keeps its durability")
	assert_eq(_view._menu_context, "trade_give", "trade remains open after refusal")
	assert_false(kael.has_acted, "the player can choose another action")


func test_traded_equipped_weapon_keeps_durability_after_cancelling_movement():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var brenna: Unit = _view.unit_at(Vector2i(4, 9))
	var origin := kael.cell
	var offered: InventoryItem = kael.inventory.equipped_weapon_item()
	offered.uses = 7
	var backup: InventoryItem = kael.inventory.items[1]
	var backup_uses := backup.uses
	var kael_slots := kael.inventory.size()
	var brenna_slots := brenna.inventory.size()

	await _move_and_pick(origin, Vector2i(4, 8), "trade", kael)
	await _view._on_menu_chosen(_view._menu_partners.find(brenna))
	await _view._on_menu_chosen(_view._menu_items.find(offered))
	assert_eq(_view._menu_context, "trade_give")
	_view._on_menu_cancelled()  # give submenu -> action menu
	_view._on_menu_cancelled()  # action menu -> undo movement

	assert_eq(_view._phase, _view.Phase.IDLE, "cancel returns to the map")
	assert_eq(kael.cell, origin, "the movement is undone")
	assert_eq(kael.position, _view._grid.cell_center(origin), "the sprite returns with the unit")
	assert_false(kael.has_acted, "trading leaves the player able to act")
	assert_false(kael.inventory.has(offered), "undoing movement does not undo the trade")
	assert_true(brenna.inventory.has(offered), "the exact worn weapon remains with the recipient")
	assert_eq(offered.uses, 7, "trade never repairs or wears the transferred weapon")
	assert_eq(kael.inventory.size(), kael_slots - 1, "the giver lost exactly one item")
	assert_eq(brenna.inventory.size(), brenna_slots + 1, "the recipient received exactly one item")
	assert_eq(kael.inventory.equipped_weapon_item(), backup, "the backup becomes equipped")
	assert_eq(backup.uses, backup_uses, "the backup was not used by trading")


func test_follow_up_attack_spends_one_use_and_out_of_range_defender_spends_none():
	var kael: Unit = _view.unit_at(Vector2i(3, 7))
	var enemy: Unit = _view.unit_at(Vector2i(6, 7))
	# Local copies force two noncritical hits and keep the target alive; the
	# defender's range-two weapon cannot counter this melee attack.
	var sword: WeaponDef = kael.weapon().duplicate()
	sword.hit = 999
	sword.crit = -999
	sword.might = 0
	sword.weight = 0
	kael.equip_weapon(sword)
	kael._stat_bonus["spd"] = 30
	var bow: WeaponDef = load("res://data/weapons/iron_bow.tres").duplicate()
	enemy.equip_weapon(bow)
	enemy._stat_bonus["hp"] = 200
	enemy.current_hp = enemy.max_hp()
	var attacker_item: InventoryItem = kael.inventory.equipped_weapon_item()
	var defender_item: InventoryItem = enemy.inventory.equipped_weapon_item()
	var attack_uses := attacker_item.uses
	var defend_uses := defender_item.uses
	var hp_before := kael.current_hp
	var enemy_hp_before := enemy.current_hp

	await _move_and_pick(kael.cell, Vector2i(5, 7), "attack", kael)
	var damage: int = CombatForecast.strike_stats(
		_view._combatant_for(kael, kael.cell), _view._combatant_for(enemy, enemy.cell))["damage"]
	assert_gt(damage, 0, "the two strikes will deal observable damage")
	await _view._handle_targeting_confirm(enemy.cell)
	await _wait_idle()

	assert_eq(enemy.current_hp, enemy_hp_before - damage * 2, "both initiating strikes landed")
	assert_eq(attacker_item.uses, attack_uses - 1, "a follow-up spends no second use")
	assert_eq(defender_item.uses, defend_uses, "a defender that cannot counter spends no use")
	assert_eq(kael.current_hp, hp_before, "the range-two defender did not counter")
	assert_eq(kael.xp, 10, "two hits still award XP only once per exchange")
