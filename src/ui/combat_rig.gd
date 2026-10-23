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

## WO-9.5 (#65): the exchange's skippable clock, set by the juice controller.
var pace := ExchangeSkip.new()

## Which way the fighter faces during the action. EAST/WEST use the side sprite
## (WEST is flipped); NORTH/SOUTH use dedicated back/front bodies when the unit
## has them (else they fall back to the side body).
enum Facing { EAST, WEST, NORTH, SOUTH }

const MAP_DIR := "res://assets/sprites/units/%s"
const WEAPONS_DIR := "res://assets/art/cutout/weapons"
const PROJ_TIME := 0.28       # projectile travel time (impact syncs to arrival)

# weapon grip point on the map sprite (from its center), per facing pose
const HAND_GRIP := {
	Facing.EAST: Vector2(5, 3),
	Facing.WEST: Vector2(5, 3),
	Facing.NORTH: Vector2(0, -5),   # up at his shoulders so the raised blade clears the body
	Facing.SOUTH: Vector2(2, 5),
}

# per weapon type: [source, grip point on the weapon sprite (native px), rest rotation]
const WEAPON_CFG := {
	WeaponDef.WeaponType.SWORD: ["kai_sword", Vector2(0, 9), -0.5],
	WeaponDef.WeaponType.LANCE: ["lib/lance", Vector2(6, 3), -0.35],
	WeaponDef.WeaponType.AXE:   ["lib/axe", Vector2(8, 11), -0.4],
	WeaponDef.WeaponType.BOW:   ["lib/bow", Vector2(23, 15), 1.55],
	WeaponDef.WeaponType.TOME:  ["lib/tome", Vector2(18, 13), 0.0],
	WeaponDef.WeaponType.STAFF: ["lib/staff", Vector2(7, 55), 0.1],
}

# Target on-screen length (longest side, in map-sprite px) per weapon type. The
# weapon auto-scales to hit this from its native texture size, so any source —
# library weapon, unique drop, regenerated art — fits a 32px body without hand
# tuning. Keep weapon PNGs tightly cropped (no transparent padding).
const WEAPON_LEN := {
	WeaponDef.WeaponType.SWORD: 16.0,
	WeaponDef.WeaponType.LANCE: 22.0,
	WeaponDef.WeaponType.AXE:   17.0,
	WeaponDef.WeaponType.BOW:   20.0,
	WeaponDef.WeaponType.TOME:  12.0,
	WeaponDef.WeaponType.STAFF: 22.0,
}

# Grip point as a FRACTION of the weapon sprite (x,y in 0..1), so a weapon of any
# size/shape — library or a unique signature — attaches at the right point.
# (These match the old library-weapon pixel grips when divided by their sizes.)
const GRIP_FRAC := {
	WeaponDef.WeaponType.SWORD: Vector2(0.02, 0.45),  # hilt end, mid-height
	WeaponDef.WeaponType.LANCE: Vector2(0.08, 0.5),
	WeaponDef.WeaponType.AXE:   Vector2(0.14, 0.5),
	WeaponDef.WeaponType.BOW:   Vector2(0.5, 0.5),    # held at the bow's middle
	WeaponDef.WeaponType.TOME:  Vector2(0.5, 0.5),
	WeaponDef.WeaponType.STAFF: Vector2(0.5, 0.9),    # gripped near the base
}

var _unit_id := "kai"
# AW-31: the equipped weapon's identity, so FX vary per SPELL/WEAPON, not just
# per caster. CP-1: the look itself now comes from DATA (CombatFxProfile built
# from the UnitDef + WeaponDef fx_* fields) — see set_fx_source().
var _weapon_id := ""
var _fx_profile := CombatFxProfile.new()
var _body: Sprite2D
var _pivot: Node2D
var _weapon: Sprite2D
var _fx: Node2D
var _fx_items: Array = []
var _rest_rot := -0.5
var _facing := Facing.EAST
var _hand := Vector2(5, 3)
var _aim_parent := Vector2.INF   # target position in the rig's PARENT space (for lunges)
var _aim_fx := Vector2.INF        # target position in the FX layer's local space (for hit FX)

# --- CP-1: strike outcome -----------------------------------------------------
# The resolved StrikeResult (crit / miss / kill / damage) drives the motion: a
# crit holds its wind-up and flashes, a miss under-reaches with a dim trail, a
# kill follows through longer, and damage scales the trail. Defaults = a plain
# connecting hit, so play_attack() without an outcome behaves as before.
var _connected := true
var _crit := false
var _kill := false
var _damage := 0
var _crit_hold := 0.14
var _kill_mult := 1.8
var _miss_reach := 0.7

# --- CP-1: high-res 3-pose hook -----------------------------------------------
# Direction pivot (2026-10, Neal): combat moves off the 32px limit toward
# illustrated 2.5D cut-outs (Persona 5 / Expedition 33). When a unit has
# `assets/art/cutout/<id>/idle.png` (+ optional action.png / parry_hit.png),
# the rig swaps POSES instead of only tilting the flat map sprite. Illustrated
# poses carry their weapon in the art, so the swung weapon sprite is hidden.
enum Pose { IDLE, ACTION, PARRY_HIT }
const POSE_FILES := {Pose.IDLE: "idle", Pose.ACTION: "action", Pose.PARRY_HIT: "parry_hit"}
const HIRES_HEIGHT := 52.0   # on-screen height in map-sprite px (a cell is 32) — stands ~1.6 tiles tall
const MAP_FOOT := 16.0       # the 32px map sprite is centered: its feet sit at +16
var _poses := {}             # Pose -> Texture2D; members keep textures alive (gotcha #11)
var _hires := false
var _pose := Pose.IDLE
var _illustrated_kit: IllustratedArt = null
var _illustrated_action := "action"
var _hires_height := HIRES_HEIGHT


