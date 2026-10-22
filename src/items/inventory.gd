class_name Inventory
extends RefCounted
## A unit's 5-slot inventory (§6 WO-2.2). Holds weapons and consumables as
## InventoryItems. The equipped weapon is the first usable weapon in the list;
## re-ordering (equip) promotes a weapon to the front. Pure/testable.

const MAX_SLOTS := 5

var items: Array[InventoryItem] = []


static func from_starting(weapons: Array, consumables: Array) -> Inventory:
	var inv := Inventory.new()
	for w in weapons:
		if w != null:
			inv.add(InventoryItem.from_weapon(w))
	for c in consumables:
		if c != null:
			inv.add(InventoryItem.from_item(c))
	return inv


func size() -> int:
	return items.size()


func is_full() -> bool:
	return items.size() >= MAX_SLOTS


func is_empty() -> bool:
	return items.is_empty()


## Adds an item if there's room. Returns false when full.
func add(item: InventoryItem) -> bool:
	if item == null or is_full():
		return false
	items.append(item)
	return true


func remove(item: InventoryItem) -> void:
	items.erase(item)


func has(item: InventoryItem) -> bool:
	return items.has(item)


## First usable (attack or staff) weapon — the one combat/heal uses.
func equipped_weapon_item() -> InventoryItem:
	for it in items:
		if it.is_weapon():
			return it
	return null


func equipped_weapon() -> WeaponDef:
	var it := equipped_weapon_item()
	return it.weapon() if it != null else null


## Move `item` to the front so it becomes equipped. No-op if absent.
func equip(item: InventoryItem) -> void:
	if not items.has(item) or not item.is_weapon():
		return
	items.erase(item)
	items.push_front(item)


## Spend one use of the equipped weapon; remove it if it breaks. Returns the item
## that broke, or null if none broke.
func use_equipped_weapon() -> InventoryItem:
	var it := equipped_weapon_item()
	if it == null:
		return null
	if it.spend():
		items.erase(it)
		return it
	return null


## Spend one use of a specific weapon item (e.g. a staff). Removes if it breaks.
func use_weapon(item: InventoryItem) -> InventoryItem:
	if item == null or not items.has(item):
		return null
	if item.spend():
		items.erase(item)
		return item
	return null


## Consume one use of a consumable; remove it if exhausted.
func use_consumable(item: InventoryItem) -> void:
	if item == null or not items.has(item) or not item.is_consumable():
		return
	if item.spend():
		items.erase(item)


func consumables() -> Array[InventoryItem]:
	var out: Array[InventoryItem] = []
	for it in items:
		if it.is_consumable():
			out.append(it)
	return out


## Whether `item` can change hands. Innate gear is part of its bearer, and
## tomes answer only the unit who learned them (AW-55: spells don't trade).
func is_tradeable(item: InventoryItem) -> bool:
	if item == null:
		return false
	var w := item.weapon()
	return w == null or (not w.innate and w.weapon_type != WeaponDef.WeaponType.TOME)


## Transfer `item` from this inventory to `other`. Returns true on success
## (item present here, tradeable, and room there).
func transfer_to(item: InventoryItem, other: Inventory) -> bool:
	if other == null or not items.has(item) or other.is_full() or not is_tradeable(item):
		return false
	items.erase(item)
	other.items.append(item)
	return true
