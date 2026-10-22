class_name ResultScreen
extends Control
## Full-screen Victory / Defeat overlay (§6). Presentation only; the battle scene
## shows it once the ObjectiveResolver returns a terminal outcome.

signal dismissed

var _text := ""
var _accent := Color.WHITE
var _shown := false
var _lines: Array = []  # AW-50: optional report lines under the title (the arena)


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


func _draw() -> void:
	if not _shown:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.06, 0.78), true)
	var band_h := 140.0 + _lines.size() * 34.0
	var y := vp.y * 0.5 - band_h * 0.5
	# AW-56: the band rides the noble frame, with the accent stripes kept
	UITheme.draw_panel(self, Rect2(vp.x * 0.08, y, vp.x * 0.84, band_h))
	draw_rect(Rect2(vp.x * 0.08 + 10, y + 6, vp.x * 0.84 - 20, 4), _accent, true)
	draw_rect(Rect2(vp.x * 0.08 + 10, y + band_h - 10, vp.x * 0.84 - 20, 4), _accent, true)
	var font := UITheme.font()
	var size := 64
	var ts := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var title_y := y + 96.0 if not _lines.is_empty() else y + band_h * 0.5 + ts.y * 0.3
	draw_string(font, Vector2(vp.x * 0.5 - ts.x * 0.5, title_y),
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _accent)
	# the report lines (arena trial card): first line brightest, the rest calmer
	var ly := title_y + 52.0
	for i in range(_lines.size()):
		var line := str(_lines[i])
		var lsize := 26 if i == 0 else 22
		var lcol := Color(0.95, 0.93, 0.82) if i == 0 else Color(0.78, 0.80, 0.86)
		if line.begins_with("★"):
			lcol = _accent  # the NEW BEST line burns in the accent colour
		var ls := font.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, -1, lsize)
		draw_string(font, Vector2(vp.x * 0.5 - ls.x * 0.5, ly),
			line, HORIZONTAL_ALIGNMENT_LEFT, -1, lsize, lcol)
		ly += 34.0
	var hint := "Press any key"
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	draw_string(font, Vector2(vp.x * 0.5 - hs.x * 0.5, y + band_h + 40),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.82, 0.88))