static func has_rig(unit_id: String) -> bool:
	return ResourceLoader.exists("res://assets/sprites/units/%s/walk_f1.png" % unit_id) or has_hires(unit_id)


## CP-1: true when the unit has illustrated high-res combat art (at minimum an
## `idle.png`; `action.png` / `parry_hit.png` fall back to idle when absent).
static func has_hires(unit_id: String) -> bool:
	return unit_id != "" and ResourceLoader.exists("res://assets/art/cutout/%s/%s.png" % [unit_id, POSE_FILES[Pose.IDLE]])


## True if the unit has dedicated north/south (back/front) combat bodies, so the
## rig can turn to face a vertical target instead of staying in profile.
static func has_facing(unit_id: String, facing: int) -> bool:
	var suffix := "_n" if facing == Facing.NORTH else ("_s" if facing == Facing.SOUTH else "")
	return suffix != "" and ResourceLoader.exists("res://assets/art/cutout/%s/body_map%s.png" % [unit_id, suffix])


func setup(unit_id: String, facing: int, rig_scale: float, art_dir: String = "", map_height: float = HIRES_HEIGHT) -> void:
	_unit_id = unit_id
	_hires_height = maxf(1.0, map_height)
	_facing = facing
	var flip := -1.0 if facing == Facing.WEST else 1.0
	scale = Vector2(flip * rig_scale, rig_scale)
	_hand = HAND_GRIP.get(facing, HAND_GRIP[Facing.EAST])
	_body = Sprite2D.new()
	_body.texture = _facing_body(unit_id, facing)
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.z_index = 0
	add_child(_body)
	_pivot = Node2D.new()
	_pivot.position = _hand
	# back view: the weapon is on the far side of the fighter, so draw it BEHIND
	# the body (only the raised blade shows above the silhouette) instead of
	# slicing through him. Front/side: weapon in front.
	_pivot.z_index = -1 if facing == Facing.NORTH else 1
	add_child(_pivot)
	_weapon = Sprite2D.new()
	_weapon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pivot.add_child(_weapon)
	_fx = Node2D.new()
	_fx.z_index = 6
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	if art_dir != "":
		_illustrated_kit = IllustratedArt.from_directory(art_dir)
		if _illustrated_kit != null:
			set_pose_textures(_illustrated_kit.texture_for("idle"), _illustrated_kit.texture_for("action"), _illustrated_kit.texture_for("parry_hit"))
			return
	if has_hires(unit_id):
		var tex := {}
		for p in POSE_FILES:
			var path := "res://assets/art/cutout/%s/%s.png" % [unit_id, POSE_FILES[p]]
			if ResourceLoader.exists(path):
				tex[p] = load(path)
		set_pose_textures(tex.get(Pose.IDLE), tex.get(Pose.ACTION), tex.get(Pose.PARRY_HIT))


## The weaponless combat body for a facing: a dedicated back/front body when the
## unit has one, otherwise the weaponless side body, otherwise the raw side walk
## frame. So units without N/S art just keep their profile for vertical attacks.
func _facing_body(unit_id: String, facing: int) -> Texture2D:
	var suffix := "_n" if facing == Facing.NORTH else ("_s" if facing == Facing.SOUTH else "")
	var candidates := [
		"res://assets/art/cutout/%s/body_map%s.png" % [unit_id, suffix],  # weaponless facing
		"res://assets/art/cutout/%s/body_map.png" % unit_id,              # weaponless side
		MAP_DIR % unit_id + "/walk_f1.png",                               # raw side walk frame
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			return load(p)
	return null


# --- CP-1: high-res poses -----------------------------------------------------

## Install illustrated pose textures (setup() does this from the art convention;
## tests and tools may inject their own). `idle` is required — null leaves the
## rig in classic flat-sprite mode. Missing action/parry poses fall back to idle.
func set_pose_textures(idle: Texture2D, action: Texture2D = null, parry_hit: Texture2D = null) -> void:
	_poses = {}
	_hires = idle != null
	if not _hires:
		return
	_poses[Pose.IDLE] = idle
	_poses[Pose.ACTION] = action if action != null else idle
	_poses[Pose.PARRY_HIT] = parry_hit if parry_hit != null else idle
	if _body != null:
		# illustrated art is painted, not pixel art — filter it smoothly
		_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _weapon != null:
		_weapon.visible = false  # the poses hold their weapon in the art
	set_pose(Pose.IDLE)


func is_hires() -> bool:
	return _hires


func current_pose() -> int:
	return _pose


## Swap the body to an illustrated pose, scaled to HIRES_HEIGHT and planted on
## the same foot line as the 32px map sprite. No-op in flat-sprite mode.
func set_pose(pose: int) -> void:
	if not _hires or _body == null:
		return
	_pose = pose
	if _illustrated_kit != null:
		var name: String = _illustrated_action if pose == Pose.ACTION else POSE_FILES.get(pose, "idle")
		_illustrated_kit.apply(_body, name, Vector2(0, MAP_FOOT), _hires_height)
		_pivot.position = Vector2(0, MAP_FOOT) + (_illustrated_kit.hand_for(name) - _illustrated_kit.foot_for(name)) * (_hires_height / _illustrated_kit.source_body_height)
		return
	var tex: Texture2D = _poses.get(pose, _poses[Pose.IDLE])
	_body.texture = tex
	# Legacy injected poses use their opaque bounds instead of transparent
	# canvas edges. Production pilot kits specify shared scale + foot anchors.
	var bounds := tex.get_image().get_used_rect()
	var idle_tex: Texture2D = _poses[Pose.IDLE]
	var idle_bounds := idle_tex.get_image().get_used_rect()
	var s := _hires_height / maxf(1.0, float(idle_bounds.size.y))
	_body.scale = Vector2(s, s)
	var anchor := Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.end.y)
	_body.centered = false
	_body.offset = -anchor
	_body.position = Vector2(0, MAP_FOOT)


