class_name LevelUpScreen
extends Control
## Level-up panel (§6 / WO-2.1): shows a unit's new level and its per-stat gains,
## revealing them one at a time. Presentation only; the battle scene queues results
## from Unit.gain_xp() and awaits `finished`.

signal finished

const REVEAL_STEP := 0.12
const HOLD_TIME := 0.7
const STAT_LABELS := {
	"hp": "HP", "str": "STR", "mag": "MAG", "skl": "SKL",
	"spd": "SPD", "lck": "LCK", "def": "DEF", "res": "RES",
}

var _unit_name := ""
var _new_level := 1
var _gains := {}
var _revealed := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


## Play a single level-up result. Awaitable via the `finished` signal.
func play(unit_name: String, result: Dictionary) -> void:
	_unit_name = unit_name
	_new_level = result["level"]
	_gains = result["gains"]
	_revealed = 0
	visible = true
	queue_redraw()
	for stat in LevelUp.STAT_ORDER:
		_revealed += 1
		queue_redraw()
		await get_tree().create_timer(REVEAL_STEP).timeout
	await get_tree().create_timer(HOLD_TIME).timeout
	visible = false
	finished.emit()


func _draw() -> void:
	var vp := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.04, 0.06, 0.55), true)
	var panel := Vector2(320, 300)
	var origin := Vector2(vp.x * 0.5 - panel.x * 0.5, vp.y * 0.5 - panel.y * 0.5)
	draw_rect(Rect2(origin, panel), Color(0.08, 0.09, 0.13, 0.97), true)
	draw_rect(Rect2(origin, panel), Color(0.95, 0.82, 0.35, 0.9), false, 2.0)

	var font := ThemeDB.fallback_font
	draw_string(font, origin + Vector2(20, 40), "%s — Level %d" % [_unit_name, _new_level],
		HORIZONTAL_ALIGNMENT_LEFT, panel.x - 40, 24, Color(0.95, 0.82, 0.35))

	var y := 84.0
	var i := 0
	for stat in LevelUp.STAT_ORDER:
		if i >= _revealed:
			break
		var gained: int = int(_gains.get(stat, 0))
		var label: String = STAT_LABELS[stat]
		var color := Color(0.5, 0.95, 0.55) if gained > 0 else Color(0.55, 0.57, 0.63)
		var txt := "%s   %s" % [label, ("+1" if gained > 0 else "—")]
		draw_string(font, origin + Vector2(30, y), txt, HORIZONTAL_ALIGNMENT_LEFT, 260, 20, color)
		y += 26
		i += 1
