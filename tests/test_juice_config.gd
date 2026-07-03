extends GutTest
## WO-2.5: the tunable JuiceConfig. These assertions operationalize "a crit feels
## ~3x more dramatic than a normal hit" and "timings are tweakable via the resource".


func test_defaults_load_from_the_resource():
	var cfg: JuiceConfig = load("res://data/config/juice.tres")
	assert_not_null(cfg, "juice.tres exists and loads")
	assert_gt(cfg.hitstop_crit, cfg.hitstop_hit, "a crit freezes longer than a plain hit")


func test_shake_scales_with_damage():
	var cfg := JuiceConfig.new()
	assert_gt(cfg.shake_magnitude(20, false), cfg.shake_magnitude(5, false),
		"more damage -> more shake")


func test_shake_is_capped_for_normal_hits_but_a_crit_exceeds_it():
	var cfg := JuiceConfig.new()
	var big_hit := cfg.shake_magnitude(9999, false)
	assert_almost_eq(big_hit, cfg.shake_max, 0.001, "normal shake caps at shake_max")
	assert_gt(cfg.shake_magnitude(9999, true), big_hit, "a crit shakes past the cap")


func test_hitstop_ordering_hit_lt_crit_lt_kill():
	var cfg := JuiceConfig.new()
	assert_lt(cfg.hitstop_duration(false, false), cfg.hitstop_duration(true, false))
	assert_lt(cfg.hitstop_duration(true, false), cfg.hitstop_duration(false, true))


func test_crit_is_dramatically_bigger_than_a_normal_hit():
	# Same damage: the crit's combined hit-stop x shake should be well above the hit's.
	var cfg := JuiceConfig.new()
	var dmg := 12
	var hit_drama := cfg.hitstop_duration(false, false) * cfg.shake_magnitude(dmg, false)
	var crit_drama := cfg.hitstop_duration(true, false) * cfg.shake_magnitude(dmg, true)
	assert_gt(crit_drama, hit_drama * 2.5, "crit reads at least ~3x the impact of a hit")


func test_splash_fires_on_crit_and_kill_only():
	var cfg := JuiceConfig.new()
	assert_true(cfg.wants_splash(true, false), "crit -> splash")
	assert_true(cfg.wants_splash(false, true), "kill -> splash")
	assert_false(cfg.wants_splash(false, false), "a plain hit gets no splash")


func test_timings_are_tweakable_without_code():
	# Editing the resource changes behavior — no code edit required.
	var cfg := JuiceConfig.new()
	cfg.hitstop_crit = 0.30
	assert_eq(cfg.hitstop_duration(true, false), 0.30)
	cfg.splash_on_crit = false
	assert_false(cfg.wants_splash(true, false), "toggled off via the resource")
