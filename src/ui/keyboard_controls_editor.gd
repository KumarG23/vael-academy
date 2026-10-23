class_name KeyboardControlsEditor
extends Control
## Issue #89: Journal → System → Keyboard Controls. Shows the shipped keys for
## the six core actions (always active) beside one optional additional key each.
## Enter on a row captures a fresh key press; Esc cancels the capture. Modal:
## while open it consumes every key event, so neither a capture nor its
## echo/release can reach the Journal or the castle underneath.

signal closed

const ROWS_AFTER_ACTIONS := ["restore", "back"]

var _row := 0
var _col := 0              # action rows: 0 = Change, 1 = Clear
var _capturing := ""       # action waiting for a key, or ""
var _swallow := KEY_NONE   # a just-captured key: its echo/release stay here
var _status := ""
var _status_error := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_status = "Default keys always work. Add one extra key per action."
	queue_redraw()


func is_capturing() -> bool:
	return _capturing != ""


func _row_count() -> int:
	return KeyboardPreferences.ACTIONS.size() + ROWS_AFTER_ACTIONS.size()


func _row_kind(row: int) -> String:
	if row < KeyboardPreferences.ACTIONS.size():
		return KeyboardPreferences.ACTIONS[row]
	return ROWS_AFTER_ACTIONS[row - KeyboardPreferences.ACTIONS.size()]


# --- input -------------------------------------------------------------------

## _input (not _unhandled_input) so the capture is consumed before any GUI,
## Journal or castle handler can interpret the same event.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		return
	if event is InputEventKey and _swallow != KEY_NONE and _key_of(event) == _swallow:
		_handled()
		if not event.pressed:
			_swallow = KEY_NONE
		return
	if _capturing != "":
		_capture(event)
		return
	if not (event is InputEventKey):
		return  # mouse wheel/clicks have no meaning here; let the book ignore them
	_handled()
	if event.is_action_pressed("cursor_cancel"):
		AudioManager.play_sfx("cancel")
		_close()
	elif event.is_action_pressed("cursor_up"):
		_move(-1)
	elif event.is_action_pressed("cursor_down"):
		_move(1)
	elif event.is_action_pressed("cursor_left") or event.is_action_pressed("cursor_right"):
		if _row < KeyboardPreferences.ACTIONS.size():
			_col = 1 - _col
			AudioManager.play_sfx("cursor")
			queue_redraw()
	elif event.is_action_pressed("cursor_confirm"):
		_activate()
	elif event.pressed and not event.echo and event.keycode == KEY_DELETE \
			and _row < KeyboardPreferences.ACTIONS.size():
		_clear(_row_kind(_row))


func _capture(event: InputEvent) -> void:
	_handled()  # consume BEFORE applying: the press can never act elsewhere
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return  # only a fresh press counts (e.g. Enter's own release/echo)
		if _key_of(event) == KEY_ESCAPE:
			AudioManager.play_sfx("cancel")
			_set_status("Cancelled — %s unchanged." % KeyboardPreferences.LABELS[_capturing], false)
			_capturing = ""
			_swallow = KEY_ESCAPE
			return
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		if not event.pressed:
			return
	else:
		return
	var action := _capturing
	var why := KeyboardPreferences.assign(action, event)
	if why != "":
		AudioManager.play_sfx("cancel")
		_set_status("%s Press another key, or Esc to cancel." % why, true)
		return
	_capturing = ""
	_swallow = _key_of(event)
	AudioManager.play_sfx("confirm")
	var msg := "%s now also uses %s." % [KeyboardPreferences.LABELS[action], KeyboardPreferences.extra_label(action)]
	_set_status(msg + _write_note(), KeyboardPreferences.last_write_error != OK)


func _activate() -> void:
	var kind := _row_kind(_row)
	match kind:
		"restore":
			var err := KeyboardPreferences.restore_defaults()
			AudioManager.play_sfx("confirm")
			_set_status("Additional keys removed. Default keys unchanged." + _write_note(), err != OK)
		"back":
			AudioManager.play_sfx("cancel")
			_close()
		_:
			if _col == 1:
				_clear(kind)
			else:
				AudioManager.play_sfx("confirm")
				_capturing = kind
				_set_status("Press a key for %s… (Esc cancels)" % KeyboardPreferences.LABELS[kind], false)


func _clear(action: String) -> void:
	if KeyboardPreferences.extra_key(action) == KEY_NONE:
		_set_status("%s has no additional key." % KeyboardPreferences.LABELS[action], false)
		return
	var err := KeyboardPreferences.clear(action)
	AudioManager.play_sfx("cancel")
	_set_status("%s additional key removed." % KeyboardPreferences.LABELS[action] + _write_note(), err != OK)


func _write_note() -> String:
	var err := KeyboardPreferences.last_write_error
	if err == OK:
		return ""
	return " Not saved (%s) — applies this session only." % error_string(err)


func _move(dir: int) -> void:
	_row = wrapi(_row + dir, 0, _row_count())
	if _row >= KeyboardPreferences.ACTIONS.size():
		_col = 0
	AudioManager.play_sfx("cursor")
	queue_redraw()


func _set_status(msg: String, error: bool) -> void:
	_status = msg
	_status_error = error
	queue_redraw()


func _close() -> void:
	visible = false
	closed.emit()
	queue_free()


func _handled() -> void:
	get_viewport().set_input_as_handled()


static func _key_of(event: InputEventKey) -> Key:
	return event.keycode if event.keycode != KEY_NONE else event.physical_keycode


# --- drawing -----------------------------------------------------------------

