class_name CombatRig
extends Node2D
## On-map cut-out attack rig (battle direction v2). A unit's flat map sprite is
## swapped for this during an attack: an articulated puppet (body + shoulder-
## pivoted arm + hand + swappable weapon) that plays a one-shot slash / thrust /
## cast clip and emits `impact` at the strike frame so the juice syncs the hit.
## Built from the unit's existing detailed idle parts under assets/art/cutout/<id>/
## (zero new generation — reuses the retired battle-kit idle). Falls back to the
## flat lunge for units without cut-out parts (has_rig == false).

signal impact

const ROOT := "res://assets/art/cutout/%s"
# key points in the source idle frame's pixel space (Kai's rig)
const HIP := Vector2(80, 118)
const SHOULDER := Vector2(100, 74)
const ARM_SPRITE_PIVOT := Vector2(7, 3)
const WRIST_IN_ARM := Vector2(7, 26)
const REST_ARM := 0.35
const FEET := Vector2(84, 122)   # figure's feet in frame space (anchor to the tile)

var _lean: Node2D
var _shoulder: Node2D
var _arm: Sprite2D
var _wrist: Node2D
var _mount: Node2D
var _weapon: Sprite2D
var _hand: Sprite2D
var _fx: Node2D
var _fx_items: Array = []
var _facing := 1.0


static func has_rig(unit_id: String) -> bool:
	return ResourceLoader.exists("res://assets/art/cutout/%s/body_v2.png" % unit_id)


