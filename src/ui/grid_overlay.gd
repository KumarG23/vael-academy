class_name GridOverlay
extends Node2D
## Draws subtle grid lines over the map. Presentation only — reads a Grid for
## geometry, owns no game state.

@export var line_color: Color = Color(1.0, 1.0, 1.0, 0.09)
@export var line_width: float = 1.0

var _grid: Grid


func setup(grid: Grid) -> void:
	_grid = grid
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	var size := _grid.pixel_size()
	var cs := _grid.cell_size
	for x in range(_grid.width + 1):
		var px := float(x * cs)
		draw_line(Vector2(px, 0.0), Vector2(px, size.y), line_color, line_width)
	for y in range(_grid.height + 1):
		var py := float(y * cs)
		draw_line(Vector2(0.0, py), Vector2(size.x, py), line_color, line_width)
