class_name ActiveDefenseJuice
extends IllustratedCombatJuice
## Judge the input before commitment, then reuse the existing impact pipeline.
signal window_opened
signal judged(report: Dictionary)
var trial: ActiveDefenseTrial
var base_strike: StrikeResult
var block_fraction := 0.5
var report: Dictionary = {}
var _window := false


func _make_rig() -> CombatRig:
	var rig := super._make_rig() as IllustratedStrikeRig
	rig.beat.connect(func(name: String) -> void:
		if name == "windup":
			_window = true
			window_opened.emit())
	return rig


func _prepare_dodge() -> void:
	_window = false
	report = trial.resolve(base_strike, block_fraction)
	var final: StrikeResult = report["strike"]
	# The inherited impact closure owns this strike object; finalize its values
	# before commitment/contact instead of fixing HP after the fact.
	for field: String in ["connected", "was_crit", "damage", "defender_hp_after"]:
		active_strike.set(field, final.get(field))
	current_rig.set_outcome(active_strike, false, cfg)
	judged.emit(report)
	if report["result"] == "block":
		active_target.set_illustrated_pose("parry_hit")
	super._prepare_dodge()


func _react_target(target: Unit, toward: Vector2, strike: StrikeResult, is_kill: bool) -> Tween:
	if report.get("result") != "block":
		return super._react_target(target, toward, strike, is_kill)
	contact.emit(target, strike)
	target._flash = 0.08
	AudioManager.play_sfx("defense_block")
	effects.gleam(target.global_position + target.combat_aim_offset(), Color("f9dc88"), 0.22, 0.5)
	target.set_illustrated_pose("parry_hit")
	var home := target.position
	var recoil := target.create_tween()
	recoil.tween_property(target, "position", home + toward * 7.0, 0.07)
	recoil.tween_property(target, "position", home, 0.18)
	recoil.finished.connect(func() -> void: target.set_illustrated_pose("idle"))
	return recoil
