class_name InventoryItem
extends RefCounted
## One occupied inventory slot: a definition (WeaponDef or ItemDef) plus its
## remaining uses. Uses are per-instance so two copies of the same weapon wear
## independently.

var def: Resource
var uses: int


static func from_weapon(w: WeaponDef) -> InventoryItem:
	var it := InventoryItem.new()
	it.def = w
	it.uses = w.max_uses
	return it


static func from_item(i: ItemDef) -> InventoryItem:
	var it := InventoryItem.new()
	it.def = i
	it.uses = i.max_uses
	return it


func is_weapon() -> bool:
	return def is WeaponDef


func is_consumable() -> bool:
	return def is ItemDef


func weapon() -> WeaponDef:
	return def as WeaponDef


func item() -> ItemDef:
	return def as ItemDef


func display_name() -> String:
	return def.display_name if def != null else "?"


func is_depleted() -> bool:
	return uses <= 0


## Spend one use. Returns true if the item is now depleted (breaks / is consumed).
func spend() -> bool:
	uses -= 1
	return uses <= 0
