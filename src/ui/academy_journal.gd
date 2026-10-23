class_name AcademyJournal
extends Control
## AW-39: the Academy Journal — one book UI over the castle that surfaces the
## systems that already exist but had no window into them: the ROSTER (every
## student, stats, kit), the CALENDAR (the year at a glance), ITEMS (who carries
## what), and SYSTEM (multi-slot save/load + audio settings + quit). Opened with
## J in the castle; ←/→ switch tabs, ↑/↓ move, Enter acts, Esc/J closes.

signal closed

const TAB_NAMES := ["Roster", "Calendar", "Inventory", "Grades", "System", "Fish Log", "Supports"]
const STAT_KEYS := ["hp", "str", "mag", "skl", "spd", "lck", "def", "res"]
const STAT_LABELS := ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]
const SLOTS := 3
# System rows: (label, kind). kind drives Enter / ←→.
const SYS_ROWS := [
	["Save — Slot 1", "save0"], ["Save — Slot 2", "save1"], ["Save — Slot 3", "save2"],
	["Load — Slot 1", "load0"], ["Load — Slot 2", "load1"], ["Load — Slot 3", "load2"],
	["Music Volume", "music"], ["SFX Volume", "sfx"], ["Master Volume", "master"],
	["Text Speed", "text_speed"],
	["Return to Title", "title"],
]

var _tab := 0
var _roster_i := 0
var _sys_i := 0
var _fish_i := 0
var _support_i := 0
var _snaps: Array = []       # per-unit data snapshots
var _slot_info: Array = []   # save-slot summaries
var _toast := ""
var _toast_t := 0.0
var _toast_is_load_error := false  # Issue #83: clear stale reject feedback on navigation
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
	# Unit.setup() seeds level from the UnitDef; this bare unit skips it, so a
	# student with no saved progression read as Lv 1 (Perrin/Rina start at 2,
	# Serra at 5). A saved state still wins — apply_progression_state below.
	u.level = def.level if def != null else 1
	Campaign.apply_to_unit(u)  # live level-ups etc.; a no-op with no saved state
	var stats := {}
	for k in STAT_KEYS:
		stats[k] = u.stat(k)
	var skills: Array = []
	for sk in u.active_skills():
		skills.append(sk.display_name)
	# current_class(): a promoted student shows the class they earned, not the def's base
	var cur := u.current_class()
	var cls := cur.display_name if cur != null else "—"
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
		# Issue #16: consume BEFORE closing — `closed` fires synchronously, the
		# castle drops its book, and an unconsumed Esc/J would then reach its
		# exploration input (system menu / a fresh Journal).
		_handled()
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
	# Issue #83: don't leave a stale load rejection on an unrelated tab.
	if _toast_is_load_error:
		_toast = ""
		_toast_t = 0.0
		_toast_is_load_error = false
	AudioManager.play_sfx("cursor")
	queue_redraw()


