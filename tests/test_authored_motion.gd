extends GutTest
## CP-4: actual imported skeleton motion and grip registration, not pose flags.


func _actor() -> AuthoredModelActor:
	var actor := AuthoredModelActor.new()
	add_child_autofree(actor)
	actor.setup()
	actor.set_process(false)
	return actor


func test_authored_walk_alternates_and_planted_toe_cancels_root_travel():
	var actor := _actor()
	actor.set_carrying(false)
	var player := actor.player
	var skeleton := actor.skeleton
	player.play("Walk", 0.0)
	player.advance(0.0)
	var length := player.get_animation("Walk").length
	for side in ["l", "r"]:
		var start := 0.125 if side == "l" else 0.625
		var reference := 0.0
		for sample in range(5):
			var phase := start + float(sample) * 0.0625
			player.seek(length * phase, true)
			player.advance(0.0)
			var toe := skeleton.get_bone_global_pose(skeleton.find_bone("ball_" + side)).origin
			var world_z := toe.z + AuthoredModelActor.HUMAN_STRIDE * phase
			if sample == 0:
				reference = world_z
			assert_almost_eq(world_z, reference, 0.008, "artist's stance and measured root travel agree")
			assert_lt(toe.y, 0.025, "support toe remains close to the floor")
	for phase in [0.25, 0.75]:
		player.seek(length * phase, true)
		player.advance(0.0)
		var left := skeleton.get_bone_global_pose(skeleton.find_bone("foot_l")).origin
		var right := skeleton.get_bone_global_pose(skeleton.find_bone("foot_r")).origin
		assert_gt(right.y - left.y if phase < 0.5 else left.y - right.y, 0.15, "opposite leg swings each half cycle")


func test_blade_exits_thumb_index_end_and_fingers_do_not_modify_the_walk():
	var actor := _actor()
	var skeleton := actor.skeleton
	assert_eq(actor.socket.bone_name, "hand_r")
	assert_eq(actor.socket.get_parent(), skeleton)
	var grip := actor._grip
	assert_eq(grip.rotations.size(), 20, "all five right fingers use the artist's pose")
	actor.player.play("Walk", 0.0)
	actor.player.advance(0.2)
	var leg := skeleton.find_bone("thigh_l")
	var leg_rotation := skeleton.get_bone_pose_rotation(leg)
	grip._process_modification_with_delta(0.0)
	assert_eq(skeleton.get_bone_pose_rotation(leg), leg_rotation)
	var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))
	var index := hand.affine_inverse() * skeleton.get_bone_global_pose(skeleton.find_bone("index_01_r")).origin
	var pinky := hand.affine_inverse() * skeleton.get_bone_global_pose(skeleton.find_bone("pinky_01_r")).origin
	assert_gt(actor.weapon.basis.y.dot((index - pinky).normalized()), 0.99, "guard at index/thumb, pommel at pinky; never reversed")
	actor.set_carrying(false)
	assert_false(grip.active)
	assert_false(actor.weapon.visible)


func test_turn_rotates_one_model_without_reflection_or_head_replacement():
	var actor := _actor()
	var model := actor.model
	var skeleton := actor.skeleton
	var scale_before := actor.sprite.scale
	var mark := actor.brow_marker.position
	var head_rest := skeleton.get_bone_rest(skeleton.find_bone("Head"))
	for angle in [0.0, PI * 0.5, PI, PI * 1.5, TAU]:
		actor.model.rotation.y = angle
		assert_eq(actor.model, model)
		assert_eq(actor.model.scale, Vector3.ONE)
		assert_eq(actor.sprite.scale, scale_before)
		assert_gt(actor.sprite.scale.x, 0.0, "no mirrored sprite")
		assert_eq(actor.brow_marker.position, mark)
		assert_eq(skeleton.get_bone_rest(skeleton.find_bone("Head")), head_rest)
	assert_eq((actor.brow_marker.get_parent() as BoneAttachment3D).bone_name, "Head")
	assert_gt(mark.x, 0.0, "marker stays on anatomical left")


func test_live_motion_tour_returns_home_without_campaign_changes():
	var state := Campaign.to_dict().duplicate(true)
	var pilot: AuthoredMotionPilot = load("res://scenes/proto/authored_motion_pilot.tscn").instantiate()
	add_child_autofree(pilot)
	pilot.set_process(false)
	pilot.actor.set_process(false)
	var home := pilot.actor.position
	pilot._act("walk")
	for frame in range(1200):
		pilot._process(1.0 / 120.0)
		if not pilot.busy:
			break
	assert_false(pilot.busy)
	assert_eq(pilot.actor.position, home)
	assert_eq(Campaign.to_dict(), state)
	assert_true(pilot.actor.viewport.transparent_bg)
	assert_not_null(pilot.actor.sprite.texture)
