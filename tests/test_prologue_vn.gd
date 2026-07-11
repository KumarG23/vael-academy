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
	assert_string_contains(s.get_step(1).backdrop, "forest.png", "the woods fade in on Kai's first line")


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