# --- CP-1: data-driven FX + strike outcome ------------------------------------

## Resolve this attack's look from DATA: the attacker's UnitDef and the weapon
## in hand (CombatFxProfile: weapon → caster → default). Either may be null.
func set_fx_source(unit_def: UnitDef, weapon: WeaponDef) -> void:
	var udef := unit_def
	if udef == null and _unit_id != "":
		var upath := "res://data/units/%s.tres" % _unit_id
		if ResourceLoader.exists(upath):
			udef = load(upath)
	_weapon_id = weapon.id if weapon != null else ""
	_fx_profile = CombatFxProfile.build(udef, weapon)
	if _weapon != null and not _hires:
		_weapon.visible = _fx_profile.show_weapon


## AW-31 compatibility shim (protos/tools): resolves the weapon by id from
## data/weapons/. The school argument is fallback if weapon.fx_style / fx_color unset.
func set_spell_meta(weapon_id: String, school: String = "") -> void:
	var path := "res://data/weapons/%s.tres" % weapon_id
	var w: WeaponDef = load(path) if weapon_id != "" and ResourceLoader.exists(path) else null
	if w == null and (weapon_id != "" or school != ""):
		w = WeaponDef.new()
		w.id = weapon_id
		w.school = school
		w.weapon_type = WeaponDef.WeaponType.TOME if school != "" else WeaponDef.WeaponType.SWORD
	elif w != null and school != "" and w.school == "":
		w.school = school
	set_fx_source(null, w)
	_weapon_id = weapon_id


## Feed the resolved strike into the motion (call before play_attack, or use
## play_strike). `cfg` supplies the outcome-timing knobs; null keeps defaults.
func set_outcome(strike: StrikeResult, is_kill: bool, cfg: JuiceConfig = null) -> void:
	_connected = strike == null or strike.connected
	_crit = strike != null and strike.connected and strike.was_crit
	_kill = is_kill and _connected
	_damage = strike.damage if strike != null and strike.connected else 0
	if cfg != null:
		_crit_hold = cfg.crit_anticipation
		_kill_mult = cfg.kill_follow_through
		_miss_reach = cfg.miss_reach


## One strike, outcome-aware: crit / miss / kill / damage shape the motion.
func play_strike(weapon_type: int, aim_global: Vector2, strike: StrikeResult, is_kill: bool, cfg: JuiceConfig = null) -> void:
	set_outcome(strike, is_kill, cfg)
	await play_attack(weapon_type, aim_global)


## Trail intensity from damage: 1.0 for a scratch, up to 1.6 for a big hit.
func _power() -> float:
	return 1.0 + clampf(float(_damage) / 20.0, 0.0, 0.6)


## Crit anticipation: hold the wind-up and flash the body before the blow lands.
func _crit_beat() -> void:
	if not _crit or _crit_hold <= 0.0:
		return
	_fx_items.append({"kind": "glint", "pos": _tip(), "age": 0.0, "life": _crit_hold + 0.1})
	_body.modulate = Color(1.8, 1.8, 1.6)
	var f := pace.track(create_tween())
	f.tween_property(_body, "modulate", Color.WHITE, _crit_hold)
	await pace.wait(self, _crit_hold)


## Post-impact hold, stretched on a killing blow so the finisher reads.
func _follow_through(base: float) -> void:
	await pace.wait(self, base * (_kill_mult if _kill else 1.0))


