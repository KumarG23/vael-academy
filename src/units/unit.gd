class_name Unit
extends Node2D
## A unit on the battle map. Presentation node: draws a placeholder token
## (team-ring disc + class letter + HP bar, §8 programmer art), animates movement,
## and gives simple hit/miss/crit feedback (placeholder for WO-2.5 juice). Game
## rules live in the pure combat/pathfinding classes; this node holds board state
## and renders.

const MOVE_SPEED_PX := 640.0  # pixels/sec along the path
const PLAYER_COLOR := Color(0.30, 0.55, 0.95)
const ENEMY_COLOR := Color(0.90, 0.32, 0.30)

signal move_finished

@export var unit_def: UnitDef

var cell: Vector2i
var team: int = 0
var current_hp: int = 1
var has_acted: bool = false

var _grid: Grid
var _moving := false
var _flash := 0.0


func setup(def: UnitDef, grid: Grid, start_cell: Vector2i) -> void:
	unit_def = def
	team = def.team if def != null else 0
	current_hp = def.max_hp if def != null else 1
	_grid = grid
	cell = start_cell
	position = _grid.cell_center(cell)
	queue_redraw()


func max_hp() -> int:
	return unit_def.max_hp if unit_def != null else 1


func is_alive() -> bool:
	return current_hp > 0


func is_moving() -> bool:
	return _moving


func weapon() -> WeaponDef:
	return unit_def.weapon if unit_def != null else null


func movement_type() -> ClassDef.MovementType:
	return unit_def.movement_type() if unit_def != null else ClassDef.MovementType.FOOT


func is_lord() -> bool:
	return unit_def != null and unit_def.is_lord


func move_points() -> int:
	return unit_def.movement if unit_def != null else 5


func can_attack() -> bool:
	var w := weapon()
	return w != null and w.can_attack()


## Build a pure Combatant snapshot from this unit's live state + its tile's terrain.
func to_combatant(terrain_def: int, terrain_avoid: int) -> Combatant:
	var s := unit_def.stats()
	s["current_hp"] = current_hp
	return Combatant.make(unit_def.display_name, s, weapon(), terrain_def, terrain_avoid)


## Apply a resolved HP value (from CombatResult), with a brief hit flash.
func set_hp(new_hp: int) -> void:
	current_hp = clampi(new_hp, 0, max_hp())
	flash()
	queue_redraw()


func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()


## Animate along a cell path (as returned by Pathfinder.find_path). Awaitable.
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
	if has_acted:
		base = base.darkened(0.4)  # greyed-out once the unit has acted this turn
	# House/team base ring (§8 art rule 3).
	draw_circle(Vector2.ZERO, r + 4.0, base.darkened(0.35))
	draw_circle(Vector2.ZERO, r, base)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, r, Color(1, 1, 1, _flash))
	_draw_letter()
	_draw_hp_bar(r)


func _draw_letter() -> void:
	var font := ThemeDB.fallback_font
	var letter := unit_def.token_letter() if unit_def != null else "?"
	var size := int(_grid.cell_size * 0.4)
	var text_size := font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var pos := Vector2(-text_size.x * 0.5, text_size.y * 0.32)
	draw_string(font, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func _draw_hp_bar(r: float) -> void:
	var w := r * 2.0
	var h := _grid.cell_size * 0.09
	var y := r + 8.0
	var frac := float(current_hp) / float(max_hp()) if max_hp() > 0 else 0.0
	var origin := Vector2(-w * 0.5, y)
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0, 0, 0, 0.7), true)
	var fill := Color(0.35, 0.85, 0.4) if team == 0 else Color(0.9, 0.5, 0.3)
	draw_rect(Rect2(origin, Vector2(w * frac, h)), fill, true)
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0, 0, 0, 0.9), false, 1.0)
