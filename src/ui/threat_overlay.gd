class_name ThreatOverlay
extends Node2D
## Toggleable display of the tiles all enemies threaten (§5 / WO-2.3). Presentation
## only — the battle scene computes the tile set from AIBrain.threat_tiles and feeds
## it in. Drawn under the units, above the terrain tints.

const THREAT_COLOR := Color(0.85, 0.15, 0.20, 0.26)
const EDGE_COLOR := Color(0.9, 0.2, 0.2, 0.5)

var _grid: Grid
var _tiles: Array = []
var _shown := false


func setup(grid: Grid) -> void:
	_grid = grid


func is_shown() -> bool:
	return _shown


func set_tiles(tiles: Array) -> void:
	_tiles = tiles
	queue_redraw()


func set_shown(shown: bool) -> void:
	_shown = shown
	visible = shown
	queue_redraw()


func _draw() -> void:
	if _grid == null or not _shown:
		return
	var cs := _grid.cell_size
	for cell in _tiles:
		draw_rect(Rect2(cell.x * cs, cell.y * cs, cs, cs), THREAT_COLOR, true)
		draw_rect(Rect2(cell.x * cs + 1, cell.y * cs + 1, cs - 2, cs - 2), EDGE_COLOR, false, 1.0)
