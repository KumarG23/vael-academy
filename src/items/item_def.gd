class_name ItemDef
extends Resource
## A non-weapon inventory item (§6 WO-2.2): consumables like the Vulnerary and the
## Promotion item. Weapons are WeaponDef; both share inventory slots via InventoryItem.

enum Kind { VULNERARY, PROMOTION }

@export var id: String = ""
@export var display_name: String = ""
@export var kind: Kind = Kind.VULNERARY
## For a Vulnerary: HP restored per use. Unused by the Promotion item.
@export var power: int = 10
@export var max_uses: int = 1


func is_promotion() -> bool:
	return kind == Kind.PROMOTION


## True if using this item heals its holder (Vulnerary).
func heals() -> bool:
	return kind == Kind.VULNERARY
