class_name CastleDoor
extends Resource
## WO-9.1: a doorway CELL in a top-down castle room. Visibly marked in-scene;
## walking onto it carries you through (CT-style — no button hunting).

@export var cell: Vector2i = Vector2i.ZERO
@export var to_room: String = ""
@export var spawn_cell: Vector2i = Vector2i.ZERO
@export var label: String = ""
