extends GutTest
## WO-5.7 + AW-57: the romance tier — one rank past A for flagged pairs,
## exclusive (one love, Neal's rule), persisted — and OPT-IN: the ♥ dialogue
## choice records consent, and points alone never reach S without it.


func _chain(a: String, b: String, romance: bool) -> SupportChainDef:
	var c := SupportChainDef.new()
	c.unit_a_id = a
	c.unit_b_id = b
	c.romance_eligible = romance
	return c


func _state_with(chains: Array) -> SupportState:
	var s := SupportState.new()
	for c in chains:
		s.add_chain(c)
	return s


# --- consent: the heart is chosen, never automatic (AW-57) ------------------------

func test_points_alone_never_reach_the_romance_rank():
	var s := _state_with([_chain("kai", "liora", true)])
	var result := s.add_points("kai", "liora", 200)
	assert_eq(result["new_rank"], "A", "a mountain of points caps at A without the ♥")
	assert_false(s.is_romanced("kai"))


func test_consent_blossoms_when_the_bond_is_deep():
	var s := _state_with([_chain("kai", "liora", true)])
	s.add_points("kai", "liora", 200)
	var res := s.consent_romance("kai", "liora")
	assert_true(bool(res.get("ranked_up", false)), "the ♥ choice completes it")
	assert_eq(str(res.get("new_rank", "")), "S")
	assert_eq(s.romance_partner("kai"), "liora")
	assert_eq(s.romance_partner("liora"), "kai")


func test_consent_before_the_bond_is_ready_waits():
	var s := _state_with([_chain("kai", "liora", true)])
	s.add_points("kai", "liora", 25)      # low bond
	var res := s.consent_romance("kai", "liora")
	assert_false(bool(res.get("ranked_up", false)), "consent recorded, S waits for the bond")
	assert_false(s.is_romanced("kai"))
	s.add_points("kai", "liora", 200)     # the bond catches up later
	assert_eq(s.rank_for_units("kai", "liora"), "S", "and the earlier consent lets it bloom")


func test_non_romance_pairs_cap_at_A():
	var s := _state_with([_chain("kai", "kael", false)])
	s.add_points("kai", "kael", 999)
	assert_eq(s.rank_for_units("kai", "kael"), "A", "no S without the flag")
	assert_true(s.consent_romance("kai", "kael").is_empty(), "and no consent to give")
	assert_false(s.is_romanced("kai"))


func test_romance_is_exclusive():
	var s := _state_with([_chain("kai", "liora", true), _chain("kai", "rina", true)])
	s.add_points("kai", "liora", 200)
	s.add_points("kai", "rina", 200)
	s.consent_romance("kai", "liora")
	assert_eq(s.romance_partner("kai"), "liora")
	var second := s.consent_romance("kai", "rina")
	assert_true(second.is_empty(), "Kai is spoken for — a second ♥ is refused")
	assert_eq(s.rank_for_units("kai", "rina"), "A", "the other bond stays a friendship")


func test_romances_and_consents_survive_save_state():
	var s := _state_with([_chain("kai", "liora", true)])
	s.add_points("kai", "liora", 25)
	s.consent_romance("kai", "liora")     # early consent, bond not there yet
	var s2 := _state_with([_chain("kai", "liora", true)])
	s2.apply_save_state(s.save_state())
	s2.add_points("kai", "liora", 200)
	assert_eq(s2.rank_for_units("kai", "liora"), "S", "the saved consent still counts")
	assert_eq(s2.romance_partner("kai"), "liora")


func test_authored_chain_is_flagged_and_bonus_grows():
	var chain: SupportChainDef = load("res://data/supports/kai_liora.tres")
	assert_true(chain.romance_eligible)
	assert_eq(chain.ranks(), ["C", "B", "A", "S"])
	var s := _state_with([chain])
	s.consent_romance("kai", "liora")
	s.add_points("kai", "liora", chain.s_threshold)
	var bonus := s.bonus_for_unit("kai", ["liora"])
	assert_eq(bonus["hit"], 20, "S-rank bonus outranks A")


func test_confession_scene_branches_both_ways():
	var scene := DialogueScene.new()
	scene.typewriter_speed = 0.0
	add_child_autofree(scene)
	for pick in [0, 1]:
		scene.play(DialogueScript.from_file("res://data/supports/kai_liora_s.json"))
		var guard := 0
		while not scene.is_finished() and guard < 60:
			if scene.awaiting_choice():
				scene.choose(pick)
			else:
				scene.advance()
			guard += 1
		assert_true(scene.is_finished(), "confession finished on pick %d" % pick)
		if pick == 0:
			assert_true(scene.flags.get("romance_liora", false), "acceptance sets the flag")
		else:
			assert_false(scene.flags.has("romance_liora"), "the gentle path sets no flag")