func set_weapon(weapon_type: int) -> void:
	var cfg: Array = WEAPON_CFG.get(weapon_type, WEAPON_CFG[WeaponDef.WeaponType.SWORD])
	var src: String = cfg[0]
	var path := ""
	# 1. the unit's own signature weapon (each hero swings their unique arm);
	#    2. Kai's green blade; 3. the shared library weapon for this type.
	var sig := "res://assets/art/cutout/%s/signature.png" % _unit_id
	if ResourceLoader.exists(sig):
		path = sig
	elif _unit_id == "kai" and ResourceLoader.exists("res://assets/art/cutout/kai/sword.png"):
		path = "res://assets/art/cutout/kai/sword.png"
	elif src.begins_with("lib/"):
		path = "%s/%s.png" % [WEAPONS_DIR, src.substr(4)]
	else:
		path = "%s/sword.png" % WEAPONS_DIR
	if ResourceLoader.exists(path):
		_weapon.texture = load(path)
	# auto-scale to the weapon type's target on-screen length from its native
	# size, so weapons of any source size sit right on the 32px body.
	var native := 1.0
	if _weapon.texture != null:
		native = maxf(1.0, float(maxi(_weapon.texture.get_width(), _weapon.texture.get_height())))
	var target: float = WEAPON_LEN.get(weapon_type, 16.0)
	var wsc: float = target / native
	_weapon.scale = Vector2(wsc, wsc)
	_weapon.centered = false
	# grip as a fraction of the ACTUAL weapon size, so any weapon (library or a
	# unique signature of any dimensions) attaches at the right point.
	var tw := native
	var th := native
	if _weapon.texture != null:
		tw = maxf(1.0, float(_weapon.texture.get_width()))
		th = maxf(1.0, float(_weapon.texture.get_height()))
	var gf: Vector2 = GRIP_FRAC.get(weapon_type, Vector2(0.0, 0.5))
	_weapon.position = -Vector2(gf.x * tw, gf.y * th) * wsc
	# bows and tomes are held OUT in front of the body, not on top of it
	if weapon_type == WeaponDef.WeaponType.BOW or weapon_type == WeaponDef.WeaponType.TOME:
		_weapon.position += Vector2(6.0, 0.0)
	# bows/staves are held UPRIGHT; if the art is already tall, don't rotate it
	# (library bow is wide and needs the rotation; signature bows are vertical).
	var rest: float = cfg[2]
	if (weapon_type == WeaponDef.WeaponType.BOW or weapon_type == WeaponDef.WeaponType.STAFF) and th >= tw:
		rest = 0.0
	_rest_rot = rest
	_pivot.rotation = _rest_rot
	# natural weapons (Nilu's claws: WeaponDef.fx_hide_sprite) have no weapon
	# sprite — the lunge + slash arc read as a swipe; hi-res poses carry their
	# weapon in the art.
	_weapon.visible = _fx_profile.show_weapon and not _hires


func _process(delta: float) -> void:
	delta *= pace.speed
	if _fx_items.is_empty():
		return
	var alive := []
	for it in _fx_items:
		it["age"] += delta
		if it["age"] < it["life"]:
			alive.append(it)
	_fx_items = alive
	_fx.queue_redraw()  # one last redraw after the final item expires clears it


## `aim_global` is the target's world position; ranged/cast attacks fly to it and
## melee lunges drive toward it (any direction — up/down/diagonal, not just
## sideways). Pass nothing (Vector2.INF) to fire straight ahead. Call
## set_outcome() first (or use play_strike) for crit/miss/kill-aware motion.
func play_attack(weapon_type: int, aim_global := Vector2.INF, impact_global := Vector2.INF) -> void:
	_illustrated_action = "cast" if weapon_type in [WeaponDef.WeaponType.TOME, WeaponDef.WeaponType.STAFF] else "action"
	var fx_aim: Vector2 = aim_global if is_inf(impact_global.x) or is_inf(impact_global.y) else impact_global
	if not (is_inf(aim_global.x) or is_inf(aim_global.y)) and get_parent() != null:
		_aim_parent = (get_parent() as Node2D).to_local(aim_global)
		_aim_fx = _fx.to_local(fx_aim)
	else:
		_aim_parent = Vector2.INF
		_aim_fx = Vector2.INF
	set_pose(Pose.IDLE)
	match weapon_type:
		WeaponDef.WeaponType.LANCE:
			await _stab()
		WeaponDef.WeaponType.BOW:
			await _shoot(fx_aim)
		WeaponDef.WeaponType.TOME:
			await _magic(fx_aim)
		WeaponDef.WeaponType.STAFF:
			await _heal(fx_aim)
		_:
			await _swing(weapon_type == WeaponDef.WeaponType.AXE)
	set_pose(Pose.IDLE)


## Target in the FX layer's local space (accounts for the rig's scale + facing
## flip). Falls back to a point straight ahead when no aim is supplied.
func _aim_local(aim_global: Vector2) -> Vector2:
	if is_inf(aim_global.x) or is_inf(aim_global.y):
		return _tip() + Vector2(120, -8)
	return _fx.to_local(aim_global)


## Unit vector (in PARENT space) from the rig toward the target tile, so a lunge
## drives at the real target — up, down, or diagonal — not just sideways. Falls
## back to the facing direction when no target was supplied.
func _lunge_dir() -> Vector2:
	if is_inf(_aim_parent.x) or is_inf(_aim_parent.y):
		return Vector2(signf(scale.x), 0.0)
	var d := _aim_parent - position
	return d.normalized() if d.length() > 1.0 else Vector2(signf(scale.x), 0.0)


## Angle (rig-local) from the fighter to the target tile, so a melee swing can be
## rotated to actually point at the target — up, down, or diagonal. 0 when the
## target is level to the right, which is how the swings are tuned. The pivot and
## _aim_fx share the rig's local frame (flip included), so this stays correct
## whichever way the unit faces.
func _aim_angle() -> float:
	if is_inf(_aim_fx.x) or is_inf(_aim_fx.y):
		return 0.0
	return _aim_fx.angle()


## How far to drive on the strike: a fraction of the gap to the target, capped so
## it reads as a lunge (not a teleport onto the target). A miss under-reaches.
func _lunge_reach(frac: float, cap_cells: float) -> float:
	var cap: float = absf(scale.x) * 32.0 * cap_cells   # scale.x carries cell/32
	var r := cap * 0.5
	if not (is_inf(_aim_parent.x) or is_inf(_aim_parent.y)):
		var gap := (_aim_parent - position).length()
		r = minf(gap * frac, cap) if gap > 1.0 else cap * 0.5
	return r * (_miss_reach if not _connected else 1.0)


