class_name CombatRig
extends Node2D
## On-map attack presentation (battle direction v2, take 2 — Neal's call). NO
## articulated arm: the unit's flat MAP sprite is kept as-is, a weapon sprite
## swings through an arc near its hand, and the WHOLE sprite lunges + tilts with
## the swing so it reads as a real attack without rigging. Ranged weapons (bow/
## tome) don't swing — they loose/cast and a projectile flies to the target.
## Emits `impact` at the strike so the juice syncs the hit. Uses the cheap map
## sprite, so it works for the whole cast with no new art beyond the weapon lib.

signal impact

const MAP_DIR := "res://assets/sprites/units/%s"
const WEAPONS_DIR := "res://assets/art/cutout/weapons"
const HAND := Vector2(5, 3)   # grip point on the map sprite (from its center)
const PROJ_TIME := 0.28       # projectile travel time (impact syncs to arrival)

# per weapon type: [source, grip offset on the weapon sprite, rest rotation]
# [source, grip point on the weapon sprite, rest rotation, scale]
const WEAPON_CFG := {
	WeaponDef.WeaponType.SWORD: ["kai_sword", Vector2(0, 9), -0.5, 0.42],
	WeaponDef.WeaponType.LANCE: ["lib/lance", Vector2(6, 3), -0.35, 0.26],
	WeaponDef.WeaponType.AXE:   ["lib/axe", Vector2(8, 11), -0.4, 0.30],
	WeaponDef.WeaponType.BOW:   ["lib/bow", Vector2(23, 15), 1.55, 0.30],
	WeaponDef.WeaponType.TOME:  ["lib/tome", Vector2(18, 13), 0.0, 0.34],
	WeaponDef.WeaponType.STAFF: ["lib/staff", Vector2(7, 55), 0.1, 0.30],
}

var _unit_id := "kai"
var _body: Sprite2D
var _pivot: Node2D
var _weapon: Sprite2D
var _fx: Node2D
var _fx_items: Array = []
var _rest_rot := -0.5


static func has_rig(unit_id: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/units/%s/walk_f1.png" % unit_id)


func setup(unit_id: String, facing_right: bool, rig_scale: float) -> void:
	_unit_id = unit_id
	scale = Vector2((1.0 if facing_right else -1.0) * rig_scale, rig_scale)
	_body = Sprite2D.new()
	# prefer a weaponless combat body (the map sprite with its baked-in weapon
	# removed) so the swung weapon isn't doubled; fall back to the walk frame.
	var wl := "res://assets/art/cutout/%s/body_map.png" % unit_id
	_body.texture = load(wl) if ResourceLoader.exists(wl) else load(MAP_DIR % unit_id + "/walk_f1.png")
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_body)
	_pivot = Node2D.new()
	_pivot.position = HAND
	add_child(_pivot)
	_weapon = Sprite2D.new()
	_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pivot.add_child(_weapon)
	_fx = Node2D.new()
	_fx.z_index = 6
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func set_weapon(weapon_type: int) -> void:
	var cfg: Array = WEAPON_CFG.get(weapon_type, WEAPON_CFG[WeaponDef.WeaponType.SWORD])
	var src: String = cfg[0]
	var path := ""
	if src.begins_with("lib/"):
		path = "%s/%s.png" % [WEAPONS_DIR, src.substr(4)]
	elif _unit_id == "kai":
		path = "res://assets/art/cutout/kai/sword.png"  # Kai's signature green blade
	else:
		path = "%s/sword.png" % WEAPONS_DIR
	if ResourceLoader.exists(path):
		_weapon.texture = load(path)
	# scale the weapon to the map sprite (per-weapon; library weapons run big)
	var wsc: float = cfg[3] if cfg.size() > 3 else 0.42
	_weapon.scale = Vector2(wsc, wsc)
	_weapon.centered = false
	_weapon.position = -cfg[1] * wsc   # grip at the pivot
	_rest_rot = cfg[2]
	_pivot.rotation = _rest_rot


func _process(delta: float) -> void:
	var alive := []
	for it in _fx_items:
		it["age"] += delta
		if it["age"] < it["life"]:
			alive.append(it)
	_fx_items = alive
	_fx.queue_redraw()


