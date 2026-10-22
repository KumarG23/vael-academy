extends GutTest
## WO-4.9: battle pop-up kit loading + availability.


func test_has_kit_for_committed_cast() -> void:
	for id in ["kai", "kael", "serra", "tm_soldier", "tm_mage"]:
		assert_true(BattlePopup.has_kit(id), "%s has a full combat kit" % id)


func test_has_kit_false_for_unknown() -> void:
	assert_false(BattlePopup.has_kit("nobody_here"))
	assert_false(BattlePopup.has_kit(""))


func test_load_kit_builds_all_animations() -> void:
	var frames := BattlePopup.load_kit("kai")
	for anim in ["idle", "attack", "hit", "ko"]:
		assert_true(frames.has_animation(anim), "kai kit has %s" % anim)
		assert_gt(frames.get_frame_count(anim), 3, "%s has real frames" % anim)
	assert_true(frames.get_animation_loop("idle"), "idle loops")
	assert_false(frames.get_animation_loop("attack"), "attack one-shots")


func test_kit_aliases_resolve() -> void:
	assert_true(BattlePopup.has_kit("tm_soldier_a"), "alias to tm_soldier design")
	assert_true(BattlePopup.has_kit("tm_armor"), "alias to tm_knight design")
	assert_true(BattlePopup.has_kit("tm_adept"), "alias to tm_mage design")


## Tiny one-shot animations reproduce completion during projectile travel or
## the single-segment impact delay without depending on imported kit timings.
func _timing_popup(paired: bool, strike_fps: float) -> BattlePopup:
	var popup := BattlePopup.new()
	add_child_autofree(popup)
	var texture := load("res://assets/art/pixellab/kai/idle_east/idle_f1.png") as Texture2D
	var frames := SpriteFrames.new()
	for anim in ["idle", "attack", "hit", "ko"]:
		frames.add_animation(anim)
		frames.add_frame(anim, texture)
		frames.set_animation_loop(anim, anim == "idle")
		frames.set_animation_speed(anim, strike_fps)
	if paired:
		for anim in ["attack_wind", "attack_strike"]:
			frames.add_animation(anim)
			frames.add_frame(anim, texture)
			frames.set_animation_loop(anim, false)
			frames.set_animation_speed(anim, strike_fps)
	popup._left_sprite.sprite_frames = frames
	popup._right_sprite.sprite_frames = frames
	popup._left_sprite.play("idle")
	popup._right_sprite.play("idle")
	popup._left_holder.position = Vector2(300, 300)
	popup._right_holder.position = Vector2(700, 300)
	popup._root.show()
	return popup


func _record_strike_completion(popup: BattlePopup, strike: StrikeResult, done: Array) -> void:
	await popup._play_strike(strike)
	done[0] = true


func _assert_strike_returns_home(paired: bool, projectile: String, counter: bool) -> void:
	var popup := _timing_popup(paired, 40.0)
	popup._left_proj = projectile
	popup._right_proj = projectile
	var strike := StrikeResult.new()
	strike.is_counter = counter
	strike.connected = false
	strike.defender_hp_after = 10
	var holder := popup._right_holder if counter else popup._left_holder
	var actor := popup._right_sprite if counter else popup._left_sprite
	var home := holder.position
	var done := [false]
	_record_strike_completion(popup, strike, done)
	var deadline := Time.get_ticks_msec() + 2000
	while not done[0] and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	assert_true(done[0], "strike completes even when its animation ends before impact")
	assert_eq(actor.animation, &"idle", "the next strike starts from idle")
	assert_eq(holder.position, home, "the attacker returns home")


func test_short_paired_arrow_miss_completes() -> void:
	await _assert_strike_returns_home(true, "arrow", false)


func test_short_paired_magic_counter_miss_completes() -> void:
	await _assert_strike_returns_home(true, "magic", true)


func test_short_single_segment_melee_miss_completes() -> void:
	await _assert_strike_returns_home(false, "", false)


func test_long_strike_finishes_before_returning_to_idle() -> void:
	var popup := _timing_popup(false, 1.0)
	var strike := StrikeResult.new()
	strike.connected = false
	strike.defender_hp_after = 10
	var finished := [false]
	popup._left_sprite.animation_finished.connect(func():
		finished[0] = true
		assert_eq(popup._left_sprite.animation, &"attack")
		assert_eq(popup._left_holder.position, Vector2(580, 300),
			"the attacker holds contact until the animation finishes"))
	var done := [false]
	_record_strike_completion(popup, strike, done)
	var deadline := Time.get_ticks_msec() + 3000
	while not done[0] and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.02).timeout
	assert_true(done[0], "long strikes also complete")
	assert_true(finished[0], "an animation still playing at impact must finish")
	assert_eq(popup._left_sprite.animation, &"idle")
	assert_eq(popup._left_holder.position, Vector2(300, 300))
