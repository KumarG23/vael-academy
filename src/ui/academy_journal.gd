class_name AcademyJournal
extends Control
## AW-39: the Academy Journal — one book UI over the castle that surfaces the
## systems that already exist but had no window into them: the ROSTER (every
## student, stats, kit), the CALENDAR (the year at a glance), ITEMS (who carries
## what), and SYSTEM (multi-slot save/load + audio settings + quit). Opened with
## J in the castle; ←/→ switch tabs, ↑/↓ move, Enter acts, Esc/J closes.

signal closed

const TAB_NAMES := ["Roster", "Calendar", "Inventory", "System"]
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

## AW-52: the Inventory HUB — live scratch Units (real inventories, campaign
## state applied) so items can be MOVED between students, not just listed.
## Trades persist through Campaign.unit_states, the same channel battles use.
var _inv_units: Array = []   # [{id, name, house, unit(Unit)}]
var _inv_mode := 0           # 0 = pick a student · 1 = pick an item · 2 = pick who to give it to
var _inv_i := 0
var _inv_item_i := 0
var _inv_give_i := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PANEL):
		_panel = load(PANEL)
	_build_inv_units()
	_build_snaps()
	_refresh_slots()
	queue_redraw()


func _exit_tree() -> void:
	# the scratch Units are never in the tree — free them by hand
	for e in _inv_units:
		if is_instance_valid(e["unit"]):
			e["unit"].free()
	_inv_units.clear()


func _build_inv_units() -> void:
	for def in Roster.player_units():
		var u := Unit.new()
		u.setup(def.duplicate(), Grid.new(1, 1), Vector2i.ZERO)  # dup: never mutate the cached .tres
		if Campaign.has_unit_state(def.id):
			u.apply_progression_state(Campaign.get_unit_state(def.id))
		_inv_units.append({"id": def.id, "name": def.display_name, "house": def.house_id, "unit": u})


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
	var items := _live_items(def.id)  # AW-52: from the live inventory, so trades show
	var snap := {
		"id": def.id, "name": def.display_name, "class": cls, "house": def.house_id,
		"level": u.level, "mov": u.move_points(), "stats": stats, "skills": skills, "items": items,
	}
	u.free()
	return snap


func _live_items(id: String) -> Array:
	var out: Array = []
	for e in _inv_units:
		if e["id"] == id:
			for item in e["unit"].inventory.items:
				out.append(item.display_name())
	return out


func _refresh_slots() -> void:
	_slot_info = _save.list_slots(SLOTS)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cursor_cancel") or _is_journal_key(event):
		# AW-52: inside the Inventory hub, cancel backs out one level (give →
		# item → student) before it closes the book. J always closes.
		if _tab == 2 and _inv_mode > 0 and not _is_journal_key(event):
			_inv_mode -= 1
			AudioManager.play_sfx("cancel")
			_handled()
			queue_redraw()
			return
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
		2:
			_inv_move(dir)
		3:
			_sys_i = (_sys_i + dir + SYS_ROWS.size()) % SYS_ROWS.size()
		_:
			return
	AudioManager.play_sfx("cursor")
	queue_redraw()


# --- AW-52: the Inventory hub ---------------------------------------------------

func _inv_move(dir: int) -> void:
	if _inv_units.is_empty():
		return
	match _inv_mode:
		0:
			_inv_i = (_inv_i + dir + _inv_units.size()) % _inv_units.size()
		1:
			var n: int = _inv_unit().inventory.items.size()
			if n > 0:
				_inv_item_i = (_inv_item_i + dir + n) % n
		2:
			# cycle the give-target through everyone except the giver
			for _guard in range(_inv_units.size()):
				_inv_give_i = (_inv_give_i + dir + _inv_units.size()) % _inv_units.size()
				if _inv_give_i != _inv_i:
					break


func _inv_unit() -> Unit:
	return _inv_units[_inv_i]["unit"]


func _inv_confirm() -> void:
	if _inv_units.is_empty():
		return
	match _inv_mode:
		0:
			if _inv_unit().inventory.items.is_empty():
				_show_toast("%s is carrying nothing." % _inv_units[_inv_i]["name"])
				return
			_inv_mode = 1
			_inv_item_i = 0
			AudioManager.play_sfx("confirm")
		1:
			_inv_mode = 2
			_inv_give_i = _inv_i
			_inv_move(1)  # start on the next student over
			AudioManager.play_sfx("confirm")
		2:
			_inv_transfer()
	queue_redraw()


