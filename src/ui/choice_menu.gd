class_name ChoiceMenu
extends Control
## A small keyboard-driven vertical menu used for the unit command menu and its
## submenus (item / equip / trade). Emits `chosen(index)` or `cancelled`. Purely
## presentational + input; the battle scene decides what each option does.

signal chosen(index: int)
signal cancelled

const ROW_H := 34.0
const PAD := 30.0  # AW-37: a hair more so text clears the gold frame's inner edge
const WIDTH := 240.0
const MAX_WIDTH := 460.0

## AW-32: the noble gold-filigree pixel panel, drawn as a 9-slice behind the
## menu. SRC_MARGIN is the ornate corner size in the source art; DST_MARGIN is
## how big it's drawn (smaller, so the flourish suits a compact menu).
const PANEL_PATH := "res://assets/art/ui/panel_noble.png"
const SRC_MARGIN := 58.0   # the crisp 256px frame's ornate corner size
const DST_MARGIN := 22.0
## The transparent-interior frame is filled with this behind the gold.
const PANEL_FILL := Color(0.11, 0.12, 0.17, 0.96)
static var _panel: Texture2D
static var _panel_loaded := false

var _title := ""
var _options: Array = []
var _index := 0
## Computed per open() so long labels never clip (WO-4.4).
var _width := WIDTH
## House-themed border/title accent (§4). Defaults to the original gold.
var accent := Color(0.85, 0.78, 0.45)


func _ready() -> void:
	visible = false
	texture_filter = TEXTURE_FILTER_NEAREST
	if not _panel_loaded:
		_panel_loaded = true
		_panel = load(PANEL_PATH) if ResourceLoader.exists(PANEL_PATH) else null


func open(title: String, options: Array, top_left: Vector2) -> void:
	_title = title
	_options = options
	_index = 0
	_width = _fit_width()
	position = top_left
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


## Widest label (title at 18px, rows at 20px) plus padding, clamped sane.
func _fit_width() -> float:
	var font := ThemeDB.fallback_font
	var w := WIDTH
	if _title != "":
		w = maxf(w, font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + PAD * 2 + 8)
	for opt in _options:
		w = maxf(w, font.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + PAD * 2 + 20)
	return minf(w, MAX_WIDTH)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _options.is_empty():
		return
	if event.is_action_pressed("cursor_up"):
		_index = (_index - 1 + _options.size()) % _options.size()
		AudioManager.play_sfx("cursor")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cursor_down"):
		_index = (_index + 1) % _options.size()
		AudioManager.play_sfx("cursor")
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cursor_confirm"):
		AudioManager.play_sfx("confirm")
		get_viewport().set_input_as_handled()
		chosen.emit(_index)
	elif event.is_action_pressed("cursor_cancel"):
		AudioManager.play_sfx("cancel")
		get_viewport().set_input_as_handled()
		cancelled.emit()


func _draw() -> void:
	var h := PAD * 2 + ROW_H * (_options.size() + (1 if _title != "" else 0))
	var rect := Rect2(Vector2.ZERO, Vector2(_width, h))
	# AW-32: the pixel-art noble frame when its art is present; otherwise the
	# original flat panel (convention: code never blocks on missing art).
	if _panel != null:
		# navy fill behind the transparent-interior gold frame (inset so its
		# square corners hide under the frame's rounded filigree)
		draw_rect(rect.grow(-8.0), PANEL_FILL, true)
		_draw_nine_patch(_panel, rect)
	else:
		draw_rect(rect, Color(0.08, 0.09, 0.13, 0.95), true)
		draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.9), false, 2.0)
	var font := ThemeDB.fallback_font
	var y := PAD + 22.0
	if _title != "":
		draw_string(font, Vector2(PAD, y), _title, HORIZONTAL_ALIGNMENT_LEFT, _width - PAD * 2, 18, accent)
		y += ROW_H
	for i in range(_options.size()):
		if i == _index:
			draw_rect(Rect2(20, y - 22, _width - 40, ROW_H - 4), Color(0.30, 0.45, 0.85, 0.55), true)
		draw_string(font, Vector2(PAD + 6, y), str(_options[i]), HORIZONTAL_ALIGNMENT_LEFT,
			_width - PAD * 2, 20, Color.WHITE)
		y += ROW_H


## Draw `tex` as a 9-slice filling `dest`: the four ornate corners stay a fixed
## size (SRC→DST margin), the edges and centre stretch to fill. Keeps the gold
## filigree crisp at any menu size.
func _draw_nine_patch(tex: Texture2D, dest: Rect2) -> void:
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sm := SRC_MARGIN
	# never let the corners overrun a small panel
	var dm := minf(DST_MARGIN, minf(dest.size.x, dest.size.y) * 0.5)
	var sx := [0.0, sm, tw - sm, tw]
	var sy := [0.0, sm, th - sm, th]
	var dx := [dest.position.x, dest.position.x + dm, dest.position.x + dest.size.x - dm, dest.position.x + dest.size.x]
	var dy := [dest.position.y, dest.position.y + dm, dest.position.y + dest.size.y - dm, dest.position.y + dest.size.y]
	for r in range(3):
		for c in range(3):
			var src := Rect2(sx[c], sy[r], sx[c + 1] - sx[c], sy[r + 1] - sy[r])
			var dst := Rect2(dx[c], dy[r], dx[c + 1] - dx[c], dy[r + 1] - dy[r])
			if dst.size.x > 0.0 and dst.size.y > 0.0:
				draw_texture_rect_region(tex, dst, src)