## Lance: a THRUST, not a swing — level the point forward and drive the whole
## sprite in hard toward the target tile, then pull back.
func _stab() -> void:
	var home := position
	var dir := _lunge_dir()
	var reach := _lunge_reach(0.42, 0.6)
	var aim := _aim_angle()
	_pivot.rotation = _rest_rot + aim   # level the point at the target tile
	var wind := pace.track(create_tween()).set_parallel(true)
	wind.tween_property(_pivot, "rotation", _rest_rot + aim - 0.25, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	wind.tween_property(_body, "rotation", 0.0 if _hires else -0.08, 0.18).set_trans(Tween.TRANS_SINE)
	wind.tween_property(self, "position", home - dir * (reach * 0.22), 0.18)
	await pace.tween(wind)
	await _crit_beat()
	set_pose(Pose.ACTION)
	var hit := pace.track(create_tween()).set_parallel(true)
	hit.tween_property(_pivot, "rotation", _rest_rot + aim + 0.15, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_body, "rotation", 0.0 if _hires else 0.06, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(self, "position", home + dir * reach, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pace.tween(hit)
	_thrust_streak()
	impact.emit()
	await _follow_through(0.09)
	await _recover(home)


## Melee: the weapon arcs and the whole sprite lunges + tilts toward the target
## tile. `heavy` (axe) winds bigger and lands harder.
func _swing(heavy: bool) -> void:
	var back := -2.0 if heavy else -1.6
	var thru := 1.5 if heavy else 1.3
	var home := position
	var dir := _lunge_dir()
	var reach := _lunge_reach(0.32 if heavy else 0.30, 0.5)
	var aim := _aim_angle()
	_pivot.rotation = _rest_rot + aim   # aim the swing at the target tile
	var wind := pace.track(create_tween()).set_parallel(true)
	wind.tween_property(_pivot, "rotation", _rest_rot + aim + back, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	wind.tween_property(_body, "rotation", 0.0 if _hires else -0.22, 0.20).set_trans(Tween.TRANS_SINE)
	wind.tween_property(self, "position", home - dir * (reach * 0.25), 0.20)
	await pace.tween(wind)
	await _crit_beat()
	set_pose(Pose.ACTION)
	var hit := pace.track(create_tween()).set_parallel(true)
	hit.tween_property(_pivot, "rotation", _rest_rot + aim + thru, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(_body, "rotation", 0.0 if _hires else 0.24, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hit.tween_property(self, "position", home + dir * reach, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pace.tween(hit)
	_slash_trail(heavy or _crit or _kill)
	impact.emit()
	await _follow_through(0.12 if heavy else 0.08)
	await _recover(home)


func _shoot(aim_global: Vector2) -> void:
	# draw back (body leans AWAY from the target), hold, loose — the arrow
	# streaks to the target
	var dest := _aim_local(aim_global)
	var home := position
	var w := pace.track(create_tween()).set_parallel(true)
	w.tween_property(_pivot, "rotation", _rest_rot - 0.35, 0.26).set_trans(Tween.TRANS_SINE)
	w.tween_property(_body, "rotation", 0.0 if _hires else -0.1, 0.26).set_trans(Tween.TRANS_SINE)
	w.tween_property(self, "position", home - _lunge_dir() * 3.0 * absf(scale.x), 0.26)
	await pace.tween(w)
	await pace.wait(self, 0.14)
	await _crit_beat()
	set_pose(Pose.ACTION)
	_pivot.rotation = _rest_rot
	if _fx_profile.ranged_style == "beam":
		_beam(dest)  # spellbow: a green energy beam, not a plain arrow
		await pace.wait(self, 0.07)
		impact.emit()
		_beam_burst(dest)
		await _follow_through(0.18)
	else:
		_projectile(dest, "arrow")
		await pace.wait(self, PROJ_TIME)
		impact.emit()
		await _follow_through(0.08)
	await _recover(home)


func _magic(aim_global: Vector2) -> void:
	if _hires:
		set_pose(Pose.ACTION)  # raise the casting hand before the gather starts
	var dest := _aim_local(aim_global)
	var home := position
	var w := pace.track(create_tween()).set_parallel(true)
	w.tween_property(_pivot, "rotation", _rest_rot - 0.3, 0.28).set_trans(Tween.TRANS_SINE)
	w.tween_property(_body, "rotation", 0.0 if _hires else -0.06, 0.28).set_trans(Tween.TRANS_SINE)
	await pace.tween(w)
	_cast_gather()
	await pace.wait(self, 0.26)
	await _crit_beat()
	set_pose(Pose.ACTION)
	_pivot.rotation = _rest_rot
	_projectile(dest, _magic_style())
	await pace.wait(self, PROJ_TIME)
	impact.emit()
	_cast_burst_at(dest)
	await _follow_through(0.14)
	await _recover(home)


func _heal(aim_global := Vector2.INF) -> void:
	if _hires:
		set_pose(Pose.ACTION)
	var home := position
	var w := pace.track(create_tween())
	w.tween_property(_pivot, "rotation", _rest_rot - 0.5, 0.26).set_trans(Tween.TRANS_SINE)
	await pace.tween(w)
	_cast_gather()
	await pace.wait(self, 0.26)
	set_pose(Pose.ACTION)
	impact.emit()
	_heal_bloom(aim_global)
	await pace.wait(self, 0.3)
	await _recover(home)


func _recover(home: Vector2) -> void:
	set_pose(Pose.IDLE)
	var r := pace.track(create_tween()).set_parallel(true)
	r.tween_property(_pivot, "rotation", _rest_rot, 0.26).set_trans(Tween.TRANS_SINE)
	r.tween_property(_body, "rotation", 0.0, 0.26).set_trans(Tween.TRANS_SINE)
	r.tween_property(self, "position", home, 0.26).set_trans(Tween.TRANS_SINE)
	await pace.tween(r)


# --- fx ---------------------------------------------------------------------

func _tip() -> Vector2:
	return _fx.to_local(_pivot.global_position)

## Point partway from the hand toward the target tile, so the hit FX lands on the
## target for any direction (up/down/diagonal), not just to the side.
func _hit_point(frac: float) -> Vector2:
	if is_inf(_aim_fx.x) or is_inf(_aim_fx.y):
		return _tip()
	return _tip().lerp(_aim_fx, frac)

func _slash_trail(heavy: bool) -> void:
	# centered at the hand; a crescent that opens toward the target and expands
	_fx_items.append({"kind": "slash", "pos": _tip(), "ang": _aim_angle(),
		"age": 0.0, "life": 0.3, "big": heavy, "col": _melee_color(),
		"power": _power(), "alpha": 1.0 if _connected else 0.35})
func _thrust_streak() -> void:
	var from := _tip()
	var to := _aim_fx if not (is_inf(_aim_fx.x) or is_inf(_aim_fx.y)) else from + Vector2(46, 0)
	var nd := (to - from)
	nd = nd.normalized() if nd.length() > 0.1 else Vector2.RIGHT
	_fx_items.append({"kind": "streak", "pos": from.lerp(to, 0.45), "ndir": nd, "perp": nd.orthogonal(),
		"age": 0.0, "life": 0.22, "power": _power(), "alpha": 1.0 if _connected else 0.35})
## CP-1: Data-driven FX getters — all presentation styles and tints resolve
## through CombatFxProfile (WeaponDef -> UnitDef -> defaults) rather than
## hardcoded match statements.
func _magic_style() -> String:
	return _fx_profile.magic_style

func _magic_color() -> Color:
	return _fx_profile.magic_color

func _melee_color() -> Color:
	return _fx_profile.melee_color

func _heal_color() -> Color:
	return _fx_profile.heal_color

func _heal_style() -> String:
	return _fx_profile.heal_style
func _cast_gather() -> void:
	_fx_items.append({"kind": "gather", "pos": _tip(), "col": _magic_color(), "age": 0.0, "life": 0.3})
func _beam(dest: Vector2) -> void:
	_fx_items.append({"kind": "beam", "pos": _tip(), "to": dest, "age": 0.0, "life": 0.24})
func _beam_burst(dest: Vector2) -> void:
	_fx_items.append({"kind": "gbrst", "pos": dest, "age": 0.0, "life": 0.3})
func _projectile(dest: Vector2, style: String) -> void:
	_fx_items.append({"kind": "proj", "pos": _tip(), "to": dest,
		"style": style, "col": _magic_color(), "age": 0.0, "life": PROJ_TIME})
func _cast_burst_at(dest: Vector2) -> void:
	_fx_items.append({"kind": "tburst", "pos": dest, "col": _magic_color(), "style": _magic_style(), "age": 0.0, "life": 0.28})
func _heal_bloom(aim_global := Vector2.INF) -> void:
	var at: Vector2 = _fx.to_local(aim_global) if not (is_inf(aim_global.x) or is_inf(aim_global.y)) \
		else _fx.to_local(global_position) + Vector2(0, -6)
	_fx_items.append({"kind": "heal", "pos": at, "col": _heal_color(), "style": _heal_style(), "age": 0.0, "life": 0.5})

func _draw_fx() -> void:
	for it in _fx_items:
		var t: float = it["age"] / it["life"]
		var a := 1.0 - t
		match it["kind"]:
			"glint":
				var gp: Vector2 = it["pos"]
				var gs: float = 6.0 * (1.0 - t) + 2.0
				_fx.draw_line(gp - Vector2(gs, 0), gp + Vector2(gs, 0), Color(1.0, 1.0, 0.8, a), 2.0)
				_fx.draw_line(gp - Vector2(0, gs), gp + Vector2(0, gs), Color(1.0, 1.0, 0.8, a), 2.0)
				_fx.draw_circle(gp, maxf(1.0, 2.5 * a), Color(1.0, 1.0, 1.0, a))
			"slash":
				var rr: float = (22.0 if it.get("big", false) else 17.0) * float(it.get("power", 1.0))
				a *= float(it.get("alpha", 1.0))
				var sc: Color = it.get("col", Color(0.85, 1.0, 0.9))
				for k in range(3):
					_fx.draw_arc(it["pos"], (rr + k * 4.0) * (0.8 + t * 0.5), float(it.get("ang",0.0)) - 1.15, float(it.get("ang",0.0)) + 1.15, 22,
						Color(sc.r, sc.g, sc.b, a * 0.85), 3.0 - k)
			"streak":
				a *= float(it.get("alpha", 1.0))
				var length: float = 23.0 * float(it.get("power", 1.0))
				for k in range(3):
					_fx.draw_line(it["pos"] - it["ndir"]*length + it["perp"]*float(k*3-3), it["pos"] + it["ndir"]*length + it["perp"]*float(k*3-3),
						Color(1,1,0.88,a), 2.6 - k*0.6)
			"gather":
				var gc: Color = it.get("col", Color(0.85,0.75,1.0))
				_fx.draw_circle(it["pos"], 12.0 * (1.0 - t), Color(gc.r, gc.g, gc.b, a))
			"proj":
				var p0: Vector2 = it["pos"]
				var p1: Vector2 = it["to"]
				var cur: Vector2 = p0.lerp(p1, t)
				if it["style"] == "arrow":
					var dir: Vector2 = (p1 - p0)
					dir = dir.normalized() if dir.length() > 0.1 else Vector2.RIGHT
					var perp := dir.orthogonal()
					_fx.draw_line(cur - dir * 22.0, cur, Color(0.95,0.92,0.8,0.95), 2.5)
					_fx.draw_line(cur, cur - dir * 7.0 + perp * 4.0, Color(0.8,0.78,0.7,1.0), 2.5)
					_fx.draw_line(cur, cur - dir * 7.0 - perp * 4.0, Color(0.8,0.78,0.7,1.0), 2.5)
				else:
					var mc: Color = it.get("col", Color(1.0, 0.42, 0.9))
					if it["style"] == "crystal":
						var dc: Vector2 = (p1 - p0)
						dc = dc.normalized() if dc.length() > 0.1 else Vector2.RIGHT
						var pc := dc.orthogonal()
						_fx.draw_colored_polygon(PackedVector2Array([cur + dc * 8.0, cur + pc * 3.5, cur - dc * 5.0, cur - pc * 3.5]), Color(mc.r, mc.g, mc.b, (1.0 - t) * 0.9))
						_fx.draw_line(cur - dc * 5.0, cur + dc * 8.0, Color(0.92, 0.98, 1.0, 1.0 - t), 1.5)
					elif it["style"] == "swirl":
						for ko in range(3):
							var a2 := TAU * float(ko) / 3.0 + float(it["age"]) * 11.0
							_fx.draw_circle(cur + Vector2(cos(a2), sin(a2)) * 6.0, maxf(1.0, 3.0 * (1.0 - t)), Color(mc.r, mc.g, mc.b, (1.0 - t) * 0.8))
						_fx.draw_circle(cur, 5.0, Color(mc.r, mc.g, mc.b, (1.0 - t) * 0.9))
						_fx.draw_circle(cur, 2.5, Color(0.9, 1.0, 0.85, 1.0))
					elif it["style"] == "crown":
						# AW-51 Kai's Crownspark: a spinning emerald circlet with five
						# gold points, shedding verdant sparks as it flies
						var spin: float = float(it["age"]) * 9.0
						_fx.draw_arc(cur, 6.5, 0.0, TAU, 14, Color(mc.r, mc.g, mc.b, (1.0 - t) * 0.9), 2.2)
						for kp in range(5):
							var ap := TAU * float(kp) / 5.0 + spin
							var spoke := Vector2(cos(ap), sin(ap))
							var tipp := cur + spoke * 11.0
							_fx.draw_line(cur + spoke * 6.0, tipp, Color(1.0, 0.88, 0.45, 1.0 - t), 2.0)
							_fx.draw_circle(tipp, 1.6, Color(1.0, 0.95, 0.7, 1.0 - t))
						var bk2: Vector2 = (p1 - p0).normalized() if (p1 - p0).length() > 0.1 else Vector2.RIGHT
						for ks in range(3):
							_fx.draw_circle(cur - bk2 * (9.0 + ks * 7.0), maxf(1.0, 2.6 - ks * 0.7),
								Color(mc.r, mc.g, mc.b, (1.0 - t) * (0.6 - ks * 0.15)))
						_fx.draw_circle(cur, 3.0, Color(0.92, 1.0, 0.9, 1.0))
					else:
						var fl: float = float(it["age"]) * 40.0
						var bk: Vector2 = (p1 - p0).normalized() if (p1 - p0).length() > 0.1 else Vector2.RIGHT
						_fx.draw_circle(cur - bk * 6.0, maxf(1.0, 3.5 * (1.0 - t)), Color(mc.r, mc.g, mc.b, (1.0 - t) * 0.4))
						for kf in range(4):
							var kk := float(kf)
							_fx.draw_circle(cur + Vector2(sin(fl + kk * 2.1) * 2.0, cos(fl + kk * 1.6) * 2.0), maxf(1.0, 6.5 - kk * 1.3), Color(mc.r, mc.g, mc.b, (1.0 - t) * (0.75 - kk * 0.15)))
						_fx.draw_circle(cur, 4.0, Color(1.0, 0.9, 0.7, 1.0))
			"beam":
				var be := 1.0 - t
				_fx.draw_line(it["pos"], it["to"], Color(0.30, 1.0, 0.50, be * 0.30), 9.0)
				_fx.draw_line(it["pos"], it["to"], Color(0.55, 1.0, 0.62, be * 0.7), 4.5)
				_fx.draw_line(it["pos"], it["to"], Color(0.92, 1.0, 0.9, be), 1.8)
			"gbrst":
				for kg in range(8):
					var ag := TAU * float(kg) / 8.0
					var tp := (it["pos"] as Vector2) + Vector2(cos(ag), sin(ag)) * (6.0 + t * 22.0)
					_fx.draw_circle(tp, maxf(1.0, 4.0 * (1.0 - t)), Color(0.4, 1.0, 0.55, (1.0 - t) * 0.6))
				_fx.draw_circle(it["pos"], 5.0 + t * 8.0, Color(0.85, 1.0, 0.88, (1.0 - t) * 0.85))
			"heal":
				var hc: Color = it.get("col", Color(0.42,1.0,0.56))
				var hs: String = it.get("style", "arcs")
				if hs == "motes":
					_fx.draw_circle(it["pos"], 6.0 + t * 8.0, Color(hc.r, hc.g, hc.b, a * 0.35))
					for k in range(6):
						var kk := float(k)
						var mp := (it["pos"] as Vector2) + Vector2(sin(kk * 2.3) * 10.0, -t * 30.0 - kk * 3.0)
						_fx.draw_circle(mp, maxf(1.0, 3.0 * a), Color(hc.r, hc.g, hc.b, a * 0.9))
				elif hs == "rays":
					for k in range(5):
						var kk2 := float(k)
						var rx := (kk2 - 2.0) * 7.0
						_fx.draw_line((it["pos"] as Vector2) + Vector2(rx, -42.0), (it["pos"] as Vector2) + Vector2(rx * 0.3, 4.0), Color(hc.r, hc.g, hc.b, a * 0.6 * (0.4 + 0.6 * absf(sin(float(t) * 6.0 + kk2)))), 2.5)
					_fx.draw_circle(it["pos"], 5.0 + t * 10.0, Color(1, 1, 1, a * 0.8))
					_fx.draw_circle(it["pos"], 3.0, Color(hc.r, hc.g, hc.b, a))
				elif hs == "cross":
					_fx.draw_arc(it["pos"], 6.0 + t * 28.0, 0.0, TAU, 28, Color(hc.r, hc.g, hc.b, a * 0.6), 2.0)
					var cs := 9.0 * (1.0 - t * 0.3)
					_fx.draw_line((it["pos"] as Vector2) - Vector2(cs, 0), (it["pos"] as Vector2) + Vector2(cs, 0), Color(hc.r, hc.g, hc.b, a * 0.95), 3.0)
					_fx.draw_line((it["pos"] as Vector2) - Vector2(0, cs), (it["pos"] as Vector2) + Vector2(0, cs), Color(hc.r, hc.g, hc.b, a * 0.95), 3.0)
				else:
					for k in range(3):
						_fx.draw_arc(it["pos"], 14.0 + t*40.0 + k*10.0, 0.0, TAU, 26, Color(hc.r, hc.g, hc.b, a*0.7), 3.0-k)
			"tburst":
				var bc: Color = it.get("col", Color(1.0, 0.4, 0.88))
				var bs: String = it.get("style", "flame")
				if bs == "crystal":
					for kb in range(8):
						var nd := Vector2(cos(TAU * float(kb) / 8.0), sin(TAU * float(kb) / 8.0))
						_fx.draw_line((it["pos"] as Vector2) + nd * 4.0, (it["pos"] as Vector2) + nd * (8.0 + t * 30.0), Color(bc.r, bc.g, bc.b, a * 0.85), 3.0 * a + 1.0)
					_fx.draw_circle(it["pos"], 4.0 + t * 6.0, Color(0.9, 0.98, 1.0, a * 0.9))
				elif bs == "crown":
					# AW-51 the coronation: an emerald ring slams down on the target
					# and five gold points rise from it — struck by royalty
					var ring := 6.0 + t * 24.0
					_fx.draw_arc(it["pos"], ring, 0.0, TAU, 24, Color(bc.r, bc.g, bc.b, a * 0.9), 3.0)
					_fx.draw_arc(it["pos"], ring * 0.6, 0.0, TAU, 18, Color(bc.r, bc.g, bc.b, a * 0.5), 2.0)
					for kb in range(5):
						var ac := TAU * float(kb) / 5.0 - PI / 2.0
						var pbase := (it["pos"] as Vector2) + Vector2(cos(ac), sin(ac)) * ring
						var ptip := pbase + Vector2(0, -5.0 - t * 16.0)
						_fx.draw_line(pbase, ptip, Color(1.0, 0.88, 0.45, a), 2.4)
						_fx.draw_circle(ptip, 2.0, Color(1.0, 0.95, 0.7, a))
					_fx.draw_circle(it["pos"], 4.0 + t * 9.0, Color(0.9, 1.0, 0.9, a * 0.8))
				elif bs == "swirl":
					for kb in range(6):
						var av := TAU * float(kb) / 6.0 + float(it["age"]) * 2.0
						var cv := (it["pos"] as Vector2) + Vector2(cos(av), sin(av)) * (8.0 + t * 22.0)
						_fx.draw_arc(cv, 5.0 * a + 2.0, av, av + 2.6, 8, Color(bc.r, bc.g, bc.b, a * 0.8), 2.0)
					_fx.draw_circle(it["pos"], 4.0 + t * 8.0, Color(0.7, 1.0, 0.6, a * 0.6))
				else:
					for kb in range(10):
						var af := TAU * float(kb) / 10.0 + float(it["age"]) * 3.0
						var rf := (6.0 + t * 30.0) * (0.6 + 0.4 * sin(float(kb) * 1.7))
						_fx.draw_circle((it["pos"] as Vector2) + Vector2(cos(af), sin(af)) * rf, maxf(1.0, 6.0 * a), Color(bc.r, bc.g, bc.b, a * 0.6))
					_fx.draw_circle(it["pos"], 6.0 + t * 14.0, Color(1.0, 0.85, 0.6, a * 0.8))
