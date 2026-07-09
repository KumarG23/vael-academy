extends GutTest
## AW-27: aura skills project stat + combat bonuses onto nearby allies (never
## the owner), Serra's Tide-Ward and Rina/Sable's Pack Hunter carry them as
## per-character personal skills, and a spellbow resolves as magic damage.

const SCENE := "res://scenes/battle/mock_battle.tscn"

var _view: Node2D


func before_each() -> void:
	Campaign.reset_new_game(false)
	var scene: PackedScene = load(SCENE)
	_view = scene.instantiate()
	_view.strike_delay = 0.0
	_view.dialogue_enabled = false
	add_child_autofree(_view)
	await wait_physics_frames(2)


func after_each() -> void:
	Campaign.reset_new_game(false)


# --- the skill resources themselves --------------------------------------------

func test_aura_skills_are_flagged_as_auras():
	var tw: SkillDef = load("res://data/skills/tide_ward.tres")
	assert_true(tw.is_aura(), "Tide-Ward is an aura")
	assert_eq(tw.aura_range, 2)
	assert_eq(int(tw.stat_bonuses.get("def", 0)), 3)
	var ph: SkillDef = load("res://data/skills/pack_hunter.tres")
	assert_true(ph.is_aura(), "Pack Hunter is an aura")
	assert_eq(ph.combat_bonus()["damage"], 2)
	assert_eq(ph.combat_bonus()["crit"], 15)


func test_a_plain_skill_is_not_an_aura():
	var sw: SkillDef = load("res://data/skills/shield_wall.tres")
	assert_false(sw.is_aura(), "Shield Wall only buffs its owner")


# --- unit-level fold (add / clear / owner exclusion) ---------------------------

func _unit(fname: String) -> Unit:
	var u := Unit.new()
	u.unit_def = (load("res://data/units/%s.tres" % fname) as UnitDef).duplicate()
	autofree(u)
	return u


func test_an_aura_does_not_buff_its_own_owner():
	# Serra carries Tide-Ward, but her own DEF must not include the +3 (auras
	# project outward). Standing in an *ally's* aura would add it — proven below.
	var serra := _unit("serra")
	assert_eq(serra.aura_skills().size(), 1, "Serra projects one aura")
	var base := serra.stat("def")
	serra.add_aura(load("res://data/skills/tide_ward.tres"))
	assert_eq(serra.stat("def"), base + 3, "standing in an ally's Tide-Ward adds +3 def")
	serra.clear_auras()
	assert_eq(serra.stat("def"), base, "clearing auras restores the base")


func test_pack_hunter_folds_a_combat_bonus():
	var rina := _unit("rina")
	rina.add_aura(load("res://data/skills/pack_hunter.tres"))
	var cb := rina.aura_combat_bonus()
	assert_eq(cb["damage"], 2, "Pack Hunter grants +2 damage")
	assert_eq(cb["crit"], 15, "Pack Hunter grants +15 crit")
	rina.clear_auras()
	assert_eq(rina.aura_combat_bonus()["damage"], 0, "cleared")


func test_heirs_and_sable_carry_their_signature_skills():
	assert_true(_has_skill(_unit("rina"), "pack_hunter"), "Rina knows Pack Hunter")
	assert_true(_has_skill(_unit("sable"), "pack_hunter"), "Sable knows Pack Hunter")
	assert_true(_has_skill(_unit("serra"), "tide_ward"), "Serra knows Tide-Ward")


func _has_skill(u: Unit, id: String) -> bool:
	for sk in u.active_skills():
		if sk.id == id:
			return true
	return false


# --- battlefield recompute (positions decide who is buffed) --------------------

func test_recompute_buffs_allies_in_range_only():
	var serra: Unit = _view.unit_by_id("serra")            # Tidemark heir, carries Tide-Ward
	var near: Unit = _view.unit_by_id("bertram")           # (16,2) — adjacent to Serra
	var far: Unit = _view.unit_by_id("osric")              # (9,9) — well out of range

	near.clear_auras()
	var near_base := near.stat("def")
	far.clear_auras()
	var far_base := far.stat("def")
	serra.clear_auras()
	var serra_base := serra.stat("def")

	_view._recompute_auras()

	assert_eq(near.stat("def") - near_base, 3, "ally beside Serra gains Tide-Ward +3 def")
	assert_eq(far.stat("def") - far_base, 0, "distant ally is out of the aura")
	assert_eq(serra.stat("def") - serra_base, 0, "Serra does not buff herself")


func test_aura_does_not_cross_teams():
	# Kai (player) stands far from Serra anyway, but assert the team gate directly:
	# move a player unit next to Serra and confirm no enemy aura leaks over.
	var serra: Unit = _view.unit_by_id("serra")
	var kai: Unit = _view.unit_by_id("kai")
	kai.cell = serra.cell + Vector2i(1, 0)
	kai.clear_auras()
	var base := kai.stat("def")
	_view._recompute_auras()
	assert_eq(kai.stat("def") - base, 0, "an enemy's aura never reaches the player team")


# --- spellbow: a bow that resolves as magic ------------------------------------

func test_spellbow_is_magical_but_stays_a_bow():
	var bow: WeaponDef = load("res://data/weapons/sig_rina.tres")
	assert_eq(bow.weapon_type, WeaponDef.WeaponType.BOW, "still a bow (Attack menu, range)")
	assert_true(bow.is_magical(), "but resolves MAG vs RES")
	var lance: WeaponDef = load("res://data/weapons/iron_lance.tres")
	assert_false(lance.is_magical(), "a mundane arm is physical")
