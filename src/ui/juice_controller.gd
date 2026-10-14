class_name JuiceController
extends Node2D
## Orchestrates the combat presentation layer (WO-2.5): standee lunge/recoil,
## hit-stop, damage-scaled screen shake, hit flash, damage-number pop, miss whiff,
## death dissolve, and the clash splash on crits/kills. All feel comes from
## JuiceConfig so it's tunable without code edits.
##
## Kept separate from battle_view so the fat controller doesn't grow (flagged for
## the post-M2 refactor). The scene owns one of these and delegates visuals to it.

var cfg: JuiceConfig
var _camera: Camera2D
var _numbers_root: Node2D
var _splash: ClashSplash

var _shake_amount := 0.0


func setup(config: JuiceConfig, camera: Camera2D, numbers_root: Node2D, splash: ClashSplash) -> void:
	cfg = config
	_camera = camera
	_numbers_root = numbers_root
	_splash = splash


func _exit_tree() -> void:
	# If we're freed mid-hit-stop, don't leave the engine frozen.
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	if _shake_amount <= 0.0 or _camera == null:
		return
	_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_amount
	_shake_amount = maxf(0.0, _shake_amount - cfg.shake_decay * delta)
	if _shake_amount <= 0.0:
		_camera.offset = Vector2.ZERO


