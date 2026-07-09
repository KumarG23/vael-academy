class_name BattlePrepController
extends RefCounted
## AW-74: the before-battle preparations screen, FE-style — reposition your
## units among their deploy slots, trade gear freely, check the objective, and
## (once unlocked) deal with the traveling merchant. Runs INSIDE the battle
## scene as Phase.PREP so the real map, foes, and danger zones are all visible
## while you plan. "Begin battle" hands over to the player phase.

var _v  # BattleView (untyped to avoid a class_name reference cycle)

## What the traveling merchant carries to a war camp — field basics, campus
## prices (the SPELLBOOKS stay a shop-and-story matter; see SPELLBOOKS.md).
const STOCK := [
	{"label": "Vulnerary", "cost": 60, "kind": "item", "path": "res://data/items/vulnerary.tres"},
	{"label": "Iron Sword", "cost": 80, "kind": "weapon", "path": "res://data/weapons/iron_sword.tres"},
	{"label": "Iron Lance", "cost": 80, "kind": "weapon", "path": "res://data/weapons/iron_lance.tres"},
	{"label": "Iron Axe", "cost": 80, "kind": "weapon", "path": "res://data/weapons/iron_axe.tres"},
	{"label": "Iron Bow", "cost": 90, "kind": "weapon", "path": "res://data/weapons/iron_bow.tres"},
]
## Known worth by def id — the merchant pays half. Anything he doesn't know,
## he won't buy (spellbooks and relics stay yours).
const VALUE := {
	"iron_sword": 80, "iron_lance": 80, "iron_axe": 80, "iron_bow": 90,
	"vulnerary": 60, "promotion_seal": 600,
}

var _pick: Unit = null            # the unit being repositioned
var _slots: Array = []            # the deploy slots (player cells at prep start)
var _trade_giver: Unit = null
var _sell_unit: Unit = null
var _sell_items: Array = []


func _init(view) -> void:
	_v = view


## Enter preparations: record the deploy slots and hand the cursor over.
func begin() -> void:
	_slots = []
	for u in _v._living_units_on_team(0):
		_slots.append(u.cell)
	_v._phase = _v.Phase.PREP
	_v._turn_banner.announce("Preparations — position your forces", true)


func gold() -> int:
	return int(Campaign.flags.get("gold", 0))


func merchant_here() -> bool:
	return bool(Campaign.flags.get("merchant_unlocked", false))


## Enter during PREP: pick up / place your units, study foes, or open the menu.
func confirm(cell: Vector2i) -> void:
	var u: Unit = _v.unit_at(cell)
	if _pick != null:
		place(cell)
		return
	if u != null and u.is_alive() and u.team != 0:
		# the danger zone works while planning too (AW-73)
		if _v._danger_unit == u:
			_v._open_stats_for(u)
		else:
			_v._show_danger_for(u)
		return
	if u != null and u.is_alive() and u.team == 0:
		_pick = u
		AudioManager.play_sfx("select")
		_v._range_overlay.show_ranges(_slots, [])  # the legal slots, lit
		return
	open_prep_menu()


## Esc during PREP: put a held unit down, else open the menu (FE's Start).
func cancel() -> void:
	if _pick != null:
		_drop_pick()
		return
	if _v._danger_unit != null:
		_v._clear_danger()
		return
	open_prep_menu()


func _drop_pick() -> void:
	_pick = null
	_v._range_overlay.clear()


## Put the held unit at `cell` — swap with whoever holds that slot.
func place(cell: Vector2i) -> void:
	if not _slots.has(cell):
		_drop_pick()
		return
	var other: Unit = _v.unit_at(cell)
	var from := _pick.cell
	if other == _pick:
		_drop_pick()
		return
	if other != null:
		other.cell = from
		other.position = _v._grid.cell_center(from)
	_pick.cell = cell
	_pick.position = _v._grid.cell_center(cell)
	AudioManager.play_sfx("confirm")
	_drop_pick()


