class_name AcademyRoomMap
extends Control
## WO-9.8: current-room map plus earned destinations supplied by CastleScene.
## Emits intent; the owner validates travel before changing the world.
signal travel_requested(room_id: String)

const EXIT_COLOR := Color("f1ca72")
const POSITION_COLOR := Color("76edff")
const BLOCKED_COLOR := Color("282a37")
const GROUND_COLOR := Color("687562")

var destinations: Array[CastleRoomDef] = []
var showing_destinations := false
var selected := 0
var _switch: Label
var _destination_labels: Array[Label] = []
var room: CastleRoomDef
var avatar: Node2D
var grid: Grid
var terrain_db: TerrainDB
var map_rect := Rect2()
var cell_size := 1.0
var _title: Label
var _legend: Label
var _exits: ScrollContainer
var _exit_rows: VBoxContainer
var _exit_labels: Array[Label] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = _label(room.display_name + " — Map", 22)
	_legend = _label("Cyan ring: you • Gold: exits\nLight ground: walkable\nDark ground: blocked\nM / Esc / RMB: close • Tab: travel\nExit list: ↑/↓ or wheel", 14)
	_exits = ScrollContainer.new()
	_exits.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_exits)
	_exit_rows = VBoxContainer.new()
	_exit_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exit_rows.add_theme_constant_override("separation", 8)
	_exits.add_child(_exit_rows)
	_switch = Label.new()
	_switch.text = "▶ Visited rooms (Tab / click)"
	_switch.add_theme_font_override("font", UITheme.font())
	_switch.add_theme_font_size_override("font_size", 14)
	_switch.add_theme_color_override("font_color", UITheme.GOLD)
	_exit_rows.add_child(_switch)
	for i in range(room.doors.size()):
		var label := Label.new()
		label.text = "%d  %s" % [i + 1, room.doors[i].label]
		label.add_theme_font_override("font", UITheme.font())
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", EXIT_COLOR)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_exit_rows.add_child(label)
		_exit_labels.append(label)
	for destination: CastleRoomDef in destinations:
		var label := Label.new()
		label.add_theme_font_override("font", UITheme.font())
		label.add_theme_font_size_override("font_size", 15)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.visible = false
		_exit_rows.add_child(label)
		_destination_labels.append(label)
	_refresh_selection()
	resized.connect(_layout)
	_layout()


func toggle_destinations() -> void:
	showing_destinations = not showing_destinations
	_switch.text = "◀ Exit labels (Tab / click)" if showing_destinations else "▶ Visited rooms (Tab / click)"
	_legend.text = "Cyan ring: you • Gold: exits\nLight ground: walkable\nDark ground: blocked\nM / Esc / RMB: close • Tab: exits\n↑/↓: select • Enter / click: go" if showing_destinations else "Cyan ring: you • Gold: exits\nLight ground: walkable\nDark ground: blocked\nM / Esc / RMB: close • Tab: travel\nExit list: ↑/↓ or wheel"
	for label: Label in _exit_labels:
		label.visible = not showing_destinations
	for label: Label in _destination_labels:
		label.visible = showing_destinations
	_exits.scroll_vertical = 0
	_refresh_selection()


func _refresh_selection() -> void:
	for i in range(destinations.size()):
		_destination_labels[i].text = ("▶ " if selected == i else "   ") + destinations[i].display_name + (" (here)" if destinations[i].id == room.id else "")
		_destination_labels[i].add_theme_color_override("font_color", UITheme.GOLD if selected == i else Color.WHITE)


func navigate(direction: int) -> void:
	if showing_destinations and not destinations.is_empty():
		selected = posmod(selected + direction, destinations.size())
		_refresh_selection()
		_exits.ensure_control_visible.call_deferred(_destination_labels[selected])
	else:
		_exits.scroll_vertical += direction * 40


func confirm_destination() -> void:
	if showing_destinations and not destinations.is_empty():
		travel_requested.emit(destinations[selected].id)


func click_destination(point: Vector2) -> void:
	if not _exits.get_global_rect().has_point(point):
		return
	if _switch.get_global_rect().has_point(point):
		toggle_destinations()
		return
	if showing_destinations:
		for i in range(_destination_labels.size()):
			if _destination_labels[i].get_global_rect().has_point(point):
				selected = i
				_refresh_selection()
				confirm_destination()
				return


func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	# Shape wrapped labels with a real width before entering the tree. A zero-
	# width first layout otherwise caches a character-per-line minimum height.
	label.size.x = size.x
	label.text = text
	label.add_theme_font_override("font", UITheme.font())
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _layout() -> void:
	if _title == null:
		return
	_title.position = Vector2(34, 62)
	_title.size = Vector2(size.x - 68, 32)
	var list_width := clampf(size.x * 0.32, 216.0, 320.0)
	var list_x := size.x - list_width - 34.0
	_legend.position = Vector2(list_x, 112)
	_legend.size = Vector2(list_width, 112)
	_exits.position = Vector2(list_x, 236)
	_exits.size = Vector2(list_width, maxf(1, size.y - 286))
	# Reserve marker radius around every edge, including doors on boundary cells.
	var area := Rect2(34, 112, maxf(1, list_x - 58), maxf(1, size.y - 162))
	cell_size = minf(area.size.x / grid.width, area.size.y / grid.height)
	var extent := Vector2(grid.width, grid.height) * cell_size
	map_rect = Rect2(area.get_center() - extent * 0.5, extent)
	queue_redraw()


func map_position(world: Vector2) -> Vector2:
	return map_rect.position + world / float(grid.cell_size) * cell_size


func _process(_delta: float) -> void:
	# Read the live avatar without writing to it (world simulation is gated by CastleScene).
	queue_redraw()


func _draw() -> void:
	if room == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.04, 0.065, 0.98))
	UITheme.draw_panel(self, Rect2(12, 12, size.x - 24, size.y - 24))
	for y in range(grid.height):
		for x in range(grid.width):
			var terrain := room.chapter.get_terrain(x, y)
			var color := BLOCKED_COLOR if terrain_db.is_impassable(terrain) else GROUND_COLOR
			if terrain == Terrain.Type.PATH or terrain == Terrain.Type.CARPET:
				color = Color("b4a179")
			draw_rect(Rect2(map_rect.position + Vector2(x, y) * cell_size,
				Vector2.ONE * cell_size), color)
	draw_rect(map_rect, Color("b2b5b9"), false, 1)
	var font := UITheme.font()
	for i in range(room.doors.size()):
		var point := map_position(grid.cell_center(room.doors[i].cell))
		draw_circle(point, 10, Color("161a26"))
		draw_circle(point, 10, EXIT_COLOR, false, 1.5)
		var key := str(i + 1)
		var width := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, point + Vector2(-width * 0.5, 4), key,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, EXIT_COLOR)
	# A crosshair stays visible even if the player stands on an exit. The ring
	# surrounds its number rather than covering it.
	var player := map_position(avatar.position)
	draw_circle(player, 13, POSITION_COLOR, false, 2)
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(player + direction * 14, player + direction * 19, POSITION_COLOR, 2)
