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
