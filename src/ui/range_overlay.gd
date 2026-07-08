class_name RangeOverlay
extends Node2D
## Draws the blue move-range and red attack-range tile highlights. Presentation
## only — it's handed pre-computed tile arrays and renders them.

# AW-37: stronger, brighter tiles with a bright per-tile border so the reachable
# area reads clearly even over busy/dark terrain (Neal's playtest note).
const MOVE_COLOR := Color(0.24, 0.56, 1.0, 0.46)
const MOVE_BORDER := Color(0.55, 0.78, 1.0, 0.85)
const ATTACK_COLOR := Color(1.0, 0.30, 0.26, 0.44)
const ATTACK_BORDER := Color(1.0, 0.52, 0.42, 0.80)

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
	var bw := maxf(1.5, cs * 0.03)
	# Attack tiles first so move tiles read on top where they overlap edges.
	for cell in _attack_tiles:
		var r := Rect2(cell.x * cs, cell.y * cs, cs, cs)
		draw_rect(r, ATTACK_COLOR, true)
		draw_rect(r, ATTACK_BORDER, false, bw)
	for cell in _move_tiles:
		var r := Rect2(cell.x * cs, cell.y * cs, cs, cs)
		draw_rect(r, MOVE_COLOR, true)
		draw_rect(r, MOVE_BORDER, false, bw)
