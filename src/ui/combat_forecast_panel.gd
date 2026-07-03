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
	queue_redraw()


func hide_panel() -> void:
	visible = false


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, PANEL_SIZE)
	draw_rect(rect, PANEL_BG, true)
	draw_rect(rect, PANEL_EDGE, false, 2.0)

	var col_a := 18.0
	var col_b := PANEL_SIZE.x * 0.5 + 8.0
	_draw_side(col_a, _attacker_name, _attacker_hp, _atk, _atk_doubles, true)
	_draw_side(col_b, _defender_name, _defender_hp, _def, _def_doubles, _def_can_counter)

	# Divider.
	var mid := PANEL_SIZE.x * 0.5
	draw_line(Vector2(mid, 12), Vector2(mid, PANEL_SIZE.y - 12), Color(1, 1, 1, 0.15), 1.0)


func _draw_side(
	x: float, unit_name: String, hp: String, stats: Dictionary, doubles: bool, active: bool
) -> void:
	var font := ThemeDB.fallback_font
	var white := Color.WHITE
	var dim := Color(0.7, 0.72, 0.78)
	var y := 30.0
	draw_string(font, Vector2(x, y), unit_name, HORIZONTAL_ALIGNMENT_LEFT, 150, 20, white)
	y += 26
	draw_string(font, Vector2(x, y), hp, HORIZONTAL_ALIGNMENT_LEFT, 150, 16, dim)
	y += 30
	if not active:
		draw_string(font, Vector2(x, y), "no counter", HORIZONTAL_ALIGNMENT_LEFT, 150, 16, dim)
		return
	var dmg_text := "Dmg  %d" % int(stats["damage"])
	if doubles:
		dmg_text += "  x2"
	draw_string(font, Vector2(x, y), dmg_text, HORIZONTAL_ALIGNMENT_LEFT, 160, 18, white)
	y += 24
	draw_string(font, Vector2(x, y), "Hit   %d%%" % int(stats["hit"]), HORIZONTAL_ALIGNMENT_LEFT, 160, 18, white)
	y += 24
	draw_string(font, Vector2(x, y), "Crit  %d%%" % int(stats["crit"]), HORIZONTAL_ALIGNMENT_LEFT, 160, 18, white)
