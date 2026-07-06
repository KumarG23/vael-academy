class_name CastlePoint
extends Resource
## WO-9.1: an interaction point at a CELL — an NPC, a function (training,
## cooking...), or a story beat. Replaces the v1 RoomSpot's screen-fraction x.

@export var id: String = ""
@export var label: String = ""
@export var cell: Vector2i = Vector2i.ZERO
@export var dialogue: String = ""
@export var npc_unit: String = ""
@export var requires_flag: String = ""
