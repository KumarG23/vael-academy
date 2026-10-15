extends GutTest
## CP-5: prove the motion comes from the accepted source, and preserve Kai's
## existing head pixels/size. These tests do not approve the artwork's motion.

func _pilot() -> KaiArtMotionPilot:
	var pilot: KaiArtMotionPilot = load("res://scenes/proto/kai_art_motion_pilot.tscn").instantiate()
	add_child_autofree(pilot)
	pilot.set_process(false)
	pilot.actor.set_process(false)
	pilot.illustration.set_process(false)
	return pilot


func test_original_head_texture_geometry_and_scale_survive_walk_and_return():
	var pilot := _pilot()
	var illustration := pilot.illustration
	var texture := illustration.torso.texture
	var shape := illustration.torso.polygon
	var uv := illustration.torso.uv
	var size := illustration.scale.abs()
	assert_eq(texture.resource_path, "res://assets/art/illustrated_pilot/kai/idle.png")
	pilot.actor.player.play("Walk", 0.0)
	for phase: float in [0.0, 0.25, 0.5, 0.75]:
		pilot.actor.player.seek(pilot.actor.player.current_animation_length * phase, true)
		pilot.actor.player.advance(0.0)
		for yaw: float in [AuthoredModelActor.YAW, -AuthoredModelActor.YAW]:
			pilot.actor.target_yaw = yaw
			illustration.update_from_motion()
			assert_eq(illustration.torso.texture, texture)
			assert_eq(illustration.torso.polygon, shape)
			assert_eq(illustration.torso.uv, uv)
			assert_eq(illustration.scale.abs(), size)
	assert_not_null(illustration.torso.material, "return view uses existing anatomical-left mark correction")


func test_painted_contact_toe_follows_authored_stance_and_root_travel():
	var pilot := _pilot()
	var illustration := pilot.illustration
	var actor := pilot.actor
	actor.player.play("Walk", 0.0)
	actor.player.advance(0.0)
	var duration := actor.player.current_animation_length
	for side: String in ["l", "r"]:
		var leg: Dictionary = {}
		for part: Dictionary in illustration.parts:
			if part["bones"][0] == "thigh_" + side:
				leg = part
		var initial_x := 0.0
		for sample in range(5):
			var phase := (0.125 if side == "l" else 0.625) + float(sample) * 0.0625
			actor.player.seek(duration * phase, true)
			actor.player.advance(0.0)
			illustration.update_from_motion()
			var foot: Sprite2D = leg["foot"]
			var contact := foot.position + (Vector2(87, 41.4) + foot.offset).rotated(foot.rotation)
			var world_x := contact.x * illustration.source_scale + actor.nominal_speed() * duration * phase
			if sample == 0:
				initial_x = world_x
			assert_almost_eq(world_x, initial_x, 1.0, "painted support toe cancels source travel within one pixel")


func test_comparison_uses_same_model_and_turn_displays_real_reference():
	var state := Campaign.to_dict().duplicate(true)
	var pilot := _pilot()
	var model := pilot.actor.model
	assert_true(pilot.show_art)
	assert_true(pilot.illustration.visible)
	assert_false(pilot.actor.sprite.visible)
	pilot._compare()
	assert_false(pilot.illustration.visible)
	assert_true(pilot.actor.sprite.visible)
	pilot._compare()
	pilot._act("carry")
	assert_false(pilot.illustration.carry.visible)
	pilot._act("turn")
	assert_false(pilot.show_art, "one painted view cannot show a genuine 3D turn")
	assert_true(pilot.actor.sprite.visible)
	assert_eq(pilot.actor.model, model)
	assert_eq(Campaign.to_dict(), state)
