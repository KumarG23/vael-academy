extends GutTest
## Promoted-tier build (evolution names approved 2026-07-05): every character
## promotes to a UNIQUE class via UnitDef.promotion_class; generic units keep
## their class's own path.

const LADDER := {
	"kai": "warder_lord", "kael": "swordmaster", "brenna": "bastion",
	"wren": "saint", "dain": "warrior", "liora": "pyromancer",
	"perrin": "paladin", "serra_prologue": "leviathan", "rina": "spellbow",
}


func _unit_for(fname: String) -> Unit:
	var u := Unit.new()
	u.unit_def = (load("res://data/units/%s.tres" % fname) as UnitDef).duplicate()
	return u


func test_every_authored_character_has_its_unique_target():
	for fname in LADDER:
		var u := _unit_for(fname)
		autofree(u)
		var target := u.promotion_target()
		assert_not_null(target, fname + " has a promotion target")
		assert_eq(target.id, LADDER[fname], fname)


func test_no_two_characters_share_a_promoted_name():
	var seen := {}
	for fname in LADDER:
		var u := _unit_for(fname)
		autofree(u)
		var id := u.promotion_target().id
		assert_false(seen.has(id), id + " is unique")
		seen[id] = true


func test_kai_is_a_lord_promoting_to_warder_lord():
	var u := _unit_for("kai")
	autofree(u)
	assert_eq(u.current_class().id, "lord")
	assert_eq(u.promotion_target().display_name, "Warder Lord")


func test_promote_applies_the_per_character_target():
	var u := _unit_for("brenna")
	autofree(u)
	u.level = 10
	var result := u.promote()
	assert_eq(result["class_name"], "Bastion")
	assert_eq(u.current_class().id, "bastion")
	assert_eq(u.level, 1, "level resets on promotion")


func test_generic_units_keep_the_class_path():
	var u := _unit_for("tm_soldier_a")
	autofree(u)
	assert_null(u.unit_def.promotion_class, "no per-character override")


func test_authored_promotions_cannot_be_repeated_after_leveling_again():
	for fname in LADDER:
		var u := _unit_for(fname)
		autofree(u)
		u.level = Promotion.MIN_LEVEL
		assert_false(u.promote().is_empty(), fname + " promotes once")
		assert_eq(u.current_class().id, LADDER[fname], fname)
		for promoted_level in [Promotion.MIN_LEVEL, 20]:
			u.level = promoted_level
			u.xp = 37
			var before := u.save_state()
			assert_null(u.promotion_target(), fname + " has no further promotion")
			assert_false(u.can_promote(), fname + " cannot repeat its promotion")
			assert_eq(u.promote(), {}, fname + " rejects a repeated promotion")
			assert_eq(u.save_state(), before, fname + " preserves stats, HP, movement, level and XP")


func test_restored_promotions_cannot_be_repeated():
	var promoted := _unit_for("brenna")
	autofree(promoted)
	promoted.level = Promotion.MIN_LEVEL
	assert_false(promoted.promote().is_empty())
	promoted.level = Promotion.MIN_LEVEL
	promoted.xp = 37
	for restore_method in ["apply_save_state", "apply_progression_state"]:
		var restored := _unit_for("brenna")
		autofree(restored)
		var state := promoted.save_state() if restore_method == "apply_save_state" else promoted.progression_state()
		restored.call(restore_method, state)
		assert_eq(restored.current_class().id, "bastion", restore_method)
		assert_eq(restored.level, Promotion.MIN_LEVEL, restore_method)
		var before := restored.save_state()
		assert_null(restored.promotion_target(), restore_method)
		assert_false(restored.can_promote(), restore_method)
		assert_eq(restored.promote(), {}, restore_method)
		assert_eq(restored.save_state(), before, restore_method + " preserves restored progression")


func test_unit_without_character_override_can_follow_its_class_path():
	var u := _unit_for("kael")
	autofree(u)
	u.unit_def.promotion_class = null
	u.level = Promotion.MIN_LEVEL
	assert_eq(u.promotion_target(), u.current_class().promoted_class)
	assert_true(u.can_promote())
	assert_eq(u.promote().get("class_name", ""), "Swordmaster")
	assert_eq(u.current_class().id, "swordmaster")
	u.level = Promotion.MIN_LEVEL
	assert_null(u.promotion_target())
	assert_false(u.can_promote())
