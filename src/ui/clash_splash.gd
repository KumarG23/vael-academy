class_name ClashSplash
extends Control
## Full-screen cut-in slammed in on crits and kills (§8 AW-5 / WO-2.5). Until the
## painted per-unit splashes exist, this draws a placeholder: a team-colored
## diagonal band with speed lines. Pure code; consumes real art later with no logic
## change (swap _draw for a TextureRect).

const PLAYER_ACCENT := Color(0.30, 0.55, 0.95)
const ENEMY_ACCENT := Color(0.90, 0.32, 0.30)

var _accent := Color.WHITE
var _label := ""
var _t := 0.0  # 0..1 slam-in progress, then held, then out (drives _draw)
var _active := false
var plays := 0  # total times played (observable for tests)
var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func is_active() -> bool:
	return _active


## Slam the splash in, hold, then fly out. Awaitable via the tween chain.
func play(team: int, label: String, cfg: JuiceConfig, pace: ExchangeSkip = null) -> void:
	_accent = PLAYER_ACCENT if team == 0 else ENEMY_ACCENT
	_label = label
	_active = true
	plays += 1
	visible = true
	_t = 0.0
	var tw := create_tween()
	if pace != null:
		pace.track(tw)
	_tween = tw
	tw.tween_method(_set_t, 0.0, 1.0, cfg.splash_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(cfg.splash_hold)
	tw.tween_method(_set_t, 1.0, 2.0, cfg.splash_out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(_finish)
	await tw.finished


## WO-9.5 (#65): a skipped exchange lands a playing splash at once.
func settle() -> void:
	ExchangeSkip.finish(_tween)
	_tween = null


func _set_t(v: float) -> void:
	_t = v
	queue_redraw()


func _finish() -> void:
	_active = false
	visible = false
	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var vp := get_viewport_rect().size
	# Slide the band across: t in [0,1] eases in from the left, [1,2] flies off right.
	var slide := 0.0
	if _t <= 1.0:
		slide = (1.0 - _t) * -vp.x * 0.5
	else:
		slide = (_t - 1.0) * vp.x
	var band_h := vp.y * 0.42
	var cy := vp.y * 0.5
	var pts := PackedVector2Array([
		Vector2(slide, cy - band_h * 0.5),
		Vector2(slide + vp.x, cy - band_h * 0.5 - 40),
		Vector2(slide + vp.x, cy + band_h * 0.5 + 40),
		Vector2(slide, cy + band_h * 0.5),
	])
	draw_colored_polygon(pts, Color(0.05, 0.05, 0.07, 0.9))
	# Accent edges + speed lines.
	draw_line(pts[0], pts[1], _accent, 4.0)
	draw_line(pts[3], pts[2], _accent, 4.0)
	for i in range(10):
		var y := cy - band_h * 0.4 + band_h * 0.8 * (float(i) / 9.0)
		var a := 0.10 + 0.05 * (i % 2)
		draw_line(Vector2(slide, y), Vector2(slide + vp.x, y), Color(_accent.r, _accent.g, _accent.b, a), 2.0)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(slide + vp.x * 0.12, cy + 18), _label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 56, _accent)
