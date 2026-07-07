extends Node2D
## Cut-out animation PROTOTYPE v2 (on-map battle direction). Kai as a rigged
## puppet: body + an ARTICULATED arm (shoulder pivot → forearm/hand → weapon).
## The arm swings from the shoulder, so a slash sweeps a real arc and the blade
## TIP travels (v1's tip-doesn't-move fix). The weapon is a swappable sprite on
## the hand; magic is just another weapon (tome) + a CAST clip + a spell VFX —
## same rig. Code-driven tween clips: sword slash, lance thrust, magic cast.

const DIR := "res://assets/art/cutout/kai"
# key points in the 166x162 idle frame's pixel space
const HIP := Vector2(80, 118)
const SHOULDER := Vector2(100, 74)     # front shoulder pivot
const ARM_SPRITE_PIVOT := Vector2(7, 3)   # shoulder point inside upper_arm.png
const WRIST_IN_ARM := Vector2(7, 26)      # far end of the sleeve inside upper_arm.png
const RIG_SCALE := 4.0
const REST_ARM := 0.35                  # arm angle at rest (hangs slightly forward)

var _root: Node2D
var _lean: Node2D
var _shoulder: Node2D
var _arm: Sprite2D
var _wrist: Node2D
var _mount: Node2D
var _hand: Sprite2D
var _sword: Sprite2D
var _lance: Sprite2D
var _tome: Sprite2D
var _label: Label
var _fx: Node2D
var _fx_items: Array = []
var _base_pos: Vector2
var _t := 0.0
var _mode := "sword"


func _ready() -> void:
	_root = Node2D.new()
	_base_pos = Vector2(160, 60)
	_root.position = _base_pos
	_root.scale = Vector2.ONE * RIG_SCALE
	add_child(_root)

	_lean = Node2D.new()
	_lean.position = HIP
	_root.add_child(_lean)

	var body := _spr("body_v2.png", -HIP)
	_lean.add_child(body)

	# articulated arm: shoulder → upper arm → wrist → hand + weapon
	_shoulder = Node2D.new()
	_shoulder.position = SHOULDER - HIP
	_shoulder.rotation = REST_ARM
	_lean.add_child(_shoulder)

	_arm = _spr("upper_arm.png", -ARM_SPRITE_PIVOT)
	_shoulder.add_child(_arm)

	_wrist = Node2D.new()
	_wrist.position = WRIST_IN_ARM - ARM_SPRITE_PIVOT  # arm's far end, in shoulder space
	_arm.add_child(_wrist)

	_mount = Node2D.new()
	_mount.position = Vector2(2, 3)
	_wrist.add_child(_mount)

	_sword = _spr("sword.png", Vector2(-8, -6))
	_mount.add_child(_sword)
	_lance = _spr("lance.png", Vector2(-4, -9))
	_lance.rotation = -0.2
	_lance.visible = false
	_mount.add_child(_lance)
	_tome = _spr("tome.png", Vector2(-8, -8))
	_tome.visible = false
	_mount.add_child(_tome)

	_hand = _spr("hand.png", Vector2(-6, -3))
	_wrist.add_child(_hand)  # hand over the grip

	_fx = Node2D.new()
	_fx.z_index = 6
	_fx.draw.connect(_draw_fx)
	_root.add_child(_fx)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.6))
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	_label.add_theme_constant_override("outline_size", 6)
	_label.position = Vector2(40, 28)
	add_child(_label)

	_demo_loop()


