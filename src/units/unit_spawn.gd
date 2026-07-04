class_name UnitSpawn
extends Resource
## One authored unit placement in a chapter (WO-4.1): which UnitDef spawns and
## where. Chapters carry these so enemy forces are data, not code (§2 rule 4).

@export var unit: UnitDef
@export var cell: Vector2i = Vector2i.ZERO
