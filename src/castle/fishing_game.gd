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

enum Phase { WAITING, BITE, DONE }

var phase: int = Phase.WAITING
var _rng := RandomNumberGenerator.new()
var _timer := 0.0
var _bite_at := 0.0
var _water_y := 0.0
var _bob_x := 0.0
var _label: Label


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
	_label.position = Vector2(_bob_x - 12, _water_y - 70)
	_label.visible = false
	add_child(_label)


func _process(delta: float) -> void:
	tick(delta)
	queue_redraw()


## Advance the state machine (called by _process; tests drive it directly).
func tick(delta: float) -> void:
	if phase == Phase.DONE:
		return
	_timer += delta
	if phase == Phase.WAITING and _timer >= _bite_at:
		phase = Phase.BITE
		_timer = 0.0
		if _label != null:
			_label.text = "!"
			_label.visible = true
	elif phase == Phase.BITE and _timer > BITE_WINDOW:
		_finish(false)


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
	var bob := Vector2(_bob_x, _water_y + sin(_timer * 3.0) * 3.0)
	draw_line(Vector2(_bob_x - 90.0, _water_y - 120.0), bob, Color(0.9, 0.9, 0.95, 0.8), 2.0)
	draw_circle(bob, 7.0, Color(0.9, 0.25, 0.2))
	draw_circle(bob + Vector2(0, -4), 3.0, Color(0.98, 0.95, 0.9))
