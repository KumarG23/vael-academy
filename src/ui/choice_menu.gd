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
## Optional caller-owned safe region; an empty rect means the whole viewport.
var layout_bounds := Rect2()
var width_limit := MAX_WIDTH
var _preferred_position := Vector2.ZERO
var _title_lines: Array[String] = []
var _row_lines: Array[Array] = []
var _row_heights: Array[float] = []
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
	_preferred_position = top_left
	position = top_left
	visible = true
	_layout_panel()


func close() -> void:
	visible = false


## Wrap with the active draw font, preserving every character (including IDs).
static func wrapped_lines(text: String, font: Font, font_size: int, width: float) -> Array[String]:
	var paragraph := TextParagraph.new()
	paragraph.width = maxf(1.0, width)
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, font, font_size)
	var lines: Array[String] = []
	for line in range(paragraph.get_line_count()):
		var span := paragraph.get_line_range(line)
		lines.append(text.substr(span.x, span.y - span.x))
	return lines


func _text_height(lines: Array, font_size: int) -> float:
	return ROW_H + maxf(0.0, lines.size() - 1) * ceilf(UITheme.font().get_height(font_size))


func _header_height() -> float:
	return _text_height(_title_lines, 18) if _title != "" else 0.0


func _panel_height() -> float:
	var height := PAD * 2 + _header_height()
	for i in range(_first_visible, _first_visible + _visible_rows):
		height += _row_heights[i]
	return height


func _safe_rect() -> Rect2:
	var viewport := get_viewport_rect()
	return viewport.intersection(layout_bounds) if layout_bounds.has_area() else viewport


func _layout_panel() -> void:
	if not visible:
		return
	var bounds := _safe_rect()
	_width = minf(_fit_width(), bounds.size.x)
	_title_lines = wrapped_lines(_title, UITheme.font(), 18, _width - PAD * 2)
	_row_lines.clear()
	_row_heights.clear()
	for option in _options:
		var lines := wrapped_lines(str(option), UITheme.font(), 20, _width - PAD * 2 - 6.0)
		_row_lines.append(lines)
		_row_heights.append(_text_height(lines, 20))
	_keep_selection_visible()
	size = Vector2(_width, _panel_height())
	position.x = clampf(_preferred_position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - size.x))
	position.y = clampf(_preferred_position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - size.y))
	queue_redraw()


func _rows_that_fit(first: int) -> int:
	var remaining := _safe_rect().size.y - PAD * 2 - _header_height()
	var count := 0
	for i in range(first, _options.size()):
		if _row_heights[i] > remaining:
			break
		remaining -= _row_heights[i]
		count += 1
	return count


func _keep_selection_visible() -> void:
	if _options.is_empty():
		_first_visible = 0
		_visible_rows = 0
		return
	_first_visible = clampi(_first_visible, 0, _index)
	while _first_visible < _index and _index >= _first_visible + _rows_that_fit(_first_visible):
		_first_visible += 1
	# Restore earlier rows whenever space permits, including after live restore.
	while _first_visible > 0 and _index < _first_visible - 1 + _rows_that_fit(_first_visible - 1):
		_first_visible -= 1
	_visible_rows = _rows_that_fit(_first_visible)
	# Selection changes can change the page's measured height too.
	size = Vector2(_width, _panel_height())
	var bounds := _safe_rect()
	position.y = clampf(_preferred_position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - size.y))


## Only complete visible rows are drawn and actionable. Padding/hidden edges
## never alias another index, even when adjacent rows have different heights.
func row_rect(index: int) -> Rect2:
	if index < _first_visible or index >= _first_visible + _visible_rows:
		return Rect2()
	var top := PAD + _header_height()
	for i in range(_first_visible, index):
		top += _row_heights[i]
	return Rect2(20, top, _width - 40, _row_heights[index])


func _move_selection(direction: int) -> void:
	_index = (_index + direction + _options.size()) % _options.size()
	_keep_selection_visible()
	AudioManager.play_sfx("cursor")
	queue_redraw()


## Option row under a local point, or -1 (title, padding or outside the rows).
func row_at(local: Vector2) -> int:
	for i in range(_first_visible, _first_visible + _visible_rows):
		if row_rect(i).has_point(local):
			return i
	return -1


## Widest label (title at 18px, rows at 20px) plus padding, clamped sane.
## Measured with the same font _draw uses, so a pixel face never clips.
func _fit_width() -> float:
	var font := UITheme.font()
	var w := WIDTH
	if _title != "":
		w = maxf(w, font.get_string_size(_title, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + PAD * 2 + 8)
	for opt in _options:
		w = maxf(w, font.get_string_size(str(opt), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + PAD * 2 + 20)
	return minf(w, width_limit)


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
	var pitch := ceilf(font.get_height(18))
	for line in range(_title_lines.size()):
		draw_string(font, Vector2(PAD, PAD + 22.0 + line * pitch), _title_lines[line],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, accent)
	pitch = ceilf(font.get_height(20))
	for i in range(_first_visible, _first_visible + _visible_rows):
		var row := row_rect(i)
		if i == _index:
			draw_rect(Rect2(row.position, row.size - Vector2(0, 4)), Color(0.30, 0.45, 0.85, 0.55), true)
		for line in range(_row_lines[i].size()):
			draw_string(font, Vector2(PAD + 6, row.position.y + 22.0 + line * pitch), _row_lines[i][line],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	# Small chevrons in the padding show when more choices are above or below.
	var center := _width * 0.5
	if _first_visible > 0:
		draw_polyline(PackedVector2Array([Vector2(center - 5, 18), Vector2(center, 13),
			Vector2(center + 5, 18)]), accent, 2.0)
	if _first_visible + _visible_rows < _options.size():
		var bottom := size.y - 18.0
		draw_polyline(PackedVector2Array([Vector2(center - 5, bottom), Vector2(center, bottom + 5),
			Vector2(center + 5, bottom)]), accent, 2.0)