func _move_row(dir: int) -> void:
	match _tab:
		0:
			if not _snaps.is_empty():
				_roster_i = (_roster_i + dir + _snaps.size()) % _snaps.size()
		2:
			_inv_move(dir)
		4:
			_sys_i = (_sys_i + dir + SYS_ROWS.size()) % SYS_ROWS.size()
		5:
			var catches := _fish_names()
			if not catches.is_empty():
				_fish_i = (_fish_i + dir + catches.size()) % catches.size()
		6:
			var supports := _support_entries()
			if not supports.is_empty():
				_support_i = (_support_i + dir + supports.size()) % supports.size()
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
	# AW-53: innate magic is part of its bearer — it can't be handed away.
	# AW-55 (Neal): spells aren't tradeable AT ALL — magic answers its learner,
	# so no tome changes hands (Kai's spellbook fire was leaking to Perrin).
	var w: WeaponDef = item.weapon()
	if w != null and (w.innate or w.weapon_type == WeaponDef.WeaponType.TOME):
		AudioManager.play_sfx("cancel")
		_show_toast("%s is bound to %s — magic can't change hands." % [item.display_name(), giver["name"]])
		return
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
	if _tab != 4:  # System (AW-54 slid it right for Grades)
		return false
	var kind: String = SYS_ROWS[_sys_i][1]
	if kind == "text_speed":
		var old_mode: String = DialoguePreferences.text_speed
		var idx := DialoguePreferences.MODES.find(old_mode)
		var next_mode: String = DialoguePreferences.MODES[wrapi(idx + dir, 0, DialoguePreferences.MODES.size())]
		var err := DialoguePreferences.set_text_speed(next_mode)
		_show_toast("Text speed: %s%s" % [DialoguePreferences.label(), " · save failed" if err != OK else ""])
		AudioManager.play_sfx("cursor")
		queue_redraw()
		return true
	var before := [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]
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
	# Issue #43: the new level is already live; also keep it for the next launch
	# (a failed write only warns — this session's sound is unaffected).
	if before != [AudioManager.master_volume, AudioManager.music_volume, AudioManager.sfx_volume]:
		AudioManager.save_preferences()
	queue_redraw()
	return true


func _activate() -> void:
	if _tab == 2:
		_inv_confirm()  # AW-52: the Inventory hub owns Enter on its tab
		return
	if _tab != 4:  # System (AW-54 slid it right for Grades)
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
	# AW-76 (Codex finding #3): save through Campaign so the payload gets the
	# {"campaign": ...} envelope load_from_slot expects — raw to_dict() wrote
	# slots that LOOKED occupied but could never load.
	if Campaign.save_to_slot(slot, _save):
		AudioManager.play_sfx("confirm")
		# The System rows read "Slot 1/2/3" (and the battle save banner does
		# too); toasts must speak the same one-based number, not the 0-based key.
		_show_toast("Saved to slot %d" % (slot + 1))
		_refresh_slots()
	else:
		_show_toast("Couldn't save slot %d" % (slot + 1))
	queue_redraw()


func _do_load(slot: int) -> void:
	if not _save.has_slot(slot):
		_show_toast("Slot %d is empty" % (slot + 1))
		queue_redraw()
		return
	# AW-75: a slot holding a live battle resumes into the battle itself.
	var payload := _save.load_slot(slot)
	if Resume.battle_live(payload):
		var scene := Resume.stage(payload)
		if scene != "":
			AudioManager.play_sfx("confirm")
			get_tree().change_scene_to_file.call_deferred(scene)
			return
	if Campaign.load_from_slot(slot, _save):
		AudioManager.play_sfx("confirm")
		# reload the castle so the loaded state takes hold (deferred — AW-49)
		get_tree().change_scene_to_file.call_deferred("res://scenes/castle/castle.tscn")
		return
	# Issue #83: an occupied file the existing loader rejects stays open for
	# another row, Escape/J, or a retry — it never pretends to have loaded.
	_report_load_failure(slot)


func _report_load_failure(slot: int) -> void:
	AudioManager.play_sfx("cancel")
	_show_toast("Slot %d couldn't be loaded — choose another slot." % (slot + 1), true)
	queue_redraw()


