class_name AcademyJournal
extends Control
## AW-39: the Academy Journal — one book UI over the castle that surfaces the
## systems that already exist but had no window into them: the ROSTER (every
## student, stats, kit), the CALENDAR (the year at a glance), ITEMS (who carries
## what), and SYSTEM (multi-slot save/load + audio settings + quit). Opened with
## J in the castle; ←/→ switch tabs, ↑/↓ move, Enter acts, Esc/J closes.

signal closed

const TAB_NAMES := ["Roster", "Calendar", "Items", "System"]
const STAT_KEYS := ["hp", "str", "mag", "skl", "spd", "lck", "def", "res"]
const STAT_LABELS := ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]
const SLOTS := 3
# System rows: (label, kind). kind drives Enter / ←→.
const SYS_ROWS := [
	["Save — Slot 1", "save0"], ["Save — Slot 2", "save1"], ["Save — Slot 3", "save2"],
	["Load — Slot 1", "load0"], ["Load — Slot 2", "load1"], ["Load — Slot 3", "load2"],
	["Music Volume", "music"], ["SFX Volume", "sfx"], ["Master Volume", "master"],
	["Return to Title", "title"],
]
const PANEL := "res://assets/art/ui/panel_noble.png"

var _tab := 0
var _roster_i := 0
var _sys_i := 0
var _snaps: Array = []       # per-unit data snapshots
var _slot_info: Array = []   # save-slot summaries
var _toast := ""
var _toast_t := 0.0
var _panel: Texture2D
var _save := SaveSystem.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PANEL):
		_panel = load(PANEL)
	_build_snaps()
	_refresh_slots()
	queue_redraw()


func _build_snaps() -> void:
	_snaps.clear()
	for def in Roster.player_units():
		_snaps.append(_snapshot(def))


func _snapshot(def: UnitDef) -> Dictionary:
	var u := Unit.new()
	u.unit_def = def
	Campaign.apply_to_unit(u)  # live level-ups etc.; a no-op with no saved state
	var stats := {}
	for k in STAT_KEYS:
		stats[k] = u.stat(k)
	var skills: Array = []
	for sk in u.active_skills():
		skills.append(sk.display_name)
	var cls := def.char_class.display_name if def.char_class != null else "—"
	var items := _def_items(def)
	var snap := {
		"id": def.id, "name": def.display_name, "class": cls, "house": def.house_id,
		"level": u.level, "mov": u.move_points(), "stats": stats, "skills": skills, "items": items,
	}
	u.free()
	return snap


func _def_items(def: UnitDef) -> Array:
	var out: Array = []
	if def.weapon != null:
		out.append(def.weapon.display_name)
	for w in def.extra_weapons:
		if w != null:
			out.append(w.display_name)
	for it in def.starting_items:
		if it != null:
			out.append(it.display_name)
	return out


func _refresh_slots() -> void:
	_slot_info = _save.list_slots(SLOTS)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cursor_cancel") or _is_journal_key(event):
		AudioManager.play_sfx("cancel")
		_close()
	elif event.is_action_pressed("cursor_left"):
		if not _adjust_volume(-1):
			_switch_tab(-1)
		_handled()
	elif event.is_action_pressed("cursor_right"):
		if not _adjust_volume(1):
			_switch_tab(1)
		_handled()
	elif event.is_action_pressed("cursor_up"):
		_move_row(-1); _handled()
	elif event.is_action_pressed("cursor_down"):
		_move_row(1); _handled()
	elif event.is_action_pressed("cursor_confirm"):
		# AW-49: handled BEFORE acting — _activate can change the scene (Return to
		# Title / Load), which de-trees this node and nulls get_viewport().
		_handled(); _activate()


func _is_journal_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J


func _handled() -> void:
	get_viewport().set_input_as_handled()


func _switch_tab(dir: int) -> void:
	_tab = (_tab + dir + TAB_NAMES.size()) % TAB_NAMES.size()
	AudioManager.play_sfx("cursor")
	queue_redraw()


func _move_row(dir: int) -> void:
	match _tab:
		0:
			if not _snaps.is_empty():
				_roster_i = (_roster_i + dir + _snaps.size()) % _snaps.size()
		3:
			_sys_i = (_sys_i + dir + SYS_ROWS.size()) % SYS_ROWS.size()
		_:
			return
	AudioManager.play_sfx("cursor")
	queue_redraw()


