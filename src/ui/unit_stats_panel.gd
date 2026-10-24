class_name UnitStatsPanel
extends Control
## Unit inspection panel (WO-4.4): class, level, stats, equipped weapon with its
## numbers and range, and a plain-language role hint ("heals allies", "cannot
## counter adjacent") so a first-time player can read the roster without a manual.
## Opened from the command menu ("Stats") or by selecting any unit that can't act
## (enemies, exhausted allies). Any key or click closes it.

signal closed

const PANEL_BG := Color(0.08, 0.09, 0.12, 0.96)
const PANEL_EDGE := Color(0.85, 0.78, 0.45, 0.9)
const PANEL_SIZE := Vector2(400, 250)

var _shown := false
var _title := ""
var _subtitle := ""
var _hp_text := ""
var _lines: Array = []
var _text_rows: Array[Dictionary] = []
var _layout_width := 0.0
var _height_limit := INF
var _wide_width := 0.0
var _wide_layout := false


func _init() -> void:
	# Mouse events only reach _gui_input inside the Control's rect. Match the
	# drawn sheet from construction on, so a freshly created panel is already a
	# valid click target even before it enters the tree.
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	# Keep the hit area pinned to the drawn sheet through tree entry as well.
	size = PANEL_SIZE
	visible = false


func is_shown() -> bool:
	return _shown


func show_unit(u: Unit) -> void:
	size = PANEL_SIZE  # a container/reparent may have reset the clickable rect
	_title = u.unit_def.display_name
	var cls := u.current_class()
	_subtitle = "%s   Lv %d  (%d/100 XP)" % [cls.display_name if cls != null else "?", u.level, u.xp]
	_hp_text = "HP %d / %d" % [u.current_hp, u.max_hp()]
	_lines = _build_lines(u)
	_shown = true
	visible = true
	_layout_width = 0.0
	fit_width(size.x)
	queue_redraw()


func close() -> void:
	if not _shown:
		return
	_shown = false
	visible = false
	queue_redraw()
	closed.emit()


static func _build_lines(u: Unit) -> Array:
	var out: Array = []
	out.append("STR %-3d  MAG %-3d  SKL %-3d  SPD %d" % [
		u.stat("str"), u.stat("mag"), u.stat("skl"), u.stat("spd")])
	out.append("LCK %-3d  DEF %-3d  RES %-3d  MOV %d" % [
		u.stat("lck"), u.stat("def"), u.stat("res"), u.move_points()])
	var w := u.weapon()
	if w == null:
		out.append("Unarmed")
	elif w.is_staff():
		out.append("%s — staff, heals %d + MAG" % [w.display_name, w.heal_amount])
	else:
		out.append("%s — Mt %d  Hit %d  Crit %d  Rng %s" % [
			w.display_name, w.might, w.hit, w.crit, _range_text(w)])
	var extras: Array = []
	for it in u.inventory.items:
		if it.is_weapon() and it.weapon() != w:
			extras.append(it.display_name())
	if not extras.is_empty():
		out.append("Also carries: " + ", ".join(extras))
	var hint := _role_hint(u, w)
	if hint != "":
		out.append(hint)
	return out


static func _range_text(w: WeaponDef) -> String:
	if w.min_range == w.max_range:
		return str(w.max_range)
	return "%d–%d" % [w.min_range, w.max_range]


static func _role_hint(u: Unit, w: WeaponDef) -> String:
	var parts: Array = []
	if w != null:
		match w.weapon_type:
			WeaponDef.WeaponType.STAFF:
				parts.append("Healer — cannot attack; XP from healing.")
			WeaponDef.WeaponType.BOW:
				parts.append("Ranged — strikes at 2; cannot counter adjacent foes.")
			WeaponDef.WeaponType.TOME:
				parts.append("Magic — targets RES, not DEF.")
			_:
				pass
	if u.movement_type() == ClassDef.MovementType.ARMORED:
		parts.append("Armored — tough but slow; mountains are impassable.")
	return " ".join(parts)


## Any key closes the panel (arrives here because nothing focuses the overlay).
func _unhandled_key_input(event: InputEvent) -> void:
	if _shown and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		close()


func _gui_input(event: InputEvent) -> void:
	if _shown and event is InputEventMouseButton and event.pressed:
		accept_event()
		close()