## Hand the selected item to the chosen student and PERSIST both sides through
## Campaign.unit_states — the same channel deployments read, so the trade is
## real in the next battle (and in saves).
func _inv_transfer() -> void:
	var giver: Dictionary = _inv_units[_inv_i]
	var taker: Dictionary = _inv_units[_inv_give_i]
	var items: Array = giver["unit"].inventory.items
	if _inv_item_i >= items.size():
		return
	var item: InventoryItem = items[_inv_item_i]
	if not giver["unit"].inventory.transfer_to(item, taker["unit"].inventory):
		AudioManager.play_sfx("cancel")
		_show_toast("%s's pack is full." % taker["name"])
		return
	Campaign.set_unit_state(giver["id"], giver["unit"].save_state())
	Campaign.set_unit_state(taker["id"], taker["unit"].save_state())
	AudioManager.play_sfx("confirm")
	_show_toast("Gave %s to %s." % [item.display_name(), taker["name"]])
	_build_snaps()  # the Roster tab's "Carries" line follows the trade
	var left: int = giver["unit"].inventory.items.size()
	_inv_item_i = clampi(_inv_item_i, 0, maxi(0, left - 1))
	_inv_mode = 1 if left > 0 else 0


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
	if _tab == 2:
		_inv_confirm()  # AW-52: the Inventory hub owns Enter on its tab
		return
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


## AW-52: the Inventory HUB — left: students; right: the selected pack. Enter
## drills in (student → item → recipient), Esc backs out, moves persist.
func _draw_items(body: Rect2, font: Font) -> void:
	var lw := 230.0
	var y := body.position.y + 6
	for i in range(_inv_units.size()):
		var e: Dictionary = _inv_units[i]
		var is_src := i == _inv_i
		var is_tgt := _inv_mode == 2 and i == _inv_give_i
		if is_tgt:
			draw_rect(Rect2(body.position.x - 6, y - 18, lw, 26), Color(0.86, 0.68, 0.25, 0.5), true)
		elif is_src and _inv_mode == 0:
			draw_rect(Rect2(body.position.x - 6, y - 18, lw, 26), Color(0.30, 0.45, 0.85, 0.45), true)
		draw_rect(Rect2(body.position.x - 2, y - 15, 4, 20), _house_color(e["house"]), true)
		var nm: String = e["name"]
		if is_src and _inv_mode > 0:
			nm += "  ◂ giving" if _inv_mode == 2 else "  ◂"
		var count: int = e["unit"].inventory.items.size()
		draw_string(font, Vector2(body.position.x + 10, y), nm,
			HORIZONTAL_ALIGNMENT_LEFT, lw - 60, 17,
			Color(0.95, 0.94, 0.88) if (is_src or is_tgt) else Color(0.78, 0.8, 0.86))
		draw_string(font, Vector2(body.position.x + lw - 44, y), "%d/5" % count,
			HORIZONTAL_ALIGNMENT_RIGHT, 40, 13, Color(0.55, 0.58, 0.68))
		y += 30
	# right pane: the selected student's pack
	if _inv_units.is_empty():
		return
	var e0: Dictionary = _inv_units[_inv_i]
	var rx := body.position.x + lw + 30
	var ry := body.position.y + 6
	draw_string(font, Vector2(rx, ry + 12), "%s's pack" % e0["name"],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 19, _house_color(e0["house"]).lightened(0.25))
	ry += 44
	var inv: Inventory = e0["unit"].inventory
	var eq: InventoryItem = inv.equipped_weapon_item()
	if inv.items.is_empty():
		draw_string(font, Vector2(rx, ry), "— carrying nothing —",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.6, 0.63, 0.72))
	for i in range(inv.items.size()):
		var item: InventoryItem = inv.items[i]
		var sel := _inv_mode >= 1 and i == _inv_item_i
		if sel:
			draw_rect(Rect2(rx - 8, ry - 18, body.size.x - lw - 50, 26),
				Color(0.86, 0.68, 0.25, 0.5) if _inv_mode == 2 else Color(0.30, 0.45, 0.85, 0.45), true)
		var label: String = item.display_name()
		if item == eq:
			label += "   (equipped)"
		draw_string(font, Vector2(rx, ry), label, HORIZONTAL_ALIGNMENT_LEFT,
			body.size.x - lw - 170, 16, Color(0.95, 0.94, 0.88) if sel else Color(0.85, 0.86, 0.92))
		var uses := "∞" if item.uses >= 999 else "×%d" % item.uses
		draw_string(font, Vector2(body.position.x + body.size.x - 70, ry), uses,
			HORIZONTAL_ALIGNMENT_RIGHT, 60, 14, Color(0.62, 0.66, 0.76))
		ry += 30
	# contextual hint under the pack
	var hint := ""
	match _inv_mode:
		0: hint = "Enter — open this student's pack"
		1: hint = "Enter — give this item to someone   ·   Esc — back"
		2: hint = "↑/↓ — choose who receives it   ·   Enter — hand it over   ·   Esc — back"
	draw_string(font, Vector2(rx, body.position.y + body.size.y - 8), hint,
		HORIZONTAL_ALIGNMENT_LEFT, body.size.x - lw - 40, 14, Color(0.86, 0.78, 0.45, 0.9))


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

## Portraits must be CACHED in a member (like dialogue_scene does) — a fresh
## load() used only as a _draw local frees the Resource when _draw returns, and
## the queued canvas command then renders Godot's white placeholder (the AW-52
## "portraits not showing" bug: draw commands don't hold texture references).
var _portrait_cache: Dictionary = {}


func _portrait(id: String) -> Texture2D:
	if not _portrait_cache.has(id):
		var path := "res://assets/portraits/portrait_%s.png" % id
		_portrait_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _portrait_cache[id]


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