func _adjust_volume(dir: int) -> bool:
	if _tab != 3:
		return false
	var kind: String = SYS_ROWS[_sys_i][1]
	match kind:
		"music":
			AudioManager.music_volume = clampf(AudioManager.music_volume + dir * 0.1, 0.0, 1.0)
		"sfx":
			AudioManager.sfx_volume = clampf(AudioManager.sfx_volume + dir * 0.1, 0.0, 1.0)
			AudioManager.play_sfx("cursor")
		"master":
			AudioManager.master_volume = clampf(AudioManager.master_volume + dir * 0.1, 0.0, 1.0)
		_:
			return false
	queue_redraw()
	return true


func _activate() -> void:
	if _tab != 3:
		return
	var kind: String = SYS_ROWS[_sys_i][1]
	if kind.begins_with("save"):
		_do_save(int(kind.substr(4)))
	elif kind.begins_with("load"):
		_do_load(int(kind.substr(4)))
	elif kind == "title":
		AudioManager.play_sfx("confirm")
		# AW-49: deferred — never swap scenes synchronously inside an input callback
		get_tree().change_scene_to_file.call_deferred("res://scenes/title/title.tscn")


func _do_save(slot: int) -> void:
	if _save.save_slot(slot, Campaign.to_dict()):
		AudioManager.play_sfx("confirm")
		_show_toast("Saved to slot %d" % slot)
		_refresh_slots()
	else:
		_show_toast("Couldn't save slot %d" % slot)
	queue_redraw()


func _do_load(slot: int) -> void:
	if not _save.has_slot(slot):
		_show_toast("Slot %d is empty" % slot)
		queue_redraw()
		return
	if Campaign.load_from_slot(slot, _save):
		AudioManager.play_sfx("confirm")
		# reload the castle so the loaded state takes hold (deferred — AW-49)
		get_tree().change_scene_to_file.call_deferred("res://scenes/castle/castle.tscn")


func _show_toast(msg: String) -> void:
	_toast = msg
	_toast_t = 2.2


func _close() -> void:
	visible = false
	closed.emit()
	queue_free()


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.06, 0.09, 0.72))  # dim the castle
	var m := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var book := Rect2(m, vp - m * 2.0)
	draw_rect(book.grow(-6), Color(0.11, 0.12, 0.17, 0.98), true)
	if _panel != null:
		_nine(_panel, book, 58.0, 22.0)
	else:
		draw_rect(book, Color(0.85, 0.78, 0.45), false, 2.0)
	var font := ThemeDB.fallback_font
	# heading + tabs
	draw_string(font, book.position + Vector2(34, 46), "Academy Journal",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.86, 0.78, 0.45))
	var tx := book.position.x + 34.0
	var ty := book.position.y + 78.0
	for i in range(TAB_NAMES.size()):
		var sel := i == _tab
		var tw := font.get_string_size(TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 26
		if sel:
			draw_rect(Rect2(tx - 8, ty - 20, tw, 28), Color(0.30, 0.45, 0.85, 0.5), true)
		draw_string(font, Vector2(tx, ty), TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(1, 1, 1) if sel else Color(0.62, 0.65, 0.74))
		tx += tw + 10
	draw_line(book.position + Vector2(30, 92), Vector2(book.position.x + book.size.x - 30, book.position.y + 92),
		Color(0.3, 0.33, 0.44), 1.0)
	var body := Rect2(book.position + Vector2(34, 108), book.size - Vector2(68, 150))
	match _tab:
		0: _draw_roster(body, font)
		1: _draw_calendar(body, font)
		2: _draw_items(body, font)
		3: _draw_system(body, font)
	# footer
	var hint := "←/→ tab      ↑/↓ move      Enter select      J / Esc close"
	draw_string(font, Vector2(book.position.x + 34, book.position.y + book.size.y - 26), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.58, 0.68))
	if _toast_t > 0.0:
		var ts := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var tr := Rect2(book.position.x + (book.size.x - ts) * 0.5 - 16, book.position.y + book.size.y - 70, ts + 32, 30)
		draw_rect(tr, Color(0.1, 0.11, 0.16, 0.95), true)
		draw_rect(tr, Color(0.86, 0.78, 0.45, 0.8), false, 1.5)
		draw_string(font, Vector2(tr.position.x + 16, tr.position.y + 20), _toast,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.9, 0.7))


