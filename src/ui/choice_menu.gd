class_name ChoiceMenu
extends Control
## A small keyboard- and mouse-driven vertical menu used for the unit command menu and its
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
var _first_visible := 0
var _visible_rows := 0
## Computed per open() so long labels never clip (WO-4.4).
var _width := WIDTH
## House-themed border/title accent (§4). Defaults to the original gold.
var accent := Color(0.85, 0.78, 0.45)


func _ready() -> void:
	visible = false
	texture_filter = TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(_layout_panel)


func open(title: String, options: Array, top_left: Vector2) -> void:
	_title = title
	_options = options
	_index = 0
	_first_visible = 0
	_width = _fit_width()
	position = top_left
	visible = true
	_layout_panel()


func close() -> void:
	visible = false


func _panel_height() -> float:
	return PAD * 2 + ROW_H * (_visible_rows + (1 if _title != "" else 0))


func _layout_panel() -> void:
	if not visible:
		return
	var viewport_height := get_viewport_rect().size.y
	var header_height := PAD * 2 + (ROW_H if _title != "" else 0.0)
	var capacity := maxi(1, int((viewport_height - header_height) / ROW_H))
	_visible_rows = mini(_options.size(), capacity)
	_keep_selection_visible()
	# Match the clickable rect to the drawn panel and keep its rows on screen.
	size = Vector2(_width, _panel_height())
	position.y = clampf(position.y, 0.0, maxf(0.0, viewport_height - size.y))
	queue_redraw()


func _keep_selection_visible() -> void:
	if _index < _first_visible:
		_first_visible = _index
	elif _index >= _first_visible + _visible_rows:
		_first_visible = _index - _visible_rows + 1
	_first_visible = clampi(_first_visible, 0, maxi(0, _options.size() - _visible_rows))


func _move_selection(direction: int) -> void:
	_index = (_index + direction + _options.size()) % _options.size()
	_keep_selection_visible()
	AudioManager.play_sfx("cursor")
	queue_redraw()


## Option row under a local point, or -1 (title, padding or outside the rows).
func row_at(local: Vector2) -> int:
	if local.x < 20.0 or local.x > _width - 20.0:
		return -1
	var top := PAD + (ROW_H if _title != "" else 0.0)
	if local.y < top:
		return -1
	var row := int((local.y - top) / ROW_H)
	return _first_visible + row if row < _visible_rows else -1


## Widest label (title at 18px, rows at 20px) plus padding, clamped sane.
## Measured with the same font _draw uses, so a pixel face never clips.
func _fit_width() -> float:
	var font := UITheme.font()
	var w := WIDTH
	if _title != "":
		w = maxf(w, font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + PAD * 2 + 8)
	for opt in _options:
		w = maxf(w, font.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + PAD * 2 + 20)
	return minf(w, MAX_WIDTH)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Cancellation must remain available even when there are no choices.
	if event.is_action_pressed("cursor_cancel"):
		AudioManager.play_sfx("cancel")
		get_viewport().set_input_as_handled()
		cancelled.emit()
		return
	if _options.is_empty():
		return
	if event.is_action_pressed("cursor_up"):
		_move_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cursor_down"):
		_move_selection(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cursor_confirm"):
		AudioManager.play_sfx("confirm")
		get_viewport().set_input_as_handled()
		chosen.emit(_index)


## Mouse: hover highlights, wheel navigates, left-click chooses, right-click cancels.
## Handled before emitting, since a choice may change scenes (gotcha #10).
func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		AudioManager.play_sfx("cancel")
		accept_event()
		cancelled.emit()
		return
	if _options.is_empty():
		return
	if event is InputEventMouseMotion:
		var row := row_at(event.position)
		if row >= 0 and row != _index:
			_index = row
			AudioManager.play_sfx("cursor")
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_move_selection(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var row := row_at(event.position)
			if row < 0:
				return
			_index = row
			AudioManager.play_sfx("confirm")
			accept_event()
			chosen.emit(_index)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(_width, _panel_height()))
	# AW-56: the shared noble frame (UITheme owns the look for every panel now).
	UITheme.draw_panel(self, rect)
	var font := UITheme.font()
	var y := PAD + 22.0
	if _title != "":
		draw_string(font, Vector2(PAD, y), _title, HORIZONTAL_ALIGNMENT_LEFT, _width - PAD * 2, 18, accent)
		y += ROW_H
	for i in range(_first_visible, _first_visible + _visible_rows):
		if i == _index:
			draw_rect(Rect2(20, y - 22, _width - 40, ROW_H - 4), Color(0.30, 0.45, 0.85, 0.55), true)
		draw_string(font, Vector2(PAD + 6, y), str(_options[i]), HORIZONTAL_ALIGNMENT_LEFT,
			_width - PAD * 2, 20, Color.WHITE)
		y += ROW_H
	# Small chevrons in the padding show when more choices are above or below.
	var center := _width * 0.5
	if _first_visible > 0:
		draw_polyline(PackedVector2Array([Vector2(center - 5, 18), Vector2(center, 13),
			Vector2(center + 5, 18)]), accent, 2.0)
	if _first_visible + _visible_rows < _options.size():
		var bottom := size.y - 18.0
		draw_polyline(PackedVector2Array([Vector2(center - 5, bottom), Vector2(center, bottom + 5),
			Vector2(center + 5, bottom)]), accent, 2.0)
