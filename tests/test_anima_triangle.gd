extends GutTest
## AW-28: the anima magic triangle — Ember(fire) > Gale(wind) > Tide(water) >
## Ember — layered on top of the physical Sword>Axe>Lance triangle. Advantage is
## the same +15 hit / +1 damage; non-anima weapons are untouched.

func _tome(school: String) -> WeaponDef:
	var w := WeaponDef.new()
	w.weapon_type = WeaponDef.WeaponType.TOME
	w.school = school
	w.might = 6
	w.hit = 90
	w.max_range = 2
	return w


func _blade() -> WeaponDef:
	var w := WeaponDef.new()
	w.weapon_type = WeaponDef.WeaponType.SWORD
	w.might = 5
	w.hit = 90
	return w


func test_ember_beats_gale_beats_tide_beats_ember():
	for pair in [["ember", "gale"], ["gale", "tide"], ["tide", "ember"]]:
		var strong := _tome(pair[0])
		var weak := _tome(pair[1])
		assert_eq(WeaponTriangle.hit_bonus_for(strong, weak), 15, "%s > %s hit" % pair)
		assert_eq(WeaponTriangle.dmg_bonus_for(strong, weak), 1, "%s > %s dmg" % pair)
		# the mirror match-up is the disadvantage
		assert_eq(WeaponTriangle.hit_bonus_for(weak, strong), -15, "%s < %s hit" % [pair[1], pair[0]])
		assert_eq(WeaponTriangle.dmg_bonus_for(weak, strong), -1, "%s < %s dmg" % [pair[1], pair[0]])


func test_same_element_is_neutral():
	assert_eq(WeaponTriangle.hit_bonus_for(_tome("ember"), _tome("ember")), 0)
	assert_eq(WeaponTriangle.dmg_bonus_for(_tome("tide"), _tome("tide")), 0)


func test_non_anima_tome_has_no_interaction():
	# A "reason" tome is outside the anima cycle.
	assert_eq(WeaponTriangle.hit_bonus_for(_tome("reason"), _tome("ember")), 0)
	assert_eq(WeaponTriangle.hit_bonus_for(_tome("ember"), _tome("reason")), 0)


func test_anima_and_physical_do_not_bleed_into_each_other():
	# Tome vs blade: neither triangle applies.
	assert_eq(WeaponTriangle.hit_bonus_for(_tome("ember"), _blade()), 0)
	# The physical triangle still resolves through the element-aware entry point.
	var axe := WeaponDef.new()
	axe.weapon_type = WeaponDef.WeaponType.AXE
	assert_eq(WeaponTriangle.hit_bonus_for(_blade(), axe), 15, "sword still beats axe")
	assert_eq(WeaponTriangle.dmg_bonus_for(_blade(), axe), 1)


func test_advantage_shows_up_in_a_real_forecast():
	var ember := Combatant.make("Ember", {"mag": 10, "skl": 8}, _tome("ember"))
	var gale := Combatant.make("Gale", {"res": 4, "skl": 6}, _tome("gale"))
	var adv := CombatForecast.strike_stats(ember, gale)   # ember > gale
	var dis := CombatForecast.strike_stats(gale, ember)   # gale < ember
	assert_gt(adv["damage"], dis["damage"], "the favoured element hits harder")
	assert_gt(adv["hit"], dis["hit"], "and more accurately")


func test_the_mage_heirs_are_wired_to_the_three_elements():
	var liora: WeaponDef = load("res://data/weapons/sig_liora.tres")
	var corvin: WeaponDef = load("res://data/weapons/sig_corvin.tres")
	var isolde: WeaponDef = load("res://data/weapons/sig_isolde.tres")
	assert_eq(liora.school, "ember", "Liora is fire")
	assert_eq(corvin.school, "gale", "Corvin is wind")
	assert_eq(isolde.school, "tide", "Isolde is water")
	# Liora (ember) has the edge on Corvin (gale).
	assert_eq(WeaponTriangle.dmg_bonus_for(liora, corvin), 1)
	assert_eq(WeaponTriangle.dmg_bonus_for(corvin, isolde), 1)
	assert_eq(WeaponTriangle.dmg_bonus_for(isolde, liora), 1)
