class_name RoomExit
extends Resource
## A doorway between rooms: stand near `x` (fraction of screen width) and
## confirm to travel. The avatar arrives at `spawn_x` in the target room.

@export var to_room: String = ""
@export var label: String = ""
@export var x: float = 0.5
@export var spawn_x: float = 0.5
