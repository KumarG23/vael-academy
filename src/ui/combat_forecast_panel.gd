class_name CombatForecastPanel
extends Control
## Two-sided combat forecast (§3 / WO-1.2): shows attacker and defender name, HP,
## and per-strike damage / hit% / crit%, with a doubling marker. Pure presentation
## — fed a precomputed CombatForecast.exchange() dict. Lives in a CanvasLayer.

const PANEL_BG := Color(0.08, 0.09, 0.12, 0.92)
const PANEL_EDGE := Color(0.85, 0.78, 0.45, 0.9)
const PANEL_SIZE := Vector2(360, 190)

var _attacker_name := ""
var _defender_name := ""
var _attacker_hp := ""
var _defender_hp := ""
var _atk := {}
var _def := {}
var _atk_doubles := false
var _def_doubles := false
var _def_can_counter := true
var _text_rows: Array[Dictionary] = []
var _layout_width := 0.0


func _init() -> void:
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_forecast(
	attacker: Unit, defender: Unit, exchange: Dictionary
) -> void:
	_attacker_name = attacker.unit_def.display_name
	_defender_name = defender.unit_def.display_name
	_attacker_hp = "HP %d/%d" % [attacker.current_hp, attacker.max_hp()]
	_defender_hp = "HP %d/%d" % [defender.current_hp, defender.max_hp()]
	_atk = exchange["attacker"]
	_def = exchange["defender"]
	_atk_doubles = exchange["attacker_doubles"]
	_def_doubles = exchange["defender_doubles"]
	_def_can_counter = exchange["defender_can_counter"]
	visible = true
	_layout_width = 0.0
	fit_width(PANEL_SIZE.x)
	queue_redraw()


func hide_panel() -> void:
	visible = false


func fit_width(width: float) -> void:
	if _layout_width == width:
		return
	_layout_width = width
	_text_rows.clear()
	var a_height := _layout_side(22, _attacker_name, _attacker_hp, _atk, _atk_doubles, true, width)
	var b_height := _layout_side(width * 0.5 + 16, _defender_name, _defender_hp, _def, _def_doubles, _def_can_counter, width)
	size = Vector2(width, maxf(PANEL_SIZE.y, maxf(a_height, b_height) + 20))
	queue_redraw()


func _layout_side(x: float, unit_name: String, hp: String, stats: Dictionary, doubles: bool, active: bool, width: float) -> float:
	var available := width * 0.5 - 38
	var y := _add_text(unit_name, 20, Vector2(x, 16), available, Color.WHITE) + 4
	y = _add_text(hp, 16, Vector2(x, y), available, Color(0.7, 0.72, 0.78)) + 12
	if stats.is_empty():
		return y
	if not active:
		return _add_text("no counter", 16, Vector2(x, y), available, Color(0.7, 0.72, 0.78))
	var dmg_text := "Dmg  %d" % int(stats["damage"])
	if doubles:
		dmg_text += "  x2"
	for text in [dmg_text, "Hit   %d%%" % int(stats["hit"]), "Crit  %d%%" % int(stats["crit"])]:
		y = _add_text(text, 18, Vector2(x, y), available, Color.WHITE) + 3
	return y


func _add_text(text: String, font_size: int, at: Vector2, width: float, color: Color) -> float:
	var paragraph := TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(text, UITheme.font(), font_size)
	_text_rows.append({"text": text, "paragraph": paragraph, "at": at, "color": color})
	return at.y + paragraph.get_size().y


func _draw() -> void:
	UITheme.draw_panel(self, Rect2(Vector2.ZERO, size), PANEL_BG, 112.0)
	for row in _text_rows:
		row.paragraph.draw(get_canvas_item(), row.at, row.color)
	var mid := size.x * 0.5
	draw_line(Vector2(mid, 12), Vector2(mid, size.y - 12), Color(1, 1, 1, 0.15), 1.0)