## Build the rig for a unit, facing the target, sized to the map (rig_scale ~1.5).
func setup(unit_id: String, facing_right: bool, rig_scale: float) -> void:
	var dir := ROOT % unit_id
	_facing = 1.0 if facing_right else -1.0
	scale = Vector2(_facing * rig_scale, rig_scale)
	# anchor the figure's feet at this node's origin (the tile)
	_lean = Node2D.new()
	_lean.position = HIP - FEET
	add_child(_lean)
	var body := _spr("%s/body_v2.png" % dir, -HIP)
	_lean.add_child(body)
	_shoulder = Node2D.new()
	_shoulder.position = SHOULDER - HIP
	_shoulder.rotation = REST_ARM
	_lean.add_child(_shoulder)
	_arm = _spr("%s/upper_arm.png" % dir, -ARM_SPRITE_PIVOT)
	_shoulder.add_child(_arm)
	_wrist = Node2D.new()
	_wrist.position = WRIST_IN_ARM - ARM_SPRITE_PIVOT
	_arm.add_child(_wrist)
	_mount = Node2D.new()
	_mount.position = Vector2(2, 3)
	_wrist.add_child(_mount)
	_weapon = _spr("%s/sword.png" % dir, Vector2(-8, -6))
	_mount.add_child(_weapon)
	_hand = _spr("%s/hand.png" % dir, Vector2(-6, -3))
	_wrist.add_child(_hand)
	_fx = Node2D.new()
	_fx.z_index = 6
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _spr(path: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = pos
	return s


func set_weapon(weapon_type: int) -> void:
	# swap the blade sprite by weapon type when the art exists (else keep the sword)
	var name := "sword"
	match weapon_type:
		WeaponDef.WeaponType.LANCE:
			name = "lance"
		WeaponDef.WeaponType.AXE:
			name = "axe"
		WeaponDef.WeaponType.BOW:
			name = "bow"
		WeaponDef.WeaponType.TOME:
			name = "tome"
		WeaponDef.WeaponType.STAFF:
			name = "staff"
	var p := ROOT % ("%s/%s.png" % [_current_unit(), name])
	if ResourceLoader.exists(p):
		_weapon.texture = load(p)


func _current_unit() -> String:
	return "kai"  # only Kai has parts today; extend as the cast is rigged


func _process(delta: float) -> void:
	var alive := []
	for it in _fx_items:
		it["age"] += delta
		if it["age"] < it["life"]:
			alive.append(it)
	_fx_items = alive
	_fx.queue_redraw()


## Play one attack for a weapon type. Emits `impact` at the strike, awaits the
## whole clip. Melee closes/swings; tome/staff/bow are cast-in-place (no advance).
func play_attack(weapon_type: int) -> void:
	match weapon_type:
		WeaponDef.WeaponType.LANCE:
			await _thrust()
		WeaponDef.WeaponType.TOME, WeaponDef.WeaponType.STAFF, WeaponDef.WeaponType.BOW:
			await _cast()
		_:
			await _slash()


func _slash() -> void:
	var w := create_tween().set_parallel(true)
	w.tween_property(_shoulder, "rotation", -2.3, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	w.tween_property(_wrist, "rotation", -0.7, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	w.tween_property(_lean, "rotation", -0.28, 0.24).set_trans(Tween.TRANS_SINE)
	await w.finished
	var h := create_tween().set_parallel(true)
	h.tween_property(_shoulder, "rotation", 0.9, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	h.tween_property(_wrist, "rotation", 0.5, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	h.tween_property(_lean, "rotation", 0.22, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await h.finished
	_slash_trail()
	impact.emit()
	await get_tree().create_timer(0.1).timeout
	await _recover()


func _thrust() -> void:
	var w := create_tween().set_parallel(true)
	w.tween_property(_shoulder, "rotation", -0.15, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	w.tween_property(_wrist, "rotation", -0.5, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await w.finished
	var h := create_tween()
	h.tween_property(_wrist, "rotation", 0.1, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await h.finished
	_thrust_streak()
	impact.emit()
	await get_tree().create_timer(0.1).timeout
	await _recover()


func _cast() -> void:
	var w := create_tween().set_parallel(true)
	w.tween_property(_shoulder, "rotation", -1.6, 0.28).set_trans(Tween.TRANS_SINE)
	w.tween_property(_wrist, "rotation", -0.3, 0.28).set_trans(Tween.TRANS_SINE)
	await w.finished
	_cast_gather()
	await get_tree().create_timer(0.24).timeout
	impact.emit()
	_cast_burst()
	await get_tree().create_timer(0.24).timeout
	await _recover()


func _recover() -> void:
	var r := create_tween().set_parallel(true)
	r.tween_property(_shoulder, "rotation", REST_ARM, 0.24).set_trans(Tween.TRANS_SINE)
	r.tween_property(_wrist, "rotation", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	r.tween_property(_lean, "rotation", 0.0, 0.24).set_trans(Tween.TRANS_SINE)
	await r.finished


func _wtip() -> Vector2:
	return _fx.to_local(_mount.global_position)

func _slash_trail() -> void:
	_fx_items.append({"kind": "slash", "pos": _fx.to_local(_shoulder.global_position), "age": 0.0, "life": 0.3})
func _thrust_streak() -> void:
	_fx_items.append({"kind": "streak", "pos": _wtip(), "age": 0.0, "life": 0.24})
func _cast_gather() -> void:
	_fx_items.append({"kind": "gather", "pos": _wtip(), "age": 0.0, "life": 0.3})
func _cast_burst() -> void:
	_fx_items.append({"kind": "burst", "pos": _wtip(), "age": 0.0, "life": 0.3})

func _draw_fx() -> void:
	for it in _fx_items:
		var t: float = it["age"] / it["life"]
		var a := 1.0 - t
		match it["kind"]:
			"slash":
				for k in range(3):
					_fx.draw_arc(it["pos"], 30.0 + k * 7.0, -1.9 + t * 2.6, 0.9 + t * 2.6, 22,
						Color(0.7, 1.0, 0.75, a * 0.8), 4.0 - k)
			"streak":
				for k in range(3):
					_fx.draw_line(it["pos"] + Vector2(-6, k*4-4), it["pos"] + Vector2(58, k*4-4), Color(1,1,0.85,a), 3.0-k*0.6)
			"gather":
				_fx.draw_circle(it["pos"], 22.0 * (1.0 - t), Color(0.85,0.75,1.0,a))
			"burst":
				_fx.draw_circle(it["pos"], 14.0 + t * 30.0, Color(0.6,0.4,0.95, a*0.7))