func open_prep_menu() -> void:
	_v._menu_actions = []
	var labels: Array = []
	_v._menu_actions.append("begin"); labels.append("Begin battle")
	_v._menu_actions.append("objective"); labels.append("Objective")
	_v._menu_actions.append("trade"); labels.append("Trade")
	if merchant_here():
		_v._menu_actions.append("shop"); labels.append("Merchant")
	_v._menu_actions.append("save"); labels.append("Save game")
	_v._menu_ctrl.open_menu("prep_field", "Preparations", labels)


func choose_field(index: int) -> void:
	var id: String = _v._menu_actions[index]
	_close_menu()
	match id:
		"begin":
			finish()
		"objective":
			_v._toast_objective()
		"trade":
			open_trade_giver()
		"shop":
			open_shop()
		"save":
			_v._open_save_menu("prep")


func _close_menu() -> void:
	_v._menu.close()
	_v._cursor.active = true
	_v._phase = _v.Phase.PREP


## Preparations end — the battle proper begins.
func finish() -> void:
	_drop_pick()
	_v._clear_danger()
	_v._prep_active = false
	_v._phase = _v.Phase.IDLE
	_v._begin_player_phase()


# --- trade (any two of your units — the camp passes gear freely) ---------------

func open_trade_giver() -> void:
	# NOTE: _menu_partners is Array[Unit] — build typed, assign whole (sweep class #5)
	var partners: Array[Unit] = []
	var labels: Array = []
	for u in _v._living_units_on_team(0):
		if not u.inventory.is_empty():
			partners.append(u)
			labels.append("%s (%d items)" % [u.unit_def.display_name, u.inventory.size()])
	_v._menu_partners = partners
	if labels.is_empty():
		_v._turn_banner.announce("No one has anything to hand over.", true)
		return
	_v._menu_ctrl.open_menu("prep_trade_a", "Who gives?", labels)


func pick_trade_giver(index: int) -> void:
	_trade_giver = _v._menu_partners[index]
	_open_receiver_menu()


func _open_receiver_menu() -> void:
	var partners: Array[Unit] = []
	var labels: Array = []
	for u in _v._living_units_on_team(0):
		if u != _trade_giver:
			partners.append(u)
			labels.append("%s (%d items)" % [u.unit_def.display_name, u.inventory.size()])
	_v._menu_partners = partners
	_v._menu_ctrl.open_menu("prep_trade_b", "To whom?", labels)


func pick_trade_receiver(index: int) -> void:
	_v._trade_partner = _v._menu_partners[index]
	open_give_menu()


func open_give_menu() -> void:
	_v._menu_items = _trade_giver.inventory.items.duplicate()
	var labels: Array = []
	for it in _v._menu_items:
		labels.append("Give %s" % it.display_name())
	_v._menu_ctrl.open_menu("prep_give",
		"%s → %s" % [_trade_giver.unit_def.display_name, _v._trade_partner.unit_def.display_name], labels)


## Hand one item over and stay in the menu — prep trading never spends actions.
func do_give(index: int) -> void:
	var item: InventoryItem = _v._menu_items[index]
	if item.is_weapon() and item.weapon().innate:
		_v._pop_text(_trade_giver.position, "bound to its bearer", Color(0.9, 0.6, 0.4))
	elif _trade_giver.inventory.transfer_to(item, _v._trade_partner.inventory):
		_v._pop_text(_v._trade_partner.position, "got %s" % item.display_name(), Color(0.7, 0.85, 1.0))
	if _trade_giver.inventory.is_empty():
		_close_menu()
	else:
		open_give_menu()


# --- the traveling merchant (buy into Kai's pack; he pays half for known gear) --

func open_shop() -> void:
	var labels: Array = []
	for w in STOCK:
		labels.append("%s — %dg" % [w["label"], int(w["cost"])])
	labels.append("Sell instead…")
	_v._menu_ctrl.open_menu("prep_shop", "Merchant — you have %dg" % gold(), labels)


