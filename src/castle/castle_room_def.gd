class_name CastleRoomDef
extends Resource
## WO-9.1: one walkable castle space — a tiled top-down map (the battle
## terrain family carries the rendering) plus doors and interaction points.

@export var id: String = ""
@export var display_name: String = ""
## The room's grid: terrain + decor ride the proven ChapterDef/TerrainTiles.
@export var chapter: ChapterDef
@export var doors: Array[CastleDoor] = []
@export var points: Array[CastlePoint] = []
