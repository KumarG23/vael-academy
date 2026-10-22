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


func _draw() -> void:
	if not _shown:
		return
	var rect := Rect2(Vector2.ZERO, PANEL_SIZE)
	UITheme.draw_panel(self, rect, PANEL_BG)  # AW-56: the shared noble frame
	var font := UITheme.font()
	var y := 34.0
	draw_string(font, Vector2(18, y), _title, HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 36, 24, Color.WHITE)
	var hp_size := font.get_string_size(_hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(font, Vector2(PANEL_SIZE.x - hp_size.x - 18, y), _hp_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.9, 0.75))
	y += 28
	draw_string(font, Vector2(18, y), _subtitle, HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 36, 16, Color(0.7, 0.72, 0.78))
	y += 34
	for line in _lines:
		draw_string(font, Vector2(18, y), str(line), HORIZONTAL_ALIGNMENT_LEFT, PANEL_SIZE.x - 36, 17, Color(0.92, 0.93, 0.97))
		y += 28
	draw_string(font, Vector2(18, PANEL_SIZE.y - 14), "any key to close",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.56, 0.62))
