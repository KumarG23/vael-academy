class_name DialogueScene
extends Control
## VN-style dialogue player (§4): portraits left/right, a name plate, a text box
## with a typewriter reveal, and advance on space/enter/click. Event steps
## (start_battle, give_item, ...) fire `event_triggered`; a terminal event or the
## end of the script fires `finished`. WO-4.6: choice steps pause playback with an
## option panel (arrows + enter, or tests call `choose()`); options may jump to a
## label and/or set a flag in `flags` for the caller (romance, school events).
##
## Portraits are placeholder panels (initial on a house-tinted card) until AW-4/AW-6
## paints them; the portrait id is carried through so the swap is art-only.

signal line_shown(step: DialogueStep)
signal event_triggered(event_name: String, params: Dictionary)
signal choice_shown(step: DialogueStep)
signal choice_made(step: DialogueStep, index: int)
signal flag_set(flag: String)
signal finished

## Auto-play this script on _ready if set (for standalone testing of scenes/dialogue).
@export var script_path: String = ""
## Characters revealed per second. <= 0 shows the whole line instantly.
@export var typewriter_speed: float = 48.0

const LEFT_COLOR := Color(0.55, 0.20, 0.20)
const RIGHT_COLOR := Color(0.20, 0.30, 0.55)

## Flags set by chosen options this playback — read by the caller after `finished`.
var flags: Dictionary = {}

var _script: DialogueScript
var _index := -1
var _finished := false
var _current: DialogueStep = null
var _choice: DialogueStep = null
var _choice_index := 0
var _revealed := 0.0
## Painted portraits (AW-6 hook): `assets/portraits/portrait_<id>.png` per side,
## falling back to the placeholder card when no art exists. Presentation only.
var _left_portrait := ""
var _right_portrait := ""
var _portrait_cache: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = TEXTURE_FILTER_LINEAR  # painted art, not pixel art
	if script_path != "":
		var s := DialogueScript.from_file(script_path)
		if s.ok():
			play(s)


## Start playing a script from the top.
func play(script: DialogueScript) -> void:
	_script = script
	_index = -1
	_finished = false
	_current = null
	_choice = null
	flags = {}
	_advance_logical()


func is_finished() -> bool:
	return _finished


func current_line() -> DialogueStep:
	return _current


func awaiting_choice() -> bool:
	return _choice != null


func current_choice() -> DialogueStep:
	return _choice


## Answer the pending choice: record its flag, jump to its label (or fall
## through), and resume playback. Tests call this directly; the panel routes here.
func choose(index: int) -> void:
	if _choice == null or index < 0 or index >= _choice.options.size():
		return
	var step := _choice
	var option: Dictionary = step.options[index]
	_choice = null
	if option["flag"] != "":
		flags[option["flag"]] = true
		flag_set.emit(option["flag"])
	choice_made.emit(step, index)
	if option["goto"] != "":
		_index = _script.labels[option["goto"]]  # loop pre-increments past the label
	_advance_logical()


func is_revealing() -> bool:
	return _current != null and _revealed < float(_current.text.length())


func skip_reveal() -> void:
	if _current != null:
		_revealed = float(_current.text.length())
		queue_redraw()


## Logical advance to the next spoken line, firing any events passed on the way and
## stopping at a terminal event or the end. This is what input drives (after any
## in-progress reveal is completed) and what tests call directly.
func advance() -> void:
	if _finished or _choice != null:  # a pending choice blocks advance
		return
	if is_revealing():
		skip_reveal()
		return
	_advance_logical()


func _advance_logical() -> void:
	while true:
		_index += 1
		if _script == null or _index >= _script.size():
			_finish()
			return
		var step := _script.get_step(_index)
		if step.is_label():
			continue  # labels are jump targets, not content
		if step.is_goto():
			_index = _script.labels[step.target]  # loop pre-increments past the label
			continue
		if step.is_choice():
			_choice = step
			_choice_index = 0
			queue_redraw()
			choice_shown.emit(step)
			return
		if step.is_event():
			event_triggered.emit(step.event_name, step.params)
			if DialogueScript.is_terminal_event(step.event_name):
				_finish()
				return
			continue  # non-terminal event: keep going to the next step
		_current = step
		if step.side == "right":
			_right_portrait = step.portrait
		else:
			_left_portrait = step.portrait
		_revealed = 0.0 if typewriter_speed > 0.0 else float(step.text.length())
		queue_redraw()
		line_shown.emit(step)
		return


func _finish() -> void:
	_finished = true
	_current = null
	queue_redraw()
	finished.emit()


func _process(delta: float) -> void:
	if is_revealing():
		_revealed = minf(float(_current.text.length()), _revealed + typewriter_speed * delta)
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if _choice != null:
			choose(_choice_index)  # click confirms the highlighted option
		else:
			advance()


