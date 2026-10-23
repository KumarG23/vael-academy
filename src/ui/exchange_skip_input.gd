class_name ExchangeSkipInput
extends CanvasLayer
## WO-9.5 (#65): Esc / cancel skips the rest of the exchange that is playing.
## Only a fresh press while an exchange is armed counts; echoes and releases of
## the cancel action are swallowed during the exchange and do nothing. Outside
## an exchange this layer is inert, so menus, dialogue, level-up and results
## keep their own input. The press is consumed in `_input`, before the GUI,
## cursor or any overlay can see it.

const HINT := "Esc  Skip"
const FONT_SIZE := 18
const MARGIN := 16.0
const PAD := Vector2(28, 0)
## The noble frame needs room for both 22 px corners plus a middle row.
const MIN_HEIGHT := 2.0 * UITheme.DST_MARGIN + 18.0

var _pace: ExchangeSkip = null
var _hint: Control


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
	_pace = pace
	_hint.visible = true
	_place_hint()


func disarm() -> void:
	_pace = null
	_hint.visible = false


func _input(event: InputEvent) -> void:
	if _pace == null or not event.is_action("cursor_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not event.is_action_pressed("cursor_cancel"):  # release / held echo
		return
	_hint.visible = false
	# Deferred: the remaining presentation finishes outside input dispatch.
	_pace.request.call_deferred()


func _place_hint() -> void:
	if _hint == null:
		return
	var font := UITheme.font()
	var text_size := font.get_string_size(HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	_hint.size = Vector2(text_size.x + PAD.x * 2.0, maxf(MIN_HEIGHT, text_size.y)).ceil()
	var viewport := get_viewport().get_visible_rect().size
	_hint.position = (viewport - _hint.size - Vector2(MARGIN, MARGIN)).floor()
	_hint.queue_redraw()


func _draw_hint() -> void:
	var rect := Rect2(Vector2.ZERO, _hint.size)
	UITheme.draw_panel(_hint, rect)
	var font := UITheme.font()
	var baseline := (_hint.size.y - font.get_height(FONT_SIZE)) * 0.5 + font.get_ascent(FONT_SIZE)
	_hint.draw_string_outline(font, Vector2(PAD.x, baseline), HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color.BLACK)
	_hint.draw_string(font, Vector2(PAD.x, baseline), HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, UITheme.GOLD)
