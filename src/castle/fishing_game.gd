class_name FishingGame
extends Node2D
## WO-6.4: the waterside fishing mini-game (§4's flagship activity).
## Cast → the bobber sits → a bite flashes "!" → strike inside the window
## to land it. Pure timing game; catches go to the campaign's fish log.

signal finished(result: Dictionary)  # {caught: bool, fish: String}

## name -> weight. The Warded Coin is a lore tease, not a fish at all.
const CATCH_TABLE := {
	"Lakeperch": 60, "Silver Dace": 25, "Vael Kingfish": 12, "Warded Coin": 3,
}
const BITE_WINDOW := 0.55

## The float's sway: how far it dips under the water line, and how fast it
## rocks. It rides its own clock, so the sway never snaps when the phase
## changes under it (the bite window restarts the phase timer).
const BOB_AMPLITUDE := 3.0
const BOB_SPEED := 3.0
## The "!" marker rides this far above the float; the x nudge centres the
## glyph over the bobber.
const MARKER_OFFSET := Vector2(-12, -70)
## The castle gives the cast no other briefing — say the keys once, small.
const STRIKE_HINT := "Space / Enter — strike when the ! appears"

enum Phase { WAITING, BITE, DONE }

var phase: int = Phase.WAITING
var _rng := RandomNumberGenerator.new()
var _timer := 0.0      # time spent in the current phase (the bite window)
var _elapsed := 0.0    # total time since the cast — drives the float's sway
var _bite_at := 0.0
var _water_y := 0.0
var _bob_x := 0.0
var _label: Label
var _hint: Label


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()


func _ready() -> void:
	var vp := get_viewport_rect().size
	_water_y = vp.y * 0.52
	_bob_x = vp.x * 0.62
	_bite_at = _rng.randf_range(0.9, 3.2)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_label.add_theme_constant_override("outline_size", 7)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the cast is not a click target
	_label.position = _bobber_position() + MARKER_OFFSET
	_label.visible = false
	add_child(_label)
	_hint = Label.new()
	_hint.text = STRIKE_HINT
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(0.95, 0.89, 0.62))
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_hint.add_theme_constant_override("outline_size", 5)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(24, vp.y - 30)
	add_child(_hint)


func _process(delta: float) -> void:
	tick(delta)
	queue_redraw()


## Advance the state machine (called by _process; tests drive it directly).
func tick(delta: float) -> void:
	if phase == Phase.DONE:
		return
	_elapsed += delta
	_timer += delta
	if phase == Phase.WAITING and _timer >= _bite_at:
		phase = Phase.BITE
		_timer = 0.0
		if _label != null:
			_label.text = "!"
			_label.visible = true
			_update_label_position()
	elif phase == Phase.BITE:
		_update_label_position()
		if _timer > BITE_WINDOW:
			_finish(false)


## The float's current on-screen position — shared by the drawing and the bite
## marker. Driven by the cast clock, not the phase timer, so the float keeps
## rocking smoothly when the bite restarts the phase timer.
func _bobber_position() -> Vector2:
	return Vector2(_bob_x, _water_y + sin(_elapsed * BOB_SPEED) * BOB_AMPLITUDE)


## Keep the "!" marker pinned above the bobbing float while the bite is live.
func _update_label_position() -> void:
	if _label != null and _label.visible:
		_label.position = _bobber_position() + MARKER_OFFSET


## The player strikes (confirm). Catch iff we're inside the bite window.
func strike() -> void:
	if phase == Phase.BITE:
		_finish(true)
	elif phase == Phase.WAITING:
		_finish(false)  # struck at nothing — scared it off


func roll_catch() -> String:
	var total := 0
	for w in CATCH_TABLE.values():
		total += w
	var pick := _rng.randi_range(1, total)
	var acc := 0
	for fish in CATCH_TABLE:
		acc += CATCH_TABLE[fish]
		if pick <= acc:
			return fish
	return "Lakeperch"


func _finish(caught: bool) -> void:
	phase = Phase.DONE
	# the cast is over — the marker and the briefing go with it
	if _label != null:
		_label.visible = false
	if _hint != null:
		_hint.visible = false
	var result := {"caught": caught, "fish": roll_catch() if caught else ""}
	if caught:
		var log: Dictionary = Campaign.fish_log
		log[result["fish"]] = int(log.get(result["fish"], 0)) + 1
	finished.emit(result)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("cursor_confirm"):
		strike()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if phase == Phase.DONE:
		return
	# the line and bobber, floating on the painted lake
	var bob := _bobber_position()
	draw_line(Vector2(_bob_x - 90.0, _water_y - 120.0), bob, Color(0.9, 0.9, 0.95, 0.8), 2.0)
	draw_circle(bob, 7.0, Color(0.9, 0.25, 0.2))
	draw_circle(bob + Vector2(0, -4), 3.0, Color(0.98, 0.95, 0.9))