func _draw_roster(body: Rect2, font: Font) -> void:
	# left: unit list; right: selected unit detail
	var lw := 210.0
	var y := body.position.y + 6
	for i in range(_snaps.size()):
		var s: Dictionary = _snaps[i]
		if i == _roster_i:
			draw_rect(Rect2(body.position.x - 6, y - 18, lw, 26), Color(0.30, 0.45, 0.85, 0.45), true)
		var col: Color = _house_color(s["house"])
		draw_rect(Rect2(body.position.x - 2, y - 15, 4, 20), col, true)
		draw_string(font, Vector2(body.position.x + 10, y), s["name"],
			HORIZONTAL_ALIGNMENT_LEFT, lw - 20, 18, Color(0.95, 0.94, 0.88) if i == _roster_i else Color(0.78, 0.8, 0.86))
		y += 30
	if _roster_i < _snaps.size():
		_draw_unit_detail(_snaps[_roster_i], Rect2(body.position + Vector2(lw + 20, 0), body.size - Vector2(lw + 20, 0)), font)


func _draw_unit_detail(s: Dictionary, r: Rect2, font: Font) -> void:
	var x := r.position.x
	var y := r.position.y
	# portrait
	var portrait := _portrait(s["id"])
	if portrait != null:
		var ph := 150.0
		var pw := portrait.get_width() * (ph / portrait.get_height())
		draw_texture_rect(portrait, Rect2(x, y, pw, ph), false)
		x += pw + 22
	draw_string(font, Vector2(x, y + 26), s["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
		_house_color(s["house"]).lightened(0.25))
	draw_string(font, Vector2(x, y + 52), "%s   ·   Lv %d   ·   Mov %d" % [s["class"], s["level"], s["mov"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.82, 0.9))
	draw_string(font, Vector2(x, y + 76), (str(s["house"]).capitalize() + " House") if s["house"] != "" else "Protagonist",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.62, 0.65, 0.74))
	# stat grid (2 columns of 4)
	var sy := r.position.y + 172
	for i in range(STAT_KEYS.size()):
		var gx := r.position.x + (i % 2) * 190.0
		var gy := sy + (i / 2) * 26.0
		draw_string(font, Vector2(gx, gy), STAT_LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.66, 0.7, 0.82))
		draw_string(font, Vector2(gx + 52, gy), str(s["stats"][STAT_KEYS[i]]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.96, 0.93, 0.82))
	var by := sy + 4 * 26 + 14
	draw_string(font, Vector2(r.position.x, by), "Carries:  " + (", ".join(s["items"]) if not s["items"].is_empty() else "—"),
		HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 14, Color(0.82, 0.84, 0.9))
	if not s["skills"].is_empty():
		draw_string(font, Vector2(r.position.x, by + 24), "Skills:  " + ", ".join(s["skills"]),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, 14, Color(0.7, 0.9, 0.75))


func _draw_calendar(body: Rect2, font: Font) -> void:
	var events := Campaign.calendar()
	draw_string(font, body.position + Vector2(0, 4), "Year One  ·  Week %d" % Campaign.week,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.86, 0.78, 0.45))
	var y := body.position.y + 40
	for e in events:
		var now := e.week == Campaign.week
		if now:
			draw_rect(Rect2(body.position.x - 6, y - 18, body.size.x - 20, 28), Color(0.30, 0.45, 0.85, 0.4), true)
		draw_string(font, Vector2(body.position.x + 6, y), "Week %d" % e.week,
			HORIZONTAL_ALIGNMENT_LEFT, 90, 16, Color(0.7, 0.73, 0.82))
		draw_string(font, Vector2(body.position.x + 100, y), e.label,
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 220, 16,
			Color(0.96, 0.92, 0.78) if now else Color(0.82, 0.84, 0.9))
		var kind_txt := _kind_name(e.kind)
		draw_string(font, Vector2(body.position.x + body.size.x - 130, y), kind_txt,
			HORIZONTAL_ALIGNMENT_RIGHT, 110, 14, _kind_color(e.kind))
		y += 32
		if y > body.position.y + body.size.y - 20:
			break


