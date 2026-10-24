class_name ResultScreen
extends Control
## Full-screen Victory / Defeat overlay (§6). Presentation only; the battle scene
## shows it once the ObjectiveResolver returns a terminal outcome.

signal dismissed

var _text := ""
var _accent := Color.WHITE
var _shown := false
var _lines: Array = []  # AW-50: optional report lines under the title (the arena)

const TITLE_SIZE := 64
const HINT_SIZE := 22
const HINT := "Press any key"
const SIDE_PAD := 40.0  # inner text margin inside the framed panel
const EDGE_PAD := 6.0   # minimum gap to the viewport edge
const MIN_PAD := 14.0   # tightest panel padding (the frame corners still clear)


func show_victory() -> void:
	_lines.clear()  # a normal battle never inherits an arena report card
	_show("Victory", Color(0.95, 0.82, 0.35))


func show_defeat() -> void:
	_lines.clear()  # a normal battle never inherits an arena report card
	_show("Defeat", Color(0.85, 0.28, 0.28))


## AW-50: a titled report card — the arena's "you made it this far" screen.
## `lines` render centred under the title.
func show_report(title: String, accent: Color, lines: Array) -> void:
	# Own the report so caller edits and later battle results cannot mutate
	# each other's lines. This overlay only presents the supplied report.
	_lines = lines.duplicate()
	_show(title, accent)


func is_shown() -> bool:
	return _shown


func _ready() -> void:
	# A click-to-dismiss overlay has to claim the pointer; with the default FILTER
	# the click can fall through to the map behind it and never reach _gui_input.
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)
	if _shown:
		_fit_to_viewport()


## Anchors alone leave a zero-size rect when the parent is a bare Viewport (the
## battle's CanvasLayer, a SubViewport), so a real click never lands on the
## overlay. Pin to the top-left and size it to the viewport explicitly.
func _fit_to_viewport() -> void:
	if not _shown or not is_inside_tree():
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	queue_redraw()  # the layout depends on the viewport; reflow on resize


func _show(text: String, accent: Color) -> void:
	_text = text
	_accent = accent
	_shown = true
	visible = true
	_fit_to_viewport()
	queue_redraw()


## Single dismissal path: hide the overlay and report once. Leaving it visible
## would keep the (now dead) overlay over the scene and let a second input emit
## `dismissed` again.
func _dismiss() -> void:
	if not _shown:
		return
	_shown = false
	visible = false
	queue_redraw()
	dismissed.emit()


func _gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_dismiss()


## Keys arrive here — _gui_input only sees them when focused, and nothing focuses
## this overlay ("press ANY key" must actually work from the keyboard, WO-4.1 fix).
func _unhandled_key_input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		_dismiss()


## Presentation layout for the current report, from the active font. Full strings
## wrap on word boundaries to the panel's inner width; when the stack is taller
## than the viewport the spacing tightens (fonts never shrink). Returns
## {panel, rows:[{text,size,kind,pos(baseline),rect}], hint:{text,size,pos,rect}, stripes}.
func compute_layout(vp: Vector2) -> Dictionary:
	var font := UITheme.font()
	var panel_w := vp.x * 0.84
	var inner_w := panel_w - 2.0 * SIDE_PAD
	var rows: Array = []  # {text, size, kind}
	for t in _wrap(_text, TITLE_SIZE, inner_w, font):
		rows.append({"text": t, "size": TITLE_SIZE, "kind": "title"})
	for i in range(_lines.size()):
		var line := str(_lines[i])
		var lsize := 26 if i == 0 else 22
		var kind := "first" if i == 0 else ("best" if line.begins_with("★") else "line")
		for t in _wrap(line, lsize, inner_w, font):
			rows.append({"text": t, "size": lsize, "kind": kind})
	var hint_h := font.get_height(HINT_SIZE)
	# default spacing reproduces the original band (140 + 34 per report line);
	# `k` < 1 tightens it only when the viewport cannot hold the default.
	var k := 1.0
	var out := {}
	for _pass in range(2):
		out = _stack(vp, font, rows, k, hint_h, panel_w)
		if out["bottom"] <= vp.y - EDGE_PAD or k <= 0.0:
			break
		k = 0.0  # tightest spacing: glyph-height steps and minimal padding
	return out


