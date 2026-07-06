extends GutTest
## WO-8.1: passive skills — data-driven per class, gated by level, folded into
## combat through the same forecast/resolver path as supports.


func _unit(fname: String, level := 1) -> Unit:
	var u := Unit.new()
	u.unit_def = (load("res://data/units/%s.tres" % fname) as UnitDef).duplicate()
	u.level = level
	autofree(u)
	return u


func test_skills_unlock_on_schedule():
	var kai := _unit("kai", 1)
	assert_eq(kai.active_skills().size(), 0, "Warder's Resolve waits for level 3")
	kai.level = 3
	assert_eq(kai.active_skills().size(), 1)
	assert_eq(kai.active_skills()[0].id, "warders_resolve")


func test_combat_bonus_flows_from_skills():
	var kai := _unit("kai", 3)
	var b := kai.skill_combat_bonus()
	assert_eq(b["hit"], 5)
	assert_eq(b["avoid"], 5)


func test_stat_modifier_skills_fold_into_stat():
	var brenna := _unit("brenna", 4)
	var before := brenna.stat("def")
	brenna.level = 5  # Shield Wall unlocks: +2 def
	assert_eq(brenna.stat("def"), before + 2)


func test_promotion_keeps_base_skills_and_adds_promoted():
	var kai := _unit("kai", 10)
	assert_eq(kai.active_skills().size(), 1, "Warder's Resolve at 10")
	kai.promote()  # -> Warder Lord, level resets to 1
	assert_eq(kai.active_skills().size(), 1, "base skill kept via the promotion floor")
	kai.level = 5
	var ids: Array = []
	for sk in kai.active_skills():
		ids.append(sk.id)
	assert_true(ids.has("warders_resolve"), "base skill persists")
	assert_true(ids.has("awakened_edge"), "promoted skill unlocks on its own schedule")


func test_skills_reach_the_resolver_path():
	# a real battle: Kai at level 3 must show his +5 hit in the forecast inputs
	var v: Node2D = (load("res://scenes/battle/mock_battle.tscn") as PackedScene).instantiate()
	v.strike_delay = 0.0
	v.dialogue_enabled = false
	add_child_autofree(v)
	var kai: Unit = null
	for u in v._units:
		if u.unit_id() == "kai":
			kai = u
	var before: Combatant = v._combatant_for(kai, kai.cell)
	kai.level = 3
	var after: Combatant = v._combatant_for(kai, kai.cell)
	assert_eq(after.support_hit - before.support_hit, 5,
		"Warder's Resolve rides the same Combatant fold as supports")
