class_name CampusEditor
extends Node2D
## AW-44: an in-game visual editor for the castle rooms. Toggle it with the
## backtick/tilde (`) key anywhere in the castle, then place / drag / delete
## props and paint terrain with the mouse, and SAVE it straight back to the
## room's .tres. No more editing coordinates by hand.
##
## Controls (shown in the on-screen HUD when active):
##   `  toggle edit mode        Tab  props ⇄ terrain
##   left-click  pick up a prop (drag), or drop the current brush on empty ground
##   right-click delete the prop under the cursor
##   [ ]  cycle the brush        arrows  nudge the held prop one cell
##   S  save the room            Esc  drop selection / leave edit

const PROPS := [
	"tree_big", "bush", "hedge", "flower_bed", "stump", "rocks", "street_lamp",
	"bench", "bench_stone", "fence", "signpost", "well", "fireplace",
	"statue_founder", "banner_pair", "notice_board", "tent", "cart", "barrels",
	"crates", "bookshelf", "long_table",
]
const BUILDINGS := [
	"res://assets/art_review/campus_v2/great_hall_v2.png",
	"res://assets/art_review/campus_v2/library_v2.png",
	"res://assets/art_review/campus_v2/classroom_hall.png",
	"res://assets/art_review/campus_v2/gatehouse_v2.png",
	"res://assets/art_review/campus_v2/fountain_plaza.png",
	"res://assets/art/pixellab/buildings/dorm_emberwing.png",
	"res://assets/art/pixellab/buildings/dorm_tidemark.png",
	"res://assets/art/pixellab/buildings/dorm_thornrook.png",
	"res://assets/art/pixellab/buildings/colosseum.png",
]
const TERRAINS := [
	["Grass", Terrain.Type.PLAINS], ["Path", Terrain.Type.PATH],
	["Carpet", Terrain.Type.CARPET], ["Flowers", Terrain.Type.FLOWERS],
	["Blocker", Terrain.Type.SITE], ["Wall", Terrain.Type.WALL],
	["Water", Terrain.Type.WATER], ["Forest", Terrain.Type.FOREST],
	["Embers", Terrain.Type.EMBERS], ["Spring", Terrain.Type.SPRING],
]

var active := false
var _castle
var _mode := "prop"         # "prop" | "terrain"
var _brush := 0             # index into _palette()
var _terrain := 0           # index into TERRAINS
var _selected: MapDecor = null
var _hover := Vector2i(-1, -1)
var _dirty := false
var _hud: Label


func setup(castle) -> void:
	_castle = castle
	z_index = 50
	_hud = Label.new()
	_hud.position = Vector2(14, 12)
	_hud.add_theme_color_override("font_color", Color(0.96, 0.92, 0.7))
	_hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hud.add_theme_constant_override("shadow_offset_x", 1)
	_hud.add_theme_constant_override("shadow_offset_y", 1)
	_hud.add_theme_font_size_override("font_size", 15)
	_hud.visible = false
	_castle._ui.add_child(_hud)


func toggle() -> void:
	active = not active
	_selected = null
	_hud.visible = active
	_update_hud()
	queue_redraw()


func _palette() -> Array:
	return TERRAINS if _mode == "terrain" else (PROPS + BUILDINGS)


func _brush_path() -> String:
	var b = _palette()[_brush % _palette().size()]
	if b is String and b.begins_with("res://"):
		return b
	return "res://assets/art/pixellab/props/%s.png" % b


## Called by the castle from _unhandled_input while active. Returns true if eaten.
func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if event is InputEventMouseMotion:
		_hover = _cell()
		if _selected != null and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_selected.cell = _hover
			_touch()
		queue_redraw()
		return true
	if event is InputEventMouseButton and event.pressed:
		_hover = _cell()
		if event.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_delete_at(_hover)
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return _on_key(event.keycode)
	return false


func _on_left_click() -> void:
	if _mode == "terrain":
		_castle.room.chapter.set_terrain(_hover.x, _hover.y, TERRAINS[_terrain][1])
		_touch(true)
		return
	var d := _decor_at(_hover)
	if d != null:
		_selected = d      # pick it up; drag with the mouse held
	else:
		_place_brush(_hover)


