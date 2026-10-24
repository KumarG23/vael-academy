class_name AcademyJournal
extends Control
## AW-39: the Academy Journal — one book UI over the castle that surfaces the
## systems that already exist but had no window into them: the ROSTER (every
## student, stats, kit), the CALENDAR (the year at a glance), ITEMS (who carries
## what), and SYSTEM (multi-slot save/load + audio settings + quit). Opened with
## J in the castle; ←/→ switch tabs, ↑/↓ move, Enter acts, Esc/J closes.

signal closed

const TAB_NAMES := ["Roster", "Calendar", "Inventory", "Grades", "System", "Fish Log", "Supports", "Objectives"]
const MULTILINE_MAX_LINES := -1
const MissionReference = preload("res://src/ui/mission_reference.gd")

const STAT_KEYS := ["hp", "str", "mag", "skl", "spd", "lck", "def", "res"]
const STAT_LABELS := ["HP", "STR", "MAG", "SKL", "SPD", "LCK", "DEF", "RES"]
const SLOTS := 3
const ROSTER_FOOTER_SAFE_INSET := UITheme.DST_MARGIN * 2.5 + 1.0
# System rows: (label, kind). kind drives Enter / ←→.
const SYS_ROWS := [
	["Save — Slot 1", "save0"], ["Save — Slot 2", "save1"], ["Save — Slot 3", "save2"],
	["Load — Slot 1", "load0"], ["Load — Slot 2", "load1"], ["Load — Slot 3", "load2"],
	["Music Volume", "music"], ["SFX Volume", "sfx"], ["Master Volume", "master"],
	["Text Speed", "text_speed"],
	["Return to Title", "title"],
	# Issue #89: appended so existing row indices stay put.
	["Keyboard Controls", "keyboard"],
]

var _tab := 0
var _roster_i := 0
var _roster_detail_page := 0
var _sys_i := 0
var _sys_scroll := 0      # Issue #117: first visible System row
var _fish_i := 0
var _support_i := 0
var _calendar_i := -1
var _calendar_scroll := 0
var _grades_scroll := 0     # Issue #108: first visible Grades item
var _objectives_scroll := 0
var _snaps: Array = []       # per-unit data snapshots
var _slot_info: Array = []   # save-slot summaries
var _toast := ""
var _toast_t := 0.0
var _toast_is_load_error := false  # Issue #83: clear stale reject feedback on navigation
var _save := SaveSystem.new()
var _keys_editor: KeyboardControlsEditor = null  # issue #89 modal sub-page

## AW-52: the Inventory HUB — live scratch Units (real inventories, campaign
## state applied) so items can be MOVED between students, not just listed.
## Trades persist through Campaign.unit_states, the same channel battles use.
var _inv_units: Array = []   # [{id, name, house, unit(Unit)}]
var _inv_mode := 0           # 0 = pick a student · 1 = pick an item · 2 = pick who to give it to
var _inv_i := 0
var _inv_item_i := 0
var _inv_give_i := 0
var _items_student_scroll := 0
var _items_pack_scroll := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_NEAREST
	_build_inv_units()
	_build_snaps()
	_refresh_slots()
	_calendar_i = _calendar_current_index()
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
	if not visible or _keys_editor != null:
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
	elif _tab == 0 and _is_roster_page_key(event):
		# The roster's list stays on Up/Down; PageUp/PageDown browse the selected
		# student's complete detail when the compact book cannot show it at once.
		# Consume echoes too so a held key cannot leak into castle exploration.
		if event is InputEventKey and event.pressed and not event.echo:
			_move_roster_detail_page(-1 if event.keycode == KEY_PAGEUP else 1)
		_handled()
	elif event.is_action_pressed("cursor_up", _tab == 3):
		_move_row(-1); _handled()
	elif event.is_action_pressed("cursor_down", _tab == 3):
		_move_row(1); _handled()
	elif event.is_action_pressed("cursor_confirm"):
		# AW-49: handled BEFORE acting — _activate can change the scene (Return to
		# Title / Load), which de-trees this node and nulls get_viewport().
		_handled(); _activate()


func _is_journal_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J


func _is_roster_page_key(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]


func _move_roster_detail_page(dir: int) -> void:
	if _snaps.is_empty() or _roster_i >= _snaps.size():
		return
	var body := _roster_body_rect()
	var list_width := clampf(body.size.x * 0.29, 112.0, 210.0)
	var detail_width := body.size.x - list_width - 14.0
	var lines := _roster_detail_lines(_snaps[_roster_i], UITheme.font(), detail_width)
	var pages := maxi(1, int(ceil(float(lines.size()) / _roster_detail_page_size(body.size.y))))
	_roster_detail_page = clampi(_roster_detail_page + dir, 0, pages - 1)
	AudioManager.play_sfx("cursor")
	queue_redraw()


func _handled() -> void:
	get_viewport().set_input_as_handled()


func _switch_tab(dir: int) -> void:
	_tab = (_tab + dir + TAB_NAMES.size()) % TAB_NAMES.size()
	_grades_scroll = 0
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
			_roster_detail_page = 0
		2:
			_inv_move(dir)
		4:
			_sys_i = (_sys_i + dir + SYS_ROWS.size()) % SYS_ROWS.size()
		5:
			var catches := _fish_names()
			if not catches.is_empty():
				_fish_i = (_fish_i + dir + catches.size()) % catches.size()
		7:
			_objectives_scroll += dir
			_objectives_layout(_body_rect(), UITheme.font())
		6:
			var supports := _support_entries()
			if not supports.is_empty():
				_support_i = (_support_i + dir + supports.size()) % supports.size()
		3:
			var before := _grades_scroll
			var layout := _grades_layout(_body_rect(), UITheme.font())
			_grades_scroll = clampi(_grades_scroll + dir, 0, layout["max_start"])
			if _grades_scroll == before:
				return
		1:
			var events := Campaign.calendar()
			if not events.is_empty():
				_calendar_i = clampi(_calendar_i + dir, 0, events.size() - 1)
				# Keep ordinary one-row browsing linear; the view clamps at both ends.
				_calendar_scroll = clampi(_calendar_scroll, 0, events.size() - 1)
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
	elif kind == "keyboard":
		_open_keys_editor()
	elif kind == "title":
		AudioManager.play_sfx("confirm")
		# AW-49: deferred — never swap scenes synchronously inside an input callback
		get_tree().change_scene_to_file.call_deferred("res://scenes/title/title.tscn")


