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
## AW-57: per-line emotion — `portrait_<id>_<expression>.png` wins when the art
## exists (e.g. portrait_liora_happy.png), falling back to the base portrait.
var _left_expr := "neutral"
var _right_expr := "neutral"
var _portrait_cache: Dictionary = {}
# AW-78: the VN backdrop — a texture (cover-fit) or a flat special ("black"/"white").
# Held in members so the textures survive redraws (gotcha #11).
var _backdrop_tex: Texture2D = null
var _backdrop_flat := Color(0, 0, 0, 0)  # a=0 means "no flat backdrop"


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
	# AW-57: taking a ♥ option is the romance consent — the scene's owner (the
	# castle) locks the pair through the same event channel step events use.
	if str(option.get("heart", "")) != "":
		event_triggered.emit("romance", {"with": str(option["heart"])})
	choice_made.emit(step, index)
	if option["goto"] != "":
		_index = _script.labels[option["goto"]]  # loop pre-increments past the label
	_advance_logical()


# --- AW-57: gated ♥ options -----------------------------------------------------

## Set by the scene's owner: Callable(unit_id) -> bool, deciding whether a ♥
## option for that unit may be offered. Unset = hearts stay hidden (battle and
## test dialogues never flash a heart by accident).
var heart_gate: Callable = Callable()

## Indices (into _choice.options) of the options actually offered.
var _shown: Array = []


func _refresh_shown_options() -> void:
	_shown = []
	for i in range(_choice.options.size()):
		var heart := str(_choice.options[i].get("heart", ""))
		if heart == "" or (heart_gate.is_valid() and bool(heart_gate.call(heart))):
			_shown.append(i)
	if _shown.is_empty():  # authoring safety: never strand a choice with no options
		for i in range(_choice.options.size()):
			_shown.append(i)


func shown_option_indices() -> Array:
	return _shown.duplicate()


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
			_refresh_shown_options()
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
		if step.backdrop != "":  # AW-78: this line changes the stage
			_set_backdrop(step.backdrop)
		if step.music == "stop":  # AW-79: scripts can score themselves
			AudioManager.stop_music()
		elif step.music != "":
			AudioManager.play_music(step.music)
		AudioManager.stop_voice()
		if step.voice != "":     # AW-78: the storyteller reads this one aloud
			AudioManager.play_voice(step.voice)
		if step.side == "right":
			_right_portrait = step.portrait
			_right_expr = step.expression  # AW-57: per-line emotion variant
		else:
			_left_portrait = step.portrait
			_left_expr = step.expression
		_revealed = 0.0 if typewriter_speed > 0.0 else float(step.text.length())
		queue_redraw()
		line_shown.emit(step)
		return


func _set_backdrop(spec: String) -> void:
	match spec:
		"black":
			_backdrop_tex = null
			_backdrop_flat = Color(0.02, 0.02, 0.03, 1.0)
		"white":
			_backdrop_tex = null
			_backdrop_flat = Color(0.98, 0.97, 0.92, 1.0)
		_:
			_backdrop_tex = load(spec) if ResourceLoader.exists(spec) else null
			_backdrop_flat = Color(0.02, 0.02, 0.03, 1.0) if _backdrop_tex == null else Color(0, 0, 0, 0)


func _finish() -> void:
	AudioManager.stop_voice()  # AW-78: the narrator doesn't outlive the scene
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
			choose(_shown[_choice_index])  # click confirms the highlighted option
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
				_choice_index = wrapi(_choice_index - 1, 0, _shown.size())
				queue_redraw()
			KEY_DOWN, KEY_S:
				_choice_index = wrapi(_choice_index + 1, 0, _shown.size())
				queue_redraw()
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				choose(_shown[_choice_index])
			_:
				return
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		advance()


func _draw() -> void:
	var vp := get_viewport_rect().size
	# AW-78: the stage first — backdrop image (cover-fit) or flat, then the scrim.
	if _backdrop_tex != null:
		var ts := _backdrop_tex.get_size()
		var s := maxf(vp.x / ts.x, vp.y / ts.y)
		var sz := ts * s
		draw_texture_rect(_backdrop_tex, Rect2((Vector2(vp) - sz) * 0.5, sz), false)
	elif _backdrop_flat.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vp), _backdrop_flat, true)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.04, 0.35), true)
	if _current == null:
		if _choice != null:
			_draw_choice_panel(vp)  # a leading choice has no line under it
		return
	if _current.is_narration():
		_draw_narration(vp)  # AW-78: the storyteller owns the whole frame
		return
	var active_left := _current.side == "left"
	_draw_portrait(Vector2(vp.x * 0.08, vp.y * 0.14), LEFT_COLOR, active_left, "left")
	_draw_portrait(Vector2(vp.x * 0.72, vp.y * 0.14), RIGHT_COLOR, not active_left, "right")

	# Text box — the shared noble pixel frame (AW-56).
	var box := Rect2(vp.x * 0.10, vp.y * 0.66, vp.x * 0.80, vp.y * 0.26)
	UITheme.draw_panel(self, box)

	var font := UITheme.font()
	# Name plate.
	if _current.speaker != "":
		var plate := Rect2(box.position + Vector2(24, -38), Vector2(220, 38))
		UITheme.draw_panel(self, plate, Color(0.10, 0.11, 0.15, 0.98))
		draw_string(font, plate.position + Vector2(18, 26), _current.speaker,
			HORIZONTAL_ALIGNMENT_LEFT, plate.size.x - 30, 20, Color(0.95, 0.82, 0.35))

	var shown := _current.text.substr(0, int(_revealed))
	draw_multiline_string(font, box.position + Vector2(28, 44), shown,
		HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 56, 24, -1, Color.WHITE)

	if not is_revealing() and _choice == null:
		draw_string(font, box.position + box.size - Vector2(40, 20), "▼",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.82, 0.88))
	if _choice != null:
		_draw_choice_panel(vp)  # last: the panel sits above portraits and box


