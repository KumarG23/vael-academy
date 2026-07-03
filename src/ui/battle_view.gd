extends Node2D
## Battle scene root. Renders a chapter map (flat placeholder backdrop until AW-2,
## per-terrain debug tints, subtle grid overlay, fitted camera, cursor terrain
## readout) and drives unit selection + movement (WO-0.4):
##   select unit -> blue move range + red attack range -> pick tile -> unit walks.
##
## Presentation/orchestration only. Terrain numbers come from ChapterDef/TerrainDB;
## reachability and paths come from the pure Pathfinder/MovementRange.

## Chapter to render. Assigned in the scene; falls back to a plains map if unset.
@export var chapter: ChapterDef
## Flat placeholder fill until a painted backdrop exists (§8 art rule 2).
@export var backdrop_color: Color = Color(0.16, 0.20, 0.15)
## Attack range steps for the placeholder demo (melee). Real weapon ranges: WO-1.1.
@export var demo_attack_ranges: Array = [1]

## Subtle per-terrain tints so the logical layer is legible before art lands.
const TERRAIN_TINTS := {
	Terrain.Type.PLAINS: Color(0.0, 0.0, 0.0, 0.0),
	Terrain.Type.FOREST: Color(0.20, 0.45, 0.20, 0.35),
	Terrain.Type.MOUNTAIN: Color(0.45, 0.36, 0.28, 0.45),
	Terrain.Type.FORT: Color(0.70, 0.62, 0.25, 0.40),
	Terrain.Type.WALL: Color(0.10, 0.10, 0.12, 0.75),
	Terrain.Type.WATER: Color(0.15, 0.35, 0.60, 0.55),
}

var _grid: Grid
var _terrain_db: TerrainDB
var _overlay: GridOverlay
var _range_overlay: RangeOverlay
var _units_root: Node2D
var _cursor: BattleCursor
var _debug_label: Label

var _units: Array[Unit] = []
var _selected: Unit = null
var _standable: Array = []


func _ready() -> void:
	if chapter == null:
		chapter = _build_fallback_chapter()
	_terrain_db = TerrainDB.create_default()
	_grid = chapter.make_grid()
	_setup_overlay()
	_setup_range_overlay()
	_setup_units_root()
	_setup_cursor()
	_setup_camera()
	_setup_debug_label()
	_spawn_demo_units()
	queue_redraw()


func _draw() -> void:
	var size := _grid.pixel_size()
	if chapter.backdrop != null:
		draw_texture_rect(chapter.backdrop, Rect2(Vector2.ZERO, size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), backdrop_color, true)
	_draw_terrain_tints()


func _draw_terrain_tints() -> void:
	var cs := _grid.cell_size
	for y in range(chapter.height):
		for x in range(chapter.width):
			var tint: Color = TERRAIN_TINTS.get(chapter.get_terrain(x, y), Color(0, 0, 0, 0))
			if tint.a > 0.0:
				draw_rect(Rect2(x * cs, y * cs, cs, cs), tint, true)


# --- unit / occupancy helpers -------------------------------------------------

func unit_at(cell: Vector2i) -> Unit:
	for u in _units:
		if u.cell == cell:
			return u
	return null


## cell -> team, for every occupied tile. Consumed by BattleMoveContext.
func occupancy() -> Dictionary:
	var occ := {}
	for u in _units:
		occ[u.cell] = u.team
	return occ


func add_unit(def: UnitDef, cell: Vector2i) -> Unit:
	var u := Unit.new()
	_units_root.add_child(u)
	u.setup(def, _grid, cell)
	_units.append(u)
	return u


# --- selection flow -----------------------------------------------------------

func _on_cursor_confirmed(cell: Vector2i) -> void:
	if _selected == null:
		_try_select(cell)
	else:
		_try_move_selected(cell)


func _on_cursor_cancelled(_cell: Vector2i) -> void:
	if _selected != null:
		_deselect()


func _try_select(cell: Vector2i) -> void:
	var u := unit_at(cell)
	if u == null:
		return
	_selected = u
	_standable = _compute_standable(u)
	var attack := MovementRange.attack_tiles(_standable, demo_attack_ranges, _make_context(u))
	_range_overlay.show_ranges(_standable, attack)
	print("selected %s at (%d, %d) — %d move tiles" % [
		_unit_name(u), cell.x, cell.y, _standable.size(),
	])


func _try_move_selected(cell: Vector2i) -> void:
	if _selected.is_moving():
		return
	if not _standable.has(cell):
		# Clicking off-range cancels the selection (FE convention).
		_deselect()
		return
	var mover := _selected
	var path := Pathfinder.find_path(mover.cell, cell, _make_context(mover))
	_deselect()
	if path.is_empty():
		return
	await mover.move_along_path(path)
	print("%s moved to (%d, %d)" % [_unit_name(mover), cell.x, cell.y])


