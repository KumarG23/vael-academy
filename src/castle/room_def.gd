class_name RoomDef
extends Resource
## One walkable castle room (WO-6.1, §4 "the living castle"): a painted
## side-view backdrop, a walkable floor band, doors to other rooms, and
## interaction spots. Everything is data — rooms are .tres files.

@export var id: String = ""
@export var display_name: String = ""
## Painted backdrop (400x224 pixel-art scene, drawn full-screen NEAREST).
@export var backdrop: Texture2D
## Walkable floor band as fractions of screen height.
@export var floor_top: float = 0.68
@export var floor_bottom: float = 0.92
@export var exits: Array[RoomExit] = []
@export var spots: Array[RoomSpot] = []
