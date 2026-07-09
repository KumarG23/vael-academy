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
		if not (q is Dictionary):
			continue
		var req := str(q.get("req_flag", ""))
		if req == "" or bool(flags.get(req, false)):
			out.append(q)
	return out


static func pick_questions(n: int, flags: Dictionary) -> Array:
	var pool := eligible_questions(flags)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))


func start(questions: Array) -> void:
	_questions = questions
	_q_i = 0
	_correct = 0
	_choice = 0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _revealing or _questions.is_empty():
		return
	if event.is_action_pressed("cursor_up"):
		get_viewport().set_input_as_handled()
		_choice = (_choice - 1 + _n_choices()) % _n_choices()
		AudioManager.play_sfx("cursor")
		queue_redraw()
	elif event.is_action_pressed("cursor_down"):
		get_viewport().set_input_as_handled()
		_choice = (_choice + 1) % _n_choices()
		AudioManager.play_sfx("cursor")
		queue_redraw()
	elif event.is_action_pressed("cursor_confirm") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_answer()


func _n_choices() -> int:
	return (_questions[_q_i]["choices"] as Array).size()


func _answer() -> void:
	_picked = _choice
	var right := _picked == int(_questions[_q_i]["correct"])
	if right:
		_correct += 1
		AudioManager.play_sfx("heal")
	else:
		AudioManager.play_sfx("miss")
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


func _draw() -> void:
	if _questions.is_empty() or _q_i >= _questions.size():
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.06, 0.09, 0.75), true)
	var w := minf(760.0, vp.x * 0.8)
	var q: Dictionary = _questions[_q_i]
	var choices: Array = q["choices"]
	var h := 190.0 + choices.size() * 46.0
	var r := Rect2((vp.x - w) * 0.5, (vp.y - h) * 0.5, w, h)
	draw_rect(r, Color(0.10, 0.11, 0.16, 0.98), true)
	draw_rect(r, Color(0.86, 0.78, 0.45, 0.9), false, 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, r.position + Vector2(28, 40), "Lesson — Question %d of %d" % [_q_i + 1, _questions.size()],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.86, 0.78, 0.45))
	draw_string(font, r.position + Vector2(w - 170, 40), "Correct: %d" % _correct,
		HORIZONTAL_ALIGNMENT_RIGHT, 140, 15, Color(0.62, 0.66, 0.76))
	draw_line(r.position + Vector2(24, 54), r.position + Vector2(w - 24, 54), Color(0.3, 0.33, 0.44), 1.0)
	# the question, wrapped
	draw_multiline_string(font, r.position + Vector2(28, 88), str(q["q"]),
		HORIZONTAL_ALIGNMENT_LEFT, w - 56, 20, 3, Color(0.95, 0.94, 0.88))
	# the choices
	var cy := r.position.y + 168.0
	for i in range(choices.size()):
		var row := Rect2(r.position.x + 24, cy - 22, w - 48, 34)
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
	var hint := "…" if _revealing else "↑/↓ choose   ·   Enter answer"
	draw_string(font, Vector2(r.position.x + 28, r.position.y + h - 20), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.55, 0.58, 0.68))
