extends GutTest
## WO-2.2: pure inventory / durability model.

func _sword(uses := 40) -> WeaponDef:
	var w := CombatTestHelpers.sword()
	w.display_name = "Iron Sword"
	w.max_uses = uses
	return w


func _vuln() -> ItemDef:
	var i := ItemDef.new()
	i.display_name = "Vulnerary"
	i.kind = ItemDef.Kind.VULNERARY
	i.power = 10
	i.max_uses = 3
	return i


func test_item_wraps_weapon_with_its_uses():
	var it := InventoryItem.from_weapon(_sword(30))
	assert_true(it.is_weapon())
	assert_false(it.is_consumable())
	assert_eq(it.uses, 30)


func test_spend_reports_depletion_at_zero():
	var it := InventoryItem.from_weapon(_sword(2))
	assert_false(it.spend(), "2 -> 1, not depleted")
	assert_true(it.spend(), "1 -> 0, depleted")
	assert_true(it.is_depleted())


func test_add_respects_five_slot_cap():
	var inv := Inventory.new()
	for i in range(Inventory.MAX_SLOTS):
		assert_true(inv.add(InventoryItem.from_weapon(_sword())))
	assert_true(inv.is_full())
	assert_false(inv.add(InventoryItem.from_weapon(_sword())), "6th item rejected")
	assert_eq(inv.size(), 5)


func test_equipped_weapon_is_the_first_weapon():
	var inv := Inventory.new()
	inv.add(InventoryItem.from_item(_vuln()))     # consumable first
	var sword := InventoryItem.from_weapon(_sword())
	inv.add(sword)
	assert_eq(inv.equipped_weapon_item(), sword, "skips the consumable")


func test_equip_promotes_a_weapon_to_the_front():
	var inv := Inventory.new()
	var a := InventoryItem.from_weapon(_sword())
	var b := InventoryItem.from_weapon(CombatTestHelpers.axe())
	inv.add(a)
	inv.add(b)
	assert_eq(inv.equipped_weapon_item(), a)
	inv.equip(b)
	assert_eq(inv.equipped_weapon_item(), b, "equipping moves b to the front")


func test_use_equipped_weapon_breaks_and_reequips():
	var inv := Inventory.new()
	var brittle := InventoryItem.from_weapon(_sword(1))
	var backup := InventoryItem.from_weapon(CombatTestHelpers.axe())
	inv.add(brittle)
	inv.add(backup)
	var broke := inv.use_equipped_weapon()
	assert_eq(broke, brittle, "the 1-use weapon broke")
	assert_false(inv.has(brittle), "broken weapon removed")
	assert_eq(inv.equipped_weapon_item(), backup, "backup auto-equips")


func test_use_equipped_weapon_returns_null_until_break():
	var inv := Inventory.new()
	inv.add(InventoryItem.from_weapon(_sword(3)))
	assert_null(inv.use_equipped_weapon())  # 3 -> 2
	assert_null(inv.use_equipped_weapon())  # 2 -> 1
	assert_not_null(inv.use_equipped_weapon(), "1 -> 0 breaks")


func test_use_consumable_removes_when_exhausted():
	var inv := Inventory.new()
	var v := InventoryItem.from_item(_vuln())  # 3 uses
	inv.add(v)
	inv.use_consumable(v)
	inv.use_consumable(v)
	assert_true(inv.has(v), "still 1 use left")
	inv.use_consumable(v)
	assert_false(inv.has(v), "removed at 0 uses")


func test_transfer_moves_item_when_target_has_room():
	var a := Inventory.new()
	var b := Inventory.new()
	var item := InventoryItem.from_item(_vuln())
	a.add(item)
	assert_true(a.transfer_to(item, b))
	assert_false(a.has(item))
	assert_true(b.has(item))


func test_transfer_fails_when_target_full():
	var a := Inventory.new()
	var b := Inventory.new()
	for i in range(Inventory.MAX_SLOTS):
		b.add(InventoryItem.from_weapon(_sword()))
	var item := InventoryItem.from_item(_vuln())
	a.add(item)
	assert_false(a.transfer_to(item, b), "no room in target")
	assert_true(a.has(item), "item stays put")