func _on_key(kc: int) -> bool:
	match kc:
		KEY_TAB:
			_mode = "terrain" if _mode == "prop" else "prop"
			_brush = 0
		KEY_BRACKETLEFT:
			_cycle(-1)
		KEY_BRACKETRIGHT:
			_cycle(1)
		KEY_DELETE, KEY_BACKSPACE, KEY_X:
			if _selected != null:
				_castle.room.chapter.decor.erase(_selected); _selected = null; _touch()
			else:
				_delete_at(_hover)
		KEY_LEFT: _nudge(Vector2i(-1, 0))
		KEY_RIGHT: _nudge(Vector2i(1, 0))
		KEY_UP: _nudge(Vector2i(0, -1))
		KEY_DOWN: _nudge(Vector2i(0, 1))
		KEY_S:
			_save()
		KEY_ESCAPE:
			if _selected != null:
				_selected = null
			else:
				toggle()
		_:
			return false
	_update_hud()
	queue_redraw()
	return true


func _cycle(dir: int) -> void:
	if _mode == "terrain":
		_terrain = (_terrain + dir + TERRAINS.size()) % TERRAINS.size()
	else:
		var n := _palette().size()
		_brush = (_brush + dir + n) % n


func _nudge(delta: Vector2i) -> void:
	if _selected != null:
		_selected.cell += delta
		_touch()


func _place_brush(cell: Vector2i) -> void:
	var path := _brush_path()
	if not ResourceLoader.exists(path):
		return
	var d := MapDecor.new()
	d.texture = load(path)
	d.cell = cell
	if int(ceil((d.texture as Texture2D).get_width() / 32.0)) % 2 == 0:
		d.offset = Vector2(16, 0)
	_castle.room.chapter.decor.append(d)
	_selected = d
	_touch()


func _delete_at(cell: Vector2i) -> void:
	var d := _decor_at(cell)
	if d != null:
		_castle.room.chapter.decor.erase(d)
		if _selected == d:
			_selected = null
		_touch()


func _decor_at(cell: Vector2i) -> MapDecor:
	# nearest decor whose anchor cell is within one tile of the cursor
	var best: MapDecor = null
	var bestd := 3
	for d: MapDecor in _castle.room.chapter.decor:
		var dist: int = absi(d.cell.x - cell.x) + absi(d.cell.y - cell.y)
		if dist < bestd:
			bestd = dist; best = d
	return best


func _cell() -> Vector2i:
	return _castle._grid.world_to_cell(_castle.get_global_mouse_position())


func _touch(terrain := false) -> void:
	_dirty = true
	if terrain:
		_castle._tiles.queue_redraw()
	_castle.queue_redraw()
	queue_redraw()
	_update_hud()


func _save() -> void:
	var path := "res://data/castle_v2/%s.tres" % _castle.room.id
	var err := ResourceSaver.save(_castle.room, path)
	_dirty = err != OK
	_castle._toast("Saved %s" % _castle.room.id if err == OK else "SAVE FAILED (%d)" % err)


func _brush_label() -> String:
	if _mode == "terrain":
		return TERRAINS[_terrain][0]
	var b = _palette()[_brush % _palette().size()]
	return (b as String).get_file().get_basename() if (b as String).begins_with("res://") else str(b)


func _update_hud() -> void:
	if _hud == null:
		return
	var star := " *unsaved*" if _dirty else ""
	_hud.text = "✎ EDIT — %s   room: %s%s\n" % [_castle.room.id, _mode.to_upper(), star]
	_hud.text += "brush: %s   ([ ] cycle · Tab prop/terrain)\n" % _brush_label()
	_hud.text += "L-click place/pick · drag move · R-click/X delete · arrows nudge · S save · ` exit"


func _draw() -> void:
	if not active or _castle == null or _castle._grid == null:
		return
	var cs := float(_castle._grid.cell_size)
	# hover cell
	if _hover.x >= 0:
		var hp := Vector2(_hover.x * cs, _hover.y * cs)
		draw_rect(Rect2(hp, Vector2(cs, cs)), Color(0.4, 0.8, 1.0, 0.25), true)
		draw_rect(Rect2(hp, Vector2(cs, cs)), Color(0.6, 0.9, 1.0, 0.9), false, 3.0)
	# selected prop outline
	if _selected != null:
		var sp := Vector2(_selected.cell.x * cs, _selected.cell.y * cs)
		draw_rect(Rect2(sp, Vector2(cs, cs)), Color(1.0, 0.85, 0.3, 0.9), false, 4.0)
