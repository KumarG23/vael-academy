class_name DialogueScene
extends Control
## VN-style dialogue player (§4): portraits left/right, a name plate, a text box
## with a typewriter reveal, and advance on space/enter/click. Event steps
## (start_battle, give_item, ...) fire `event_triggered`; a terminal event or the
## end of the script fires `finished`. Choices are parked (not in the slice).
##
## Portraits are placeholder panels (initial on a house-tinted card) until AW-4/AW-6
## paints them; the portrait id is carried through so the swap is art-only.

signal line_shown(step: DialogueStep)
signal event_triggered(event_name: String, params: Dictionary)
signal finished

## Auto-play this script on _ready if set (for standalone testing of scenes/dialogue).
@export var script_path: String = ""
## Characters revealed per second. <= 0 shows the whole line instantly.
@export var typewriter_speed: float = 48.0

const LEFT_COLOR := Color(0.55, 0.20, 0.20)
const RIGHT_COLOR := Color(0.20, 0.30, 0.55)

var _script: DialogueScript
var _index := -1
var _finished := false
var _current: DialogueStep = null
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
	_advance_logical()


func is_finished() -> bool:
	return _finished


func current_line() -> DialogueStep:
	return _current


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
	if _finished:
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
		advance()


## Keys arrive here — _gui_input only sees them when the control is focused, and
## this overlay never grabs focus (space/enter must advance from the keyboard).
func _unhandled_key_input(event: InputEvent) -> void:
	if _finished:
		return
	if (event is InputEventKey and event.pressed and not event.echo
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]):
		get_viewport().set_input_as_handled()
		advance()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.04, 0.35), true)
	if _current == null:
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

	if not is_revealing():
		draw_string(font, box.position + box.size - Vector2(40, 20), "▼",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.82, 0.88))


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
