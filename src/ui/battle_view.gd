extends Node2D
## Battle scene root (WO-0.2). Renders a chapter map: a flat placeholder backdrop
## (painted texture once AW-2 lands), per-terrain debug tints, a subtle grid
## overlay, a fitted camera, and a debug readout of the terrain under the cursor.
##
## Presentation only. All terrain numbers come from ChapterDef + TerrainDB.

## Chapter to render. Assigned in the scene; falls back to a plains map if unset.
@export var chapter: ChapterDef
## Flat placeholder fill until a painted backdrop exists (§8 art rule 2).
@export var backdrop_color: Color = Color(0.16, 0.20, 0.15)

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
var _debug_label: Label
var _last_cell := Vector2i(-9999, -9999)


func _ready() -> void:
	if chapter == null:
		chapter = _build_fallback_chapter()
	_terrain_db = TerrainDB.create_default()
	_grid = chapter.make_grid()
	_setup_overlay()
	_setup_camera()
	_setup_debug_label()
	_update_debug(Vector2i(-1, -1))
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var cell := _grid.world_to_cell(get_global_mouse_position())
		if cell != _last_cell:
			_last_cell = cell
			_update_debug(cell)


func _setup_overlay() -> void:
	_overlay = GridOverlay.new()
	add_child(_overlay)
	_overlay.setup(_grid)


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


func _update_debug(cell: Vector2i) -> void:
	if _debug_label == null:
		return
	if not _grid.in_bounds(cell):
		_debug_label.text = "Cursor: off-map"
		return
	var info := _terrain_db.get_info(chapter.get_terrain(cell.x, cell.y))
	var move_txt := "impassable" if info.impassable else "move %d" % info.move_cost
	var line := "(%d, %d)  %s  [%s, def +%d, avoid +%d]" % [
		cell.x, cell.y, info.display_name, move_txt, info.defense, info.avoid,
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
