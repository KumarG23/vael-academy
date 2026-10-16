extends GutTest
## AW-78: the awakening VN — narration steps, voice/backdrop fields, and the
## sequenced prologue scripts (co-write 2026-07-10, scenes 1–5).

const SCRIPTS := [
	"res://data/dialogue/prologue_forest_intro.json",
	"res://data/dialogue/prologue_cave_awakening.json",
	"res://data/dialogue/prologue_oakstead_wake.json",
	"res://data/dialogue/prologue_parent_reveal.json",
	"res://data/dialogue/prologue_director_arrives.json",
]


func test_all_five_prologue_scripts_parse():
	for path in SCRIPTS:
		var s := DialogueScript.from_file(path)
		assert_true(s.ok(), "%s parses: %s" % [path, s.error])
		assert_gt(s.size(), 5, path + " has real content")


func test_narration_is_inferred_from_empty_speaker_and_portrait():
	var s := DialogueScript.from_file(SCRIPTS[0])
	assert_true(s.get_step(0).is_narration(), "the opener belongs to the storyteller")
	var kai_line := s.get_step(1)
	assert_false(kai_line.is_narration(), "Kai's lines are spoken, not narrated")
	assert_eq(kai_line.portrait, "kai_nomark", "pre-awakening Kai wears no mark")


func test_voice_and_backdrop_fields_ride_the_steps():
	var s := DialogueScript.from_file(SCRIPTS[0])
	assert_eq(s.get_step(0).backdrop, "black", "text-on-black opener")
	assert_string_contains(s.get_step(0).voice, "p1_opener")
	assert_string_contains(s.get_step(1).backdrop, "forest_path.png", "the painted woods fade in on Kai's first line")


func test_referenced_backdrops_and_voices_exist():
	for path in SCRIPTS:
		var s := DialogueScript.from_file(path)
		for i in range(s.size()):
			var step := s.get_step(i)
			if not step.is_line():
				continue
			if step.backdrop != "" and not step.backdrop in ["black", "white"]:
				assert_true(ResourceLoader.exists(step.backdrop), step.backdrop + " exists")
			if step.voice != "":
				assert_true(ResourceLoader.exists(step.voice), step.voice + " exists")


func test_prologue_vn_sequences_its_scripts():
	var vn := PrologueVN.new()
	vn.exit_scene = ""  # tests never change the running scene
	vn.scripts = [SCRIPTS[0], SCRIPTS[1]] as Array[String]
	add_child_autofree(vn)
	assert_eq(vn._i, 0, "opens on the forest")
	var guard := 0
	while vn._i == 0 and guard < 60:
		vn._dialogue.advance()
		guard += 1
	assert_eq(vn._i, 1, "the forest hands over to the cave")
	guard = 0
	while not (vn._i >= 2) and guard < 80:
		vn._dialogue.advance()
		guard += 1
	assert_eq(vn._i, 2, "the cave ends the sequence")


func test_play_voice_is_null_safe():
	AudioManager.play_voice("res://assets/audio/vo/does_not_exist.wav")
	AudioManager.play_voice("")
	AudioManager.stop_voice()
	assert_true(true, "no crash on missing narration")


func test_backdrop_specials_and_texture_load():
	var d := DialogueScene.new()
	add_child_autofree(d)
	d._set_backdrop("white")
	assert_gt(d._backdrop_flat.a, 0.0, "white flash is a flat")
	d._set_backdrop("res://assets/art/vn/sanctum.png")
	assert_not_null(d._backdrop_tex, "the sanctum backdrop loads")
	assert_eq(d._backdrop_flat.a, 0.0, "texture replaces the flat")


## AW-79: scripts can score themselves — the music field parses and defaults empty.
func test_music_field_parses():
	var s := DialogueScript.from_json('[{"speaker":"","text":"x","music":"res://assets/audio/music/vn/forest.mp3"}]')
	assert_true(s.ok())
	assert_string_contains(s.get_step(0).music, "forest.mp3")
	var plain := DialogueScript.from_json('[{"speaker":"","text":"x"}]')
	assert_eq(plain.get_step(0).music, "", "no field, no change")



func after_each() -> void:
	Campaign.reset_new_game(false)


func _finish_vn(vn: PrologueVN) -> Array:
	var order: Array = []
	var guard: int = 0
	while vn._i < vn.scripts.size() and guard < 400:
		if order.is_empty() or order[-1] != vn._i:
			order.append(vn._i)
		vn._dialogue.advance()
		guard += 1
	assert_lt(guard, 400, "all authored scenes finish without a stall")
	return order


func test_campaign_opening_plays_all_five_and_commits_flags_only_at_their_beats():
	Campaign.reset_new_game(true)
	Campaign.active = true
	var vn: PrologueVN = load("res://scenes/flow/opening.tscn").instantiate()
	vn.exit_scene = ""
	add_child_autofree(vn)
	assert_eq(vn.scripts, SCRIPTS as Array[String], "canonical co-write order")
	assert_false(Campaign.flags.has("kai_awakened"), "no mark before the touch")
	while vn._i < 2:
		vn._dialogue.advance()
	assert_true(Campaign.flags.get("kai_awakened", false), "cave event reaches Campaign")
	assert_false(Campaign.flags.has("opening_complete"), "family and Hesta must still play")
	assert_eq(_finish_vn(vn), [2, 3, 4], "wake → reveal → collection/goodbye, once each")
	assert_true(Campaign.flags.get("opening_complete", false))
	assert_false(Campaign.flags.has("prologue_done"), "VN never wins the road")
	assert_false(Campaign.house_locked)
	assert_eq(Campaign.week, 1)
	assert_eq(Campaign.semester, 1)
	assert_true(Campaign.casual)
	assert_true(Campaign.active)
	assert_eq(Campaign.unit_states, {}, "no inventory/XP grant from narration")
	vn._next_script()
	assert_eq(vn._i, 5, "completion is idempotent")


func test_dev_preview_plays_the_whole_opening_without_campaign_writes():
	Campaign.reset_new_game(false)
	Campaign.active = true  # preview must be isolated even after an active run
	Campaign.flags["existing_progress"] = true
	var before := Campaign.to_dict()
	var vn: PrologueVN = load("res://scenes/flow/prologue_vn.tscn").instantiate()
	assert_false(vn.campaign_opening)
	assert_eq(vn.exit_scene, "res://scenes/title/title.tscn")
	vn.exit_scene = ""
	add_child_autofree(vn)
	assert_eq(_finish_vn(vn), [0, 1, 2, 3, 4])
	assert_eq(Campaign.to_dict(), before, "no awakening/completion leak into a save")


func test_missing_opening_script_stops_before_any_scene_or_progress_is_skipped():
	Campaign.reset_new_game(false)
	var vn := PrologueVN.new()
	vn.campaign_opening = true
	vn.exit_scene = ""
	vn.scripts = [SCRIPTS[0], "res://data/dialogue/missing_opening.json"] as Array[String]
	add_child_autofree(vn)
	assert_string_contains(vn.load_error, "missing_opening.json")
	assert_eq(vn._i, -1, "preflight fails before even the forest")
	assert_null(vn._dialogue)
	assert_eq(Campaign.flags, {}, "missing content cannot complete the opening")
