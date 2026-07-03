class_name ChoiceMenu
extends Control
## A small keyboard-driven vertical menu used for the unit command menu and its
## submenus (item / equip / trade). Emits `chosen(index)` or `cancelled`. Purely
## presentational + input; the battle scene decides what each option does.

signal chosen(index: int)
signal cancelled

const ROW_H := 34.0
const PAD := 14.0
const WIDTH := 240.0

var _title := ""
var _options: Array = []
var _index := 0
## House-themed border/title accent (§4). Defaults to the original gold.
var accent := Color(0.85, 0.78, 0.45)


func _ready() -> void:
	visible = false


func open(title: String, options: Array, top_left: Vector2) -> void:
	_title = title
	_options = options
	_index = 0
	position = top_left
	visible = true
	queue_redraw()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _options.is_empty():
		return
	if event.is_action_pressed("cursor_up"):
		_index = (_index - 1 + _options.size()) % _options.size()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cursor_down"):
		_index = (_index + 1) % _options.size()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cursor_confirm"):
		get_viewport().set_input_as_handled()
		chosen.emit(_index)
	elif event.is_action_pressed("cursor_cancel"):
		get_viewport().set_input_as_handled()
		cancelled.emit()


func _draw() -> void:
	var h := PAD * 2 + ROW_H * (_options.size() + (1 if _title != "" else 0))
	var rect := Rect2(Vector2.ZERO, Vector2(WIDTH, h))
	draw_rect(rect, Color(0.08, 0.09, 0.13, 0.95), true)
	draw_rect(rect, Color(accent.r, accent.g, accent.b, 0.9), false, 2.0)
	var font := ThemeDB.fallback_font
	var y := PAD + 22.0
	if _title != "":
		draw_string(font, Vector2(PAD, y), _title, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - PAD * 2, 18, accent)
		y += ROW_H
	for i in range(_options.size()):
		if i == _index:
			draw_rect(Rect2(6, y - 22, WIDTH - 12, ROW_H - 4), Color(0.30, 0.45, 0.85, 0.55), true)
		draw_string(font, Vector2(PAD + 6, y), str(_options[i]), HORIZONTAL_ALIGNMENT_LEFT,
			WIDTH - PAD * 2, 20, Color.WHITE)
		y += ROW_H
