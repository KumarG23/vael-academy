class_name Unit
extends Node2D
## A unit on the battle map. Presentation node: it draws a placeholder token
## (colored disc + class letter + team ring, §8 programmer art) and animates
## movement along a path. Game rules live in the pure logic classes; this node
## holds board position and renders.

const MOVE_SPEED_PX := 640.0  # pixels/sec along the path
const PLAYER_COLOR := Color(0.30, 0.55, 0.95)
const ENEMY_COLOR := Color(0.90, 0.32, 0.30)

signal move_finished

@export var unit_def: UnitDef

var cell: Vector2i
var team: int = 0

var _grid: Grid
var _moving := false


func setup(def: UnitDef, grid: Grid, start_cell: Vector2i) -> void:
	unit_def = def
	team = def.team if def != null else 0
	_grid = grid
	cell = start_cell
	position = _grid.cell_center(cell)
	queue_redraw()


func is_moving() -> bool:
	return _moving


## Animate along a cell path (as returned by Pathfinder.find_path). Awaitable.
## Updates `cell` to the final tile. A path of length <= 1 is a no-op move.
func move_along_path(path: Array) -> void:
	if path.size() <= 1:
		cell = path[-1] if not path.is_empty() else cell
		position = _grid.cell_center(cell)
		move_finished.emit()
		return
	_moving = true
	for i in range(1, path.size()):
		var target: Vector2 = _grid.cell_center(path[i])
		while position.distance_to(target) > 1.0:
			var delta: float = get_process_delta_time()
			position = position.move_toward(target, MOVE_SPEED_PX * delta)
			await get_tree().process_frame
		position = target
	cell = path[-1]
	_moving = false
	move_finished.emit()


func _draw() -> void:
	if _grid == null:
		return
	var r: float = _grid.cell_size * 0.34
	var base := PLAYER_COLOR if team == 0 else ENEMY_COLOR
	# House/team base ring (§8 art rule 3: house-color base ring around the standee).
	draw_circle(Vector2.ZERO, r + 4.0, base.darkened(0.35))
	draw_circle(Vector2.ZERO, r, base)
	_draw_letter()


func _draw_letter() -> void:
	var font := ThemeDB.fallback_font
	var letter := unit_def.token_letter() if unit_def != null else "?"
	var size := int(_grid.cell_size * 0.4)
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var pos := Vector2(-text_size.x * 0.5, text_size.y * 0.32)
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