func _open_keys_editor() -> void:
	AudioManager.play_sfx("confirm")
	_keys_editor = KeyboardControlsEditor.new()
	_keys_editor.closed.connect(func() -> void:
		_keys_editor = null
		queue_redraw())
	add_child(_keys_editor)


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
	# Preserve GH-96's accepted Roster frame/title alongside its measured footer.
	# Other tabs retain GH-106's captured complete-corner slice and heading.
	var source_margin := UITheme.SRC_MARGIN if _tab == 0 else 112.0
	UITheme.draw_panel(self, book, Color(0.11, 0.12, 0.17, 0.98), source_margin)
	var font := UITheme.font()
	# heading + tabs
	var heading_position := book.position + Vector2(34, 46) if _tab == 0 else _heading_rect().position + Vector2(0, font.get_ascent(26))
	draw_string(font, heading_position, "Academy Journal",
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
	var body := _roster_body_rect() if _tab == 0 else _body_rect()
	match _tab:
		0: _draw_roster(body, font)
		1: _draw_calendar(body, font)
		2: _draw_items(body, font)
		3: _draw_grades(body, font)
		4: _draw_system(body, font)
		5: _draw_fish_log(body, font)
		6: _draw_supports(body, font)
		7: _draw_objectives(body, font)
	# footer
	if _tab == 0:
		var roster_hint := _roster_footer_hint()
		var footer_bounds := _roster_footer_bounds(book, font, roster_hint)
		draw_string(font, Vector2(footer_bounds.position.x, footer_bounds.position.y + font.get_ascent(14)), roster_hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.58, 0.68))
	else:
		var hint := "←/→ tab      ↑/↓ move      Enter select      J / Esc close"
		if _tab == 7:
			hint = "←/→ tab      ↑/↓ scroll      J / Esc close"
		draw_string(font, _footer_rect(hint).position + Vector2(0, font.get_ascent(14)), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.58, 0.68))
	if _toast_t > 0.0 and _tab == 2 and not _toast_is_load_error:
		var toast_layout := _inventory_toast_layout(font)
		var tr: Rect2 = toast_layout["rect"]
		draw_rect(tr, Color(0.1, 0.11, 0.16, 0.97), true)
		draw_rect(tr, Color(0.86, 0.78, 0.45, 0.9), false, 1.5)
		draw_multiline_string(font, toast_layout["baseline"], "\n".join(toast_layout["lines"]),
			HORIZONTAL_ALIGNMENT_LEFT, toast_layout["text_width"], 16, MULTILINE_MAX_LINES, Color(0.95, 0.9, 0.7))
	elif _toast_t > 0.0 and _tab == 4:
		# System feedback uses its reserved row/range-hint layout.
		var sr: Rect2 = _system_layout(body, font)["toast_rect"]
		draw_rect(sr, Color(0.1, 0.11, 0.16, 0.95), true)
		draw_rect(sr, Color(0.86, 0.78, 0.45, 0.8), false, 1.5)
		draw_string(font, Vector2(sr.position.x + 8.0, sr.position.y + 3.0 + font.get_ascent(SYS_FONT_SIZE)), _toast,
			HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE, Color(0.95, 0.9, 0.7))
	elif _toast_t > 0.0:
		# Keep shared load-error and other-tab feedback geometry unchanged.
		var tr := _toast_rect()
		draw_rect(tr, Color(0.1, 0.11, 0.16, 0.95), true)
		draw_rect(tr, Color(0.86, 0.78, 0.45, 0.8), false, 1.5)
		draw_string(font, Vector2(tr.position.x + 16, tr.position.y + 20), _toast,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.9, 0.7))


func _roster_body_rect() -> Rect2:
	return _journal_body_rect()


func _journal_body_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var m := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var book := Rect2(m, vp - m * 2.0)
	var rows := _tab_row_count(UITheme.font(), book.size.x - 68.0, 16)
	var body_top := 92.0 + (rows - 1) * 22.0 + 16.0
	return Rect2(book.position + Vector2(34, body_top),
		Vector2(book.size.x - 68.0, book.size.y - body_top - 42.0))


func _roster_footer_hint() -> String:
	return "↑/↓ student   PgUp/PgDn details   ←/→ tab   J / Esc close"


## Bounds the actual Roster footer glyphs inside the clear area of the ornate
## panel. Width and height come from the active font; the safe inset avoids the
## lower corner filigree at every supported window size.
func _roster_footer_bounds(book: Rect2, font: Font, hint: String) -> Rect2:
	var font_size := 14
	var measured := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var safe_left := book.position.x + ROSTER_FOOTER_SAFE_INSET
	var safe_right := book.end.x - ROSTER_FOOTER_SAFE_INSET
	var x := clampf(book.get_center().x - measured.x * 0.5, safe_left, safe_right - measured.x)
	var bottom := book.end.y - ROSTER_FOOTER_SAFE_INSET
	var baseline := bottom - descent
	return Rect2(Vector2(x, baseline - ascent), Vector2(measured.x, ascent + descent))


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
	# Keep both panes inside the measured body. At compact heights only the
	# selected roster rows are shown; Up/Down still wraps through every member.
	var lw := clampf(body.size.x * 0.29, 112.0, 210.0)
	var list_x := body.position.x
	var row_step := 26.0
	var visible_rows := maxi(1, int(floor((body.size.y - 4.0) / row_step)))
	var first := clampi(_roster_i - visible_rows + 1, 0, maxi(0, _snaps.size() - visible_rows))
	var y := body.position.y + 18
	for i in range(first, mini(_snaps.size(), first + visible_rows)):
		var s: Dictionary = _snaps[i]
		if i == _roster_i:
			draw_rect(Rect2(list_x, y - 17, lw, 22), Color(0.30, 0.45, 0.85, 0.45), true)
		var col: Color = _house_color(s["house"])
		draw_rect(Rect2(list_x + 2, y - 14, 3, 16), col, true)
		draw_string(font, Vector2(list_x + 10, y), s["name"],
			HORIZONTAL_ALIGNMENT_LEFT, lw - 14, 16, Color(0.95, 0.94, 0.88) if i == _roster_i else Color(0.78, 0.8, 0.86))
		y += row_step
	if _roster_i < _snaps.size():
		var pane := Rect2(body.position + Vector2(lw + 14.0, 0), Vector2(body.size.x - lw - 14.0, body.size.y))
		_draw_unit_detail(_snaps[_roster_i], pane, font)


