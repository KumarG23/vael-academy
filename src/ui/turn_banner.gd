class_name TurnBanner
extends Control
## A brief centered banner announcing the current phase ("Player Phase" /
## "Enemy Phase"). Presentation only; the battle scene tells it what to show.

const SHOW_TIME := 1.1

var _text := ""
var _alpha := 0.0
var _player := true


func announce(text: String, is_player: bool) -> void:
	_text = text
	_player = is_player
	_alpha = 1.0
	queue_redraw()
	var tween := create_tween()
	tween.tween_interval(SHOW_TIME * 0.5)
	tween.tween_method(_set_alpha, 1.0, 0.0, SHOW_TIME * 0.5)


func _set_alpha(a: float) -> void:
	_alpha = a
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var vp := get_viewport_rect().size
	var band_h := 84.0
	var y := vp.y * 0.5 - band_h * 0.5
	var accent := Color(0.30, 0.55, 0.95) if _player else Color(0.90, 0.32, 0.30)
	var edge := Color(accent.r, accent.g, accent.b, _alpha)
	draw_rect(Rect2(0, y, vp.x, band_h), Color(0.05, 0.06, 0.09, 0.82 * _alpha), true)
	draw_rect(Rect2(0, y, vp.x, 3), edge, true)
	draw_rect(Rect2(0, y + band_h - 3, vp.x, 3), edge, true)
	var font := ThemeDB.fallback_font
	var size := 40
	var ts := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	var pos := Vector2(vp.x * 0.5 - ts.x * 0.5, y + band_h * 0.5 + ts.y * 0.3)
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, _alpha))
