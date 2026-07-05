class_name VisitSpot
extends Resource
## An FE-style visitable place on a chapter map (maps v3): a unit standing on
## `cell` (a house door, a stall, a shrine) gets a "Visit" action — a short
## NPC dialogue plays, an optional item is granted, and the visit is spent
## for the battle. Authored alongside the prop the cell belongs to.

## Unique key for the once-per-battle flag (e.g. "hamlet_cottage").
@export var id: String = ""
## The walkable cell that triggers the visit (usually the door).
@export var cell: Vector2i = Vector2i.ZERO
## JSON dialogue path (§4) played on visit. "" => a fallback line.
@export var dialogue: String = ""
## Optional reward handed to the visiting unit.
@export var item: ItemDef
