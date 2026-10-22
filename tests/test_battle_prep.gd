extends GutTest
## AW-74: the preparations screen — reposition among deploy slots, camp-wide
## trade, the traveling merchant (once unlocked), and Begin battle.

const SCENE := "res://scenes/battle/mock_battle.tscn"

var _view


func before_each() -> void:
	Campaign.reset_new_game(false)
	Campaign.set_house("emberwing")
	Campaign.deploy()
	BattleView.next_prep = true
	_view = (load(SCENE) as PackedScene).instantiate()
	_view.dialogue_enabled = false
	add_child_autofree(_view)


func after_each() -> void:
	BattleView.next_prep = false


func test_missions_open_on_preparations():
	assert_eq(_view._phase, _view.Phase.PREP, "the map waits for your plan")
	assert_true(_view._prep_active)
	assert_false(BattleView.next_prep, "the flag is consumed")
	assert_gt(_view._prep._slots.size(), 1, "the deploy slots are recorded")


func test_swap_two_units_between_slots():
	var a: Unit = _view._living_units_on_team(0)[0]
	var b: Unit = _view._living_units_on_team(0)[1]
	var ca := a.cell
	var cb := b.cell
	_view._prep.confirm(ca)          # pick up A
	assert_eq(_view._prep._pick, a)
	_view._prep.confirm(cb)          # drop on B
	assert_eq(a.cell, cb, "A stands where B stood")
	assert_eq(b.cell, ca, "and B where A stood")
	assert_null(_view._prep._pick, "hands are empty again")


func test_cannot_place_outside_the_deploy_slots():
	var a: Unit = _view._living_units_on_team(0)[0]
	var ca := a.cell
	_view._prep.confirm(ca)
	_view._prep.confirm(Vector2i(0, 0))  # not a slot
	assert_eq(a.cell, ca, "no wandering off the formation")


func test_begin_battle_hands_over_to_the_player_phase():
	_view._prep.open_prep_menu()
	var idx: int = _view._menu_actions.find("begin")
	assert_true(idx >= 0, "Begin battle is on the menu")
	_view._prep.choose("prep_field", idx)
	assert_eq(_view._phase, _view.Phase.IDLE)
	assert_false(_view._prep_active)
	for u in _view._living_units_on_team(0):
		assert_false(u.has_acted, "everyone is fresh for round 1")


func test_prep_trade_moves_gear_without_spending_anyone():
	var giver: Unit = null
	for u in _view._living_units_on_team(0):
		if not u.inventory.is_empty():
			giver = u
			break
	assert_not_null(giver, "someone has gear")
	_view._prep.open_trade_giver()
	var gi: int = _view._menu_partners.find(giver)
	_view._prep.choose("prep_trade_a", gi)
	var recv: Unit = _view._menu_partners[0]
	var before: int = recv.inventory.size()
	_view._prep.choose("prep_trade_b", 0)
	# skip anything innate (Crownspark refuses to move) — find a tradeable index
	var idx := -1
	for i in range(_view._menu_items.size()):
		var it: InventoryItem = _view._menu_items[i]
		if not (it.is_weapon() and it.weapon().innate):
			idx = i
			break
	assert_true(idx >= 0, "a tradeable piece exists")
	_view._prep.choose("prep_give", idx)
	assert_eq(recv.inventory.size(), before + 1, "the gear moved")
	assert_false(giver.has_acted, "prep trades cost nothing")
	assert_true(_view._prep_active, "still planning — no phase started")


func test_merchant_hidden_until_unlocked_then_sells_and_buys():
	_view._prep.open_prep_menu()
	assert_eq(_view._menu_actions.find("shop"), -1, "no merchant before the unlock")
	_view._menu.close()
	Campaign.flags["merchant_unlocked"] = true
	Campaign.flags["gold"] = 100
	_view._prep.open_prep_menu()
	assert_true(_view._menu_actions.find("shop") >= 0, "the cart has arrived")
	# buy: a vulnerary into Kai's pack
	var kai: Unit = _view._lord_unit
	var packed: int = kai.inventory.size()
	_view._prep.open_shop()
	_view._prep.choose("prep_shop", 0)  # Vulnerary, 60g
	assert_eq(int(Campaign.flags["gold"]), 40, "60g spent")
	assert_eq(kai.inventory.size(), packed + 1, "the vulnerary is packed")
	# sell it back for half
	_view._prep.open_sell_unit()
	var si: int = _view._menu_partners.find(kai)
	_view._prep.choose("prep_sell_unit", si)
	var idx := -1
	for i in range(_view._prep._sell_items.size()):
		if _view._prep.sell_price(_view._prep._sell_items[i]) == 30:
			idx = i
			break
	assert_true(idx >= 0, "the vulnerary lists at half price")
	_view._prep.choose("prep_sell_item", idx)
	assert_eq(int(Campaign.flags["gold"]), 70, "half the price comes back")
	assert_eq(kai.inventory.size(), packed, "and the pack is back to before")