## Measure every field with the same paragraph/font used to paint it. Keep the
## legacy minimum/click rect while allowing long carried weapons and role hints.
func fit_width(width: float, height_limit: float = INF, wide_width: float = 0.0) -> void:
	if _layout_width == width and _height_limit == height_limit and _wide_width == wide_width:
		return
	_layout_width = width
	_height_limit = height_limit
	_wide_width = wide_width
	_wide_layout = false
	_text_rows.clear()
	var hp_width := UITheme.font().get_string_size(_hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var y := _add_text(_title, 24, Vector2(22, 16), width - hp_width - 66, Color.WHITE)
	_add_text(_hp_text, 18, Vector2(width - hp_width - 22, 20), hp_width + 1, Color(0.7, 0.9, 0.75))
	y = _add_text(_subtitle, 16, Vector2(22, y + 3), width - 44, Color(0.7, 0.72, 0.78)) + 6
	for line in _lines:
		y = _add_text(str(line), 17, Vector2(22, y), width - 44, Color(0.92, 0.93, 0.97)) + 3
	var footer_bottom := _add_text("any key to close", 13, Vector2(22, y + 8), width - 44, Color(0.55, 0.56, 0.62))
	size = Vector2(width, maxf(PANEL_SIZE.y, footer_bottom + 22))
	_text_rows[-1].at.y += size.y - footer_bottom - 22
	if size.y > height_limit and wide_width > width:
		_layout_columns(wide_width)
	queue_redraw()


## A full five-weapon pack can exceed the compact left lane. Reflow those
## existing fields into two measured columns, with name/class/HP across the top.
## The close hint participates in the balance rather than costing another row.
func _layout_columns(width: float) -> void:
	_wide_layout = true
	_text_rows.clear()
	var font := UITheme.font()
	var hp_width := font.get_string_size(_hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var title_width := minf(width * 0.4, font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x)
	var bottom := _add_text(_title, 24, Vector2(22, 16), title_width + 1, Color.WHITE)
	var subtitle_x := 22 + title_width + 16
	bottom = maxf(bottom, _add_text(_subtitle, 16, Vector2(subtitle_x, 20), width - hp_width - 38 - subtitle_x, Color(0.7, 0.72, 0.78)))
	bottom = maxf(bottom, _add_text(_hp_text, 18, Vector2(width - hp_width - 22, 20), hp_width + 1, Color(0.7, 0.9, 0.75))) + 8
	var first := _text_rows.size()
	var heights: Array[float] = []
	for line in _lines:
		heights.append(_add_text(str(line), 17, Vector2.ZERO, (width - 60) * 0.5, Color(0.92, 0.93, 0.97)) + 2)
	var footer_height := _add_text("any key to close", 13, Vector2.ZERO, (width - 60) * 0.5, Color(0.55, 0.56, 0.62)) + 2
	var split := 1
	var best := INF
	for candidate in range(1, heights.size()):
		var left := 0.0
		var right := 0.0
		for i in heights.size():
			if i < candidate:
				left += heights[i]
			else:
				right += heights[i]
		var height := maxf(left + footer_height, right) if left <= right else maxf(left, right + footer_height)
		if height < best:
			best = height
			split = candidate
	var left_height := 0.0
	var right_height := 0.0
	var y := bottom
	for i in heights.size():
		if i == split:
			y = bottom
		_text_rows[first + i].at = Vector2(22 if i < split else width * 0.5 + 8, y)
		y += heights[i]
		if i < split:
			left_height += heights[i]
		else:
			right_height += heights[i]
	_text_rows[-1].at = Vector2(22 if left_height <= right_height else width * 0.5 + 8, bottom + minf(left_height, right_height))
	size = Vector2(width, maxf(188, bottom + best + 22))


func _add_text(text: String, font_size: int, at: Vector2, width: float, color: Color) -> float:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, UITheme.font(), font_size)
	_text_rows.append({"text": text, "paragraph": paragraph, "at": at, "color": color})
	return at.y + paragraph.get_size().y


func _draw() -> void:
	if not _shown:
		return
	UITheme.draw_panel(self, Rect2(Vector2.ZERO, size), PANEL_BG, 112.0)
	for row in _text_rows:
		row.paragraph.draw(get_canvas_item(), row.at, row.color)
