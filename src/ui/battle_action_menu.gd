class_name BattleActionMenuController
extends RefCounted
## WO-4.5: command-menu slice extracted from battle_view (zero behavior
## change). Builds the Action menu and its submenus (Item / Equip / Trade /
## Supports) and routes choices. Menu STATE stays on the view (tests inspect
## `_menu_actions`, `_menu_context`, ...); this object only drives it.

var _v  # BattleView (untyped to avoid a class_name reference cycle)


func _init(view) -> void:
	_v = view


func open_action_menu() -> void:
	var unit: Unit = _v._selected
	var labels: Array = []
	_v._menu_actions = []
	# AW-26: Attack lists physical weapons, Magic lists tomes — each category
	# appears only if the unit carries a weapon of that kind that can hit
	# something from here (picking the weapon/spell comes next, in a submenu).
	if not attack_weapons(unit, false).is_empty():
		_v._menu_actions.append("attack"); labels.append("Attack")
	if not attack_weapons(unit, true).is_empty():
		_v._menu_actions.append("magic"); labels.append("Magic")
	var w := unit.weapon()
	if w != null and w.is_staff() and not _v._heal_targets(unit.cell, unit).is_empty():
		_v._menu_actions.append("heal"); labels.append("Heal")
	if not usable_consumables(unit).is_empty():
		_v._menu_actions.append("item"); labels.append("Item")
	if not _v._adjacent_allies(unit).is_empty():
		_v._menu_actions.append("trade"); labels.append("Trade")
	if weapon_count(unit) > 1:
		_v._menu_actions.append("equip"); labels.append("Equip")
	if not unviewed_conversations(unit.unit_def.id).is_empty():
		_v._menu_actions.append("supports"); labels.append("Supports")
	if unit.team == 0 and _v._visit_spot_at(unit.cell) != null:
		_v._menu_actions.append("visit"); labels.append("Visit")
	_v._menu_actions.append("stats"); labels.append("Stats")
	_v._menu_actions.append("wait"); labels.append("Wait")
	open_menu("action", "Action", labels)


## Unlocked support conversations this unit hasn't watched yet — the in-battle
## Supports menu only offers new scenes; the Common Hall keeps the full archive.
func unviewed_conversations(unit_id: String) -> Array:
	var out: Array = []
	for entry in _v._support_state.unlocked_conversations_for_unit(unit_id):
		if not bool(entry.get("viewed", false)):
			out.append(entry)
	return out


## Field menu (playtest 3): confirm on an empty tile to end the turn without
## walking every unit first, or check the objective.
func open_field_menu() -> void:
	_v._menu_actions = []
	open_menu("field", "Field", ["End Turn", "Objective", "Cancel"])


func field_choice(index: int) -> void:
	_v._menu.close()
	_v._cursor.active = true
	_v._phase = _v.Phase.IDLE
	match index:
		0:
			_v._end_player_phase()
		1:
			_v._toast_objective()


func open_menu(context: String, title: String, labels: Array) -> void:
	_v._menu_context = context
	_v._phase = _v.Phase.MENU
	_v._cursor.active = false
	_v._menu.open(title, labels, Vector2(40, 110))


func choose(index: int) -> void:
	if _v._busy:
		return
	match _v._menu_context:
		"field":
			field_choice(index)
		"action":
			await do_action(_v._menu_actions[index])
		"attack_weapon", "magic_spell":
			pick_attack_weapon(index)
		"item":
			await use_consumable(index)
		"equip":
			do_equip(index)
		"trade_ally":
			pick_trade_ally(index)
		"trade_give":
			do_give(index)
		"supports":
			view_support_entry(index)


func cancel() -> void:
	if _v._busy:
		return
	match _v._menu_context:
		"action":
			_v._undo_move_and_deselect()  # cancel the command menu = take the move back
		"field":
			_v._menu.close()
			_v._cursor.active = true
			_v._phase = _v.Phase.IDLE
		_:
			open_action_menu()            # any submenu -> back to the command menu


