extends GutTest
## WO-4.7: variable-frame + multi-direction walk sprite loading.

const FIXTURE := "res://tests/fixtures/sprites/testunit47"


func test_scan_finds_variable_east_frames() -> void:
	var sets: Dictionary = Unit.scan_walk_frames(FIXTURE)
	assert_eq((sets["walk"] as Array).size(), 5, "east set is walk_f1..f5")
	assert_eq(sets["walk"][0], FIXTURE + "/walk_f1.png")
	assert_eq(sets["walk"][4], FIXTURE + "/walk_f5.png")


func test_scan_finds_optional_north_set() -> void:
	var sets: Dictionary = Unit.scan_walk_frames(FIXTURE)
	assert_eq((sets["walk_n"] as Array).size(), 2, "north set is walk_n_f1..f2")


func test_scan_missing_south_set_is_empty() -> void:
	var sets: Dictionary = Unit.scan_walk_frames(FIXTURE)
	assert_eq((sets["walk_s"] as Array).size(), 0, "no south frames in fixture")


func test_scan_missing_dir_is_all_empty() -> void:
	var sets: Dictionary = Unit.scan_walk_frames("res://tests/fixtures/sprites/nope")
	for anim in ["walk", "walk_n", "walk_s"]:
		assert_eq((sets[anim] as Array).size(), 0)


func test_idle_indices_keep_legacy_four_frame_behavior() -> void:
	assert_eq(Unit.idle_frame_indices(4), [2, 4] as Array[int],
		"N=4 must keep the original f2/f4 idle bob")


func test_idle_indices_generalize() -> void:
	assert_eq(Unit.idle_frame_indices(9), [5, 9] as Array[int])
	assert_eq(Unit.idle_frame_indices(1), [1, 1] as Array[int])
	assert_eq(Unit.idle_frame_indices(2), [1, 2] as Array[int])


func test_sprite_frames_built_from_fixture_sets() -> void:
	# Point a real Unit at the fixture dir by scanning + building manually the
	# way _setup_sprite_frames does: verify anims exist with right counts.
	var sets: Dictionary = Unit.scan_walk_frames(FIXTURE)
	var frames := SpriteFrames.new()
	for anim in ["walk", "walk_n", "walk_s"]:
		var paths: Array = sets[anim]
		if paths.is_empty():
			continue
		frames.add_animation(anim)
		for p in paths:
			frames.add_frame(anim, load(p))
	assert_true(frames.has_animation("walk"))
	assert_eq(frames.get_frame_count("walk"), 5)
	assert_true(frames.has_animation("walk_n"))
	assert_eq(frames.get_frame_count("walk_n"), 2)
	assert_false(frames.has_animation("walk_s"))


# --- WO-4.8: variant resolution ---------------------------------------------

func test_variant_dir_resolves_when_frames_exist() -> void:
	# kai's school variant is committed data (WO-4.8)
	assert_eq(Unit.resolve_sprite_dir("kai", "school"),
		"res://assets/sprites/units/kai/school")


func test_variant_falls_back_to_root_when_missing() -> void:
	assert_eq(Unit.resolve_sprite_dir("kai", "nonexistent_variant"),
		"res://assets/sprites/units/kai")


func test_battle_variant_uses_root() -> void:
	assert_eq(Unit.resolve_sprite_dir("kai", "battle"),
		"res://assets/sprites/units/kai")


func test_scan_variant_frame_counts_differ() -> void:
	var root := Unit.scan_walk_frames("res://tests/fixtures/sprites/testunit47")
	var school := Unit.scan_walk_frames("res://tests/fixtures/sprites/testunit47/school")
	assert_eq((root["walk"] as Array).size(), 5)
	assert_eq((school["walk"] as Array).size(), 2)
