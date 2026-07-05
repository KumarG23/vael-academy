extends GutTest
## WO-4.6: dialogue choices/branches — label/goto/choice parsing with jump
## validation, and branched playback (choice pauses, choose() resumes down the
## picked path, flags recorded). Linear scripts are untouched (WO-3.1 suites).

const BRANCH := """
[
  {"speaker":"A","text":"Pick."},
  {"choice":"Which way?","options":[
    {"text":"Left","goto":"left","flag":"went_left"},
    {"text":"Right","goto":"right"}
  ]},
  {"label":"left"},
  {"speaker":"A","text":"Left path."},
  {"goto":"end"},
  {"label":"right"},
  {"speaker":"A","text":"Right path."},
  {"label":"end"},
  {"speaker":"A","text":"Converged."}
]
"""

var _scene: DialogueScene
var _lines: Array = []
var _choices: Array = []
var _flags_seen: Array = []
var _finished := false


func before_each() -> void:
	_lines = []
	_choices = []
	_flags_seen = []
	_finished = false
	_scene = DialogueScene.new()
	_scene.typewriter_speed = 0.0
	add_child_autofree(_scene)
	_scene.line_shown.connect(func(step): _lines.append(step.text))
	_scene.choice_shown.connect(func(step): _choices.append(step.text))
	_scene.flag_set.connect(func(flag): _flags_seen.append(flag))
	_scene.finished.connect(func(): _finished = true)


func _play_to_end(script: DialogueScript, pick: int) -> void:
	_scene.play(script)
	var guard := 0
	while not _scene.is_finished() and guard < 50:
		if _scene.awaiting_choice():
			_scene.choose(pick)
		else:
			_scene.advance()
		guard += 1


# --- parsing -----------------------------------------------------------------

func test_parses_choice_labels_and_gotos():
	var s := DialogueScript.from_json(BRANCH)
	assert_true(s.ok(), "parses cleanly: " + s.error)
	var choice := s.get_step(1)
	assert_true(choice.is_choice())
	assert_eq(choice.text, "Which way?")
	assert_eq(choice.options.size(), 2)
	assert_eq(choice.options[0]["text"], "Left")
	assert_eq(choice.options[0]["goto"], "left")
	assert_eq(choice.options[0]["flag"], "went_left")
	assert_eq(choice.options[1]["flag"], "", "flag defaults to empty")
	assert_true(s.get_step(2).is_label())
	assert_true(s.get_step(4).is_goto())
	assert_eq(s.labels, {"left": 2, "right": 5, "end": 7})


func test_option_goto_defaults_to_fall_through():
	var s := DialogueScript.from_json('[{"choice":"?","options":[{"text":"Ok"}]},{"text":"next"}]')
	assert_true(s.ok())
	assert_eq(s.get_step(0).options[0]["goto"], "")


func test_goto_to_unknown_label_is_a_parse_error():
	var s := DialogueScript.from_json('[{"text":"hi"},{"goto":"nowhere"}]')
	assert_false(s.ok())
	assert_string_contains(s.error, "nowhere")


func test_option_goto_to_unknown_label_is_a_parse_error():
	var s := DialogueScript.from_json('[{"choice":"?","options":[{"text":"x","goto":"ghost"}]}]')
	assert_false(s.ok())
	assert_string_contains(s.error, "ghost")


func test_duplicate_label_is_a_parse_error():
	var s := DialogueScript.from_json('[{"label":"a"},{"text":"hi"},{"label":"a"}]')
	assert_false(s.ok())


func test_choice_requires_options_with_text():
	assert_false(DialogueScript.from_json('[{"choice":"?"}]').ok(), "missing options")
	assert_false(DialogueScript.from_json('[{"choice":"?","options":[]}]').ok(), "empty options")
	assert_false(DialogueScript.from_json('[{"choice":"?","options":[{"goto":"x"}]}]').ok(),
		"option without text")


func test_linear_scripts_have_no_labels():
	var s := DialogueScript.from_json('[{"speaker":"Kai","text":"Hi."}]')
	assert_true(s.ok())
	assert_true(s.labels.is_empty())


# --- playback ----------------------------------------------------------------

func test_choice_pauses_playback_and_blocks_advance():
	_scene.play(DialogueScript.from_json(BRANCH))
	_scene.advance()  # past "Pick." -> hits the choice
	assert_true(_scene.awaiting_choice())
	assert_eq(_choices, ["Which way?"], "choice_shown fired once")
	_scene.advance()
	assert_true(_scene.awaiting_choice(), "advance is a no-op while a choice is pending")
	assert_eq(_lines.size(), 1, "no new line shown")


func test_choosing_left_plays_only_the_left_path():
	_play_to_end(DialogueScript.from_json(BRANCH), 0)
	assert_true(_finished)
	assert_eq(_lines, ["Pick.", "Left path.", "Converged."])
	assert_true(_scene.flags.get("went_left", false), "the option's flag was recorded")
	assert_eq(_flags_seen, ["went_left"])


func test_choosing_right_plays_only_the_right_path():
	_play_to_end(DialogueScript.from_json(BRANCH), 1)
	assert_true(_finished)
	assert_eq(_lines, ["Pick.", "Right path.", "Converged."])
	assert_false(_scene.flags.has("went_left"), "no flag on the unflagged option")


func test_choose_out_of_range_is_a_no_op():
	_scene.play(DialogueScript.from_json(BRANCH))
	_scene.advance()
	_scene.choose(5)
	assert_true(_scene.awaiting_choice(), "still waiting on a valid answer")


func test_flags_reset_between_playbacks():
	_play_to_end(DialogueScript.from_json(BRANCH), 0)
	assert_true(_scene.flags.has("went_left"))
	_play_to_end(DialogueScript.from_json(BRANCH), 1)
	assert_false(_scene.flags.has("went_left"), "play() clears the previous run's flags")


func test_fall_through_option_continues_to_the_next_step():
	_play_to_end(DialogueScript.from_json(
		'[{"choice":"?","options":[{"text":"Ok","flag":"agreed"}]},{"speaker":"A","text":"after"}]'), 0)
	assert_true(_finished)
	assert_eq(_lines, ["after"])
	assert_true(_scene.flags.get("agreed", false))


func test_branch_sample_file_plays_both_paths():
	for pick in [0, 1]:
		_lines = []
		_finished = false
		_play_to_end(DialogueScript.from_file("res://data/dialogue/branch_sample.json"), pick)
		assert_true(_finished, "sample finished on pick %d" % pick)
		assert_eq(_lines.size(), 4, "ask + two path lines + converge on pick %d" % pick)
	assert_string_contains(_lines[1], "marsh", "pick 1 took the marsh branch")
