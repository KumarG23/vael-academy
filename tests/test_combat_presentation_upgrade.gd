extends GutTest
## CP-1: Tests for the combat presentation upgrade (Phase 1).
## Covers HitReaction classification, data-driven CombatFxProfile,
## CombatRig strike outcome awareness, and the high-res 3-pose hook.


func test_hit_reaction_classification():
	var miss := StrikeResult.new()
	miss.connected = false
	assert_eq(HitReaction.classify(miss, false, 30), HitReaction.Kind.DODGE, "miss classifies as DODGE")

	var light_hit := StrikeResult.new()
	light_hit.connected = true
	light_hit.damage = 5
	light_hit.was_crit = false
	assert_eq(HitReaction.classify(light_hit, false, 30), HitReaction.Kind.FLINCH, "light hit classifies as FLINCH")

	var heavy_hit := StrikeResult.new()
	heavy_hit.connected = true
	heavy_hit.damage = 15
	heavy_hit.was_crit = false
	assert_eq(HitReaction.classify(heavy_hit, false, 30, 0.35), HitReaction.Kind.STAGGER, ">=35% HP damage classifies as STAGGER")

	var crit_hit := StrikeResult.new()
	crit_hit.connected = true
	crit_hit.damage = 6
	crit_hit.was_crit = true
	assert_eq(HitReaction.classify(crit_hit, false, 30), HitReaction.Kind.STAGGER, "crit classifies as STAGGER")

	var kill_hit := StrikeResult.new()
	kill_hit.connected = true
	kill_hit.damage = 10
	assert_eq(HitReaction.classify(kill_hit, true, 30), HitReaction.Kind.KNOCKBACK, "lethal blow classifies as KNOCKBACK")


func test_combat_fx_profile_data_driven():
	# 1. Natural weapon hides weapon sprite (Nilu's claws)
	var claw: WeaponDef = load("res://data/weapons/claw.tres")
	assert_not_null(claw)
	var profile_claw := CombatFxProfile.build(null, claw)
	assert_false(profile_claw.show_weapon, "claw hides weapon sprite via data")
	assert_gt(profile_claw.melee_color.g, profile_claw.melee_color.r, "claw has green tint")

	# 2. Crownspark has crown style and emerald tint
	var crownspark: WeaponDef = load("res://data/weapons/crownspark.tres")
	assert_not_null(crownspark)
	var profile_crown := CombatFxProfile.build(null, crownspark)
	assert_eq(profile_crown.magic_style, "crown")
	assert_gt(profile_crown.magic_color.g, profile_crown.magic_color.r)

	# 3. Fire tome has flame style and ember tint
	var fire: WeaponDef = load("res://data/weapons/fire.tres")
	assert_not_null(fire)
	var profile_fire := CombatFxProfile.build(null, fire)
	assert_eq(profile_fire.magic_style, "flame")
	assert_gt(profile_fire.magic_color.r, profile_fire.magic_color.b)

	# 4. Caster heal style fallback from UnitDef (Wren)
	var wren: UnitDef = load("res://data/units/wren.tres")
	assert_not_null(wren)
	var profile_wren := CombatFxProfile.build(wren, null)
	assert_eq(profile_wren.heal_style, "motes")
	assert_almost_eq(profile_wren.heal_color.r, 1.0, 0.05)


func test_combat_rig_outcome_awareness():
	var rig := CombatRig.new()
	rig.setup("kai", CombatRig.Facing.EAST, 1.0)
	add_child_autofree(rig)

	var strike := StrikeResult.new()
	strike.connected = true
	strike.damage = 18
	strike.was_crit = true

	rig.set_outcome(strike, false)
	assert_true(rig._connected)
	assert_true(rig._crit)
	assert_false(rig._kill)
	assert_eq(rig._damage, 18)
	assert_gt(rig._power(), 1.0, "power scales with damage")

	rig.set_outcome(strike, true)
	assert_true(rig._kill, "kill flag set when is_kill=true")


func test_combat_rig_hires_3pose_hook():
	var rig := CombatRig.new()
	rig.setup("kai", CombatRig.Facing.EAST, 1.0)
	add_child_autofree(rig)

	assert_false(rig.is_hires(), "default kai has no hires loaded yet")

	# Generate 3 dummy textures for idle, action, parry_hit
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.4, 0.8, 1.0))
	var tex_idle := ImageTexture.create_from_image(img)

	var img_act := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img_act.fill(Color(0.8, 0.2, 0.2, 1.0))
	var tex_action := ImageTexture.create_from_image(img_act)

	var img_parry := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img_parry.fill(Color(0.2, 0.8, 0.2, 1.0))
	var tex_parry := ImageTexture.create_from_image(img_parry)

	rig.set_pose_textures(tex_idle, tex_action, tex_parry)
	assert_true(rig.is_hires(), "rig is now in hi-res mode")
	assert_eq(rig.current_pose(), CombatRig.Pose.IDLE)
	assert_false(rig._weapon.visible, "weapon sprite hidden in hi-res mode")

	rig.set_pose(CombatRig.Pose.ACTION)
	assert_eq(rig.current_pose(), CombatRig.Pose.ACTION)
	assert_eq(rig._body.texture, tex_action)

	rig.set_pose(CombatRig.Pose.PARRY_HIT)
	assert_eq(rig.current_pose(), CombatRig.Pose.PARRY_HIT)
	assert_eq(rig._body.texture, tex_parry)

	rig.set_pose(CombatRig.Pose.IDLE)
	assert_eq(rig.current_pose(), CombatRig.Pose.IDLE)
	assert_eq(rig._body.texture, tex_idle)
