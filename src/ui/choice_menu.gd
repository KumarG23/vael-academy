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

# AW-56: the noble frame moved to the shared UITheme (one look for all panels).

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
	# AW-56: the shared noble frame (UITheme owns the look for every panel now).
	UITheme.draw_panel(self, rect)
	var font := UITheme.font()
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
