extends GutTest
## AW-54: the report card (GRADING_SYSTEM.md) — pure grade math, the Campaign
## recorders, the quiz pool's exploration gating, and the classroom lesson flow
## (teacher by house, weekly gate, the 100% spellbook).


func before_each() -> void:
	Campaign.reset_new_game(false)


func after_each() -> void:
	Campaign.reset_new_game(false)


# --- the math (pure) -----------------------------------------------------------

func test_empty_marks_read_neutral_not_zero():
	var g := Grading.running({"quiz_scores": [], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0})
	assert_eq(int(g["score"]), 60, "no data = a neutral C-ish start, never an F")
	assert_eq(str(g["rank"]), "C")


func test_marks_blend_by_weight():
	var g := Grading.running({"quiz_scores": [100], "battle_scores": [100], "arena_best_wave": 10, "conduct_points": 40})
	assert_eq(int(g["score"]), 100, "perfect everything = 100")
	assert_eq(str(g["rank"]), "S")
	var g2 := Grading.running({"quiz_scores": [0], "battle_scores": [], "arena_best_wave": 0, "conduct_points": 0})
	assert_lt(int(g2["score"]), 60, "a bombed quiz drags the blend below neutral")


func test_rank_ladder():
	assert_eq(str(Grading.rank_for(95.0)[1]), "S")
	assert_eq(str(Grading.rank_for(80.0)[1]), "A")
	assert_eq(str(Grading.rank_for(70.0)[1]), "B")
	assert_eq(str(Grading.rank_for(55.0)[1]), "C")
	assert_eq(str(Grading.rank_for(30.0)[1]), "D")


func test_battle_score_shape():
	assert_eq(Grading.battle_score(true, 0, 8), 100, "clean fast win = perfect")
	assert_lt(Grading.battle_score(true, 2, 8), Grading.battle_score(true, 0, 8), "losses cost")
	assert_lt(Grading.battle_score(true, 0, 14), 100, "dawdling costs")
	assert_eq(Grading.battle_score(false, 0, 5), Grading.BATTLE_LOSS_SCORE, "a loss is a low fixed mark")


func test_campaign_recorders_feed_the_grade():
	Campaign.record_quiz(90)
	Campaign.record_battle_score(80)
	Campaign.record_arena_run(5)
	Campaign.add_conduct(10)
	var g := Campaign.running_grade()
	assert_eq(roundi(float(g["marks"]["coursework"])), 90)
	assert_eq(roundi(float(g["marks"]["arena"])), 50, "wave 5 of 10 = 50")
	assert_eq(roundi(float(g["marks"]["conduct"])), 70, "60 base + 10 participation")
	assert_gt(int(g["score"]), 60)


func test_semester_closes_and_locks_a_report_card():
	Campaign.record_quiz(100)
	var end_week := Campaign.semester_end_week()
	Campaign.week = end_week
	Campaign.advance_week()
	assert_eq(Campaign.semester, 2, "crossing the midpoint starts term two")
	assert_eq(Campaign.report_cards.size(), 1, "and locks a report card")
	assert_true((Campaign.grade_samples["quiz_scores"] as Array).is_empty(), "fresh term, fresh samples")


func test_grade_block_survives_a_save_round_trip():
	Campaign.record_quiz(85)
	Campaign.record_arena_run(3)
	var d := Campaign.to_dict()
	Campaign.reset_new_game(false)
	Campaign.from_dict(d)
	assert_eq((Campaign.grade_samples["quiz_scores"] as Array)[0], 85)
	assert_eq(int(Campaign.grade_samples["arena_best_wave"]), 3)


# --- the quiz pool: exploration is study -----------------------------------------

func test_lore_questions_gate_on_having_read_the_source():
	var closed := QuizScene.eligible_questions({})
	for q in closed:
		assert_eq(str(q.get("req_flag", "")), "", "unread lore stays out of the pool")
	var open := QuizScene.eligible_questions({"read_shelf_houses": true})
	assert_gt(open.size(), closed.size(), "reading the shelf adds its questions")


func test_pick_questions_returns_a_lesson():
	var qs := QuizScene.pick_questions(4, {})
	assert_eq(qs.size(), 4)
	for q in qs:
		assert_true(q.has("q") and q.has("choices") and q.has("correct"), "well-formed question")


# --- the lesson in the castle ----------------------------------------------------

var _castle: CastleScene


func _open_castle() -> void:
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	_castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(_castle)


func test_classroom_hosts_the_lesson_point():
	_open_castle()
	var found := false
	for p in _castle._rooms["classroom"].points:
		if p.id == "fn_class":
			found = true
	assert_true(found, "the classroom offers 'Attend the lesson'")


func test_teacher_matches_the_house():
	_open_castle()
	assert_eq(str(_castle._teacher()["id"]), "callan", "Emberwing learns under Callan")
	Campaign.house_locked = false
	Campaign.set_house("tidemark")
	assert_eq(str(_castle._teacher()["id"]), "maren", "Tidemark under Maren")
	Campaign.set_house("thornrook")
	assert_eq(str(_castle._teacher()["id"]), "alaric", "Thornrook under Alaric")