## AW-78: narration rendering — the hearth storyteller. No box, no plate, no
## portraits: letterboxed text between two thin gold rules, centered low.
func _draw_narration(vp: Vector2) -> void:
	var font := UITheme.font()
	var shown := _current.text.substr(0, int(_revealed))
	var band_w := minf(vp.x * 0.72, 900.0)
	var x := (vp.x - band_w) * 0.5
	# Size for the FULL line so the typewriter does not move the frame. Several
	# authored opening paragraphs exceed the old three-line clipping limit.
	var text_height := font.get_multiline_string_size(_current.text,
		HORIZONTAL_ALIGNMENT_CENTER, band_w - 20, 22).y
	var y := minf(vp.y * 0.68, vp.y - text_height - 76.0)
	var rule := Color(0.86, 0.72, 0.42, 0.55)
	draw_rect(Rect2(x, y - 34, band_w, 1.5), rule, true)
	draw_rect(Rect2(x, y + text_height + 12, band_w, 1.5), rule, true)
	draw_multiline_string(font, Vector2(x + 10, y), shown,
		HORIZONTAL_ALIGNMENT_CENTER, band_w - 20, 22, -1, Color(0.93, 0.89, 0.78))
	if not is_revealing() and _choice == null:
		draw_string(font, Vector2(vp.x * 0.5 - 8, y + text_height + 44), "▼",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.8, 0.82, 0.88, 0.7))


## The WO-4.6 option panel: prompt title + option rows, highlighted row marked.
## Drawn above the text box on the right, FE dialogue-choice style.
func _draw_choice_panel(vp: Vector2) -> void:
	var font := UITheme.font()
	var row_h := 40.0
	var title_h := 44.0 if _choice.text != "" else 8.0
	var panel := Rect2(
		Vector2(vp.x * 0.50, vp.y * 0.66 - title_h - row_h * _shown.size() - 24),
		Vector2(vp.x * 0.36, title_h + row_h * _shown.size() + 12))
	UITheme.draw_panel(self, panel)  # AW-56: the shared noble frame
	if _choice.text != "":
		draw_string(font, panel.position + Vector2(20, 30), _choice.text,
			HORIZONTAL_ALIGNMENT_LEFT, panel.size.x - 40, 20, Color(0.95, 0.82, 0.35))
	for i in range(_shown.size()):
		var option: Dictionary = _choice.options[_shown[i]]
		var is_heart := str(option.get("heart", "")) != ""
		var row := Rect2(panel.position + Vector2(10, title_h + row_h * i),
			Vector2(panel.size.x - 20, row_h - 6))
		if i == _choice_index:
			# AW-57: the ♥ row glows rose instead of gold
			var hi := Color(0.42, 0.16, 0.24, 0.95) if is_heart else Color(0.30, 0.26, 0.14, 0.95)
			var edge := Color(1.0, 0.5, 0.65, 0.9) if is_heart else Color(0.95, 0.82, 0.35, 0.9)
			draw_rect(row, hi, true)
			draw_rect(row, edge, false, 1.5)
			draw_string(font, row.position + Vector2(10, 24), "▶",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 18, edge)
		var label := ("♥ " if is_heart else "") + str(option["text"])
		var col := Color(1.0, 0.62, 0.74) if is_heart else Color(0.75, 0.76, 0.80)
		if i == _choice_index:
			col = Color(1.0, 0.78, 0.86) if is_heart else Color.WHITE
		draw_string(font, row.position + Vector2(34, 24), label,
			HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 44, 20, col)


func _draw_portrait(pos: Vector2, color: Color, active: bool, side: String) -> void:
	# AW-78: an unused side draws NOTHING — the empty placeholder card only ever
	# looked intentional when both sides had speakers (VN scenes exposed it).
	if (_left_portrait if side == "left" else _right_portrait) == "":
		if not (active and _current != null and _current.speaker != ""):
			return
	var vp := get_viewport_rect().size
	var size := Vector2(vp.x * 0.20, vp.y * 0.48)
	# Painted portrait when the art exists (AW-6); placeholder card otherwise.
	var tex := _portrait_texture(_left_portrait if side == "left" else _right_portrait,
		_left_expr if side == "left" else _right_expr)
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


func _portrait_texture(id: String, expression := "neutral") -> Texture2D:
	if id == "":
		return null
	var path := portrait_path(id, expression)
	if not _portrait_cache.has(path):
		_portrait_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _portrait_cache[path]


## AW-57: resolve a portrait's file for an expression — the emotion variant
## (`portrait_<id>_<expression>.png`) when its art exists, else the base. Pure,
## so the convention is testable; ComfyUI/Gemini emotion sets just drop in.
static func portrait_path(id: String, expression := "neutral") -> String:
	if expression != "" and expression != "neutral":
		var variant := "res://assets/portraits/portrait_%s_%s.png" % [id, expression]
		if ResourceLoader.exists(variant):
			return variant
	return "res://assets/portraits/portrait_%s.png" % id
