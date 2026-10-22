class_name BattleCursor
extends Node2D
## Grid cursor: cell-by-cell keyboard movement (arrows/WASD with held-key repeat),
## mouse follow, and confirm/cancel producing a selection. Presentation + input;
## it owns no game rules. Higher layers (WO-0.4 unit selection) listen to its
## signals rather than the cursor reaching into them.

const INVALID := Vector2i(-1, -1)
const INITIAL_REPEAT_DELAY := 0.28
const REPEAT_INTERVAL := 0.06

## Emitted whenever the hovered cell changes.
signal cell_changed(cell: Vector2i)
## Emitted on confirm (Enter/Space/left-click) over a cell.
signal confirmed(cell: Vector2i)
## Emitted on cancel (Esc/right-click).
signal cancelled(cell: Vector2i)
## Emitted when the committed selection changes (selected cell or INVALID).
signal selection_changed(selected: Vector2i)

@export var cursor_color: Color = Color(1.0, 0.93, 0.4, 0.95)
@export var selected_color: Color = Color(0.35, 0.75, 1.0, 0.95)

var cell := Vector2i.ZERO
var selected_cell := INVALID

var _grid: Grid
var _initialized := false
var _held_dir := Vector2i.ZERO
var _repeat_timer := 0.0
var _pulse := 0.0  # drives the cursor's brightness pulse
## When false, the cursor ignores all input (e.g. while a menu is open).
var active := true


func setup(grid: Grid, start := Vector2i.ZERO) -> void:
	_grid = grid
	_initialized = false
	move_to(start)


func is_selection_active() -> bool:
	return selected_cell != INVALID


func move_to(target: Vector2i) -> void:
	if _grid == null:
		return
	var clamped := Vector2i(
		clampi(target.x, 0, _grid.width - 1),
		clampi(target.y, 0, _grid.height - 1),
	)
	if _initialized and clamped == cell:
		return
	_initialized = true
	cell = clamped
	cell_changed.emit(cell)
	queue_redraw()


func try_move(dir: Vector2i) -> void:
	move_to(cell + dir)


func confirm() -> void:
	selected_cell = cell
	confirmed.emit(cell)
	selection_changed.emit(selected_cell)
	queue_redraw()


func cancel() -> void:
	if is_selection_active():
		selected_cell = INVALID
		selection_changed.emit(selected_cell)
	cancelled.emit(cell)
	queue_redraw()


func _process(delta: float) -> void:
	if _grid == null:
		return
	_pulse += delta
	queue_redraw()  # keep the pulse animating
	if not active:
		return
	step_repeat(_poll_direction(), delta)


## Reads the current held movement direction from the input actions.
func _poll_direction() -> Vector2i:
	return Vector2i(
		int(Input.is_action_pressed("cursor_right")) - int(Input.is_action_pressed("cursor_left")),
		int(Input.is_action_pressed("cursor_down")) - int(Input.is_action_pressed("cursor_up")),
	)


## Advances the held-key repeat state machine by `delta` for a held `dir`.
## First frame of a new direction moves immediately; then it waits
## INITIAL_REPEAT_DELAY before repeating every REPEAT_INTERVAL. Testable in
## isolation (no Input polling).
func step_repeat(dir: Vector2i, delta: float) -> void:
	if dir == Vector2i.ZERO:
		_held_dir = Vector2i.ZERO
		_repeat_timer = 0.0
		return
	if dir != _held_dir:
		_held_dir = dir
		_repeat_timer = INITIAL_REPEAT_DELAY
		try_move(dir)
		return
	_repeat_timer -= delta
	if _repeat_timer <= 0.0:
		_repeat_timer = REPEAT_INTERVAL
		try_move(dir)


func _unhandled_input(event: InputEvent) -> void:
	if _grid == null or not active:
		return
	if event is InputEventMouseMotion:
		var hovered := _grid.world_to_cell(event.global_position)
		if _grid.in_bounds(hovered):
			move_to(hovered)
		return
	if event.is_action_pressed("cursor_confirm"):
		confirm()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cursor_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed:
		var hovered := _grid.world_to_cell(event.global_position)
		if not _grid.in_bounds(hovered):
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			confirm()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()


func _draw() -> void:
	if _grid == null:
		return
	var cs := _grid.cell_size
	if is_selection_active():
		var srect := Rect2(selected_cell.x * cs, selected_cell.y * cs, cs, cs)
		var fill := Color(selected_color.r, selected_color.g, selected_color.b, 0.20)
		draw_rect(srect, fill, true)
		draw_rect(srect, selected_color, false, 3.0)
	var rect := Rect2(cell.x * cs, cell.y * cs, cs, cs)
	var pulse := 0.5 + 0.5 * sin(_pulse * 5.0)  # 0..1
	# pulsing glow fill + a bright breathing border so the cursor never gets
	# lost over busy terrain (Neal's playtest: it was hard to see)
	draw_rect(rect, Color(1.0, 0.95, 0.5, 0.10 + 0.16 * pulse), true)
	draw_rect(rect.grow(-2.0), Color(1.0, 0.97, 0.62, 0.45 + 0.45 * pulse), false, 3.0)
	_draw_cursor_brackets(rect, pulse)


func _draw_cursor_brackets(rect: Rect2, pulse: float) -> void:
	# Corner brackets so the cursor reads clearly over any terrain/standee.
	var cs: float = rect.size.x
	var arm: float = cs * 0.32
	var w := 5.0 + 2.0 * pulse
	var col := Color(1.0, 0.96, 0.5, 0.85 + 0.15 * pulse)
	var p := rect.position
	var corners := [
		[p, Vector2(arm, 0), Vector2(0, arm)],
		[p + Vector2(cs, 0), Vector2(-arm, 0), Vector2(0, arm)],
		[p + Vector2(0, cs), Vector2(arm, 0), Vector2(0, -arm)],
		[p + Vector2(cs, cs), Vector2(-arm, 0), Vector2(0, -arm)],
	]
	for c in corners:
		var origin: Vector2 = c[0]
		draw_line(origin, origin + c[1], col, w)
		draw_line(origin, origin + c[2], col, w)