func do_action(id: String) -> void:
	match id:
		"attack":
			begin_attack_category(false)
		"magic":
			begin_attack_category(true)
		"heal":
			_v._menu.close()
			_v._cursor.active = true
			_v._begin_targeting(true)
		"item":
			open_item_menu()
		"trade":
			open_trade_ally_menu()
		"equip":
			open_equip_menu()
		"supports":
			open_support_menu()
		"visit":
			_v._menu.close()
			await do_visit()
		"stats":
			_v._menu.close()
			_v._stats_from_menu = true
			_v._open_stats_for(_v._selected)
		"wait":
			_v._menu.close()
			_v._finish_action()


## AW-26 — Attack/Magic weapon selection ---------------------------------------
## Weapons in a category the unit can actually use from here. `magic` = tomes
## (offensive spells); otherwise physical arms (sword/axe/lance/bow). Staves are
## the Heal command, never listed here. Only weapons with a live target are kept,
## and the currently-equipped one is placed first so the default pick is a no-op.
func attack_weapons(unit: Unit, magic: bool) -> Array:
	var out: Array = []
	var equipped: InventoryItem = unit.inventory.equipped_weapon_item()
	for it in unit.inventory.items:
		if not it.is_weapon():
			continue
		var w := it.weapon()
		# Category is by weapon FAMILY, not damage type: tomes are "Magic", every
		# other attacking arm (incl. a magic-damage spellbow) is "Attack".
		var is_spell := w.weapon_type == WeaponDef.WeaponType.TOME
		if not w.can_attack() or is_spell != magic:
			continue
		if not unit.can_use_weapon(w):
			continue
		if _v._weapon_has_target(unit, w):
			out.append(it)
	if equipped != null and out.has(equipped):
		out.erase(equipped)
		out.insert(0, equipped)
	return out


## Chose Attack or Magic: with one usable weapon, equip it and go straight to
## targeting; with several, open the weapon/spell picker first.
func begin_attack_category(magic: bool) -> void:
	var weps := attack_weapons(_v._selected, magic)
	if weps.size() <= 1:
		if weps.size() == 1:
			_v._selected.inventory.equip(weps[0])
		_v._menu.close()
		_v._cursor.active = true
		_v._begin_targeting(false)
	else:
		open_weapon_menu(magic, weps)


func open_weapon_menu(magic: bool, weps: Array) -> void:
	_v._menu_items = weps
	var labels: Array = []
	var equipped: InventoryItem = _v._selected.inventory.equipped_weapon_item()
	for it in weps:
		var eq := " *" if it == equipped else ""
		labels.append("%s (%d)%s" % [it.display_name(), it.uses, eq])
	open_menu("magic_spell" if magic else "attack_weapon", "Magic" if magic else "Attack", labels)


## Picked a specific weapon/spell: equip it, then target with it.
func pick_attack_weapon(index: int) -> void:
	_v._selected.inventory.equip(_v._menu_items[index])
	_v._menu.close()
	_v._cursor.active = true
	_v._begin_targeting(false)


## Consumables the unit can meaningfully use right now: a Vulnerary only when
## damaged, a Promotion item only when the unit is eligible to promote (§3).
func usable_consumables(unit: Unit) -> Array[InventoryItem]:
	var out: Array[InventoryItem] = []
	for it in unit.inventory.consumables():
		var def := it.item()
		if def.heals() and unit.current_hp < unit.max_hp():
			out.append(it)
		elif def.is_promotion() and unit.can_promote():
			out.append(it)
	return out


func open_item_menu() -> void:
	_v._menu_items = usable_consumables(_v._selected)
	var labels: Array = []
	for it in _v._menu_items:
		labels.append("%s (%d)" % [it.display_name(), it.uses])
	open_menu("item", "Item", labels)


func use_consumable(index: int) -> void:
	var item: InventoryItem = _v._menu_items[index]
	var def: ItemDef = item.item()
	# Only usable items reach this menu.
	if def.is_promotion():
		var result: Dictionary = _v._selected.promote()
		_v._pop_text(_v._selected.position, "→ %s!" % result["class_name"], Color(0.95, 0.82, 0.35))
	else:
		var healed: int = _v._selected.heal(def.power)
		_v._pop_text(_v._selected.position, "+%d" % healed, Color(0.4, 0.9, 0.5))
	_v._selected.inventory.use_consumable(item)
	_v._menu.close()
	_v._finish_action()


