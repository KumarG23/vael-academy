class_name Grid
extends RefCounted
## Pure cell <-> world coordinate math for the battle map.
##
## No rendering, no node references (§2 rule 2 — logic/presentation split).
## Cells are Vector2i in grid space; world positions are pixels.

const DEFAULT_CELL_SIZE := 128

var width: int
var height: int
var cell_size: int


func _init(p_width: int, p_height: int, p_cell_size: int = DEFAULT_CELL_SIZE) -> void:
	width = p_width
	height = p_height
	cell_size = p_cell_size


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height


## Top-left pixel corner of a cell.
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size, cell.y * cell_size)


## Center pixel of a cell (for placing standees, cursor, effects).
func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * cell_size, (cell.y + 0.5) * cell_size)


## World pixel -> cell (floor division). Result may be out of bounds.
func world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / float(cell_size)), floori(world.y / float(cell_size)))


## Total map size in pixels.
func pixel_size() -> Vector2:
	return Vector2(width * cell_size, height * cell_size)