func _show_toast(msg: String, load_error := false) -> void:
	_toast = msg
	_toast_t = 2.2
	_toast_is_load_error = load_error


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
	UITheme.draw_panel(self, book, Color(0.11, 0.12, 0.17, 0.98))  # AW-56 shared frame
	var font := UITheme.font()
	# heading + tabs
	draw_string(font, book.position + Vector2(34, 46), "Academy Journal",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.86, 0.78, 0.45))
	# AW-70: the purse, always visible — gold finally has sinks, show the total
	var purse := "Purse: %dg" % int(Campaign.flags.get("gold", 0))
	draw_string(font, book.position + Vector2(book.size.x - 220, 46), purse,
		HORIZONTAL_ALIGNMENT_RIGHT, 190, 18, Color(0.95, 0.85, 0.5))
	var tx := book.position.x + 34.0
	var ty := book.position.y + 78.0
	var tab_font_size := 16
	var tab_rows := _tab_row_count(font, book.size.x - 68.0, tab_font_size)
	var tab_row := 0
	for i in range(TAB_NAMES.size()):
		var tw := _tab_width(font, TAB_NAMES[i], tab_font_size)
		if tx + tw > book.position.x + book.size.x - 34.0 and tx > book.position.x + 34.0:
			tab_row += 1
			tx = book.position.x + 34.0
		var row_y := ty + tab_row * 22.0
		var sel := i == _tab
		if sel:
			draw_rect(Rect2(tx - 8, row_y - 17, tw, 21), Color(0.30, 0.45, 0.85, 0.5), true)
		draw_string(font, Vector2(tx, row_y), TAB_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, tab_font_size,
			Color(1, 1, 1) if sel else Color(0.62, 0.65, 0.74))
		tx += tw + 10
	var tabs_height := 92.0 + (tab_rows - 1) * 22.0
	draw_line(book.position + Vector2(30, tabs_height), Vector2(book.position.x + book.size.x - 30, book.position.y + tabs_height),
		Color(0.3, 0.33, 0.44), 1.0)
	var body_top := tabs_height + 16.0
	var body := Rect2(book.position + Vector2(34, body_top),
		Vector2(book.size.x - 68.0, book.size.y - body_top - 42.0))
	match _tab:
		0: _draw_roster(body, font)
		1: _draw_calendar(body, font)
		2: _draw_items(body, font)
		3: _draw_grades(body, font)
		4: _draw_system(body, font)
		5: _draw_fish_log(body, font)
		6: _draw_supports(body, font)
	# footer
	var hint := "←/→ tab      ↑/↓ move      Enter select      J / Esc close"
	draw_string(font, Vector2(book.position.x + 34, book.position.y + book.size.y - 26), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.58, 0.68))
	if _toast_t > 0.0:
		var tr := _toast_rect()
		draw_rect(tr, Color(0.1, 0.11, 0.16, 0.95), true)
		draw_rect(tr, Color(0.86, 0.78, 0.45, 0.8), false, 1.5)
		draw_string(font, Vector2(tr.position.x + 16, tr.position.y + 20), _toast,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.9, 0.7))


## The toast box, measured once so the layout test can verify both default and
## compact books without rendering a capture.
func _toast_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var m := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var book := Rect2(m, vp - m * 2.0)
	var ts := UITheme.font().get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	return Rect2(book.position.x + (book.size.x - ts) * 0.5 - 16,
		book.position.y + book.size.y - 70, ts + 32, 30)


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


