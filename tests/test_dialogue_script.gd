extends GutTest
## WO-3.1: JSON dialogue parser.


func test_parses_lines_and_events():
	var json := """
	[
	  {"speaker":"Ash","side":"left","text":"Hello."},
	  {"event":"give_item","to":"Kael","item":"vulnerary"},
	  {"speaker":"Serra","side":"right","text":"Hmph."}
	]
	"""
	var s := DialogueScript.from_json(json)
	assert_true(s.ok(), "parses cleanly: " + s.error)
	assert_eq(s.size(), 3)
	assert_true(s.get_step(0).is_line())
	assert_eq(s.get_step(0).speaker, "Ash")
	assert_eq(s.get_step(0).side, "left")
	assert_true(s.get_step(1).is_event())
	assert_eq(s.get_step(1).event_name, "give_item")
	assert_eq(s.get_step(1).params.get("item"), "vulnerary")
	assert_eq(s.get_step(1).params.get("to"), "Kael")
	assert_false(s.get_step(1).params.has("event"), "the event key is stripped from params")


func test_line_defaults():
	var s := DialogueScript.from_json('[{"text":"Just narration."}]')
	assert_true(s.ok())
	var step := s.get_step(0)
	assert_eq(step.speaker, "")
	assert_eq(step.side, "left", "defaults to the left side")
	assert_eq(step.expression, "neutral")


func test_invalid_json_reports_error():
	var s := DialogueScript.from_json("{ not valid ]")
	assert_false(s.ok())
	assert_ne(s.error, "")


func test_non_array_root_is_rejected():
	var s := DialogueScript.from_json('{"speaker":"Ash","text":"x"}')
	assert_false(s.ok(), "root must be an array")


func test_line_without_text_is_rejected():
	var s := DialogueScript.from_json('[{"speaker":"Ash"}]')
	assert_false(s.ok())
	assert_string_contains(s.error, "text")


func test_terminal_event_detection():
	assert_true(DialogueScript.is_terminal_event("start_battle"))
	assert_false(DialogueScript.is_terminal_event("give_item"))


func test_loads_the_sample_script_from_disk():
	var s := DialogueScript.from_file("res://data/dialogue/sample.json")
	assert_true(s.ok(), "sample.json parses: " + s.error)
	assert_gt(s.size(), 0)
	# It ends by starting the battle.
	assert_true(s.get_step(s.size() - 1).is_event())
	assert_eq(s.get_step(s.size() - 1).event_name, "start_battle")
