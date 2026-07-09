class_name BattleIntroCard
extends Control
## AW-71: the chapter opening card — name of the battle, the objective, and the
## odds, held center-screen for a beat before round 1. Non-blocking (a timed
## fade like TurnBanner), so the prep screen / first phase flows on underneath;
## the round-1 phase banner is skipped while this holds the center.

const HOLD := 3.0
const FADE := 0.6

var _text := ""
var _lines: Array = []
var _alpha := 0.0


func show_card(title: String, lines: Array) -> void:
	_text = title
	_lines = lines
	_set_alpha(1.0)
	var tween := create_tween()
	tween.tween_interval(HOLD)
	tween.tween_method(_set_alpha, 1.0, 0.0, FADE)


func is_showing() -> bool:
	return _alpha > 0.01


func _set_alpha(a: float) -> void:
	_alpha = a
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var vp := get_viewport_rect().size
	var font := UITheme.font()
	var h := 118.0 + _lines.size() * 30.0
	var w := minf(560.0, vp.x * 0.7)
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y * 0.5 - h * 0.5, w, h)
	modulate.a = _alpha
	UITheme.draw_panel(self, r)
	var ts := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 34)
	draw_string(font, Vector2(vp.x * 0.5 - ts.x * 0.5, r.position.y + 56),
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(0.95, 0.90, 0.72))
	var ly := r.position.y + 94.0
	for line in _lines:
		var ls := font.get_string_size(str(line), HORIZONTAL_ALIGNMENT_CENTER, -1, 19)
		draw_string(font, Vector2(vp.x * 0.5 - ls.x * 0.5, ly),
			str(line), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(0.80, 0.82, 0.88))
		ly += 30.0
