class_name UnitSpawn
extends Resource
## One authored unit placement in a chapter (WO-4.1): which UnitDef spawns and
## where. Chapters carry these so enemy forces are data, not code (§2 rule 4).

@export var unit: UnitDef
@export var cell: Vector2i = Vector2i.ZERO
## WO-5.6: spawn-time overrides so rival chapters can field the SAME house
## UnitDefs as enemies (team 1 + an AI brain) without duplicate .tres files.
## -1 = keep the def's own value.
@export var team_override: int = -1
@export var ai_override: int = -1