func play_attack(weapon_type: int, reach := 120.0) -> void:
	match weapon_type:
		WeaponDef.WeaponType.LANCE:
			await _stab()
		WeaponDef.WeaponType.BOW:
			await _shoot(reach)
		WeaponDef.WeaponType.TOME:
			await _magic(reach)
		WeaponDef.WeaponType.STAFF:
			await _heal()
		_:
			await _swing(weapon_type == WeaponDef.WeaponType.AXE)


## Lance: a THRUST, not a swing — level the point forward and drive the whole
## sprite in hard, then pull back.
func _stab() -> void:
	var wind := create_tween().set_parallel(true)
	wind.tween_property(_pivot, "rotation", _rest_rot - 0.25, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	wind.tween_property(_body, "rotation", -0.08, 0.18).set_trans(Tween.TRANS_SINE)
	wind.tween_property(self, "position:x", position.x - 14.0 * scale.x, 0.18)
	await wind.finished
	var hx := position.x
	var hit := create_tween().set_parallel(true)
	hit.tween_property(_pivot, "rotation", _rest_rot + 0.15, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_body, "rotation", 0.06, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(self, "position:x", hx + 58.0 * scale.x, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hit.finished
	_thrust_streak()
	impact.emit()
	await get_tree().create_timer(0.09).timeout
	await _recover(hx)


## Melee: the weapon arcs and the whole sprite lunges + tilts with it. `heavy`
## (axe) winds bigger and lands harder.
func _swing(heavy: bool) -> void:
	var back := -2.0 if heavy else -1.6
	var thru := 1.5 if heavy else 1.3
	var wind := create_tween().set_parallel(true)
	wind.tween_property(_pivot, "rotation", _rest_rot + back, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	wind.tween_property(_body, "rotation", -0.22, 0.20).set_trans(Tween.TRANS_SINE)
	wind.tween_property(self, "position:x", position.x - 12.0 * scale.x, 0.20)
	await wind.finished
	var hx := position.x
	var hit := create_tween().set_parallel(true)
	hit.tween_property(_pivot, "rotation", _rest_rot + thru, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_body, "rotation", 0.24, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(self, "position:x", hx + 40.0 * scale.x, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await hit.finished
	_slash_trail(heavy)
	impact.emit()
	await get_tree().create_timer(0.12 if heavy else 0.08).timeout
	await _recover(hx)


func _shoot(reach: float) -> void:
	# draw back (body leans), hold, loose — the arrow streaks the full gap
	var w := create_tween().set_parallel(true)
	w.tween_property(_pivot, "rotation", _rest_rot - 0.35, 0.26).set_trans(Tween.TRANS_SINE)
	w.tween_property(_body, "rotation", -0.1, 0.26).set_trans(Tween.TRANS_SINE)
	w.tween_property(self, "position:x", position.x - 6.0 * scale.x, 0.26)
	await w.finished
	await get_tree().create_timer(0.14).timeout
	_pivot.rotation = _rest_rot
	_projectile(reach, "arrow")
	await get_tree().create_timer(PROJ_TIME).timeout
	impact.emit()
	await get_tree().create_timer(0.08).timeout
	await _recover(position.x)


func _magic(reach: float) -> void:
	# structured like _shoot (which renders reliably): a parallel wind tween
	var w := create_tween().set_parallel(true)
	w.tween_property(_pivot, "rotation", _rest_rot - 0.3, 0.28).set_trans(Tween.TRANS_SINE)
	w.tween_property(_body, "rotation", -0.06, 0.28).set_trans(Tween.TRANS_SINE)
	await w.finished
	_cast_gather()
	await get_tree().create_timer(0.26).timeout
	_pivot.rotation = _rest_rot
	_projectile(reach, "bolt")
	await get_tree().create_timer(PROJ_TIME).timeout
	impact.emit()
	_cast_burst_at(reach)
	await get_tree().create_timer(0.14).timeout
	await _recover(position.x)


func _heal() -> void:
	var w := create_tween()
	w.tween_property(_pivot, "rotation", _rest_rot - 0.5, 0.26).set_trans(Tween.TRANS_SINE)
	await w.finished
	_cast_gather()
	await get_tree().create_timer(0.26).timeout
	impact.emit()
	_heal_bloom()
	await get_tree().create_timer(0.3).timeout
	await _recover(position.x)


func _recover(hx: float) -> void:
	var r := create_tween().set_parallel(true)
	r.tween_property(_pivot, "rotation", _rest_rot, 0.26).set_trans(Tween.TRANS_SINE)
	r.tween_property(_body, "rotation", 0.0, 0.26).set_trans(Tween.TRANS_SINE)
	r.tween_property(self, "position:x", hx, 0.26).set_trans(Tween.TRANS_SINE)
	await r.finished


# --- fx ---------------------------------------------------------------------

func _tip() -> Vector2:
	return _fx.to_local(_pivot.global_position)

func _slash_trail(heavy: bool) -> void:
	_fx_items.append({"kind": "slash", "pos": _tip(), "age": 0.0, "life": 0.3, "big": heavy})
func _thrust_streak() -> void:
	_fx_items.append({"kind": "streak", "pos": _tip(), "age": 0.0, "life": 0.22})
func _cast_gather() -> void:
	_fx_items.append({"kind": "gather", "pos": _tip(), "age": 0.0, "life": 0.3})
func _projectile(reach: float, style: String) -> void:
	var from := _tip()
	_fx_items.append({"kind": "proj", "pos": from, "to": from + Vector2(reach, -8),
		"style": style, "age": 0.0, "life": PROJ_TIME})
func _cast_burst_at(reach: float) -> void:
	_fx_items.append({"kind": "tburst", "pos": _tip() + Vector2(reach, -8), "age": 0.0, "life": 0.28})
func _heal_bloom() -> void:
	_fx_items.append({"kind": "heal", "pos": _fx.to_local(global_position) + Vector2(0, -6),
		"age": 0.0, "life": 0.5})

func _draw_fx() -> void:
	for it in _fx_items:
		var t: float = it["age"] / it["life"]
		var a := 1.0 - t
		match it["kind"]:
			"slash":
				var rr := (18.0 if it.get("big", false) else 14.0)
				for k in range(3):
					_fx.draw_arc(it["pos"], rr + k * 5.0, -1.7 + t * 2.4, 0.9 + t * 2.4, 20,
						Color(0.85, 1.0, 0.9, a * 0.85), 3.0 - k)
			"streak":
				for k in range(3):
					_fx.draw_line(it["pos"] + Vector2(0, k*3-3), it["pos"] + Vector2(46, k*3-3),
						Color(1,1,0.88,a), 2.6 - k*0.6)
			"gather":
				_fx.draw_circle(it["pos"], 12.0 * (1.0 - t), Color(0.85,0.75,1.0,a))
			"proj":
				var cur: Vector2 = (it["pos"] as Vector2).lerp(it["to"], t)
				if it["style"] == "bolt":
					_fx.draw_circle(cur, 8.0, Color(0.6,0.4,0.95, 0.9))
					_fx.draw_circle(cur, 4.0, Color(0.92,0.85,1.0, 1.0))
				else:
					_fx.draw_line(cur - Vector2(22,0), cur, Color(0.95,0.92,0.8,0.95), 2.5)
					_fx.draw_line(cur, cur - Vector2(7,4), Color(0.8,0.78,0.7,1.0), 2.5)
					_fx.draw_line(cur, cur - Vector2(7,-4), Color(0.8,0.78,0.7,1.0), 2.5)
			"heal":
				for k in range(3):
					_fx.draw_arc(it["pos"], 14.0 + t*40.0 + k*10.0, 0.0, TAU, 26,
						Color(0.42,1.0,0.56, a*0.7), 3.0-k)
			"tburst":
				_fx.draw_circle(it["pos"], 8.0 + t*26.0, Color(0.6,0.4,0.95, a*0.7))
				_fx.draw_circle(it["pos"], 4.0 + t*14.0, Color(0.92,0.85,1.0, a*0.9))
