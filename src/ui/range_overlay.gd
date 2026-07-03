class_name RangeOverlay
extends Node2D
## Draws the blue move-range and red attack-range tile highlights. Presentation
## only — it's handed pre-computed tile arrays and renders them.

const MOVE_COLOR := Color(0.30, 0.55, 0.95, 0.35)
const ATTACK_COLOR := Color(0.90, 0.30, 0.28, 0.32)

var _grid: Grid
var _move_tiles: Array = []
var _attack_tiles: Array = []


func setup(grid: Grid) -> void:
	_grid = grid


func show_ranges(move_tiles: Array, attack_tiles: Array) -> void:
	_move_tiles = move_tiles
	_attack_tiles = attack_tiles
	queue_redraw()


func clear() -> void:
	_move_tiles = []
	_attack_tiles = []
	queue_redraw()


func _draw() -> void:
	if _grid == null:
		return
	var cs := _grid.cell_size
	# Attack tiles first so move tiles read on top where they overlap edges.
	for cell in _attack_tiles:
		draw_rect(Rect2(cell.x * cs, cell.y * cs, cs, cs), ATTACK_COLOR, true)
	for cell in _move_tiles:
		draw_rect(Rect2(cell.x * cs, cell.y * cs, cs, cs), MOVE_COLOR, true)