func test_innate_gear_has_no_price():
	var kai: Unit = _view._lord_unit
	var crownspark: InventoryItem = null
	for it in kai.inventory.items:
		if it.is_weapon() and it.weapon().innate:
			crownspark = it
	assert_not_null(crownspark, "Kai carries his bound spell")
	assert_eq(_view._prep.sell_price(crownspark), 0, "the merchant won't touch it")


func test_prep_trade_refuses_bound_and_tome_gear():
	var kai: Unit = _view._lord_unit
	var crownspark: InventoryItem = null
	for it in kai.inventory.items:
		if it.is_weapon() and it.weapon().innate:
			crownspark = it
	assert_not_null(crownspark, "Kai carries his bound spell")
	var spell := InventoryItem.from_weapon(load("res://data/weapons/fire.tres"))
	assert_true(kai.inventory.add(spell), "the test tome fits in Kai's pack")
	var recv: Unit = null
	for u in _view._living_units_on_team(0):
		if u != kai:
			recv = u
			break
	assert_not_null(recv, "there is someone to trade with")

	_view._prep._trade_giver = kai
	_view._trade_partner = recv
	var kai_slots := kai.inventory.size()
	var recv_slots := recv.inventory.size()
	_view._prep.open_give_menu()

	var crown_i: int = _view._menu_items.find(crownspark)
	assert_true(crown_i >= 0, "bound gear is listed so the refusal is visible")
	_view._prep.do_give(crown_i)
	assert_true(kai.inventory.has(crownspark), "bound gear stays with its bearer")

	var spell_i: int = _view._menu_items.find(spell)
	assert_true(spell_i >= 0, "the tome is listed so the refusal is visible")
	_view._prep.do_give(spell_i)
	assert_true(kai.inventory.has(spell), "spells don't change hands in prep")
	assert_eq(kai.inventory.size(), kai_slots, "the giver keeps both items")
	assert_eq(recv.inventory.size(), recv_slots, "the receiver gets nothing")


func test_prep_trade_into_a_full_pack_says_why():
	var kai: Unit = _view._lord_unit
	var gift := InventoryItem.from_item(load("res://data/items/vulnerary.tres"))
	if kai.inventory.is_full():
		kai.inventory.items.pop_back()
	assert_true(kai.inventory.add(gift), "Kai holds a tradeable vulnerary")
	var recv: Unit = null
	for u in _view._living_units_on_team(0):
		if u != kai:
			recv = u
			break
	assert_not_null(recv, "there is someone to trade with")
	while not recv.inventory.is_full():
		recv.inventory.add(InventoryItem.from_item(load("res://data/items/vulnerary.tres")))

	_view._prep._trade_giver = kai
	_view._trade_partner = recv
	_view._prep.open_give_menu()
	var kai_slots := kai.inventory.size()
	_view._prep.do_give(_view._menu_items.find(gift))
	assert_true(kai.inventory.has(gift), "nothing moves into a full pack")
	assert_eq(kai.inventory.size(), kai_slots)
	assert_eq(recv.inventory.size(), Inventory.MAX_SLOTS)
	assert_eq(_view._menu_context, "prep_give", "still choosing what to give")
	var told := false
	for c in _view._units_root.get_children():
		if c is Label and (c as Label).text.find("pack is full") >= 0:
			told = true
	assert_true(told, "the refusal is shown, not silent")
	_view._menu.close()


func test_lone_unit_gets_no_empty_trade_menu():
	var kai: Unit = _view._lord_unit
	for u in _view._living_units_on_team(0):
		if u != kai:
			u.current_hp = 0
	assert_eq(_view._living_units_on_team(0).size(), 1, "Kai stands alone")
	_view._prep.open_trade_giver()
	assert_ne(_view._menu_context, "prep_trade_a", "no trade list opens")
	assert_eq(_view._phase, _view.Phase.PREP, "still planning")


func test_save_menu_is_reachable_from_prep():
	_view._prep.open_prep_menu()
	var idx: int = _view._menu_actions.find("save")
	assert_true(idx >= 0, "Save game sits on the prep menu")
	_view._prep.choose("prep_field", idx)
	assert_eq(_view._menu_context, "save_slot", "the slot list opens")
	assert_eq(_view._save_menu_origin, "prep")
	_view._menu.close()


func test_arena_and_plain_battles_skip_prep():
	# the arena never preps (solo trial); a scene without the flag starts hot
	var plain = (load(SCENE) as PackedScene).instantiate()
	plain.dialogue_enabled = false
	add_child_autofree(plain)
	assert_eq(plain._phase, plain.Phase.IDLE, "no flag, no prep")