func open_equip_menu() -> void:
	_v._menu_items = []
	var labels: Array = []
	for it in _v._selected.inventory.items:
		if it.is_weapon() and _v._selected.can_use_weapon(it.weapon()):
			_v._menu_items.append(it)
			var eq := " *" if it == _v._selected.inventory.equipped_weapon_item() else ""
			labels.append("%s (%d)%s" % [it.display_name(), it.uses, eq])
	open_menu("equip", "Equip", labels)


func do_equip(index: int) -> void:
	_v._selected.inventory.equip(_v._menu_items[index])
	open_action_menu()  # equipping is free — return to the command menu


func open_trade_ally_menu() -> void:
	_v._menu_partners = _v._adjacent_allies(_v._selected)
	var labels: Array = []
	for a in _v._menu_partners:
		labels.append("%s (%d items)" % [a.unit_def.display_name, a.inventory.size()])
	open_menu("trade_ally", "Trade with", labels)


func pick_trade_ally(index: int) -> void:
	_v._trade_partner = _v._menu_partners[index]
	open_trade_give_menu()


func open_trade_give_menu() -> void:
	_v._menu_items = _v._selected.inventory.items.duplicate()
	var labels: Array = []
	for it in _v._menu_items:
		labels.append("Give %s" % it.display_name())
	open_menu("trade_give", "Give to %s" % _v._trade_partner.unit_def.display_name, labels)


func do_give(index: int) -> void:
	var item: InventoryItem = _v._menu_items[index]
	if _v._selected.inventory.transfer_to(item, _v._trade_partner.inventory):
		_v._pop_text(_v._trade_partner.position, "got %s" % item.display_name(), Color(0.7, 0.85, 1.0))
	# Stay in the give menu so multiple items can be handed over; cancel finishes.
	if _v._selected.inventory.is_empty():
		_v._menu.close()
		_v._finish_action()
	else:
		open_trade_give_menu()


func open_support_menu() -> void:
	_v._support_menu_entries = unviewed_conversations(_v._selected.unit_def.id)
	var labels: Array = []
	for entry in _v._support_menu_entries:
		labels.append(entry["label"])
	if labels.is_empty():
		open_action_menu()
	else:
		open_menu("supports", "Supports", labels)


## Play the chosen support conversation as a VN overlay (WO-4.2), then return to
## the command menu — viewing a conversation doesn't consume the unit's action.
## Once watched it stops appearing in battle (WO-4.4); the Common Hall keeps it.
func view_support_entry(index: int) -> void:
	var entry: Dictionary = _v._support_menu_entries[index]
	var path := str(entry.get("path", ""))
	_v._menu.close()
	if _v.dialogue_enabled and path != "" and FileAccess.file_exists(path):
		await _v._play_dialogue(path)
		_v._support_state.mark_viewed(str(entry["pair_id"]), str(entry["rank"]))
	else:
		_v._pop_text(_v._selected.position, "%s ready" % entry["label"], Color(0.95, 0.75, 0.35))
	open_action_menu()


## FE village visit (maps v3): play the spot's NPC dialogue, hand over the
## reward, and spend the unit's action. Once per spot per battle.
func do_visit() -> void:
	var unit: Unit = _v._selected
	var spot: VisitSpot = _v._visit_spot_at(unit.cell)
	if spot == null:
		_v._finish_action()
		return
	_v._visited_spot_ids.append(spot.id)
	if _v.dialogue_enabled and spot.dialogue != "" and FileAccess.file_exists(spot.dialogue):
		await _v._play_dialogue(spot.dialogue)
	if spot.item != null:
		if unit.inventory.add(InventoryItem.from_item(spot.item)):
			_v._pop_text(unit.position, "got %s!" % spot.item.display_name,
				Color(0.95, 0.82, 0.35))
	_v._finish_action()


func weapon_count(unit: Unit) -> int:
	var n := 0
	for it in unit.inventory.items:
		if it.is_weapon():
			n += 1
	return n
