class_name AreaTitleCard
extends Control
## AW-71: FE-style location card — "— The Sealed Grove —" on a slim noble band
## when you enter an area. Presentation only; the castle tells it what to show.

const HOLD := 1.5
const FADE := 0.45

var _text := ""
var _alpha := 0.0
var _tween: Tween


func show_title(area_name: String) -> void:
	if area_name == "":
		return
	_text = "—  %s  —" % area_name
	_set_alpha(1.0)  # on instantly — a tweened fade-in reads as lag on a doorway
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(HOLD)
	_tween.tween_method(_set_alpha, 1.0, 0.0, FADE)


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
	var ts := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 26)
	var w := maxf(ts.x + 96.0, 300.0)
	var r := Rect2(vp.x * 0.5 - w * 0.5, 46.0, w, 64.0)
	modulate.a = _alpha
	UITheme.draw_panel(self, r)
	draw_string(font, Vector2(vp.x * 0.5 - ts.x * 0.5, r.position.y + 41),
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.90, 0.72))