func choose_shop(index: int) -> void:
	if index >= STOCK.size():
		open_sell_unit()
		return
	var w: Dictionary = STOCK[index]
	var cost := int(w["cost"])
	var lord: Unit = _v._lord_unit
	if gold() < cost:
		_v._turn_banner.announce("Not enough gold. (%dg short)" % (cost - gold()), true)
		_close_menu()
		return
	if lord == null or lord.inventory.is_full():
		_v._turn_banner.announce("Kai's pack is full — trade something away first.", true)
		_close_menu()
		return
	var entry: InventoryItem
	if str(w["kind"]) == "weapon":
		entry = InventoryItem.from_weapon(load(str(w["path"])))
	else:
		entry = InventoryItem.from_item(load(str(w["path"])))
	lord.inventory.add(entry)
	Campaign.flags["gold"] = gold() - cost
	AudioManager.play_sfx("confirm")
	_v._pop_text(lord.position, "bought %s" % str(w["label"]), Color(0.95, 0.82, 0.35))
	open_shop()  # multi-buy, same as the campus stalls (AW-70)


func open_sell_unit() -> void:
	var partners: Array[Unit] = []
	var labels: Array = []
	for u in _v._living_units_on_team(0):
		if not u.inventory.is_empty():
			partners.append(u)
			labels.append("%s (%d items)" % [u.unit_def.display_name, u.inventory.size()])
	_v._menu_partners = partners
	if labels.is_empty():
		_close_menu()
		return
	_v._menu_ctrl.open_menu("prep_sell_unit", "Sell whose gear?", labels)


func pick_sell_unit(index: int) -> void:
	_sell_unit = _v._menu_partners[index]
	open_sell_items()


func open_sell_items() -> void:
	_sell_items = _sell_unit.inventory.items.duplicate()
	var labels: Array = []
	for it in _sell_items:
		labels.append("%s — %s" % [it.display_name(), _price_label(it)])
	_v._menu_ctrl.open_menu("prep_sell_item", "Sell — you have %dg" % gold(), labels)


func _def_id(it: InventoryItem) -> String:
	return it.weapon().id if it.is_weapon() else it.item().id


func sell_price(it: InventoryItem) -> int:
	if it.is_weapon() and it.weapon().innate:
		return 0  # bound gear has no price
	return int(VALUE.get(_def_id(it), 0)) / 2


func _price_label(it: InventoryItem) -> String:
	var p := sell_price(it)
	return "%dg" % p if p > 0 else "he won't buy it"


func do_sell(index: int) -> void:
	var it: InventoryItem = _sell_items[index]
	var p := sell_price(it)
	if p <= 0:
		_v._pop_text(_sell_unit.position, "\"Can't move that.\"", Color(0.9, 0.6, 0.4))
		open_sell_items()
		return
	_sell_unit.inventory.remove(it)
	Campaign.flags["gold"] = gold() + p
	AudioManager.play_sfx("confirm")
	_v._pop_text(_sell_unit.position, "sold %s (+%dg)" % [it.display_name(), p], Color(0.95, 0.82, 0.35))
	if _sell_unit.inventory.is_empty():
		_close_menu()
	else:
		open_sell_items()


## Route a ChoiceMenu pick for any prep_* context (called by the menu controller).
func choose(context: String, index: int) -> void:
	match context:
		"prep_field":
			choose_field(index)
		"prep_trade_a":
			pick_trade_giver(index)
		"prep_trade_b":
			pick_trade_receiver(index)
		"prep_give":
			do_give(index)
		"prep_shop":
			choose_shop(index)
		"prep_sell_unit":
			pick_sell_unit(index)
		"prep_sell_item":
			do_sell(index)


## Esc inside a prep submenu steps back one level; from the top menu it closes.
func cancel_menu(context: String) -> void:
	match context:
		"prep_field":
			_close_menu()
		"prep_trade_a", "prep_shop":
			open_prep_menu()
		"prep_trade_b":
			open_trade_giver()
		"prep_give":
			pick_trade_giver_reopen()
		"prep_sell_unit":
			open_shop()
		"prep_sell_item":
			open_sell_unit()


func pick_trade_giver_reopen() -> void:
	_open_receiver_menu()  # back out of the give list to "To whom?", same giver