## Keys arrive here — _gui_input only sees them when the control is focused, and
## this overlay never grabs focus (space/enter must advance from the keyboard).
func _unhandled_key_input(event: InputEvent) -> void:
	if _finished or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if _choice != null:
		match event.keycode:
			KEY_UP, KEY_W:
				_choice_index = wrapi(_choice_index - 1, 0, _choice.options.size())
				queue_redraw()
			KEY_DOWN, KEY_S:
				_choice_index = wrapi(_choice_index + 1, 0, _choice.options.size())
				queue_redraw()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				choose(_choice_index)
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		advance()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.04, 0.35), true)
	if _current == null:
		if _choice != null:
			_draw_choice_panel(vp)  # a leading choice has no line under it
		return
	var active_left := _current.side == "left"
	_draw_portrait(Vector2(vp.x * 0.08, vp.y * 0.14), LEFT_COLOR, active_left, "left")
	_draw_portrait(Vector2(vp.x * 0.72, vp.y * 0.14), RIGHT_COLOR, not active_left, "right")

	# Text box.
	var box := Rect2(vp.x * 0.10, vp.y * 0.66, vp.x * 0.80, vp.y * 0.26)
	draw_rect(box, Color(0.06, 0.07, 0.10, 0.96), true)
	draw_rect(box, Color(0.85, 0.78, 0.45, 0.9), false, 2.0)

	var font := ThemeDB.fallback_font
	# Name plate.
	if _current.speaker != "":
		var plate := Rect2(box.position + Vector2(24, -34), Vector2(220, 34))
		draw_rect(plate, Color(0.10, 0.11, 0.15, 0.98), true)
		draw_rect(plate, Color(0.85, 0.78, 0.45, 0.9), false, 2.0)
		draw_string(font, plate.position + Vector2(14, 24), _current.speaker,
			HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 20, 20, Color(0.95, 0.82, 0.35))

	var shown := _current.text.substr(0, int(_revealed))
	draw_multiline_string(font, box.position + Vector2(28, 44), shown,
		HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 56, 24, -1, Color.WHITE)

	if not is_revealing() and _choice == null:
		draw_string(font, box.position + box.size - Vector2(40, 20), "▼",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.82, 0.88))
	if _choice != null:
		_draw_choice_panel(vp)  # last: the panel sits above portraits and box


## The WO-4.6 option panel: prompt title + option rows, highlighted row marked.
## Drawn above the text box on the right, FE dialogue-choice style.
func _draw_choice_panel(vp: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var row_h := 40.0
	var title_h := 44.0 if _choice.text != "" else 8.0
	var panel := Rect2(
		Vector2(vp.x * 0.50, vp.y * 0.66 - title_h - row_h * _choice.options.size() - 24),
		Vector2(vp.x * 0.36, title_h + row_h * _choice.options.size() + 12))
	draw_rect(panel, Color(0.06, 0.07, 0.10, 0.97), true)
	draw_rect(panel, Color(0.85, 0.78, 0.45, 0.9), false, 2.0)
	if _choice.text != "":
		draw_string(font, panel.position + Vector2(20, 30), _choice.text,
			HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 40, 20, Color(0.95, 0.82, 0.35))
	for i in range(_choice.options.size()):
		var row := Rect2(panel.position + Vector2(10, title_h + row_h * i),
			Vector2(panel.size.x - 20, row_h - 6))
		if i == _choice_index:
			draw_rect(row, Color(0.30, 0.26, 0.14, 0.95), true)
			draw_rect(row, Color(0.95, 0.82, 0.35, 0.9), false, 1.5)
			draw_string(font, row.position + Vector2(10, 24), "▶",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.82, 0.35))
		draw_string(font, row.position + Vector2(34, 24), str(_choice.options[i]["text"]),
			HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 44, 20,
			Color.WHITE if i == _choice_index else Color(0.75, 0.76, 0.80))


func _draw_portrait(pos: Vector2, color: Color, active: bool, side: String) -> void:
	var vp := get_viewport_rect().size
	var size := Vector2(vp.x * 0.20, vp.y * 0.48)
	# Painted portrait when the art exists (AW-6); placeholder card otherwise.
	var tex := _portrait_texture(_left_portrait if side == "left" else _right_portrait)
	if tex != null:
		var h := size.y * 1.15  # portraits may overhang the slot a touch, VN-style
		var w := tex.get_width() * (h / tex.get_height())
		var rect := Rect2(Vector2(pos.x + size.x * 0.5 - w * 0.5, pos.y + size.y - h + vp.y * 0.06), Vector2(w, h))
		var mod := Color.WHITE if active else Color(0.45, 0.45, 0.50)
		draw_texture_rect(tex, rect, false, mod)
		return
	var card := color if active else color.darkened(0.5)
	var alpha := 1.0 if active else 0.55
	draw_rect(Rect2(pos, size), Color(card.r, card.g, card.b, alpha), true)
	draw_rect(Rect2(pos, size), Color(0.9, 0.85, 0.6, alpha), false, 2.0)
	# Placeholder initial for the speaker on the active side.
	if active and _current != null and _current.speaker != "":
		var font := ThemeDB.fallback_font
		var initial := _current.speaker.substr(0, 1)
		draw_string(font, pos + size * 0.5 - Vector2(20, -20), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(1, 1, 1, 0.9))


func _portrait_texture(id: String) -> Texture2D:
	if id == "":
		return null
	if not _portrait_cache.has(id):
		var path := "res://assets/portraits/portrait_%s.png" % id
		_portrait_cache[id] = load(path) if ResourceLoader.exists(path) else null
	return _portrait_cache[id]