## Play one strike's full presentation. Applies the resolved HP at the impact beat
## so the number and hp-bar land with the hit. Awaitable.
func play_strike(striker: Unit, target: Unit, strike: StrikeResult, is_kill: bool) -> void:
	# Battle direction v2: if the attacker has a cut-out rig, swap it in and play
	# the actual attack swing on its tile (not just a flat-sprite bump).
	if CombatRig.has_rig(striker.sprite_id()):  # AW-48: rigs resolve via the sprite alias
		await _play_rig_strike(striker, target, strike, is_kill)
		return
	var home := striker.position
	var toward := (target.position - home).normalized()
	if toward == Vector2.ZERO:
		toward = Vector2.RIGHT
	var reach := cfg.whiff_distance if not strike.connected else cfg.lunge_distance
	var contact := home + toward * reach

	var lunge := create_tween()
	lunge.tween_property(striker, "position", contact, cfg.lunge_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await lunge.finished
	var reaction: Tween = null

	if strike.connected:
		target.set_hp(strike.defender_hp_after)  # white flash + hp bar
		_spawn_number(target.position + target.combat_aim_offset(), strike)
		_shake_amount = maxf(_shake_amount, cfg.shake_magnitude(strike.damage, strike.was_crit))
		if cfg.wants_splash(strike.was_crit, is_kill):
			var label := "CRIT" if strike.was_crit else "DOWN"
			_splash.play(striker.team, label, cfg)
		reaction = _react_target(target, toward, strike, is_kill)
		await _hitstop(cfg.hitstop_duration(strike.was_crit, is_kill))
	else:
		_spawn_miss(target.position + target.combat_aim_offset())
		reaction = _react_target(target, toward, strike, is_kill)

	var back := create_tween()
	back.tween_property(striker, "position", home, cfg.recoil_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	if reaction != null and reaction.is_running():
		await reaction.finished


## Attacker swaps to its cut-out rig, plays the weapon's attack clip on its tile,
## and the strike's effects (hp, number, shake, recoil, hit-stop) fire on the
## rig's `impact` beat. Then the flat sprite is restored.
func _play_rig_strike(striker: Unit, target: Unit, strike: StrikeResult, is_kill: bool) -> void:
	var toward := (target.position - striker.position).normalized()
	if toward == Vector2.ZERO:
		toward = Vector2.RIGHT
	var rig := CombatRig.new()
	striker.get_parent().add_child(rig)
	# match the unit's on-map sprite exactly (same 32px source, same cell scale
	# and offset) so swapping the rig in doesn't resize or shift the fighter.
	rig.position = striker.position + striker.map_sprite_offset()
	# face the target tile (4-way when the unit has back/front art, else E/W)
	var facing := _rig_facing(striker, target.position)
	if facing == CombatRig.Facing.EAST:
		striker.set_facing(true)
	elif facing == CombatRig.Facing.WEST:
		striker.set_facing(false)
	rig.setup(striker.sprite_id(), facing, striker.map_sprite_scale(), striker.illustrated_art_dir, striker.illustrated_height)
	var w := striker.weapon()
	var wt: int = w.weapon_type if w != null else 0
	rig.set_weapon(wt)
	rig.set_fx_source(striker.unit_def if "unit_def" in striker else null, w)
	rig.set_outcome(strike, is_kill, cfg)
	striker.visible = false
	var fired := [false]
	var reactions: Array[Tween] = []
	rig.impact.connect(func() -> void:
		if fired[0]:
			return
		fired[0] = true
		if strike.connected:
			AudioManager.play_sfx("crit" if strike.was_crit else "hit")  # AW-36
			target.set_hp(strike.defender_hp_after)
			_spawn_number(target.position + target.combat_aim_offset(), strike)
			_shake_amount = maxf(_shake_amount, cfg.shake_magnitude(strike.damage, strike.was_crit))
			if cfg.wants_splash(strike.was_crit, is_kill):
				_splash.play(striker.team, "CRIT" if strike.was_crit else "DOWN", cfg)
			reactions.append(_react_target(target, toward, strike, is_kill))
			_hitstop_fire(cfg.hitstop_duration(strike.was_crit, is_kill))
		else:
			AudioManager.play_sfx("miss")  # AW-36
			_spawn_miss(target.position + target.combat_aim_offset())
			reactions.append(_react_target(target, toward, strike, is_kill)))
	# aim ranged attacks at the real target (diagonals included), not straight ahead
	await rig.play_attack(wt, target.global_position, target.global_position + target.combat_aim_offset())
	if not reactions.is_empty() and reactions[0] != null and reactions[0].is_running():
		await reactions[0].finished
	striker.visible = true
	rig.queue_free()


## Staff heal on the map: the healer swaps to its rig, plays the staff cast
## gesture, and a heal bloom lands on the ally. Awaitable; returns false (no-op)
## when the healer has no rig so the caller can fall back to float-text.
func play_heal(healer: Unit, ally: Unit) -> bool:
	if not CombatRig.has_rig(healer.sprite_id()):
		return false
	var rig := CombatRig.new()
	healer.get_parent().add_child(rig)
	rig.position = healer.position + healer.map_sprite_offset()
	var facing := _rig_facing(healer, ally.position)
	if facing == CombatRig.Facing.EAST:
		healer.set_facing(true)
	elif facing == CombatRig.Facing.WEST:
		healer.set_facing(false)
	rig.setup(healer.sprite_id(), facing, healer.map_sprite_scale(), healer.illustrated_art_dir, healer.illustrated_height)
	var w := healer.weapon()
	rig.set_weapon(WeaponDef.WeaponType.STAFF)
	rig.set_fx_source(healer.unit_def if "unit_def" in healer else null, w)
	healer.visible = false
	await rig.play_attack(WeaponDef.WeaponType.STAFF, ally.global_position, ally.global_position + ally.combat_aim_offset())
	healer.visible = true
	rig.queue_free()
	return true


## Which way the actor should face to act on `to`. Uses the dominant axis; only
## turns to NORTH/SOUTH when the unit actually has back/front art, otherwise it
## keeps its current side facing so it doesn't spin around on a vertical action.
func _rig_facing(actor: Unit, to: Vector2) -> int:
	var d := to - actor.position
	if absf(d.x) >= absf(d.y):
		return CombatRig.Facing.EAST if d.x > 0.0 else CombatRig.Facing.WEST
	var want: int = CombatRig.Facing.NORTH if d.y < 0.0 else CombatRig.Facing.SOUTH
	if CombatRig.has_facing(actor.sprite_id(), want):
		return want
	return CombatRig.Facing.EAST if actor.facing_right() else CombatRig.Facing.WEST


## Non-blocking hit-stop: freeze real time briefly (the rig's tweens pause too —
## the GBA crunch) and self-reset, without awaiting inside the impact callback.
func _hitstop_fire(duration: float) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = 0.0
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0)


## Death dissolve: fade + shrink, then the caller frees the node.
func play_death(unit: Unit) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(unit, "modulate:a", 0.0, cfg.dissolve_time)
	tw.tween_property(unit, "scale", Vector2(0.5, 0.5), cfg.dissolve_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished


## CP-1: Data-driven target hit reaction at impact (DODGE, FLINCH, STAGGER, KNOCKBACK)
func _react_target(target: Unit, toward: Vector2, strike: StrikeResult, is_kill: bool) -> Tween:
	if target == null or not is_instance_valid(target) or cfg == null:
		return null
	var kind := HitReaction.classify(strike, is_kill, target.max_hp(), cfg.stagger_hp_frac)
	if kind == HitReaction.Kind.NONE:
		return null
	target.set_illustrated_pose("defeat" if kind == HitReaction.Kind.KNOCKBACK else ("idle" if kind == HitReaction.Kind.DODGE else "parry_hit"))
	var home := target.position
	var r_out := cfg.reaction_out
	var r_back := cfg.reaction_back
	var tw := target.create_tween()
	match kind:
		HitReaction.Kind.DODGE:
			var perp := toward.orthogonal()
			tw.tween_property(target, "position", home + perp * cfg.dodge_distance, r_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(target, "position", home, r_back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		HitReaction.Kind.FLINCH:
			var orig_scale := target.scale
			tw.set_parallel(true)
			tw.tween_property(target, "position", home + toward * cfg.flinch_distance, r_out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(target, "scale", Vector2(orig_scale.x * (1.0 + cfg.squash * 0.5), orig_scale.y * (1.0 - cfg.squash)), r_out)
			tw.chain().tween_property(target, "position", home, r_back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(target, "scale", orig_scale, r_back)
		HitReaction.Kind.STAGGER:
			var orig_scale := target.scale
			var wobble := cfg.stagger_wobble * (1.0 if toward.x >= 0.0 else -1.0)
			tw.set_parallel(true)
			tw.tween_property(target, "position", home + toward * cfg.stagger_distance, r_out * 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(target, "rotation", wobble, r_out * 1.2)
			tw.tween_property(target, "scale", Vector2(orig_scale.x * (1.0 + cfg.squash), orig_scale.y * (1.0 - cfg.squash * 1.5)), r_out * 1.2)
			tw.chain().tween_property(target, "position", home, r_back * 1.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(target, "rotation", 0.0, r_back * 1.3)
			tw.parallel().tween_property(target, "scale", orig_scale, r_back * 1.3)
		HitReaction.Kind.KNOCKBACK:
			tw.tween_property(target, "position", home + toward * cfg.knockback_distance, r_out * 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if kind != HitReaction.Kind.KNOCKBACK:
		tw.finished.connect(func() -> void:
			if is_instance_valid(target):
				target.set_illustrated_pose("idle"))
	return tw


func _recoil(target: Unit, toward: Vector2) -> void:
	if target == null or not is_instance_valid(target) or cfg == null:
		return
	var home := target.position
	var tw := target.create_tween()
	tw.tween_property(target, "position", home + toward * cfg.target_recoil, cfg.hitstop_hit)
	tw.tween_property(target, "position", home, cfg.recoil_time)


## Freeze the game briefly on connect (real-time, immune to the zeroed time scale).
func _hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func _spawn_number(world_pos: Vector2, strike: StrikeResult) -> void:
	var label := Label.new()
	label.text = ("CRIT " + str(strike.damage)) if strike.was_crit else str(strike.damage)
	var size := 34 if strike.was_crit else 26
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if strike.was_crit else Color(1.0, 0.45, 0.4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.position = world_pos + Vector2(-18, -60)
	label.z_index = 200
	label.pivot_offset = Vector2(18, 12)
	label.scale = Vector2.ZERO
	_numbers_root.add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector2.ONE, 0.16).from(Vector2(cfg.number_pop_scale, cfg.number_pop_scale)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", label.position.y - cfg.number_rise, cfg.number_time)
	tw.tween_property(label, "modulate:a", 0.0, cfg.number_time).set_delay(cfg.number_time * 0.35)
	tw.chain().tween_callback(label.queue_free)


func _spawn_miss(world_pos: Vector2) -> void:
	var label := Label.new()
	label.text = "Miss"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.85, 0.86, 0.92))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.position = world_pos + Vector2(-16, -56)
	label.z_index = 200
	_numbers_root.add_child(label)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:x", label.position.x + 40.0, cfg.number_time)  # slide/whiff
	tw.tween_property(label, "modulate:a", 0.0, cfg.number_time)
	tw.chain().tween_callback(label.queue_free)