# --- the ♥ option in dialogue (AW-57) ----------------------------------------------

const HEART_JSON := """[
 {"speaker": "Liora", "portrait": "liora", "text": "Hey."},
 {"choice": "Say something.",
  "options": [
   {"text": "Nice weather.", "goto": ""},
   {"text": "It's you.", "heart": "liora"}
  ]}
]"""


func test_heart_option_hides_without_a_gate():
	var d := DialogueScene.new()
	d.typewriter_speed = 0.0
	add_child_autofree(d)
	d.play(DialogueScript.from_json(HEART_JSON))
	d.advance()
	assert_true(d.awaiting_choice())
	assert_eq(d.shown_option_indices(), [0], "no gate = the ♥ stays hidden")


func test_heart_option_shows_when_the_gate_allows():
	var d := DialogueScene.new()
	d.typewriter_speed = 0.0
	add_child_autofree(d)
	d.heart_gate = func(uid: String) -> bool: return uid == "liora"
	d.play(DialogueScript.from_json(HEART_JSON))
	d.advance()
	assert_eq(d.shown_option_indices(), [0, 1], "the gate opens the ♥")


func test_choosing_the_heart_emits_the_romance_event():
	var d := DialogueScene.new()
	d.typewriter_speed = 0.0
	add_child_autofree(d)
	d.heart_gate = func(_uid: String) -> bool: return true
	d.play(DialogueScript.from_json(HEART_JSON))
	d.advance()
	var got: Array = []
	d.event_triggered.connect(func(n: String, p: Dictionary) -> void: got.append([n, p]))
	d.choose(1)
	assert_eq(got.size(), 1)
	assert_eq(str(got[0][0]), "romance")
	assert_eq(str(got[0][1]["with"]), "liora")


# --- bonds through campus dialogue (AW-57, Neal's ask) ------------------------------

func test_campus_chat_bond_event_deepens_the_support():
	Campaign.reset_new_game(false)
	CastleScene.next_room = ""
	CastleScene.next_spawn = Vector2i(-1, -1)
	var castle := (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
	add_child_autofree(castle)
	var before: int = castle._support_state.points_for_units("kai", "liora")
	castle._on_dialogue_event("bond", {"with": "liora", "points": 8})
	assert_eq(castle._support_state.points_for_units("kai", "liora"), before + 8,
		"saying the right thing deepens the bond")
	assert_true(Campaign.support_save.has("points"), "and it persists to the campaign")
	Campaign.reset_new_game(false)


func test_lioras_campus_chat_carries_the_scaffold():
	var s := DialogueScript.from_file("res://data/dialogue/castle_liora.json")
	assert_true(s.ok(), "the demo chat parses: " + s.error)
	var has_heart := false
	var has_bond := false
	for i in range(s.size()):
		var step := s.get_step(i)
		if step.is_choice():
			for o in step.options:
				if str(o.get("heart", "")) != "":
					has_heart = true
		if step.is_event() and step.event_name == "bond":
			has_bond = true
	assert_true(has_heart, "a ♥ option waits behind the gate")
	assert_true(has_bond, "and the right words carry bond points")


# --- emotion portraits (AW-57 convention) -------------------------------------------

func test_portrait_resolves_emotion_variants_with_base_fallback():
	# AW-58: Liora's Gemini emotion set is installed — variants win when they exist
	assert_eq(DialogueScene.portrait_path("liora", "happy"),
		"res://assets/portraits/portrait_liora_happy.png",
		"the happy variant serves her happy lines")
	assert_eq(DialogueScene.portrait_path("liora", "sleepy"),
		"res://assets/portraits/portrait_liora.png",
		"an expression with no art falls back to the base")
	assert_eq(DialogueScene.portrait_path("liora", "neutral"),
		"res://assets/portraits/portrait_liora.png")


func test_liora_ships_the_full_emotion_set():
	for e in ["happy", "sad", "angry", "blush"]:
		assert_true(ResourceLoader.exists("res://assets/portraits/portrait_liora_%s.png" % e),
			"portrait_liora_%s.png installed" % e)