func _deselect() -> void:
	_selected = null
	_standable = []
	_range_overlay.clear()


func _compute_standable(u: Unit) -> Array:
	return MovementRange.standable_tiles(u.cell, _mov(u), _make_context(u))


func _make_context(u: Unit) -> BattleMoveContext:
	return BattleMoveContext.new(
		chapter, _terrain_db, _movement_type(u), occupancy(), u.team
	)


func _mov(u: Unit) -> int:
	return u.unit_def.movement if u.unit_def != null else 5


func _movement_type(u: Unit) -> ClassDef.MovementType:
	return u.unit_def.movement_type() if u.unit_def != null else ClassDef.MovementType.FOOT


func _unit_name(u: Unit) -> String:
	return u.unit_def.display_name if u.unit_def != null else "unit"


# --- setup --------------------------------------------------------------------

func _setup_overlay() -> void:
	_overlay = GridOverlay.new()
	add_child(_overlay)
	_overlay.setup(_grid)


func _setup_range_overlay() -> void:
	_range_overlay = RangeOverlay.new()
	add_child(_range_overlay)
	_range_overlay.setup(_grid)


func _setup_units_root() -> void:
	_units_root = Node2D.new()
	_units_root.name = "Units"
	add_child(_units_root)


func _setup_cursor() -> void:
	_cursor = BattleCursor.new()
	add_child(_cursor)
	_cursor.cell_changed.connect(_update_debug)
	_cursor.confirmed.connect(_on_cursor_confirmed)
	_cursor.cancelled.connect(_on_cursor_cancelled)
	_cursor.setup(_grid, Vector2i(_grid.width / 2, _grid.height / 2))


func _setup_camera() -> void:
	var camera := Camera2D.new()
	add_child(camera)
	var map := _grid.pixel_size()
	camera.position = map * 0.5
	var vp := get_viewport_rect().size
	var fit := minf(vp.x / map.x, vp.y / map.y) * 0.96
	camera.zoom = Vector2(fit, fit)
	camera.make_current()


func _setup_debug_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_debug_label = Label.new()
	_debug_label.position = Vector2(12, 10)
	_debug_label.add_theme_color_override("font_color", Color.WHITE)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_debug_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_debug_label)


## Places a few demo units so the movement loop is playable on the test map.
## Real deployment comes from ChapterDef in WO-1.4/WO-4.1.
func _spawn_demo_units() -> void:
	var myrmidon: ClassDef = _try_load("res://data/classes/myrmidon.tres")
	var knight: ClassDef = _try_load("res://data/classes/knight.tres")
	var soldier: ClassDef = _try_load("res://data/classes/soldier.tres")
	if myrmidon == null:
		return  # demo data not authored; map still renders + cursor works
	var kael := _make_demo_unit("kael", "Kael", myrmidon, 0, 6)
	var brenna := _make_demo_unit("brenna", "Brenna", knight, 0, 8)
	var enemy := _make_demo_unit("tide_soldier", "Tidemark Soldier", soldier, 1, 4)
	add_unit(kael, Vector2i(3, 7))
	add_unit(brenna, Vector2i(4, 9))
	add_unit(enemy, Vector2i(8, 7))


func _make_demo_unit(
	id: String, disp: String, cls: ClassDef, team: int, mov: int
) -> UnitDef:
	var d := UnitDef.new()
	d.id = id
	d.display_name = disp
	d.char_class = cls
	d.team = team
	d.movement = mov
	return d


func _try_load(path: String) -> Resource:
	return load(path) if ResourceLoader.exists(path) else null


func _update_debug(cell: Vector2i) -> void:
	if _debug_label == null:
		return
	if not _grid.in_bounds(cell):
		_debug_label.text = "Cursor: off-map"
		return
	var info := _terrain_db.get_info(chapter.get_terrain(cell.x, cell.y))
	var move_txt := "impassable" if info.impassable else "move %d" % info.move_cost
	var occupant := unit_at(cell)
	var who := "  <%s>" % _unit_name(occupant) if occupant != null else ""
	var line := "(%d, %d)  %s  [%s, def +%d, avoid +%d]%s" % [
		cell.x, cell.y, info.display_name, move_txt, info.defense, info.avoid, who,
	]
	_debug_label.text = line
	print(line)  # accept criterion: "hovering prints terrain stats"


func _build_fallback_chapter() -> ChapterDef:
	var c := ChapterDef.new()
	c.id = "fallback"
	c.display_name = "Fallback Plains"
	c.width = 20
	c.height = 15
	c.fill(Terrain.Type.PLAINS)
	return c