func _draw_items(body: Rect2, font: Font) -> void:
	var y := body.position.y + 4
	for s in _snaps:
		if s["items"].is_empty():
			continue
		draw_string(font, Vector2(body.position.x, y), s["name"],
			HORIZONTAL_ALIGNMENT_LEFT, 180, 16, _house_color(s["house"]).lightened(0.2))
		draw_string(font, Vector2(body.position.x + 190, y), ", ".join(s["items"]),
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 200, 16, Color(0.85, 0.86, 0.92))
		y += 28
		if y > body.position.y + body.size.y - 10:
			break


func _draw_system(body: Rect2, font: Font) -> void:
	var y := body.position.y + 6
	for i in range(SYS_ROWS.size()):
		var kind: String = SYS_ROWS[i][1]
		var sel := i == _sys_i
		if sel:
			draw_rect(Rect2(body.position.x - 6, y - 18, body.size.x - 20, 26), Color(0.30, 0.45, 0.85, 0.45), true)
		draw_string(font, Vector2(body.position.x + 6, y), SYS_ROWS[i][0],
			HORIZONTAL_ALIGNMENT_LEFT, 300, 17, Color(0.96, 0.94, 0.86) if sel else Color(0.78, 0.8, 0.86))
		# right column: slot summary or a volume bar
		var rx := body.position.x + 320
		if kind.begins_with("save") or kind.begins_with("load"):
			var slot := int(kind.substr(4))
			draw_string(font, Vector2(rx, y), _slot_label(slot),
				HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 340, 14, Color(0.62, 0.66, 0.76))
		elif kind in ["music", "sfx", "master"]:
			var v: float = AudioManager.music_volume if kind == "music" else (AudioManager.sfx_volume if kind == "sfx" else AudioManager.master_volume)
			draw_rect(Rect2(rx, y - 12, 160, 12), Color(0.2, 0.22, 0.3), true)
			draw_rect(Rect2(rx, y - 12, 160 * v, 12), Color(0.5, 0.7, 1.0), true)
			draw_string(font, Vector2(rx + 172, y), "%d%%" % roundi(v * 100),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.82, 0.9))
		y += 30


func _slot_label(slot: int) -> String:
	for info in _slot_info:
		if int(info.get("slot", -1)) == slot:
			var mode := "Casual" if bool(info.get("casual_mode", false)) else "Classic"
			var ch := str(info.get("chapter_id", ""))
			return "%s · %s" % [ch if ch != "" else "the academy", mode]
	return "— empty —"


# --- helpers -----------------------------------------------------------------

func _portrait(id: String) -> Texture2D:
	var path := "res://assets/portraits/portrait_%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


func _house_color(house: String) -> Color:
	match house:
		"emberwing": return Color(0.85, 0.35, 0.28)
		"tidemark": return Color(0.36, 0.6, 0.85)
		"thornrook": return Color(0.42, 0.72, 0.35)
	return Color(0.86, 0.78, 0.45)


func _kind_name(kind: int) -> String:
	return CalendarEventDef.Kind.keys()[kind].capitalize() if kind < CalendarEventDef.Kind.keys().size() else "Free"


func _kind_color(kind: int) -> Color:
	var n := _kind_name(kind).to_lower()
	if n == "battle":
		return Color(0.9, 0.5, 0.4)
	if n == "festival" or n == "feast":
		return Color(0.9, 0.75, 0.4)
	return Color(0.6, 0.66, 0.78)


func _nine(t: Texture2D, dest: Rect2, sm: float, dm: float) -> void:
	var tw := float(t.get_width())
	var th := float(t.get_height())
	var sx := [0.0, sm, tw - sm, tw]
	var sy := [0.0, sm, th - sm, th]
	var dx := [dest.position.x, dest.position.x + dm, dest.position.x + dest.size.x - dm, dest.position.x + dest.size.x]
	var dy := [dest.position.y, dest.position.y + dm, dest.position.y + dest.size.y - dm, dest.position.y + dest.size.y]
	for r in range(3):
		for c in range(3):
			draw_texture_rect_region(t, Rect2(dx[c], dy[r], dx[c + 1] - dx[c], dy[r + 1] - dy[r]),
				Rect2(sx[c], sy[r], sx[c + 1] - sx[c], sy[r + 1] - sy[r]))
