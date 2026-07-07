extends Node2D
## Cut-out animation PROTOTYPE (Neal's playtest-3 direction): Kai as a rigged
## puppet instead of pre-rendered frames. His sprite is split into body / hand /
## weapon; the weapon is a SWAPPABLE sprite on a hand pivot, and attacks are
## code-driven tween clips (a sword-slash and a lance-thrust) — the same body
## rig, different motion per weapon type. This is the Darkest-Dungeon / Banner
## Saga approach: smooth, tunable, and weapon-swap-native.

const DIR := "res://assets/art/cutout/kai"
# key points in the ORIGINAL 166x162 frame's pixel space (from the exact reassembly)
const HIP := Vector2(80, 118)
const WRIST := Vector2(90, 90)
const GRIP := Vector2(92, 93)
const HAND_ORIGIN := Vector2(86, 87)
const SWORD_ORIGIN := Vector2(86, 86)
const RIG_SCALE := 4.0

var _root: Node2D
var _lean: Node2D
var _wrist: Node2D
var _mount: Node2D
var _sword: Sprite2D
var _lance: Sprite2D
var _label: Label
var _trail: Node2D
var _trail_t := 0.0
var _using_lance := false
var _t := 0.0
var _base_pos: Vector2


func _ready() -> void:
	_root = Node2D.new()
	# the body frame draws down-right from the root; place it so Kai is centered
	# with room to lunge right
	_base_pos = Vector2(150, 40)
	_root.position = _base_pos
	_root.scale = Vector2.ONE * RIG_SCALE
	add_child(_root)

	_lean = Node2D.new()
	_lean.position = HIP
	_root.add_child(_lean)

	var body := Sprite2D.new()
	body.texture = load("%s/body_raw.png" % DIR)
	body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.position = -HIP
	_lean.add_child(body)

	_wrist = Node2D.new()
	_wrist.position = WRIST - HIP
	_lean.add_child(_wrist)

	_mount = Node2D.new()
	_mount.position = GRIP - WRIST
	_wrist.add_child(_mount)

	_sword = Sprite2D.new()
	_sword.texture = load("%s/sword.png" % DIR)
	_sword.centered = false
	_sword.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sword.position = SWORD_ORIGIN - GRIP
	_mount.add_child(_sword)

	_lance = Sprite2D.new()
	_lance.texture = load("%s/lance.png" % DIR)
	_lance.centered = false
	_lance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_lance.position = Vector2(-5, -10)
	_lance.rotation = -0.35
	_lance.visible = false
	_mount.add_child(_lance)

	var hand := Sprite2D.new()
	hand.texture = load("%s/hand.png" % DIR)
	hand.centered = false
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand.position = HAND_ORIGIN - WRIST
	_wrist.add_child(hand)  # hand draws over the weapon grip

	_trail = Node2D.new()
	_trail.z_index = 5
	_trail.draw.connect(_draw_trail)
	_root.add_child(_trail)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(40, 30)
	add_child(_label)

	_demo_loop()


func _process(delta: float) -> void:
	_t += delta
	# gentle idle breathing (non-accumulating; attacks only tween position:x)
	_root.position.y = _base_pos.y + sin(_t * 2.2) * 3.0
	if _trail_t > 0.0:
		_trail_t -= delta * 3.0
		_trail.queue_redraw()


# --- clips -----------------------------------------------------------------

func _reset_pose() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lean, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_wrist, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_root, "position:x", _root.position.x, 0.25)
	await tw.finished


func sword_slash() -> void:
	var hx := _root.position.x
	# wind-up: lean back, raise the blade
	var wind := create_tween().set_parallel(true)
	wind.tween_property(_lean, "rotation", -0.35, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	wind.tween_property(_wrist, "rotation", -1.5, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await wind.finished
	# strike: step in and slash down-forward, fast
	var hit := create_tween().set_parallel(true)
	hit.tween_property(_root, "position:x", hx + 46, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_lean, "rotation", 0.30, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_wrist, "rotation", 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hit.finished
	_trail_t = 1.0
	_trail.queue_redraw()
	await get_tree().create_timer(0.06).timeout
	# recover
	var rec := create_tween().set_parallel(true)
	rec.tween_property(_root, "position:x", hx, 0.30).set_trans(Tween.TRANS_SINE)
	rec.tween_property(_lean, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	rec.tween_property(_wrist, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	await rec.finished


func lance_thrust() -> void:
	var hx := _root.position.x
	# wind-up: coil back
	var wind := create_tween().set_parallel(true)
	wind.tween_property(_root, "position:x", hx - 16, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	wind.tween_property(_lean, "rotation", -0.12, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	wind.tween_property(_wrist, "rotation", -0.35, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await wind.finished
	# strike: explosive lunge, lance levels forward
	var hit := create_tween().set_parallel(true)
	hit.tween_property(_root, "position:x", hx + 60, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_lean, "rotation", 0.08, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_wrist, "rotation", 0.15, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hit.finished
	_trail_t = 1.0
	_trail.queue_redraw()
	await get_tree().create_timer(0.07).timeout
	var rec := create_tween().set_parallel(true)
	rec.tween_property(_root, "position:x", hx, 0.30).set_trans(Tween.TRANS_SINE)
	rec.tween_property(_lean, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	rec.tween_property(_wrist, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	await rec.finished


func swap_weapon(to_lance: bool) -> void:
	_using_lance = to_lance
	_sword.visible = not to_lance
	_lance.visible = to_lance


func _draw_trail() -> void:
	if _trail_t <= 0.0:
		return
	# a slash afterglow arc centered on the weapon hand
	var c := _trail.to_local(_wrist.global_position)
	if _using_lance:
		# thrust: a forward speed streak, not an arc
		var col := Color(1, 1, 0.85, _trail_t * 0.7)
		for k in range(3):
			_trail.draw_line(c + Vector2(6, k * 4 - 4), c + Vector2(62, k * 4 - 4), col, 3.0 - k * 0.6)
	else:
		var col := Color(0.6, 1.0, 0.7, _trail_t * 0.8)
		for k in range(3):
			_trail.draw_arc(c, 40.0 - k * 8.0, -1.2, 0.9, 20, col, 4.0 - k)


# --- demo -----------------------------------------------------------------

func _demo_loop() -> void:
	await get_tree().create_timer(0.6).timeout
	while true:
		swap_weapon(false)
		_label.text = "Kai  —  SWORD (slash clip)"
		for i in 2:
			await sword_slash()
			await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.4).timeout
		swap_weapon(true)
		_label.text = "Kai  —  LANCE (thrust clip)   ← same rig, weapon swapped"
		for i in 2:
			await lance_thrust()
			await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.6).timeout