## AW-54: the Grades tab (GRADING_SYSTEM.md §3) — the running grade, the four
## weighted marks as bars, and the "↑ how to raise it" hint per mark.
func _draw_grades(body: Rect2, font: Font) -> void:
	var g := Campaign.running_grade()
	var x := body.position.x
	var y := body.position.y + 8
	draw_string(font, Vector2(x, y), "ACADEMY STANDING",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.86, 0.78, 0.45))
	draw_string(font, Vector2(x + body.size.x - 260, y), "Semester %d  ·  Week %d" % [Campaign.semester, Campaign.week],
		HORIZONTAL_ALIGNMENT_RIGHT, 250, 15, Color(0.62, 0.66, 0.76))
	y += 52
	# the running grade, big
	var rank_col := _rank_color(str(g["rank"]))
	draw_string(font, Vector2(x, y + 10), str(g["rank"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 54, rank_col)
	draw_string(font, Vector2(x + 56, y + 4), "%d  ·  %s" % [int(g["score"]), str(g["rank_name"])],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.95, 0.94, 0.88))
	draw_string(font, Vector2(x + 56, y + 26), "the grade if the semester ended today",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.58, 0.68))
	y += 66
	# the four marks
	var order := ["coursework", "battlefield", "arena", "conduct"]
	var labels := {"coursework": "Coursework", "battlefield": "Battlefield", "arena": "The Arena", "conduct": "Conduct"}
	var marks: Dictionary = g["marks"]
	var hints: Dictionary = g["hints"]
	for k in order:
		var v: float = marks[k]
		var has_data := v >= 0.0
		var shown := v if has_data else Grading.NEUTRAL
		draw_string(font, Vector2(x, y), labels[k], HORIZONTAL_ALIGNMENT_LEFT, 130, 16, Color(0.9, 0.9, 0.95))
		draw_string(font, Vector2(x + 130, y), "%d%%" % roundi(Grading.WEIGHTS[k] * 100),
			HORIZONTAL_ALIGNMENT_LEFT, 50, 13, Color(0.55, 0.58, 0.68))
		var bar := Rect2(x + 180, y - 13, 190, 14)
		draw_rect(bar, Color(0.2, 0.22, 0.3), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown / 100.0, bar.size.y)),
			rank_col.darkened(0.1) if has_data else Color(0.45, 0.48, 0.58), true)
		draw_string(font, Vector2(x + 380, y), ("%d" % roundi(shown)) + ("" if has_data else " (no marks yet)"),
			HORIZONTAL_ALIGNMENT_LEFT, 150, 15, Color(0.96, 0.93, 0.82))
		draw_string(font, Vector2(x + 380 + 130, y), "↑ " + str(hints[k]),
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 520, 14, Color(0.7, 0.9, 0.75))
		y += 40
	y += 8
	draw_string(font, Vector2(x, y), "→ Next report card: end of Semester %d (Week %d)" % [Campaign.semester, Campaign.semester_end_week()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.62, 0.66, 0.76))
	# locked history
	for rc in Campaign.report_cards:
		y += 28
		draw_string(font, Vector2(x, y), "Semester %d — %s (%s, %d)" % [int(rc["semester"]), str(rc["rank"]), str(rc["rank_name"]), int(rc["score"])],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, _rank_color(str(rc["rank"])))


func _rank_color(rank: String) -> Color:
	match rank:
		"S": return Color(0.98, 0.85, 0.35)
		"A": return Color(0.55, 0.9, 0.6)
		"B": return Color(0.5, 0.75, 1.0)
		"C": return Color(0.85, 0.8, 0.6)
	return Color(0.9, 0.5, 0.4)


func _draw_system(body: Rect2, font: Font) -> void:
	# Fit every existing save/audio/title row plus Text Speed in compact supported
	# windows. The old fixed 30 px spacing pushed the bottom controls off-screen.
	var pitch := clampf((body.size.y - 8.0) / SYS_ROWS.size(), 10.0, 30.0)
	var font_size := 10 if pitch < 13.0 else (12 if pitch < 17.0 else (13 if pitch < 23.0 else 16))
	var y := body.position.y + minf(20.0, pitch * 0.72)
	for i in range(SYS_ROWS.size()):
		var kind: String = SYS_ROWS[i][1]
		var sel := i == _sys_i
		if sel:
			draw_rect(Rect2(body.position.x - 6, y - pitch * 0.62, body.size.x - 20, pitch * 0.88), Color(0.30, 0.45, 0.85, 0.45), true)
		draw_string(font, Vector2(body.position.x + 6, y), SYS_ROWS[i][0],
			HORIZONTAL_ALIGNMENT_LEFT, minf(300.0, body.size.x * 0.48), font_size, Color(0.96, 0.94, 0.86) if sel else Color(0.78, 0.8, 0.86))
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
		elif kind == "text_speed":
			draw_string(font, Vector2(rx, y), DialoguePreferences.label(),
				HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 340, font_size, Color(0.8, 0.82, 0.9))
		y += pitch
	# The Journal-wide navigation hint already covers this tab. The older full
	# castle controls reference exceeded the compact System panel and collided
	# with that footer after adding the extra preference row.


