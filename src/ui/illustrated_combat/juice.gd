class_name IllustratedCombatJuice
extends JuiceController
## CP-6: retain the established result/impact/HP/sound/hit-stop orchestration.
signal beat(name: String)
signal contact(target: Unit, strike: StrikeResult)
signal sound_cued(name: String)
var presentation_data: Dictionary
var effects: IllustratedCombatFX
var active_striker: Unit
var active_target: Unit
var active_strike: StrikeResult
var current_rig: IllustratedStrikeRig
var _dodge: Tween
var _target_home := Vector2.ZERO


func play_strike(striker: Unit, target: Unit, strike: StrikeResult, is_kill: bool) -> void:
	active_striker = striker
	active_target = target
	active_strike = strike
	_target_home = target.position
	_dodge = null
	await super.play_strike(striker, target, strike, is_kill)
	if not strike.connected:
		target.position = _target_home


func _make_rig() -> CombatRig:
	var rig := IllustratedStrikeRig.new()
	current_rig = rig
	rig.timing = presentation_data["timing"]
	var point: Array = presentation_data["characters"][active_striker.unit_id()]["strike_tip"]
	rig.strike_tip = Vector2(point[0], point[1])
	var guard: Array = presentation_data["characters"][active_striker.unit_id()]["guard_tip"]
	rig.guard_tip = Vector2(guard[0], guard[1])
	var base: Array = presentation_data["characters"][active_striker.unit_id()]["blade_base"]
	rig.blade_base = Vector2(base[0], base[1])
	rig.effects = effects
	rig.beat.connect(func(name: String) -> void:
		play_cue(name)
		beat.emit(name))
	rig.committing.connect(_prepare_dodge)
	return rig


func play_cue(event: String) -> void:
	var cues: Dictionary = presentation_data.get("audio", {})
	if not cues.has(event) or pace.skipped:
		return
	var name := str(cues[event])
	AudioManager.play_sfx(name)
	sound_cued.emit(name)


func _prepare_dodge() -> void:
	if HitReaction.classify(active_strike, false, active_target.max_hp()) != HitReaction.Kind.DODGE:
		return
	# Clear the blade/projectile's original path BEFORE arrival, then recover.
	# This is an evasion translation of a whole pose, never limb deformation.
	var away := signf(active_target.position.x - active_striker.position.x)
	active_target.set_illustrated_pose("parry_hit")
	_dodge = active_target.create_tween()
	_dodge.tween_property(active_target, "position", _target_home + Vector2(away * 90.0, 0), 0.075).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dodge.tween_interval(0.34)
	_dodge.tween_property(active_target, "position", _target_home, 0.22).set_trans(Tween.TRANS_SINE)
	_dodge.finished.connect(func() -> void: active_target.set_illustrated_pose("idle"))
	beat.emit("dodge")


func _react_target(target: Unit, toward: Vector2, strike: StrikeResult, is_kill: bool) -> Tween:
	contact.emit(target, strike)
	if not strike.connected:
		return _dodge
	# Keep a brief flash while retaining face and costume detail in the painting.
	target._flash = 0.16
	var magical := active_striker.weapon().is_magical()
	if magical:
		play_cue("magic_impact")
	var profile := CombatFxProfile.build(active_striker.unit_def, active_striker.weapon())
	effects.burst(target.global_position + target.combat_aim_offset(), profile.magic_color if magical else profile.melee_color, strike.was_crit, magical)
	if HitReaction.classify(strike, is_kill, target.max_hp(), cfg.stagger_hp_frac) == HitReaction.Kind.KNOCKBACK:
		# Read the upright impact before revealing the already-collapsed key pose.
		# HP still changes at contact; only the visual collapse is delayed.
		target.set_illustrated_pose("parry_hit")
		var home := target.position
		var reaction := target.create_tween()
		reaction.tween_property(target, "position", home + toward * cfg.flinch_distance, cfg.reaction_out * 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reaction.tween_interval(float(presentation_data["timing"]["defeat_hit_hold"]))
		reaction.tween_callback(func() -> void:
			target.set_illustrated_pose("defeat")
			play_cue("defeat")
			beat.emit("defeat"))
		reaction.tween_property(target, "position", home + toward * cfg.knockback_distance, cfg.reaction_back).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return reaction
	return super._react_target(target, toward, strike, is_kill)


func play_death(unit: Unit) -> void:
	unit.set_illustrated_pose("defeat")
	var fade := create_tween()
	fade.tween_interval(0.18)
	fade.tween_property(unit, "modulate:a", 0.0, cfg.dissolve_time)
	await pace.tween(fade)


var shake_layer: Node2D
var _shake_clock := 0.0


func _process(delta: float) -> void:
	if shake_layer == null:
		return
	_shake_clock += delta
	_shake_amount = maxf(0.0, _shake_amount - cfg.shake_decay * delta)
	var amount := minf(9.0, _shake_amount * 0.22)
	shake_layer.position = Vector2(sin(_shake_clock * 151.0), cos(_shake_clock * 127.0)) * amount
