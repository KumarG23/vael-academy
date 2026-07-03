class_name ChapterDef
extends Resource
## A chapter's map data. WO-0.2 scope: grid dimensions + logical terrain layer
## + optional backdrop. Objectives, deployed units, and dialogue attach in later
## work orders (WO-1.4, WO-4.1).

@export var id: String = ""
@export var display_name: String = ""
@export var width: int = 20
@export var height: int = 15
## Row-major terrain grid, length == width * height, each value a Terrain.Type.
@export var terrain: PackedInt32Array = PackedInt32Array()
## Painted battlefield backdrop (AW-2). Null => flat placeholder color.
@export var backdrop: Texture2D = null


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func get_terrain(x: int, y: int) -> Terrain.Type:
	return terrain[y * width + x] as Terrain.Type


## Fills the terrain grid with a single type (helper for authoring/tests).
func fill(type: Terrain.Type) -> void:
	terrain = PackedInt32Array()
	terrain.resize(width * height)
	terrain.fill(int(type))


func set_terrain(x: int, y: int, type: Terrain.Type) -> void:
	terrain[y * width + x] = int(type)


## Builds a Grid matching this chapter's dimensions.
func make_grid() -> Grid:
	return Grid.new(width, height)
