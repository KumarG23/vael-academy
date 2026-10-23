class_name ExchangeSkipInput
extends CanvasLayer
## WO-9.5 (#65/#75): Esc skips; a fresh held Space plays at 2× until release.
## Only fresh presses while armed count. Space edges/echoes and cancel input
## are consumed while armed; cancel echoes/releases never skip. Outside
## an exchange this layer is inert, so menus, dialogue, level-up and results
## keep their own input. The press is consumed in `_input`, before the GUI,
## cursor or any overlay can see it.

const HINT := "Space  Hold 2×    Esc  Skip"
const ACTIVE_HINT := "Space  2× ACTIVE    Esc  Skip"
const FONT_SIZE := 18
const MARGIN := 16.0
## Top-right, below every presenter's top chrome: map objective (y 10–34),
## popup name plates (22–62), illustrated letterbox (0–48). The bottom-right
## corner holds the illustrated/popup HP plates.
const TOP := 72.0
const PAD := Vector2(28, 0)
## The noble frame needs room for both 22 px corners plus a middle row.
const MIN_HEIGHT := 2.0 * UITheme.DST_MARGIN + 18.0

var _pace: ExchangeSkip = null
var _hint: Control
var _compact := false
var _font_size := FONT_SIZE
var _padding := PAD.x


func _ready() -> void:
	layer = 70  # above the illustrated stage (60), popup and dialogue layers
	_hint = Control.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	_hint.draw.connect(_draw_hint)
	add_child(_hint)
	get_viewport().size_changed.connect(_place_hint)
	_place_hint()


func is_armed() -> bool:
	return _pace != null


func hint_rect() -> Rect2:
	return Rect2(_hint.position, _hint.size)


func hint_visible() -> bool:
	return _hint.visible


## Arm for one exchange. The press only ever skips this `pace`.
func arm(pace: ExchangeSkip) -> void:
	if _pace != null:
		_pace.set_fast(false)
	_pace = pace
	_pace.set_fast(false)
	_hint.visible = true
	_place_hint()


func disarm() -> void:
	if _pace != null:
		_pace.set_fast(false)
	_pace = null
	_hint.visible = false


func _exit_tree() -> void:
	if _pace != null:
		_pace.set_fast(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _pace != null:
		_pace.set_fast(false)
		if _hint != null:
			_hint.queue_redraw()


func _input(event: InputEvent) -> void:
	if _pace != null and event is InputEventKey and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		get_viewport().set_input_as_handled()
		if not event.echo:
			_pace.set_fast(event.pressed)
			_hint.queue_redraw()
		return
	if _pace == null or not event.is_action("cursor_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not event.is_action_pressed("cursor_cancel"):  # release / held echo
		return
	_hint.visible = false
	# Deferred: the remaining presentation finishes outside input dispatch.
	_pace.request.call_deferred()


## Compact stages scale the actors down, but the hint stays at readable UI
## size. Stack its controls to avoid spreading across the right actor's face.
func _hint_lines(active: bool) -> PackedStringArray:
	if _compact:
		return PackedStringArray(["2× ACTIVE" if active else "Hold Space 2×", "Esc  Skip"])
	return PackedStringArray([ACTIVE_HINT if active else HINT])


func _place_hint() -> void:
	if _hint == null:
		return
	var viewport := get_viewport().get_visible_rect().size
	_compact = viewport.x < 1000.0
	_font_size = 16 if _compact else FONT_SIZE
	_padding = UITheme.DST_MARGIN if _compact else PAD.x
	var font := UITheme.font()
	var width := 0.0
	for active: bool in [false, true]:
		for line: String in _hint_lines(active):
			width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x)
	var height := font.get_height(_font_size) * _hint_lines(false).size()
	_hint.size = Vector2(width + _padding * 2.0, maxf(96.0 if _compact else MIN_HEIGHT, height + 12.0)).ceil()
	_hint.position = Vector2(viewport.x - _hint.size.x - MARGIN, 64.0 if _compact else TOP).floor()
	_hint.queue_redraw()


func _draw_hint() -> void:
	var lines := _hint_lines(_pace != null and _pace.speed > 1.0)
	var rect := Rect2(Vector2.ZERO, _hint.size)
	UITheme.draw_panel(_hint, rect)
	var font := UITheme.font()
	var line_height := font.get_height(_font_size)
	var baseline := (_hint.size.y - line_height * lines.size()) * 0.5 + font.get_ascent(_font_size)
	for line: String in lines:
		_hint.draw_string_outline(font, Vector2(_padding, baseline), line, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 4, Color.BLACK)
		_hint.draw_string(font, Vector2(_padding, baseline), line, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, UITheme.GOLD)
		baseline += line_height
