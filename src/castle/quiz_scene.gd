class_name QuizScene
extends Control
## AW-54: the classroom lesson — a short quiz over the castle (FishingGame
## pattern: the castle opens it, busy() gates walking, we emit `finished`).
## Questions come from data/quizzes/bank_v1.json; lore questions only enter the
## pool once you've actually READ their source (req_flag = "read_<point_id>",
## set by the castle when a lore point plays) — exploration is study.

signal finished(correct: int, total: int)

const BANK_PATH := "res://data/quizzes/bank_v1.json"
const QUESTIONS_PER_LESSON := 4
const REVEAL_TIME := 0.9

var _questions: Array = []
var _q_i := 0
var _choice := 0
var _correct := 0
var _revealing := false
var _reveal_left := 0.0
var _picked := -1


## A question the lesson can actually run: text, at least one choice, and a
## `correct` index inside the choices. Anything else would crash mid-lesson
## (modulo-by-zero on navigation, out-of-range reveal), so it never enters the pool.
static func is_well_formed(q: Variant) -> bool:
	if not (q is Dictionary):
		return false
	if not (q.get("q") is String) or not (q.get("choices") is Array):
		return false
	var n: int = (q["choices"] as Array).size()
	var c: Variant = q.get("correct")
	if n == 0 or not (c is int or c is float) or float(c) != floorf(float(c)):
		return false
	return int(c) >= 0 and int(c) < n


## The eligible pool for the current campaign: ungated basics + any lore whose
## source has been read. Pure/static so tests can call it directly.
static func eligible_questions(flags: Dictionary) -> Array:
	if not FileAccess.file_exists(BANK_PATH):
		return []
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(BANK_PATH))
	if not (raw is Array):
		return []
	var out: Array = []
	for q in raw:
		if not is_well_formed(q):
			continue
		var req := str(q.get("req_flag", ""))
		if req == "" or bool(flags.get(req, false)):
			out.append(q)
	return out


static func pick_questions(n: int, flags: Dictionary) -> Array:
	var pool := eligible_questions(flags)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


func _ready() -> void:
	# A lesson is a modal overlay. A Control added under the castle's CanvasLayer
	# keeps a zero-size rect even after an anchor preset, so it would neither
	# receive pointer input nor shield the scene underneath from stray clicks.
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func start(questions: Array) -> void:
	# The pool helper filters the shipped bank, but `start` is also the scene's
	# public lesson boundary. Drop anything it could not run so one bad entry
	# can never divide by zero on navigation or index past the choices.
	var runnable: Array = []
	for q in questions:
		if is_well_formed(q):
			runnable.append(q)
	_questions = runnable
	_q_i = 0
	_correct = 0
	_choice = 0
	_revealing = false
	_reveal_left = 0.0
	_picked = -1
	_fit_to_viewport()
	queue_redraw()


## Size the overlay to the real viewport. Anchors alone are not enough for a
## Control under a CanvasLayer/SubViewport; without this its clickable rect is 0×0.
func _fit_to_viewport() -> void:
	if not is_inside_tree():
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = get_viewport_rect().size


func _unhandled_input(event: InputEvent) -> void:
	# past the last question the lesson is over (the host frees us next frame)
	if _revealing or _q_i < 0 or _q_i >= _questions.size():
		return
	var n := _n_choices()
	if n <= 0:
		return
	if event.is_action_pressed("cursor_up"):
		get_viewport().set_input_as_handled()
		_choice = (_choice - 1 + n) % n
		AudioManager.play_sfx("cursor")
		queue_redraw()
	elif event.is_action_pressed("cursor_down"):
		get_viewport().set_input_as_handled()
		_choice = (_choice + 1) % n
		AudioManager.play_sfx("cursor")
		queue_redraw()
	elif event.is_action_pressed("cursor_confirm") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_answer()


## Mouse users get the same choice rows as keyboard users: hover highlights,
## a left click answers. The rows live inside the modal rect sized above.
func _gui_input(event: InputEvent) -> void:
	if _revealing or _q_i < 0 or _q_i >= _questions.size():
		return
	if event is InputEventMouseMotion:
		var hovered := _choice_at(event.position)
		if hovered >= 0 and hovered != _choice:
			_choice = hovered
			AudioManager.play_sfx("cursor")
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked := _choice_at(event.position)
		if clicked >= 0:
			_choice = clicked
			accept_event()
			_answer()


