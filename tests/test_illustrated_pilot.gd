extends GutTest
## CP-2: motion and recovery, opaque-bound geometry, live illustrated exchange.


func test_flinch_and_stagger_have_an_outward_beat_and_restore():
	var target := Unit.new()
	target.setup(load("res://data/units/kai.tres"), Grid.new(2, 2), Vector2i.ZERO)
	add_child_autofree(target)
	var controller := JuiceController.new()
	add_child_autofree(controller)
	controller.cfg = JuiceConfig.new()
	controller.cfg.reaction_out = 0.12
	controller.cfg.reaction_back = 0.12
	var home := target.position
	var strike := StrikeResult.new()
	strike.connected = true
	strike.damage = 1
	for critical in [false, true]:
		strike.was_crit = critical
		var reaction := controller._react_target(target, Vector2.RIGHT, strike, false)
		await get_tree().create_timer(0.07).timeout
		assert_gt(target.position.x, home.x + 1.0, "reaction visibly pushes out before recovery")
		assert_lt(target.scale.y, 1.0, "reaction deforms before recovering")
		if critical:
			assert_gt(absf(target.rotation), 0.01, "stagger visibly rocks")
		await reaction.finished
		assert_almost_eq(target.position.x, home.x, 0.01)
		assert_almost_eq(target.scale.y, 1.0, 0.01)
		assert_almost_eq(target.rotation, 0.0, 0.01)


func test_trail_payloads_carry_damage_intensity_and_miss_alpha():
	var rig := CombatRig.new()
	add_child_autofree(rig)
	rig.setup("kai", CombatRig.Facing.EAST, 1.0)
	var strike := StrikeResult.new()
	strike.connected = true
	strike.damage = 1
	rig.set_outcome(strike, false)
	rig._slash_trail(false)
	var light: Dictionary = rig._fx_items.back()
	strike.damage = 20
	rig.set_outcome(strike, false)
	rig._slash_trail(false)
	assert_gt(float(rig._fx_items.back()["power"]), float(light["power"]))
	strike.connected = false
	rig.set_outcome(strike, false)
	rig._slash_trail(false)
	assert_lt(float(rig._fx_items.back()["alpha"]), float(light["alpha"]))


func test_padded_pose_uses_visible_feet_and_preserves_body_scale():
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(44, 16, 40, 96), Color.WHITE)
	var idle := ImageTexture.create_from_image(image)
	var action_image := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	action_image.fill(Color.TRANSPARENT)
	action_image.fill_rect(Rect2i(90, 40, 70, 64), Color.WHITE)
	var action := ImageTexture.create_from_image(action_image)
	var rig := CombatRig.new()
	add_child_autofree(rig)
	rig.setup("kai", CombatRig.Facing.EAST, 1.0)
	rig.set_pose_textures(idle, action)
	var scale := rig._body.scale.y
	assert_almost_eq(rig._body.position.y + (112.0 + rig._body.offset.y) * scale, CombatRig.MAP_FOOT, 0.001)
	rig.set_pose(CombatRig.Pose.ACTION)
	assert_almost_eq(rig._body.scale.y, scale, 0.001, "crouching pose doesn't inflate")
	assert_almost_eq(rig._body.position.y + (104.0 + rig._body.offset.y) * scale, CombatRig.MAP_FOOT, 0.001)


func test_illustrated_windup_stays_upright_and_spell_gathers_at_casting_hand():
	var rig := CombatRig.new()
	add_child_autofree(rig)
	rig.setup("kai", CombatRig.Facing.EAST, 1.0, "res://assets/art/illustrated_pilot/kai")
	rig.play_attack(WeaponDef.WeaponType.SWORD)
	await get_tree().create_timer(0.15).timeout
	assert_almost_eq(rig._body.rotation, 0.0, 0.001, "illustration stays upright during anticipation")
	assert_lt(rig.position.x, 0.0, "weight shifts back without rotating the full body")
	await rig.impact
	await get_tree().create_timer(0.45).timeout
	rig.play_attack(WeaponDef.WeaponType.TOME)
	assert_eq(rig._body.texture, rig._illustrated_kit.textures["cast"], "casting hand rises before gather")
	await get_tree().create_timer(0.32).timeout
	var gather: Dictionary = rig._fx_items.back()
	assert_eq(gather["kind"], "gather")
	assert_almost_eq(Vector2(gather["pos"]).distance_to(rig._tip()), 0.0, 0.001, "gather is at the active casting hand")
	var gather_hand: Vector2 = gather["pos"]
	await get_tree().create_timer(0.28).timeout
	assert_almost_eq(gather_hand.distance_to(rig._tip()), 0.0, 0.001, "launch uses the same hand")
	await rig.impact
	await get_tree().create_timer(0.45).timeout


func test_live_pilot_walk_and_strikes_keep_illustration_and_campaign_state():
	var state := Campaign.to_dict().duplicate(true)
	var pilot: IllustratedPilot = load("res://scenes/proto/illustrated_pilot.tscn").instantiate()
	add_child_autofree(pilot)
	assert_not_null(pilot.kai._illustrated)
	assert_not_null(pilot.serra._illustrated)
	assert_false(pilot.kai._anim.visible, "pixel actor is hidden persistently")
	var start := pilot.kai.position
	await pilot._act("walk")
	assert_eq(pilot.kai.position, start, "walk out-and-back restores origin")
	assert_eq(pilot.kai._illustrated.kit.walk_names.size(), 4)
	await pilot._act("hit")
	assert_lt(pilot.serra.current_hp, pilot.serra.max_hp(), "live controller applies HP at impact")
	assert_true(pilot.kai.visible)
	assert_false(pilot.kai._anim.visible, "illustration persists after rig swap")
	assert_eq(pilot.serra._illustrated.pose, "idle", "defender hit pose restores")
	var weapon := pilot.kai.weapon()
	await pilot._act("cast")
	assert_eq(pilot.kai.weapon(), weapon, "cast restores original equipment")
	await pilot._act("kill")
	assert_eq(pilot.serra.current_hp, 0)
	pilot.reset_actors()
	assert_eq(pilot.serra.current_hp, pilot.serra.max_hp())
	assert_eq(pilot.serra.scale, Vector2.ONE)
	assert_eq(Campaign.to_dict(), state, "pilot never modifies campaign/saves")