## Show the saved catch dictionary as-is, in a stable name order. Reading this
## view never rolls, grants, normalizes, or writes a catch.
func _fish_names() -> Array:
	var names: Array = Campaign.fish_log.keys()
	names.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_name := str(a)
		var b_name := str(b)
		var a_folded := a_name.to_lower()
		var b_folded := b_name.to_lower()
		return a_folded < b_folded if a_folded != b_folded else a_name < b_name
	)
	return names


func _fish_log_entries() -> Array:
	var entries: Array = []
	for key in _fish_names():
		entries.append({"name": str(key), "count": Campaign.fish_log[key]})
	return entries


func _draw_fish_log(body: Rect2, font: Font) -> void:
	var x := body.position.x
	var y := body.position.y + 10.0
	draw_string(font, Vector2(x, y), "Fishing Catch Log",
		HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 20, Color(0.86, 0.78, 0.45))
	y += 38.0
	var entries := _fish_log_entries()
	if entries.is_empty():
		draw_string(font, Vector2(x, y), "No catches yet. Visit the waterside to try fishing.",
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 16, Color(0.72, 0.75, 0.82))
		return
	var row_pitch := 30.0
	var visible_rows := maxi(1, floori((body.size.y - 50.0) / row_pitch))
	_fish_i = clampi(_fish_i, 0, entries.size() - 1)
	var first := clampi(_fish_i - visible_rows + 1, 0, maxi(0, entries.size() - visible_rows))
	var last := mini(entries.size(), first + visible_rows)
	for i in range(first, last):
		var row_y := y + (i - first) * row_pitch
		if i == _fish_i:
			draw_rect(Rect2(x - 6, row_y - 18, body.size.x - 8, 25), Color(0.30, 0.45, 0.85, 0.35), true)
		var entry: Dictionary = entries[i]
		draw_string(font, Vector2(x + 8, row_y), str(entry["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 100.0, 16,
			Color(0.95, 0.94, 0.88) if i == _fish_i else Color(0.78, 0.8, 0.86))
		draw_string(font, Vector2(x + body.size.x - 78.0, row_y), "×%d" % int(entry["count"]),
			HORIZONTAL_ALIGNMENT_RIGHT, 64.0, 16, Color(0.86, 0.78, 0.45))
	draw_string(font, Vector2(x, body.position.y + body.size.y - 4.0), "↑/↓ browse catches",
		HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 13, Color(0.55, 0.58, 0.68))


## Read the authored Kai chains through a throwaway SupportState. Applying the
## campaign snapshot here keeps this reference page separate from live state.
func _support_entries() -> Array:
	var roster_names := {}
	for def in Roster.player_units():
		if def.id != "kai":
			roster_names[def.id] = def.display_name
	var state := SupportRegistry.build_state()
	state.apply_save_state(Campaign.support_save)
	var unlocked_by_pair := {}
	for conversation: Dictionary in state.unlocked_conversations_for_unit("kai"):
		var pair_id := str(conversation["pair_id"])
		if not unlocked_by_pair.has(pair_id):
			unlocked_by_pair[pair_id] = []
		unlocked_by_pair[pair_id].append(conversation)
	var entries: Array = []
	for companion_id in roster_names:
		var chain := state.chain_for_units("kai", str(companion_id))
		if chain == null:
			continue
		entries.append({
			"id": str(companion_id),
			"name": str(roster_names[companion_id]),
			"rank": state.rank_for_units("kai", str(companion_id)),
			"conversations": unlocked_by_pair.get(chain.pair_id(), []),
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_folded := str(a["name"]).to_lower()
		var b_folded := str(b["name"]).to_lower()
		return a_folded < b_folded if a_folded != b_folded else str(a["name"]) < str(b["name"])
	)
	return entries


func _draw_supports(body: Rect2, font: Font) -> void:
	var x := body.position.x
	var y := body.position.y + 8.0
	draw_string(font, Vector2(x, y), "Kai's Support Record",
		HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 20, Color(0.86, 0.78, 0.45))
	y += 38.0
	var entries := _support_entries()
	if entries.is_empty():
		draw_string(font, Vector2(x, y), "No authored Kai support chains are available on the current roster.",
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 15, Color(0.72, 0.75, 0.82))
		return
	_support_i = clampi(_support_i, 0, entries.size() - 1)
	var visible_indices := _support_visible_indices(entries, body.size.y - 66.0)
	for i in visible_indices:
		var entry: Dictionary = entries[i]
		var conversations: Array = entry["conversations"]
		var row_height := 28.0 + maxf(1, conversations.size()) * 19.0
		if i == _support_i:
			draw_rect(Rect2(x - 6.0, y - 17.0, body.size.x - 8.0, row_height - 2.0),
				Color(0.30, 0.45, 0.85, 0.30), true)
		var rank: String = str(entry["rank"])
		var rank_text := rank if rank != "" else "No rank earned"
		draw_string(font, Vector2(x + 4.0, y), "%s  ·  Current rank: %s" % [entry["name"], rank_text],
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 20.0, 16, Color(0.95, 0.94, 0.88))
		y += 22.0
		if conversations.is_empty():
			draw_string(font, Vector2(x + 14.0, y), "No earned conversations.",
				HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 28.0, 14, Color(0.62, 0.66, 0.76))
			y += 19.0
		else:
			for conversation: Dictionary in conversations:
				var status := "Viewed" if bool(conversation["viewed"]) else "Unviewed"
				draw_string(font, Vector2(x + 14.0, y), "%s conversation  ·  %s" % [conversation["rank"], status],
					HORIZONTAL_ALIGNMENT_LEFT, body.size.x - 28.0, 14,
					Color(0.75, 0.84, 0.92) if status == "Viewed" else Color(0.95, 0.80, 0.55))
				y += 19.0
		y += 6.0
	if entries.size() > 1:
		draw_string(font, Vector2(x, body.position.y + body.size.y - 4.0), "↑/↓ browse companions",
			HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 13, Color(0.55, 0.58, 0.68))


func _support_visible_indices(entries: Array, available_height: float) -> Array[int]:
	var visible: Array[int] = []
	var used := 0.0
	for i in range(_support_i, entries.size()):
		var conversations: Array = entries[i]["conversations"]
		var row_height := 28.0 + maxf(1, conversations.size()) * 19.0
		if not visible.is_empty() and used + row_height > available_height:
			break
		visible.append(i)
		used += row_height
	return visible


func _tab_width(font: Font, label: String, font_size: int) -> float:
	return font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 20.0


func _tab_row_count(font: Font, available_width: float, font_size: int) -> int:
	var rows := 1
	var used := 0.0
	for label in TAB_NAMES:
		var width := _tab_width(font, label, font_size)
		if used > 0.0 and used + width + 10.0 > available_width:
			rows += 1
			used = 0.0
		used += width + 10.0
	return rows


## AW-70: everything on one line, always one J-press away.
const CONTROLS_REF := "CONTROLS — Arrows/WASD walk · Enter interact · Esc menu · J journal · ` room editor · In battle: Enter select/confirm, Esc cancel, Enter on empty ground = field menu (save here!), Enter on a foe = its danger zone, H = all foes' reach"


func _slot_label(slot: int) -> String:
	for info in _slot_info:
		if int(info.get("slot", -1)) == slot:
			var mode := "Casual" if bool(info.get("casual_mode", false)) else "Classic"
			var ch := str(info.get("chapter_id", ""))
			# A live battle is not a campus checkpoint: say so before the player
			# loads it (the title screen uses the same ⚔ marker).
			var battle_tag := "  ⚔ mid-battle" if bool(info.get("in_battle", false)) else ""
			return "%s · %s%s" % [ch if ch != "" else "the academy", mode, battle_tag]
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


