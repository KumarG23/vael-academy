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