func _n_choices() -> int:
	if _q_i < 0 or _q_i >= _questions.size():
		return 0
	var choices: Variant = _questions[_q_i].get("choices")
	return (choices as Array).size() if choices is Array else 0


func _choice_at(local: Vector2) -> int:
	for i in range(_n_choices()):
		if _choice_row_rect(i).has_point(local):
			return i
	return -1


func _panel_rect() -> Rect2:
	if _questions.is_empty() or _q_i < 0 or _q_i >= _questions.size():
		return Rect2()
	var vp := get_viewport_rect().size
	var w := minf(760.0, vp.x * 0.8)
	var h := 208.0 + _n_choices() * 46.0
	return Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)


func _choice_row_rect(i: int) -> Rect2:
	var r := _panel_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Rect2()
	return Rect2(r.position.x + 30.0, r.position.y + 180.0 + i * 46.0 - 22.0,
		maxf(20.0, r.size.x - 60.0), 34.0)


func _answer() -> void:
	# Public method: ignore a repeated/direct call while the reveal is running,
	# and never index a question that was filtered or already completed.
	if _revealing or _q_i < 0 or _q_i >= _questions.size():
		return
	var n := _n_choices()
	if n <= 0 or _choice < 0 or _choice >= n:
		return
	_picked = _choice
	var right := _picked == int(_questions[_q_i]["correct"])
	if right:
		_correct += 1
		AudioManager.play_sfx("correct")  # AW-72: a proper chime, not a borrowed heal
	else:
		AudioManager.play_sfx("wrong")
	_revealing = true
	_reveal_left = REVEAL_TIME
	queue_redraw()


func _process(delta: float) -> void:
	if not _revealing:
		return
	_reveal_left -= delta
	if _reveal_left <= 0.0:
		_revealing = false
		_picked = -1
		_q_i += 1
		_choice = 0
		if _q_i >= _questions.size():
			finished.emit(_correct, _questions.size())
			return
		queue_redraw()


## The footer must describe the real controls: a click on a row answers at once
## (there is no separate click-to-choose step), exactly like Enter.
func hint_text() -> String:
	return "…" if _revealing else "↑/↓ choose   ·   Enter or click answer"


func _draw() -> void:
	if _questions.is_empty() or _q_i < 0 or _q_i >= _questions.size():
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.06, 0.09, 0.75), true)
	var q: Dictionary = _questions[_q_i]
	var choices: Array = q["choices"]
	var r := _panel_rect()
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var w := r.size.x
	var h := r.size.y
	UITheme.draw_panel(self, r)  # AW-56: the shared noble frame
	var font := UITheme.font()
	# content sits inside the frame's ornate corners (AW-56 inset)
	draw_string(font, r.position + Vector2(36, 50), "Lesson — Question %d of %d" % [_q_i + 1, _questions.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.86, 0.78, 0.45))
	draw_string(font, r.position + Vector2(w - 196, 50), "Correct: %d" % _correct,
		HORIZONTAL_ALIGNMENT_RIGHT, 140, 15, Color(0.62, 0.66, 0.76))
	draw_line(r.position + Vector2(32, 64), r.position + Vector2(w - 32, 64), Color(0.3, 0.33, 0.44), 1.0)
	# the question, wrapped
	draw_multiline_string(font, r.position + Vector2(36, 98), str(q["q"]),
		HORIZONTAL_ALIGNMENT_LEFT, w - 72, 20, 3, Color(0.95, 0.94, 0.88))
	# the choices
	var cy := r.position.y + 180.0
	for i in range(choices.size()):
		var row := _choice_row_rect(i)
		if row.size.x <= 0.0:
			continue
		if _revealing:
			if i == int(q["correct"]):
				draw_rect(row, Color(0.25, 0.65, 0.35, 0.55), true)   # the truth, green
			elif i == _picked:
				draw_rect(row, Color(0.75, 0.25, 0.22, 0.5), true)    # a miss, red
		elif i == _choice:
			draw_rect(row, Color(0.30, 0.45, 0.85, 0.5), true)
		draw_string(font, Vector2(row.position.x + 14, cy), "%s.  %s" % [char(65 + i), str(choices[i])],
			HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 24, 17,
			Color(0.96, 0.94, 0.86) if (i == _choice and not _revealing) else Color(0.82, 0.84, 0.9))
		cy += 46.0
	draw_string(font, Vector2(r.position.x + 36, r.position.y + h - 30), hint_text(),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.58, 0.68))