func _spr(file: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("%s/%s" % [DIR, file])
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	return s


func _process(delta: float) -> void:
	_t += delta
	_root.position.y = _base_pos.y + sin(_t * 2.2) * 3.0
	# idle arm sway
	if _fx_items.is_empty():
		_shoulder.rotation = REST_ARM + sin(_t * 2.0) * 0.04
	var alive := []
	for it in _fx_items:
		it["age"] += delta
		if it["age"] < it["life"]:
			alive.append(it)
	_fx_items = alive
	if not _fx_items.is_empty() or true:
		_fx.queue_redraw()


# --- clips -----------------------------------------------------------------

func sword_slash() -> void:
	var hx := _root.position.x
	# wind-up: arm raises up-and-back over the shoulder, body coils
	var w := create_tween().set_parallel(true)
	w.tween_property(_shoulder, "rotation", -2.3, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	w.tween_property(_wrist, "rotation", -0.7, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	w.tween_property(_lean, "rotation", -0.28, 0.26).set_trans(Tween.TRANS_SINE)
	await w.finished
	# strike: the whole arm whips down-forward through a big arc, body lunges
	var h := create_tween().set_parallel(true)
	h.tween_property(_shoulder, "rotation", 0.9, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	h.tween_property(_wrist, "rotation", 0.5, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	h.tween_property(_lean, "rotation", 0.22, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	h.tween_property(_root, "position:x", hx + 44, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await h.finished
	_slash_trail()
	await get_tree().create_timer(0.08).timeout
	await _recover(hx)


func lance_thrust() -> void:
	var hx := _root.position.x
	var w := create_tween().set_parallel(true)
	w.tween_property(_shoulder, "rotation", -0.15, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	w.tween_property(_wrist, "rotation", -0.5, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	w.tween_property(_root, "position:x", hx - 14, 0.18)
	await w.finished
	var h := create_tween().set_parallel(true)
	h.tween_property(_wrist, "rotation", 0.1, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	h.tween_property(_root, "position:x", hx + 58, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await h.finished
	_thrust_streak()
	await get_tree().create_timer(0.08).timeout
	await _recover(hx)


func magic_cast() -> void:
	# no advance — cast from where you stand, spell travels
	var w := create_tween().set_parallel(true)
	w.tween_property(_shoulder, "rotation", -1.7, 0.30).set_trans(Tween.TRANS_SINE)
	w.tween_property(_wrist, "rotation", -0.3, 0.30).set_trans(Tween.TRANS_SINE)
	await w.finished
	# gather, then release a bolt
	_cast_gather()
	await get_tree().create_timer(0.30).timeout
	var p := create_tween()
	p.tween_property(_shoulder, "rotation", -0.9, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await p.finished
	_cast_bolt()
	await get_tree().create_timer(0.5).timeout
	await _recover(_root.position.x)


func _recover(hx: float) -> void:
	var r := create_tween().set_parallel(true)
	r.tween_property(_shoulder, "rotation", REST_ARM, 0.30).set_trans(Tween.TRANS_SINE)
	r.tween_property(_wrist, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	r.tween_property(_lean, "rotation", 0.0, 0.30).set_trans(Tween.TRANS_SINE)
	r.tween_property(_root, "position:x", hx, 0.30).set_trans(Tween.TRANS_SINE)
	await r.finished


func swap(mode: String) -> void:
	_mode = mode
	_sword.visible = mode == "sword"
	_lance.visible = mode == "lance"
	_tome.visible = mode == "tome"


# --- fx --------------------------------------------------------------------

func _wtip() -> Vector2:
	return _fx.to_local(_mount.global_position)

func _slash_trail() -> void:
	_fx_items.append({"kind": "slash", "pos": _fx.to_local(_shoulder.global_position), "age": 0.0, "life": 0.32})

func _thrust_streak() -> void:
	_fx_items.append({"kind": "streak", "pos": _wtip(), "age": 0.0, "life": 0.26})

func _cast_gather() -> void:
	_fx_items.append({"kind": "gather", "pos": _wtip(), "age": 0.0, "life": 0.34})

func _cast_bolt() -> void:
	var from := _wtip()
	_fx_items.append({"kind": "bolt", "pos": from, "to": from + Vector2(150, 20), "age": 0.0, "life": 0.42})

func _draw_fx() -> void:
	for it in _fx_items:
		var t: float = it["age"] / it["life"]
		var a := 1.0 - t
		match it["kind"]:
			"slash":
				var c: Vector2 = it["pos"]
				for k in range(3):
					_fx.draw_arc(c, (30.0 + k * 7.0), -1.9 + t * 2.6, 0.9 + t * 2.6, 22,
						Color(0.7, 1.0, 0.75, a * 0.8), 4.0 - k)
			"streak":
				var p: Vector2 = it["pos"]
				for k in range(3):
					_fx.draw_line(p + Vector2(-6, k*4-4), p + Vector2(58, k*4-4), Color(1,1,0.85,a), 3.0-k*0.6)
			"gather":
				var g: Vector2 = it["pos"]
				var rr := 22.0 * (1.0 - t)
				_fx.draw_circle(g, rr + 4, Color(0.55,0.35,0.95, a*0.5))
				_fx.draw_circle(g, rr, Color(0.85,0.75,1.0, a))
			"bolt":
				var cur: Vector2 = (it["pos"] as Vector2).lerp(it["to"], t)
				_fx.draw_circle(cur, 12, Color(0.55,0.35,0.95, 0.9))
				_fx.draw_circle(cur, 7, Color(0.9,0.8,1.0, 1.0))
				_fx.draw_circle(cur - Vector2(18,0), 5, Color(0.55,0.35,0.95, 0.4))


# --- demo ------------------------------------------------------------------

func _demo_loop() -> void:
	await get_tree().create_timer(0.6).timeout
	while true:
		swap("sword")
		_label.text = "Kai — SWORD (slash: arm swings from the shoulder)"
		for i in 2:
			await sword_slash(); await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.3).timeout
		swap("lance")
		_label.text = "Kai — LANCE (thrust)   ← weapon swapped, same rig"
		for i in 2:
			await lance_thrust(); await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(0.3).timeout
		swap("tome")
		_label.text = "Kai — TOME (magic cast: no advance, spell travels)"
		for i in 2:
			await magic_cast(); await get_tree().create_timer(0.4).timeout
		await get_tree().create_timer(0.5).timeout
