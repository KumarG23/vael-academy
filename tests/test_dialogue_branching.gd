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


# --- edge cases and UI helpers ------------------------------------------------

func test_leading_choice_works_without_a_current_line():
	var s := DialogueScript.from_json('[{"choice":"Pick?","options":[{"text":"A"},{"text":"B"}]},{"text":"after"}]')
	assert_true(s.ok())
	_scene.play(s)
	assert_true(_scene.awaiting_choice())
	assert_eq(_choices, ["Pick?"], "choice_shown fired for leading choice")
	# No line should be shown yet
	assert_eq(_lines.size(), 0)
	_scene.choose(0)
	var guard := 0
	while not _scene.is_finished() and guard < 10:
		_scene.advance()
		guard += 1
	assert_true(_finished)
	assert_eq(_lines, ["after"])


func test_shown_option_indices_reflects_filtered_options():
	var s := DialogueScript.from_json('''
	[{"choice":"Pick?",
	  "options":[
	    {"text":"Normal"},
	    {"text":"Heart option","heart":"liora"}
	  ]}
	]''')
	assert_true(s.ok())
	_scene.play(s)
	_scene.advance()  # hit the choice
	# Without heart_gate, heart option is hidden
	assert_eq(_scene.shown_option_indices(), [0])
	# With heart_gate allowing, both shown
	_scene.heart_gate = func(uid: String) -> bool: return uid == "liora"
	_scene._refresh_shown_options()
	assert_eq(_scene.shown_option_indices(), [0, 1])


func test_choice_with_only_heart_options_falls_back_to_showing_all():
	# Authoring safety: if all options are heart options and gate blocks all,
	# the fallback shows all options so the player isn't stranded.
	var s := DialogueScript.from_json('''
	[{"choice":"Pick?",
	  "options":[
	    {"text":"Heart A","heart":"a"},
	    {"text":"Heart B","heart":"b"}
	  ]}
	]''')
	assert_true(s.ok())
	_scene.play(s)
	_scene.advance()
	# Gate blocks both
	_scene.heart_gate = func(uid: String) -> bool: return false
	_scene._refresh_shown_options()
	assert_eq(_scene.shown_option_indices(), [0, 1], "fallback shows all when gate blocks everything")


## The overlay fills the viewport even under a CanvasLayer (how castle, battle,
## hub and house choice parent it). Before this, PRESET_FULL_RECT alone left a
## zero-sized rect under a non-Control parent, so clicks never reached _gui_input.
func test_scene_fills_the_viewport_under_a_canvas_layer():
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var scene := DialogueScene.new()
	scene.typewriter_speed = 0.0
	layer.add_child(scene)
	await wait_physics_frames(1)
	assert_gt(scene.size.x, 0.0, "the overlay has a clickable width")
	assert_eq(scene.size, scene.get_viewport_rect().size, "the overlay covers the viewport")
	assert_eq(scene.global_position, Vector2.ZERO, "top-left anchors keep the overlay at the origin")


## A real viewport click on a specific option row must choose that row, not just
## confirm the highlighted one. A desktop-sized SubViewport is used because GUT's
## headless viewport (64x64) puts the option panel off-screen.
func test_viewport_click_on_a_choice_row_picks_it():
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	add_child_autofree(vp)
	var scene := DialogueScene.new()
	scene.typewriter_speed = 0.0
	vp.add_child(scene)
	scene.play(DialogueScript.from_json(BRANCH))
	scene.advance()
	assert_true(scene.awaiting_choice(), "the script paused on its choice")
	var vp_size := scene.get_viewport_rect().size
	var row_h := 40.0
	var title_h := 44.0
	var panel_pos := Vector2(vp_size.x * 0.50, vp_size.y * 0.66 - title_h - row_h * 2 - 24)
	var right_row := Rect2(panel_pos + Vector2(10, title_h + row_h),
		Vector2(vp_size.x * 0.36 - 20, row_h - 6))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = right_row.get_center()
	click.global_position = click.position
	vp.push_input(click)
	await wait_physics_frames(1)
	assert_false(scene.awaiting_choice(), "the row click answered the choice")
	assert_eq(scene.current_line().text, "Right path.")
	assert_eq(scene.flags, {}, "the Right option sets no flag")
