extends GutTest
## WO-5.7: the romance tier — one rank past A for flagged pairs, exclusive,
## persisted, with a branched confession scene riding WO-4.6.


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


func test_flagged_pair_reaches_the_romance_rank():
	var s := _state_with([_chain("kai", "liora", true)])
	var result := s.add_points("kai", "liora", 200)
	assert_true(result["ranked_up"])
	assert_eq(result["new_rank"], "S")
	assert_eq(s.romance_partner("kai"), "liora")
	assert_eq(s.romance_partner("liora"), "kai")


func test_non_romance_pairs_cap_at_A():
	var s := _state_with([_chain("kai", "kael", false)])
	var result := s.add_points("kai", "kael", 999)
	assert_eq(result["new_rank"], "A", "no S without the flag")
	assert_false(s.is_romanced("kai"))


func test_romance_is_exclusive():
	var s := _state_with([_chain("kai", "liora", true), _chain("kai", "corin", true)])
	s.add_points("kai", "liora", 200)
	var result := s.add_points("kai", "corin", 200)
	assert_eq(result["new_rank"], "A", "Kai is spoken for — the second pair stops at A")
	assert_eq(s.romance_partner("kai"), "liora")


func test_romances_survive_save_state():
	var s := _state_with([_chain("kai", "liora", true)])
	s.add_points("kai", "liora", 200)
	var s2 := _state_with([_chain("kai", "liora", true)])
	s2.apply_save_state(s.save_state())
	assert_eq(s2.romance_partner("kai"), "liora")
	assert_eq(s2.highest_rank_for_pair("kai_liora"), "S")


func test_authored_chain_is_flagged_and_bonus_grows():
	var chain: SupportChainDef = load("res://data/supports/kai_liora.tres")
	assert_true(chain.romance_eligible)
	assert_eq(chain.ranks(), ["C", "B", "A", "S"])
	var s := _state_with([chain])
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