func test_lesson_runs_once_a_week_and_grades():
	_open_castle()
	_castle._start_class()
	assert_not_null(_castle._quiz, "the lesson opens")
	assert_true(_castle.busy(), "and gates walking")
	_castle._on_quiz_done(3, 4)  # 75%
	assert_null(_castle._quiz)
	assert_eq((Campaign.grade_samples["quiz_scores"] as Array)[0], 75, "the mark banked")
	assert_not_null(_castle._dialogue, "the teacher reacts")
	# the week is spent
	_castle._dialogue.queue_free()
	_castle._dialogue = null
	_castle._start_class()
	assert_null(_castle._quiz, "class is done for the week")


## AW-55 (Neal): the spellbook's magic answers KAI alone — no lane, no cast, and
## the Inventory hub refuses to trade any tome at all.
func test_spellbook_magic_is_kai_bound():
	Campaign.flags["school_ember"] = true
	var fire: WeaponDef = load("res://data/weapons/fire.tres")
	var kai := Unit.new()
	kai.setup((load("res://data/units/kai.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	assert_true(kai.can_use_weapon(fire), "Kai casts his learned school")
	var perrin := Unit.new()
	perrin.setup((load("res://data/units/perrin.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	assert_false(perrin.can_use_weapon(fire), "Perrin has no tome lane — the fire won't answer")
	var liora := Unit.new()
	liora.setup((load("res://data/units/liora.tres") as UnitDef).duplicate(), Grid.new(3, 3), Vector2i.ZERO)
	assert_true(liora.can_use_weapon(fire), "born mages still cast schooled tomes")
	kai.free(); perrin.free(); liora.free()


func test_hub_refuses_to_trade_tomes():
	var j = load("res://src/ui/academy_journal.gd").new()
	add_child_autofree(j)
	await wait_frames(1)
	# find a unit carrying a tome (Kai always carries Crownspark; also grant fire)
	Campaign.flags["school_ember"] = true
	var kai_i := -1
	for i in range(j._inv_units.size()):
		if j._inv_units[i]["id"] == "kai":
			kai_i = i
	j._inv_units[kai_i]["unit"].inventory.add(InventoryItem.from_weapon(load("res://data/weapons/fire.tres")))
	var inv: Inventory = j._inv_units[kai_i]["unit"].inventory
	var fire_i := -1
	for i in range(inv.items.size()):
		var w: WeaponDef = inv.items[i].weapon()
		if w != null and w.id == "fire":
			fire_i = i
	var before: int = inv.items.size()
	j._tab = 2
	j._inv_i = kai_i
	j._inv_mode = 2
	j._inv_item_i = fire_i
	j._inv_give_i = 0 if kai_i != 0 else 1
	j._inv_transfer()
	assert_eq(inv.items.size(), before, "no tome changes hands — spellbooks can't leak")


## AW-64: crossing the semester's end plays the report-card CEREMONY — teacher
## line, rank, and the reward chest (gold; a Promotion Seal at rank S).
func test_semester_end_plays_the_ceremony_with_rewards():
	_open_castle()
	# stack the term so the rank is S
	Campaign.record_quiz(100)
	Campaign.record_battle_score(100)
	Campaign.record_arena_run(10)
	Campaign.add_conduct(40)
	var gold_before := int(Campaign.flags.get("gold", 0))
	Campaign.week = Campaign.semester_end_week()
	_castle._rest_week()
	assert_eq(Campaign.semester, 2, "the term closed")
	assert_not_null(_castle._dialogue, "the ceremony plays")
	assert_gt(int(Campaign.flags.get("gold", 0)), gold_before, "the chest paid out")
	# rank S also grants the rare seal into Kai's persisted kit
	var saved: Array = Campaign.get_unit_state("kai")["inventory"]
	var has_seal := false
	for e in saved:
		if "promotion_seal" in str(e.get("path", "")):
			has_seal = true
	assert_true(has_seal, "an Ascendant term earns the Promotion Seal")


func test_perfect_score_awards_a_spellbook_once():
	_open_castle()
	_castle._start_class()
	_castle._on_quiz_done(4, 4)  # 100%
	assert_true(bool(Campaign.flags.get("spellbook_ember", false)), "the first book is Ember's")
	assert_true(bool(Campaign.flags.get("school_ember", false)), "and the school opens to Kai")
	# Kai's persisted kit now carries the Fire tome
	var saved: Array = Campaign.get_unit_state("kai")["inventory"]
	var has_fire := false
	for e in saved:
		if str(e.get("id", "")) == "fire":
			has_fire = true
	assert_true(has_fire, "the spellbook's tome is in Kai's saved kit")
	# a second perfect week grants the NEXT book, not a duplicate
	Campaign.advance_week()
	_castle._dialogue.queue_free()
	_castle._dialogue = null
	_castle._start_class()
	_castle._on_quiz_done(4, 4)
	assert_true(bool(Campaign.flags.get("spellbook_gale", false)), "the ladder advances to Gale")
