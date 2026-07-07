extends GutTest
## NW-1 (story spine v2): the draft prologue + house-pitch dialogue files parse
## cleanly under the real dialogue parser, so the canon scaffolding is safe to
## wire in later.

const FILES := [
	"prologue_forest_intro", "prologue_cave_awakening", "prologue_oakstead_wake",
	"prologue_parent_reveal", "road_bandit_intro",
	"house_pitch_emberwing", "house_pitch_tidemark", "house_pitch_thornrook",
]


func test_all_prologue_dialogues_parse():
	for name in FILES:
		var path := "res://data/dialogue/%s.json" % name
		assert_true(FileAccess.file_exists(path), "%s exists" % name)
		var s := DialogueScript.from_file(path)
		assert_true(s.ok(), "%s parses: %s" % [name, s.error])
		assert_gt(s.size(), 0, "%s has steps" % name)


func test_awakening_sets_its_flag():
	var s := DialogueScript.from_file("res://data/dialogue/prologue_cave_awakening.json")
	assert_true(s.ok())
	var found := false
	for i in range(s.size()):
		var step := s.get_step(i)
		if step.is_event() and step.event_name == "set_flag" and step.params.get("flag") == "kai_awakened":
			found = true
	assert_true(found, "the awakening beat sets the kai_awakened flag")
