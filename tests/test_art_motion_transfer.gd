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


func test_painted_ankle_stays_inside_boot_through_both_walks_and_facings():
	var pilot := _pilot()
	var rig := pilot.illustration
	var shin_image: Image = load(KaiArtMotion.LAYERS + "shin.png").get_image()
	var foot_image: Image = load(KaiArtMotion.LAYERS + "foot.png").get_image()
	if shin_image.is_compressed():
		shin_image.decompress()
	if foot_image.is_compressed():
		foot_image.decompress()
	var least_overlap := 1000
	var worst_pose := ""
	for clip: String in ["Idle", "Walk", "Walk_Formal"]:
		pilot.actor.player.play(clip, 0.0)
		for frame in range(80):
			pilot.actor.player.seek(pilot.actor.player.current_animation_length * frame / 80.0, true)
			pilot.actor.player.advance(0.0)
			for yaw: float in [AuthoredModelActor.YAW, -AuthoredModelActor.YAW]:
				pilot.actor.target_yaw = yaw
				rig.update_from_motion()
				for part: Dictionary in rig.parts:
					if part["type"] != "leg":
						continue
					var shin: Sprite2D = part["lower"]
					var foot: Sprite2D = part["foot"]
					var overlap := 0
					# Compare opaque painted pixels at the cuff in world space.
					# Coincident bone positions alone missed the detached foot.
					for y in range(12, 28, 2):
						for x in range(40, 58, 2):
							if foot_image.get_pixel(x, y).a < 0.9:
								continue
							var sample := shin.to_local(foot.to_global(Vector2(x, y) + foot.offset)) - shin.offset
							if Rect2(Vector2.ZERO, shin_image.get_size()).has_point(sample) and shin_image.get_pixelv(Vector2i(sample)).a > 0.9:
								overlap += 1
					if overlap < least_overlap:
						least_overlap = overlap
						worst_pose = "%s frame %s yaw %s %s" % [clip, frame, yaw, part["bones"][0]]
	assert_gte(least_overlap, 12, "painted ankle must overlap its boot shaft: " + worst_pose)


func test_actual_painted_blade_points_forward_and_down_in_both_facings():
	var pilot := _pilot()
	var image := pilot.illustration.carry.texture.get_image()
	if image.is_compressed():
		image.decompress()
	var blade := Vector2.ZERO
	var hilt := Vector2.ZERO
	var blade_pixels := 0
	var hilt_pixels := 0
	# Inspect the actual steel and green pixels, rather than a facing flag or
	# a configured tip coordinate. The old backward painting fails this check.
	for y in range(450, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			if color.a < 0.8:
				continue
			if y > 650 and minf(color.r, minf(color.g, color.b)) > 0.35 and maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) < 0.15:
				blade += Vector2(x, y)
				blade_pixels += 1
			elif color.g > color.r * 1.2 and color.g > color.b * 1.2:
				hilt += Vector2(x, y)
				hilt_pixels += 1
	assert_gt(blade_pixels, 30)
	assert_gt(hilt_pixels, 10)
	if blade_pixels == 0 or hilt_pixels == 0:
		return
	blade /= float(blade_pixels)
	hilt /= float(hilt_pixels)
	for direction: float in [1.0, -1.0]:
		pilot.actor.target_yaw = direction * AuthoredModelActor.YAW
		pilot.illustration.update_from_motion()
		var carry := pilot.illustration.carry
		var blade_world := carry.to_global(blade + carry.offset)
		var hilt_world := carry.to_global(hilt + carry.offset)
		assert_gt((blade_world.x - hilt_world.x) * direction, 15.0)
		assert_gt(blade_world.y, hilt_world.y)