## Geometry for a viewport size; drawing and the layout-fit tests share it.
func layout(vp: Vector2) -> Dictionary:
	var m := Vector2(minf(80, vp.x * 0.08), minf(56, vp.y * 0.08))
	var book := Rect2(m, vp - m * 2.0)
	var compact := vp.x < 1000.0 or vp.y < 600.0
	var x := book.position.x + (22.0 if compact else 34.0)
	var width := book.size.x - (44.0 if compact else 68.0)
	var title_y := book.position.y + (30.0 if compact else 46.0)
	var note_y := title_y + (20.0 if compact else 28.0)
	var header_y := note_y + (22.0 if compact else 30.0)
	var rows_top := header_y + 4.0
	var footer_h := 30.0 if compact else 40.0
	var status_h := 40.0 if compact else 46.0
	var status_top := book.end.y - footer_h - status_h
	var pitch := clampf((status_top - rows_top) / _row_count(), 16.0, 36.0)
	return {
		"book": book, "compact": compact, "x": x, "width": width, "title_y": title_y,
		"note_y": note_y, "header_y": header_y, "rows_top": rows_top, "pitch": pitch,
		"rows_bottom": rows_top + pitch * _row_count(), "status_top": status_top,
		# Centered between the frame's bottom corner ornaments (QA: a left-aligned
		# hint ran under the bottom-left filigree).
		"footer_y": book.end.y - (20.0 if compact else 26.0),
		"fs": 12 if compact else 16, "small": 11 if compact else 14,
	}


func _draw() -> void:
	var g := layout(get_viewport_rect().size)
	var book: Rect2 = g["book"]
	# Opaque: the Journal page underneath must not show through this page.
	UITheme.draw_panel(self, book, Color(0.11, 0.12, 0.17, 1.0))
	var font := UITheme.font()
	var fs: int = g["fs"]
	var small: int = g["small"]
	var x: float = g["x"]
	var width: float = g["width"]
	draw_string(font, Vector2(x, g["title_y"]), "Keyboard Controls", HORIZONTAL_ALIGNMENT_LEFT, -1,
		20 if g["compact"] else 26, Color(0.86, 0.78, 0.45))
	draw_string(font, Vector2(x, g["note_y"]), "Default keys always work. Other shortcuts are not changed here.",
		HORIZONTAL_ALIGNMENT_LEFT, width, small, Color(0.62, 0.65, 0.74))
	# columns: action · default keys · additional key · buttons
	var c_def := x + width * 0.17
	var c_add := x + width * 0.47
	var c_btn := x + width * 0.70
	for col in [[x, "Action"], [c_def, "Default keys"], [c_add, "Additional key"]]:
		draw_string(font, Vector2(col[0] + 6, g["header_y"]), col[1], HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(0.55, 0.58, 0.68))
	var y: float = g["rows_top"]
	var pitch: float = g["pitch"]
	for i in range(_row_count()):
		var kind := _row_kind(i)
		var top := y + pitch * i
		var base := top + pitch * 0.5 + fs * 0.35
		var sel := i == _row
		if sel:
			draw_rect(Rect2(x - 4, top + 2, width + 8, pitch - 4), Color(0.30, 0.45, 0.85, 0.40), true)
		var text_col := Color(0.96, 0.94, 0.86) if sel else Color(0.78, 0.8, 0.86)
		if i < KeyboardPreferences.ACTIONS.size():
			draw_string(font, Vector2(x + 6, base), KeyboardPreferences.LABELS[kind],
				HORIZONTAL_ALIGNMENT_LEFT, c_def - x - 8, fs, text_col)
			draw_string(font, Vector2(c_def + 6, base), KeyboardPreferences.default_label(kind),
				HORIZONTAL_ALIGNMENT_LEFT, c_add - c_def - 10, fs, Color(0.62, 0.66, 0.76))
			var extra := "Press a key…" if _capturing == kind else KeyboardPreferences.extra_label(kind)
			var extra_col := Color(1.0, 0.86, 0.45) if _capturing == kind \
				else (Color(0.6, 0.85, 1.0) if KeyboardPreferences.extra_key(kind) != KEY_NONE else Color(0.5, 0.52, 0.6))
			draw_string(font, Vector2(c_add + 6, base), extra, HORIZONTAL_ALIGNMENT_LEFT, c_btn - c_add - 10, fs, extra_col)
			var bw := (x + width - c_btn) * 0.5 - 6.0
			for b in range(2):
				var r := Rect2(c_btn + b * (bw + 8.0), top + 4, bw, pitch - 8)
				var on := sel and _col == b
				draw_rect(r, Color(0.86, 0.78, 0.45, 0.85) if on else Color(0.2, 0.22, 0.3, 0.9), true)
				draw_string(font, Vector2(r.position.x, base), ["Change", "Clear"][b],
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, small, Color(0.1, 0.1, 0.14) if on else text_col)
		else:
			var label := "Restore Defaults (remove additional keys)" if kind == "restore" else "Back to System"
			draw_string(font, Vector2(x + 6, base), label, HORIZONTAL_ALIGNMENT_LEFT, width - 12, fs, text_col)
	# feedback line (wraps to two lines in compact windows)
	var sy: float = g["status_top"] + 4.0
	var status_col := Color(1.0, 0.62, 0.5) if _status_error else Color(0.95, 0.9, 0.7)
	draw_multiline_string(font, Vector2(x, sy + small), _status, HORIZONTAL_ALIGNMENT_LEFT, width, small, 2, status_col)
	var hint := "↑/↓ choose   ←/→ Change/Clear   Enter select   Del clear   Esc back"
	draw_string(font, Vector2(x, g["footer_y"]), hint, HORIZONTAL_ALIGNMENT_CENTER, width, small,
		Color(0.55, 0.58, 0.68))
