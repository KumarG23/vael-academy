class_name ResultScreen
extends Control
## Full-screen Victory / Defeat overlay (§6). Presentation only; the battle scene
## shows it once the ObjectiveResolver returns a terminal outcome.

signal dismissed

var _text := ""
var _accent := Color.WHITE
var _shown := false


func show_victory() -> void:
	_show("Victory", Color(0.95, 0.82, 0.35))


func show_defeat() -> void:
	_show("Defeat", Color(0.85, 0.28, 0.28))


func is_shown() -> bool:
	return _shown


func _show(text: String, accent: Color) -> void:
	_text = text
	_accent = accent
	_shown = true
	visible = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not _shown:
		return
	if (event is InputEventKey or event is InputEventMouseButton) and event.pressed:
		dismissed.emit()


func _draw() -> void:
	if not _shown:
		return
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.06, 0.78), true)
	var band_h := 140.0
	var y := vp.y * 0.5 - band_h * 0.5
	draw_rect(Rect2(0, y, vp.x, band_h), Color(0.06, 0.07, 0.10, 0.95), true)
	draw_rect(Rect2(0, y, vp.x, 4), _accent, true)
	draw_rect(Rect2(0, y + band_h - 4, vp.x, 4), _accent, true)
	var font := ThemeDB.fallback_font
	var size := 64
	var ts := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	draw_string(font, Vector2(vp.x * 0.5 - ts.x * 0.5, y + band_h * 0.5 + ts.y * 0.3),
		_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, _accent)
	var hint := "Press any key"
	var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 22)
	draw_string(font, Vector2(vp.x * 0.5 - hs.x * 0.5, y + band_h + 40),
		hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 0.82, 0.88))