func _stack(vp: Vector2, font: Font, rows: Array, k: float, hint_h: float, panel_w: float) -> Dictionary:
	var pad_top := lerpf(MIN_PAD, 22.0, k)
	var pad_bot := lerpf(MIN_PAD, 22.0, k)
	var cursor := pad_top
	var placed: Array = []
	var prev_kind := ""
	for r in rows:
		var size: int = r["size"]
		var h := font.get_height(size)
		if r["kind"] != "title" and prev_kind == "title":
			cursor += lerpf(2.0, 14.0, k)
		placed.append({"text": r["text"], "size": size, "kind": r["kind"], "top": cursor, "h": h, "asc": font.get_ascent(size)})
		cursor += h + (lerpf(2.0, 12.0, k) if r["kind"] != "title" else lerpf(0.0, 4.0, k))
		prev_kind = r["kind"]
	var band_h := cursor + pad_bot
	var hint_gap := lerpf(6.0, 14.0, k)
	var total_h := band_h + hint_gap + hint_h
	# the band stays centred as before; the hint below it must also fit
	var y := vp.y * 0.5 - band_h * 0.5
	y = maxf(EDGE_PAD, minf(y, vp.y - EDGE_PAD - total_h))
	var px := vp.x * 0.08
	var rect_rows: Array = []
	for r in placed:
		var w := font.get_string_size(r["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, r["size"]).x
		var x := vp.x * 0.5 - w * 0.5
		var base := y + float(r["top"]) + float(r["asc"])
		r["pos"] = Vector2(x, base)
		r["rect"] = Rect2(x, y + float(r["top"]), w, r["h"])
		rect_rows.append(r)
	var hw := font.get_string_size(HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_SIZE).x
	var hy := y + band_h + hint_gap
	return {
		"panel": Rect2(px, y, panel_w, band_h),
		"rows": rect_rows,
		"hint": {"text": HINT, "size": HINT_SIZE, "pos": Vector2(vp.x * 0.5 - hw * 0.5, hy + font.get_ascent(HINT_SIZE)),
			"rect": Rect2(vp.x * 0.5 - hw * 0.5, hy, hw, hint_h)},
		"bottom": hy + hint_h,
	}


## Greedy word wrap with the real font metrics; a single word wider than the
## width is split by character so nothing is ever cut or elided.
static func _wrap(text: String, size: int, width: float, font: Font) -> Array:
	var out: Array = []
	var cur := ""
	for word in text.split(" ", true):
		var trial := word if cur.is_empty() else cur + " " + word
		if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			cur = trial
			continue
		if not cur.is_empty():
			out.append(cur)
			cur = ""
		while font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and word.length() > 1:
			var n := 1
			while n < word.length() and font.get_string_size(word.substr(0, n + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
				n += 1
			out.append(word.substr(0, n))
			word = word.substr(n)
		cur = word
	if not cur.is_empty() or out.is_empty():
		out.append(cur)
	return out


func _draw() -> void:
	if not _shown:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.06, 0.78), true)
	var lay := compute_layout(vp)
	var panel: Rect2 = lay["panel"]
	# AW-56: the band rides the noble frame, with the accent stripes kept
	UITheme.draw_panel(self, panel)
	draw_rect(Rect2(panel.position.x + 10, panel.position.y + 6, panel.size.x - 20, 4), _accent, true)
	draw_rect(Rect2(panel.position.x + 10, panel.end.y - 10, panel.size.x - 20, 4), _accent, true)
	var font := UITheme.font()
	for r in lay["rows"]:
		var col := _accent
		match r["kind"]:
			"first": col = Color(0.95, 0.93, 0.82)
			"line": col = Color(0.78, 0.80, 0.86)
		draw_string(font, r["pos"], r["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, r["size"], col)
	var h: Dictionary = lay["hint"]
	draw_string(font, h["pos"], h["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, h["size"], Color(0.8, 0.82, 0.88))