func _draw_unit_detail(s: Dictionary, r: Rect2, font: Font) -> void:
	var lines := _roster_detail_lines(s, font, r.size.x)
	var page_size := _roster_detail_page_size(r.size.y)
	var page_count := maxi(1, int(ceil(float(lines.size()) / page_size)))
	_roster_detail_page = clampi(_roster_detail_page, 0, page_count - 1)
	var start := _roster_detail_page * page_size
	var end := mini(lines.size(), start + page_size)
	var portrait := _portrait(s["id"])
	var heading_y := r.position.y + 18
	var portrait_h := minf(42.0, maxf(0.0, r.size.y * 0.42)) if _roster_detail_page == 0 else 0.0
	if portrait != null and portrait_h >= 18.0:
		var portrait_w := portrait.get_width() * (portrait_h / portrait.get_height())
		draw_texture_rect(portrait, Rect2(r.position.x, r.position.y + 2.0, portrait_w, portrait_h), false)
		var hx := r.position.x + portrait_w + 8.0
		draw_string(font, Vector2(hx, heading_y), s["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - (hx - r.position.x), 17,
			_house_color(s["house"]).lightened(0.25))
		draw_string(font, Vector2(hx, heading_y + 17), "%s · Lv %d · Mov %d" % [s["class"], s["level"], s["mov"]],
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - (hx - r.position.x), 13, Color(0.8, 0.82, 0.9))
	else:
		draw_string(font, Vector2(r.position.x, heading_y), s["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 17,
			_house_color(s["house"]).lightened(0.25))
		draw_string(font, Vector2(r.position.x, heading_y + 17), "%s · Lv %d · Mov %d" % [s["class"], s["level"], s["mov"]],
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x, 13, Color(0.8, 0.82, 0.9))
	var line_y := r.position.y + 60.0
	for i in range(start, end):
		draw_string(font, Vector2(r.position.x, line_y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 2.0, 14, Color(0.82, 0.84, 0.9))
		line_y += 18.0


func _roster_detail_page_size(body_height: float) -> int:
	# The title/portrait header and footer stay outside this measured text region,
	# so every visible line remains inside the book body even at 640×360.
	return maxi(1, int(floor((body_height - 68.0) / 18.0)))


func _roster_detail_lines(s: Dictionary, font: Font, width: float) -> Array[String]:
	var rows: Array[String] = []
	var house := (str(s["house"]).capitalize() + " House") if s["house"] != "" else "Protagonist"
	rows.append("House: " + house)
	rows.append("Stats")
	for i in range(0, STAT_KEYS.size(), 2):
		var next := i + 1
		rows.append("%s %s     %s %s" % [STAT_LABELS[i], s["stats"][STAT_KEYS[i]], STAT_LABELS[next], s["stats"][STAT_KEYS[next]]])
	rows.append("Carries")
	if s["items"].is_empty():
		rows.append("—")
	else:
		for item in s["items"]:
			rows.append(str(item))
	rows.append("Skills")
	if s["skills"].is_empty():
		rows.append("—")
	else:
		for skill in s["skills"]:
			rows.append(str(skill))
	var wrapped: Array[String] = []
	for row in rows:
		wrapped.append_array(_wrap_roster_line(row, font, width - 2.0, 14))
	return wrapped


func _wrap_roster_line(value: String, font: Font, width: float, font_size: int) -> Array[String]:
	var result: Array[String] = []
	var line := ""
	for word in value.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if not line.is_empty() and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			result.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		result.append(line)
	return result


func _draw_calendar(body: Rect2, font: Font) -> void:
	var events := Campaign.calendar()
	var heading := "Year One  ·  Week %d" % Campaign.week
	var heading_width := font.get_string_size(heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var legend_rect := _calendar_legend_rect(body, font, heading_width)
	draw_string(font, body.position + Vector2(0, 4), heading,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.86, 0.78, 0.45))
	draw_string(font, legend_rect.position + Vector2(0, 4), "Blue: selected   Gold: current",
		HORIZONTAL_ALIGNMENT_LEFT, legend_rect.size.x, 13, Color(0.72, 0.76, 0.88))
	var layout := _calendar_layout(body, font, events)
	for row: Dictionary in layout["rows"]:
		var e: CalendarEventDef = events[row["index"]]
		var rect: Rect2 = row["rect"]
		var selected: bool = row["index"] == _calendar_i
		var now := e.week == Campaign.week
		if selected:
			draw_rect(rect, Color(0.25, 0.42, 0.78, 0.48), true)
			draw_rect(rect, Color(0.55, 0.68, 1.0, 0.72), false, 1.0)
		if now:
			# Gold bar marks the saved current week independently of blue selection.
			draw_rect(Rect2(rect.position.x, rect.position.y + 3, 4, rect.size.y - 6),
				Color(0.96, 0.75, 0.27), true)
		var baseline_y: float = rect.position.y + 19
		draw_string(font, Vector2(row["week_x"], baseline_y), "Week %d" % e.week,
			HORIZONTAL_ALIGNMENT_LEFT, row["week_width"], 16,
			Color(0.98, 0.79, 0.34) if now else Color(0.7, 0.73, 0.82))
		var label_color := Color(0.98, 0.87, 0.62) if now else Color(0.82, 0.84, 0.9)
		draw_multiline_string(font, Vector2(row["label_x"], rect.position.y + 19), e.label,
			HORIZONTAL_ALIGNMENT_LEFT, row["label_width"], 16, -1, label_color)
		draw_string(font, Vector2(row["kind_x"], baseline_y), _kind_name(e.kind),
			HORIZONTAL_ALIGNMENT_RIGHT, row["kind_width"], 14, _kind_color(e.kind))
	if events.size() > layout["rows"].size():
		var first: int = layout["visible_indices"][0]
		var last: int = layout["visible_indices"][-1]
		var feedback := "↑/↓ browse   %d–%d of %d" % [first + 1, last + 1, events.size()]
		draw_string(font, Vector2(body.position.x, body.end.y - 2), feedback,
			HORIZONTAL_ALIGNMENT_RIGHT, body.size.x, 13, Color(0.72, 0.76, 0.88))


func _calendar_legend_rect(body: Rect2, font: Font, heading_width: float) -> Rect2:
	var legend_x := body.position.x + heading_width + 12.0
	return Rect2(legend_x, body.position.y, maxf(0.0, body.end.x - legend_x), 18.0)


func _calendar_current_index(events: Array = Campaign.calendar()) -> int:
	for i in range(events.size()):
		if events[i].week == Campaign.week:
			return i
	return 0 if not events.is_empty() else -1


func _body_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var margin := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var book := Rect2(margin, vp - margin * 2.0)
	var font := UITheme.font()
	var tab_rows := _tab_row_count(font, book.size.x - 68.0, 16)
	var tabs_height := 92.0 + (tab_rows - 1) * 22.0
	var body_top := tabs_height + 16.0
	return Rect2(book.position + Vector2(34, body_top),
		Vector2(book.size.x - 68.0, book.size.y - body_top - UITheme.DST_MARGIN - 9.0 - font.get_height(14)))


func _calendar_layout(body: Rect2, font: Font, events: Array = Campaign.calendar()) -> Dictionary:
	if events.is_empty():
		_calendar_i = -1
		_calendar_scroll = 0
		return {"rows": [], "visible_indices": [], "content_rect": Rect2()}
	_calendar_i = clampi(_calendar_i, 0, events.size() - 1)
	_calendar_scroll = clampi(_calendar_scroll, 0, events.size() - 1)
	var week_width := clampf(body.size.x * 0.20, 76.0, 96.0)
	var kind_width := clampf(body.size.x * 0.20, 82.0, 112.0)
	var week_x := body.position.x + 8.0
	var kind_x := body.end.x - kind_width - 4.0
	var label_x := week_x + week_width + 8.0
	var label_width := maxf(72.0, kind_x - label_x - 8.0)
	var content_rect := Rect2(body.position.x, body.position.y + 35.0,
		body.size.x, maxf(0.0, body.size.y - 58.0))
	var heights: Array[float] = []
	for e: CalendarEventDef in events:
		var measured := font.get_multiline_string_size(e.label, HORIZONTAL_ALIGNMENT_LEFT,
			label_width, 16, -1, TextServer.BREAK_WORD_BOUND).y
		heights.append(maxf(28.0, measured + 8.0))
	var start := _calendar_scroll
	var selected_visible := false
	while start < events.size():
		var used := 0.0
		var end_index := start
		while end_index < events.size() and used + heights[end_index] <= content_rect.size.y:
			used += heights[end_index]
			end_index += 1
		if end_index == start:
			end_index = start + 1
		selected_visible = _calendar_i >= start and _calendar_i < end_index
		if selected_visible:
			break
		start = _calendar_i
	# When a resize creates room, fill upward again while keeping the selected row
	# visible. Compact layouts therefore do not strand earlier rows after restore.
	var filled := 0.0
	var filled_end := start
	while filled_end < events.size() and filled + heights[filled_end] <= content_rect.size.y:
		filled += heights[filled_end]
		filled_end += 1
	while start > 0 and filled + heights[start - 1] <= content_rect.size.y:
		start -= 1
		filled += heights[start]
	_calendar_scroll = start
	var rows: Array[Dictionary] = []
	var visible: Array[int] = []
	var y := content_rect.position.y
	for i in range(start, events.size()):
		var h: float = heights[i]
		if not rows.is_empty() and y + h > content_rect.end.y:
			break
		var rect := Rect2(body.position.x, y, body.size.x, minf(h, content_rect.size.y))
		rows.append({"index": i, "rect": rect, "week_x": week_x, "week_width": week_width,
			"label_x": label_x, "label_width": label_width, "kind_x": kind_x, "kind_width": kind_width})
		visible.append(i)
		y += h
	return {"rows": rows, "visible_indices": visible, "content_rect": content_rect}


## AW-52: the Inventory HUB — left: students; right: the selected pack. Enter
## drills in (student → item → recipient), Esc backs out, moves persist.
func _draw_items(body: Rect2, font: Font) -> void:
	var layout := _items_layout(body, font)
	if _inv_units.is_empty():
		draw_string(font, layout["student_header"], "Students · none", HORIZONTAL_ALIGNMENT_LEFT,
			layout["student_rect"].size.x, 14, Color(0.86, 0.78, 0.45))
		draw_string(font, layout["pack_header"], "Pack", HORIZONTAL_ALIGNMENT_LEFT,
			layout["pack_rect"].size.x, 16, Color(0.86, 0.78, 0.45))
	else:
		var giver: Dictionary = _inv_units[_inv_i]
		var pane_title := "Giver: %s" % giver["name"] if _inv_mode == 2 else "Students"
		draw_string(font, layout["student_header"], pane_title, HORIZONTAL_ALIGNMENT_LEFT,
			layout["student_rect"].size.x, 14, Color(0.86, 0.78, 0.45))
		for row: Dictionary in layout["student_rows"]:
			var i: int = row["index"]
			var e: Dictionary = _inv_units[i]
			var is_src := i == _inv_i
			var is_tgt := _inv_mode == 2 and i == _inv_give_i
			if is_tgt:
				draw_rect(row["rect"], Color(0.86, 0.68, 0.25, 0.5), true)
			elif is_src:
				draw_rect(row["rect"], Color(0.30, 0.45, 0.85, 0.45), true)
			draw_rect(Rect2(row["rect"].position.x + 2, row["rect"].position.y + 2, 3,
				row["rect"].size.y - 4), _house_color(e["house"]), true)
			var name_color := Color(0.98, 0.92, 0.72) if is_tgt else (Color(0.95, 0.94, 0.88) if is_src else Color(0.78, 0.8, 0.86))
			draw_string(font, row["name_baseline"], str(e["name"]), HORIZONTAL_ALIGNMENT_LEFT,
				row["name_width"], 17, name_color)
			draw_string(font, row["count_baseline"], "%d/5" % e["unit"].inventory.items.size(),
				HORIZONTAL_ALIGNMENT_RIGHT, row["count_width"], 12, Color(0.62, 0.66, 0.76))
		var pack_label := "%s's pack" % giver["name"]
		if _inv_mode == 2:
			pack_label = "%s's pack · giver" % giver["name"]
		draw_string(font, layout["pack_header"], pack_label, HORIZONTAL_ALIGNMENT_LEFT,
			layout["pack_rect"].size.x, 16, _house_color(giver["house"]).lightened(0.25))
		var inv: Inventory = giver["unit"].inventory
		if inv.items.is_empty():
			draw_string(font, layout["pack_content_rect"].position + Vector2(0, font.get_ascent(14)),
				"— carrying nothing —", HORIZONTAL_ALIGNMENT_LEFT, layout["pack_content_rect"].size.x, 14,
				Color(0.6, 0.63, 0.72))
		for row: Dictionary in layout["pack_rows"]:
			var item: InventoryItem = inv.items[row["index"]]
			var selected: bool = _inv_mode >= 1 and row["index"] == _inv_item_i
			if selected:
				draw_rect(row["rect"], Color(0.86, 0.68, 0.25, 0.5) if _inv_mode == 2 else Color(0.30, 0.45, 0.85, 0.45), true)
			var marker := "› " if selected else "  "
			draw_multiline_string(font, row["label_baseline"], marker + "\n".join(row["lines"]),
				HORIZONTAL_ALIGNMENT_LEFT, row["label_width"], 16, MULTILINE_MAX_LINES,
				Color(0.95, 0.94, 0.88) if selected else Color(0.85, 0.86, 0.92))
			draw_string(font, row["uses_baseline"], row["uses"], HORIZONTAL_ALIGNMENT_RIGHT,
				row["uses_width"], 13, Color(0.62, 0.66, 0.76))
		if layout["pack_scrolls"]:
			var progress := "Items %d–%d/%d" % [layout["visible_items"][0] + 1,
				layout["visible_items"][-1] + 1, inv.items.size()]
			draw_string(font, layout["pack_progress_baseline"], progress, HORIZONTAL_ALIGNMENT_RIGHT,
				layout["pack_rect"].size.x, 11, Color(0.62, 0.66, 0.76))
	draw_multiline_string(font, layout["hint_baseline"], "\n".join(layout["hint_lines"]),
		HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 14, MULTILINE_MAX_LINES, Color(0.86, 0.78, 0.45, 0.95))


func _items_hint() -> String:
	match _inv_mode:
		0: return "Enter — open this student's pack"
		1: return "Enter — give this item to someone   ·   Esc — back"
		2: return "↑/↓ — choose who receives it   ·   Enter — hand it over   ·   Esc — back"
	return ""


## Active-font measurements shared by the Items renderer and its production-
## SubViewport regression. Lists window the existing selections when space is
## short; the selected row is kept in view through both directions of resize.
func _items_layout(body: Rect2, font: Font) -> Dictionary:
	var gap := 16.0
	var student_width := clampf(body.size.x * 0.38, 176.0, 250.0)
	student_width = minf(student_width, body.size.x * 0.48)
	var pack_width := maxf(96.0, body.size.x - student_width - gap)
	var student_rect := Rect2(body.position, Vector2(student_width, body.size.y))
	var pack_rect := Rect2(Vector2(body.position.x + student_width + gap, body.position.y),
		Vector2(pack_width, body.size.y))
	var hint_lines := _wrap_roster_line(_items_hint(), font, body.size.x, 14)
	var hint_height := maxf(font.get_height(14), float(hint_lines.size()) * font.get_height(14))
	var hint_rect := Rect2(Vector2(body.position.x, body.end.y - hint_height), Vector2(body.size.x, hint_height))
	var content_top := body.position.y + 24.0
	var content_bottom := hint_rect.position.y - 4.0
	var row_height := font.get_height(17) + 4.0
	var student_rows: Array[Dictionary] = []
	var visible_students: Array[int] = []
	var selected_student := _inv_give_i if _inv_mode == 2 else _inv_i
	if not _inv_units.is_empty():
		selected_student = clampi(selected_student, 0, _inv_units.size() - 1)
		_inv_i = clampi(_inv_i, 0, _inv_units.size() - 1)
		_inv_give_i = clampi(_inv_give_i, 0, _inv_units.size() - 1)
		var student_capacity := maxi(1, int(floor((content_bottom - content_top) / row_height)))
		_items_student_scroll = clampi(_items_student_scroll, 0, maxi(0, _inv_units.size() - student_capacity))
		if selected_student < _items_student_scroll:
			_items_student_scroll = selected_student
		elif selected_student >= _items_student_scroll + student_capacity:
			_items_student_scroll = selected_student - student_capacity + 1
		_items_student_scroll = clampi(_items_student_scroll, 0, maxi(0, _inv_units.size() - student_capacity))
		for i in range(_items_student_scroll, mini(_inv_units.size(), _items_student_scroll + student_capacity)):
			var row_rect := Rect2(Vector2(student_rect.position.x, content_top + (i - _items_student_scroll) * row_height),
				Vector2(student_rect.size.x, row_height))
			visible_students.append(i)
			student_rows.append({"index": i, "rect": row_rect,
				"name_baseline": row_rect.position + Vector2(10, font.get_ascent(17) + 2),
				"name_width": student_width - 56.0,
				"count_baseline": row_rect.position + Vector2(student_width - 46.0, font.get_ascent(12) + 4),
				"count_width": 42.0})
	var pack_header := Vector2(pack_rect.position.x, pack_rect.position.y + font.get_ascent(16))
	var inv: Inventory = null
	if not _inv_units.is_empty():
		inv = _inv_units[_inv_i]["unit"].inventory
	_inv_item_i = clampi(_inv_item_i, 0, maxi(0, inv.items.size() - 1)) if inv != null else 0
	var uses_width := 44.0
	var label_width := maxf(48.0, pack_width - uses_width - 12.0)
	var item_heights: Array[float] = []
	var item_lines: Array[Array] = []
	if inv != null:
		for item: InventoryItem in inv.items:
			var label := item.display_name()
			if item == inv.equipped_weapon_item():
				label += "   (equipped)"
			var lines := _wrap_roster_line(label, font, label_width - 18.0, 16)
			item_lines.append(lines)
			item_heights.append(maxf(font.get_height(16) + 4.0, lines.size() * font.get_height(16) + 3.0))
	var pack_content_top := content_top
	var pack_content_bottom := content_bottom - (font.get_height(11) + 2.0)
	var pack_content_rect := Rect2(pack_rect.position.x, pack_content_top, pack_width,
		maxf(0.0, pack_content_bottom - pack_content_top))
	var visible_items: Array[int] = []
	var pack_rows: Array[Dictionary] = []
	var pack_scrolls := false
	var used_height := 0.0
	if inv != null and not inv.items.is_empty():
		var selected_item := _inv_item_i if _inv_mode >= 1 else 0
		var start := clampi(_items_pack_scroll, 0, inv.items.size() - 1)
		if selected_item < start:
			start = selected_item
		used_height = 0.0
		for i in range(start, selected_item + 1):
			used_height += item_heights[i]
		while start < selected_item and used_height > pack_content_rect.size.y:
			used_height -= item_heights[start]
			start += 1
		while start > 0 and used_height + item_heights[start - 1] <= pack_content_rect.size.y:
			start -= 1
			used_height += item_heights[start]
		_items_pack_scroll = start
		var item_y := pack_content_rect.position.y
		for i in range(start, inv.items.size()):
			if not visible_items.is_empty() and item_y + item_heights[i] > pack_content_rect.end.y:
				break
			if visible_items.is_empty() and item_heights[i] > pack_content_rect.size.y:
				# A narrow label wraps to complete lines; permit the selected row to
				# use the content window and keep its text inside the book body.
				item_heights[i] = pack_content_rect.size.y
			var row_rect := Rect2(pack_content_rect.position.x, item_y, pack_width, item_heights[i])
			visible_items.append(i)
			pack_rows.append({"index": i, "rect": row_rect, "lines": item_lines[i],
				"label_width": label_width - 18.0,
				"label_baseline": row_rect.position + Vector2(18, font.get_ascent(16) + 1),
				"uses_width": uses_width,
				"uses": "∞" if inv.items[i].uses >= 999 else "×%d" % inv.items[i].uses,
				"uses_baseline": row_rect.position + Vector2(pack_width - uses_width - 4.0,
					font.get_ascent(13) + 3)})
			item_y += item_heights[i]
		pack_scrolls = start > 0 or visible_items.size() < inv.items.size()
	return {"student_rect": student_rect, "pack_rect": pack_rect,
		"student_header": Vector2(student_rect.position.x, student_rect.position.y + font.get_ascent(14)),
		"pack_header": pack_header, "student_rows": student_rows, "visible_students": visible_students,
		"pack_rows": pack_rows, "visible_items": visible_items, "pack_content_rect": pack_content_rect,
		"pack_scrolls": pack_scrolls,
		"pack_progress_baseline": Vector2(pack_rect.position.x, pack_header.y),
		"giver_name": str(_inv_units[_inv_i]["name"]) if not _inv_units.is_empty() else "",
		"hint_lines": hint_lines, "hint_rect": hint_rect,
		"hint_baseline": Vector2(body.position.x, hint_rect.position.y + font.get_ascent(14))}


func _inventory_toast_layout(font: Font) -> Dictionary:
	var vp := get_viewport_rect().size
	var margin := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var book := Rect2(margin, vp - margin * 2.0)
	var text_width := maxf(120.0, book.size.x - 64.0)
	var lines := _wrap_roster_line(_toast, font, text_width, 16)
	var text_height := maxf(font.get_height(16), lines.size() * font.get_height(16))
	var rect := Rect2(book.position.x + (book.size.x - text_width - 24.0) * 0.5,
		book.end.y - text_height - 42.0, text_width + 24.0, text_height + 18.0)
	return {"rect": rect, "lines": lines, "text_width": text_width,
		"baseline": Vector2(rect.position.x + 12.0, rect.position.y + 9.0 + font.get_ascent(16))}


## AW-54: the Grades tab (GRADING_SYSTEM.md §3) — the running grade, the four
## weighted marks as bars, and the "↑ how to raise it" hint per mark.
## Issue #108: the content is a list of measured items (every op carries its own
## active-font rect) so compact windows page through it instead of overflowing.
func _draw_grades(body: Rect2, font: Font) -> void:
	var g := Campaign.running_grade()
	var layout := _grades_layout(body, font, g)
	for op: Dictionary in layout["ops"]:
		var rect: Rect2 = op["rect"]
		if op["kind"] == "rect":
			draw_rect(rect, op["color"], true)
		else:
			draw_multiline_string(font, Vector2(rect.position.x, rect.position.y + font.get_ascent(op["size"])),
				op["text"], HORIZONTAL_ALIGNMENT_LEFT, op["wrap"], op["size"], -1, op["color"],
				TextServer.BREAK_WORD_BOUND)
	if layout["scrolls"]:
		var fb: Rect2 = layout["feedback_rect"]
		draw_string(font, Vector2(fb.position.x, fb.position.y + font.get_ascent(13)), layout["feedback"],
			HORIZONTAL_ALIGNMENT_RIGHT, fb.size.x, 13, Color(0.72, 0.76, 0.88))


func _grades_text(font: Font, text: String, size: int, color: Color, pos: Vector2, width := -1.0) -> Dictionary:
	var measured := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size, -1,
		TextServer.BREAK_WORD_BOUND)
	return {"kind": "text", "text": text, "size": size, "color": color, "wrap": width,
		"rect": Rect2(pos, Vector2(ceilf(measured.x), measured.y))}


## One grade item per block (header, standing, each mark, next card, each locked
## card). Ops are item-relative; _grades_layout offsets the visible ones.
func _grades_items(body: Rect2, font: Font, g: Dictionary) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var w := body.size.x
	var dim := Color(0.55, 0.58, 0.68)
	var rank_col := _rank_color(str(g["rank"]))
	# header: title + semester/week, stacked when they would collide
	var compact := body.size.y < 200.0
	var head := _grades_text(font, "ACADEMY STANDING", 18, Color(0.86, 0.78, 0.45), Vector2.ZERO)
	var sem := _grades_text(font, "Semester %d  ·  Week %d" % [Campaign.semester, Campaign.week],
		15, Color(0.62, 0.66, 0.76), Vector2.ZERO)
	var sem_rect: Rect2 = sem["rect"]
	var head_rect: Rect2 = head["rect"]
	if head_rect.size.x + 16.0 + sem_rect.size.x <= w:
		sem["rect"] = Rect2(Vector2(w - sem_rect.size.x, 2), sem_rect.size)
	else:
		sem["rect"] = Rect2(Vector2(0, head_rect.size.y + 2), sem_rect.size)
	items.append({"ops": [head, sem], "h": (sem["rect"] as Rect2).end.y + (6.0 if compact else 12.0)})
	# the running grade, big
	# Compact bodies shrink the rank glyph so the header and standing share a page.
	var big := _grades_text(font, str(g["rank"]), 40 if compact else 54, rank_col, Vector2.ZERO)
	var tx := maxf(44.0 if compact else 56.0, (big["rect"] as Rect2).size.x + 8.0)
	var score := _grades_text(font, "%d  ·  %s" % [int(g["score"]), str(g["rank_name"])], 20,
		Color(0.95, 0.94, 0.88), Vector2(tx, 6), w - tx)
	var meaning := _grades_text(font, "the grade if the semester ended today", 13, dim,
		Vector2(tx, (score["rect"] as Rect2).end.y + 4), w - tx)
	items.append({"ops": [big, score, meaning],
		"h": maxf((big["rect"] as Rect2).end.y, (meaning["rect"] as Rect2).end.y) + (4.0 if compact else 8.0)})
	# the four marks
	var order := ["coursework", "battlefield", "arena", "conduct"]
	var labels := {"coursework": "Coursework", "battlefield": "Battlefield", "arena": "The Arena", "conduct": "Conduct"}
	var marks: Dictionary = g["marks"]
	var hints: Dictionary = g["hints"]
	var wide := true
	var value_w := 0.0
	for k in order:
		var v: float = marks[k]
		var vt := ("%d" % roundi(v if v >= 0.0 else Grading.NEUTRAL)) + ("" if v >= 0.0 else " (no marks yet)")
		value_w = maxf(value_w, font.get_string_size(vt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
		if 510.0 + font.get_string_size("↑ " + str(hints[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > w \
				or 380.0 + value_w > 510.0:
			wide = false
	var bar_x := 180.0 if wide else 176.0
	var bar_w := 190.0 if wide else clampf(w - bar_x - value_w - 14.0, 48.0, 190.0)
	var value_x := bar_x + bar_w + 10.0
	for k in order:
		var v: float = marks[k]
		var has_data := v >= 0.0
		var shown := v if has_data else Grading.NEUTRAL
		var ops: Array = []
		var label := _grades_text(font, labels[k], 16, Color(0.9, 0.9, 0.95), Vector2.ZERO)
		var line_h: float = (label["rect"] as Rect2).size.y
		ops.append(label)
		ops.append(_grades_text(font, "%d%%" % roundi(Grading.WEIGHTS[k] * 100), 13, dim, Vector2(bar_x - 50.0, 2)))
		var bar := Rect2(bar_x, (line_h - 14.0) * 0.5, bar_w, 14.0)
		ops.append({"kind": "rect", "color": Color(0.2, 0.22, 0.3), "rect": bar})
		ops.append({"kind": "rect", "color": rank_col.darkened(0.1) if has_data else Color(0.45, 0.48, 0.58),
			"rect": Rect2(bar.position, Vector2(bar.size.x * shown / 100.0, bar.size.y))})
		ops.append(_grades_text(font, ("%d" % roundi(shown)) + ("" if has_data else " (no marks yet)"), 15,
			Color(0.96, 0.93, 0.82), Vector2(value_x, 0)))
		var hint_text := "↑ " + str(hints[k])
		var hint_op: Dictionary
		if wide:
			hint_op = _grades_text(font, hint_text, 14, Color(0.7, 0.9, 0.75), Vector2(510, 1), w - 510.0)
		else:
			hint_op = _grades_text(font, hint_text, 14, Color(0.7, 0.9, 0.75), Vector2(0, line_h + 2), w)
		ops.append(hint_op)
		items.append({"ops": ops, "h": maxf(40.0, (hint_op["rect"] as Rect2).end.y + 12.0)})
	var next_op := _grades_text(font, "→ Next report card: end of Semester %d (Week %d)" % [Campaign.semester, Campaign.semester_end_week()],
		14, Color(0.62, 0.66, 0.76), Vector2(0, 8), w)
	items.append({"ops": [next_op], "h": (next_op["rect"] as Rect2).end.y + 14.0})
	# locked history, oldest first as stored
	for rc in Campaign.report_cards:
		var card := _grades_text(font, "Semester %d — %s (%s, %d)" % [int(rc["semester"]), str(rc["rank"]), str(rc["rank_name"]), int(rc["score"])],
			15, _rank_color(str(rc["rank"])), Vector2(0, 6), w)
		items.append({"ops": [card], "h": maxf(28.0, (card["rect"] as Rect2).end.y + 8.0)})
	return items


## Measured, scroll-clamped Grades layout. `ops` are the absolute draw ops of the
## visible items; `_grades_scroll` is the first visible item and is clamped here
## so resizes and content changes never strand the view.
func _grades_layout(body: Rect2, font: Font, g: Dictionary = Campaign.running_grade()) -> Dictionary:
	var items := _grades_items(body, font, g)
	var total := 0.0
	for it in items:
		total += it["h"]
	var scrolls := total > body.size.y
	var avail := body.size.y - (20.0 if scrolls else 0.0)
	var max_start := 0
	if scrolls:
		var used := 0.0
		max_start = items.size()
		while max_start > 0 and used + items[max_start - 1]["h"] <= avail:
			max_start -= 1
			used += items[max_start]["h"]
		max_start = mini(max_start, items.size() - 1)
	_grades_scroll = clampi(_grades_scroll, 0, max_start)
	var ops: Array = []
	var visible: Array[int] = []
	var y := body.position.y
	for i in range(_grades_scroll, items.size()):
		var h: float = items[i]["h"]
		if not visible.is_empty() and y + h > body.position.y + avail:
			break
		for op: Dictionary in items[i]["ops"]:
			var placed: Dictionary = op.duplicate()
			placed["rect"] = Rect2((op["rect"] as Rect2).position + Vector2(body.position.x, y), (op["rect"] as Rect2).size)
			ops.append(placed)
		visible.append(i)
		y += h
	return {"items": items, "visible_indices": visible, "ops": ops, "scrolls": scrolls,
		"max_start": max_start, "content_bottom": y,
		"feedback": "↑/↓ browse   %d–%d of %d" % [visible[0] + 1, visible[-1] + 1, items.size()],
		"feedback_rect": Rect2(body.position.x, body.end.y - 16.0, body.size.x, 16.0)}


func _rank_color(rank: String) -> Color:
	match rank:
		"S": return Color(0.98, 0.85, 0.35)
		"A": return Color(0.55, 0.9, 0.6)
		"B": return Color(0.5, 0.75, 1.0)
		"C": return Color(0.85, 0.8, 0.6)
	return Color(0.9, 0.5, 0.4)


const SYS_FONT_SIZE := 14
const SYS_COL_GAP := 16.0
const SYS_PCT_SAMPLE := "100%"


## Issue #117: the text shown right of a System row's label (volume rows draw a
## bar plus a percentage instead, handled by the layout). "" for action rows.
func _system_data_text(kind: String) -> String:
	if kind.begins_with("save") or kind.begins_with("load"):
		return _slot_label(int(kind.substr(4)))
	if kind == "text_speed":
		return DialoguePreferences.label()
	if kind == "keyboard":
		return _keys_summary()
	return ""


func _system_volume(kind: String) -> float:
	return AudioManager.music_volume if kind == "music" else (AudioManager.sfx_volume if kind == "sfx" else AudioManager.master_volume)


func _system_wrap(text: String, font: Font, width: float) -> Array[String]:
	var lines: Array[String] = []
	var paragraph := TextParagraph.new()
	paragraph.width = maxf(1.0, width)
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, font, SYS_FONT_SIZE)
	for line in range(paragraph.get_line_count()):
		var span := paragraph.get_line_range(line)
		lines.append(text.substr(span.x, span.y - span.x).strip_edges())
	return lines


## Measured System layout: label column sized from the active font, data wrapped
## into the remaining width (rows grow taller instead of shrinking the font), and
## a scrolling window that always contains the selected row. Index/order of
## SYS_ROWS is untouched; every row is reachable with the existing Up/Down.
func _system_layout(body: Rect2, font: Font) -> Dictionary:
	var line_h := ceilf(font.get_height(SYS_FONT_SIZE))
	var pitch := line_h + 4.0
	var label_w := 0.0
	for row in SYS_ROWS:
		label_w = maxf(label_w, font.get_string_size(row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE).x)
	var pad := 6.0
	var rx := body.position.x + pad + label_w + SYS_COL_GAP
	var data_w := maxf(1.0, body.end.x - rx - pad)
	var pct_w := font.get_string_size(SYS_PCT_SAMPLE, HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE).x
	var bar_w := clampf(data_w - pct_w - 12.0, 24.0, 160.0)
	var heights: Array[float] = []
	var lines_by_row: Array = []
	for i in range(SYS_ROWS.size()):
		var kind: String = SYS_ROWS[i][1]
		var text := _system_data_text(kind)
		var lines: Array[String] = []
		if text != "":
			lines = _system_wrap(text, font, data_w)
		lines_by_row.append(lines)
		heights.append(maxi(1, lines.size()) * pitch)
	var total := 0.0
	for h in heights:
		total += h
	# Feedback gets its own reserved line at the bottom of the body (a System-local
	# slot, never the shared floating toast box), so a save/speed/load message can
	# never cover the row hint, footer or rows. The hint sits just above it.
	var toast_h := ceilf(font.get_height(SYS_FONT_SIZE)) + 6.0
	var hint_h := ceilf(font.get_height(12)) + 4.0
	var windowed := total + toast_h > body.size.y
	var avail := body.size.y - toast_h - (hint_h if windowed else 0.0)
	var toast_w := minf(body.size.x, font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE).x + 16.0)
	var toast_rect := Rect2(body.position.x, body.end.y - toast_h, toast_w, toast_h)
	var hint_rect := Rect2(body.position.x, toast_rect.position.y - hint_h, body.size.x, hint_h)
	_sys_i = clampi(_sys_i, 0, SYS_ROWS.size() - 1)
	_sys_scroll = clampi(_sys_scroll, 0, _sys_i)
	while _sys_scroll < _sys_i and _span_height(heights, _sys_scroll, _sys_i) > avail:
		_sys_scroll += 1
	while _sys_scroll > 0 and _span_height(heights, _sys_scroll - 1, SYS_ROWS.size() - 1) <= avail:
		_sys_scroll -= 1
	var rows: Array[Dictionary] = []
	var y := body.position.y
	for i in range(_sys_scroll, SYS_ROWS.size()):
		if not rows.is_empty() and y + heights[i] > body.position.y + avail + 0.01:
			break
		var kind: String = SYS_ROWS[i][1]
		var rect := Rect2(body.position.x, y, body.size.x, heights[i])
		var row := {
			"index": i, "kind": kind, "rect": rect,
			"label": SYS_ROWS[i][0],
			"label_rect": Rect2(body.position.x + pad, y + 2.0, font.get_string_size(SYS_ROWS[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE).x, line_h),
			"lines": lines_by_row[i], "line_rects": [],
		}
		for l in range(lines_by_row[i].size()):
			row.line_rects.append(Rect2(rx, y + 2.0 + l * pitch,
				font.get_string_size(lines_by_row[i][l], HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE).x, line_h))
		if kind in ["music", "sfx", "master"]:
			var v := _system_volume(kind)
			row["bar_rect"] = Rect2(rx, y + 2.0 + (line_h - 12.0) * 0.5, bar_w, 12.0)
			row["pct"] = "%d%%" % roundi(v * 100)
			row["pct_rect"] = Rect2(rx + bar_w + 12.0, y + 2.0,
				font.get_string_size(row["pct"], HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE).x, line_h)
			row["value"] = v
		rows.append(row)
		y += heights[i]
	return {"rows": rows, "windowed": windowed, "toast_rect": toast_rect, "hint_rect": hint_rect, "total": SYS_ROWS.size(), "pitch": pitch, "line_h": line_h}


func _span_height(heights: Array[float], from: int, to: int) -> float:
	var sum := 0.0
	for i in range(from, to + 1):
		sum += heights[i]
	return sum


func _draw_system(body: Rect2, font: Font) -> void:
	var layout := _system_layout(body, font)
	var rows: Array = layout["rows"]
	for row: Dictionary in rows:
		var sel: bool = row["index"] == _sys_i
		var rect: Rect2 = row["rect"]
		if sel:
			draw_rect(rect, Color(0.30, 0.45, 0.85, 0.45), true)
		var lr: Rect2 = row["label_rect"]
		draw_string(font, lr.position + Vector2(0, font.get_ascent(SYS_FONT_SIZE)), row["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE, Color(0.96, 0.94, 0.86) if sel else Color(0.78, 0.8, 0.86))
		var is_slot: bool = row["kind"].begins_with("save") or row["kind"].begins_with("load")
		for l in range(row["lines"].size()):
			var r: Rect2 = row["line_rects"][l]
			draw_string(font, r.position + Vector2(0, font.get_ascent(SYS_FONT_SIZE)), row["lines"][l],
				HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE,
				Color(0.62, 0.66, 0.76) if is_slot else Color(0.8, 0.82, 0.9))
		if row.has("bar_rect"):
			var bar: Rect2 = row["bar_rect"]
			draw_rect(bar, Color(0.2, 0.22, 0.3), true)
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(row["value"]), bar.size.y)), Color(0.5, 0.7, 1.0), true)
			var pr: Rect2 = row["pct_rect"]
			draw_string(font, pr.position + Vector2(0, font.get_ascent(SYS_FONT_SIZE)), row["pct"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, SYS_FONT_SIZE, Color(0.8, 0.82, 0.9))
	if layout["windowed"] and not rows.is_empty():
		var first: int = rows[0]["index"]
		var last: int = rows[rows.size() - 1]["index"]
		var hr: Rect2 = layout["hint_rect"]
		draw_string(font, Vector2(hr.position.x + 6.0, hr.end.y - font.get_descent(12) - 2.0),
			"↑/↓ more  ·  rows %d–%d / %d" % [first + 1, last + 1, SYS_ROWS.size()],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 0.66, 0.76))


func _keys_summary() -> String:
	var n := 0
	for action: String in KeyboardPreferences.ACTIONS:
		if KeyboardPreferences.extra_key(action) != KEY_NONE:
			n += 1
	return "Default keys" if n == 0 else "Default + %d additional" % n


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



## GH-106: only the current assignment. Routing is the War Room's existing
## registry lookup; unavailable metadata never claims a usable deployment.
func _objective_lines() -> Array[String]:
	var event := Campaign.current_event()
	var lines: Array[String] = []
	if event == null:
		return ["Week %d" % Campaign.week, "Current assignment unavailable.", "No mission this week."]
	lines.append("Week %d · %s" % [Campaign.week, event.label])
	if event.kind != CalendarEventDef.Kind.BATTLE:
		lines.append("No mission this week.")
		return lines
	var chapter := MissionReference.chapter_from_path(ChapterRegistry.scene_for(event.chapter_id, Campaign.house_id))
	if chapter == null or chapter.display_name.strip_edges().is_empty():
		lines.append("Mission details unavailable.")
		return lines
	lines.append(chapter.display_name)
	lines.append(MissionReference.objective_text(chapter))
	lines.append("Deploy from the War Room.")
	return lines


func _objectives_layout(body: Rect2, font: Font) -> Dictionary:
	var wrapped: Array[Dictionary] = []
	var sections := _objective_lines()
	for section in range(sections.size()):
		var text: String = sections[section]
		var paragraph := TextParagraph.new()
		paragraph.width = maxf(1.0, body.size.x)
		paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
		paragraph.add_string(text, font, 16)
		for line in range(paragraph.get_line_count()):
			var span := paragraph.get_line_range(line)
			wrapped.append({"text": text.substr(span.x, span.y - span.x).strip_edges(), "section": section})
	var pitch := ceilf(font.get_height(16)) + 6.0
	var capacity := maxi(1, floori(body.size.y / pitch))
	var scrolling := wrapped.size() > capacity
	if scrolling:
		capacity = maxi(1, floori((body.size.y - font.get_height(12) - 4.0) / pitch))
	_objectives_scroll = clampi(_objectives_scroll, 0, maxi(0, wrapped.size() - capacity))
	var rows: Array[Dictionary] = []
	for i in range(_objectives_scroll, mini(wrapped.size(), _objectives_scroll + capacity)):
		var row := wrapped[i].duplicate()
		row["index"] = i
		row["rect"] = Rect2(body.position + Vector2(0, (i - _objectives_scroll) * pitch),
			Vector2(body.size.x, font.get_height(16)))
		rows.append(row)
	return {"rows": rows, "total": wrapped.size(), "scrolling": scrolling}


func _draw_objectives(body: Rect2, font: Font) -> void:
	var layout := _objectives_layout(body, font)
	for row: Dictionary in layout.rows:
		var rect: Rect2 = row.rect
		draw_string(font, rect.position + Vector2(0, font.get_ascent(16)), row.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
			Color(0.86, 0.78, 0.45) if row.section == 0 else Color(0.90, 0.91, 0.95))
	if layout.scrolling:
		var progress := "↑/↓ scroll  ·  %d–%d / %d" % [_objectives_scroll + 1,
			_objectives_scroll + layout.rows.size(), layout.total]
		draw_string(font, Vector2(body.position.x, body.end.y - font.get_descent(12)), progress,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.62, 0.66, 0.76))



## Include ascent/descent, not just the baseline, when clearing the ornament.
func _heading_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var margin := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	return Rect2(margin + Vector2(34, UITheme.DST_MARGIN + 2),
		UITheme.font().get_string_size("Academy Journal", HORIZONTAL_ALIGNMENT_LEFT, -1, 26))


func _footer_rect(hint: String) -> Rect2:
	var vp := get_viewport_rect().size
	var margin := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var measured := UITheme.font().get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	return Rect2(Vector2(margin.x + 34, vp.y - margin.y - UITheme.DST_MARGIN - 3 - measured.y), measured)
