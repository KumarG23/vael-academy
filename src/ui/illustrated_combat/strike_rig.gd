class_name IllustratedStrikeRig
extends CombatRig
## CP-6: whole approved poses, never articulated/deformed anatomy.
## Timing and painted blade-tip anchors are data; outcome is inherited.
signal beat(name: String)
signal committing
var timing: Dictionary = {}
var strike_tip := Vector2.ZERO
var guard_tip := Vector2.ZERO
var blade_base := Vector2.ZERO
var effects: IllustratedCombatFX


func _swing(_heavy: bool) -> void:
	await _pose_thrust()


func _stab() -> void:
	await _pose_thrust()


func _pose_thrust() -> void:
	var home := position
	var direction := _lunge_dir()
	set_pose(Pose.PARRY_HIT)
	beat.emit("windup")
	var wind := create_tween()
	wind.tween_property(self, "position", home - direction * 10.0, float(timing["windup"])).set_trans(Tween.TRANS_SINE)
	await wind.finished
	if _crit:
		effects.gleam(_body.to_global(guard_tip + _body.offset), Color(1.0, 0.82, 0.38), float(timing["critical_hold"]), 0.35)
		beat.emit("critical_hold")
		await get_tree().create_timer(float(timing["critical_hold"])).timeout
	# The existing action is a thrust. Align its painted blade with the target;
	# don't simulate a broad swing by rotating a whole illustration.
	var kit := _illustrated_kit
	var tip_reach := (strike_tip.x - kit.foot_for("action").x) * _hires_height / kit.source_body_height
	var gap := home.distance_to(_aim_parent)
	var reach := clampf(gap - tip_reach - 12.0, 16.0, 170.0)
	committing.emit()
	set_pose(Pose.ACTION)
	effects.blade_light(_body, blade_base, strike_tip, _fx_profile.melee_color, 0.38)
	beat.emit("commit")
	var forward := create_tween()
	forward.tween_property(self, "position", home + direction * reach, float(timing["commit"])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await forward.finished
	var trail := CombatFX.spawn(effects, "white_slash", _body.to_global(strike_tip + _body.offset))
	trail.scale = Vector2(0.7, 0.24) * _power()
	trail.modulate = _fx_profile.melee_color.lerp(Color.WHITE, 0.15)
	trail.modulate.a = 0.35 if not _connected else 0.8
	impact.emit()
	beat.emit("contact")
	await get_tree().create_timer(float(timing["contact_hold"]) * (_kill_mult if _kill else 1.0)).timeout
	set_pose(Pose.PARRY_HIT)
	beat.emit("recovery")
	var back := create_tween()
	back.tween_property(self, "position", home, float(timing["recovery"])).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await back.finished
	set_pose(Pose.IDLE)
	await get_tree().create_timer(0.08).timeout


func _magic(_aim_global: Vector2) -> void:
	set_pose(Pose.ACTION)
	beat.emit("gather")
	var origin := _pivot.global_position
	var destination := _fx.to_global(_aim_fx)
	effects.gather(origin, _fx_profile.magic_color, float(timing["cast_gather"]))
	await get_tree().create_timer(float(timing["cast_gather"])).timeout
	committing.emit()
	beat.emit("release")
	var bolt := SpellFX.spawn(effects, "arcane_bolt", origin)
	IllustratedCombatFX.tint(bolt, _fx_profile.magic_color)
	bolt.scale = Vector2.ONE * 0.78
	bolt.rotation = (destination - origin).angle()
	var flight := bolt.create_tween()
	flight.tween_property(bolt, "global_position", destination, float(timing["projectile"]))
	await flight.finished
	bolt.queue_free()
	impact.emit()
	beat.emit("contact")
	await get_tree().create_timer(0.26).timeout
	set_pose(Pose.IDLE)
	beat.emit("recovery")
	await get_tree().create_timer(float(timing["recovery"])).timeout
