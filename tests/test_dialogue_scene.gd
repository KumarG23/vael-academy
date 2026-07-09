extends GutTest
## WO-3.1: the VN dialogue player runs a script start to finish, showing lines in
## order, firing event hooks, and finishing at the terminal event.

var _scene: DialogueScene
var _lines: Array = []
var _events: Array = []
var _finished := false


func before_each() -> void:
	_lines = []
	_events = []
	_finished = false
	_scene = DialogueScene.new()
	_scene.typewriter_speed = 0.0  # show lines instantly for deterministic stepping
	add_child_autofree(_scene)
	_scene.line_shown.connect(func(step): _lines.append(step.speaker + ": " + step.text))
	_scene.event_triggered.connect(func(name, params): _events.append([name, params]))
	_scene.finished.connect(func(): _finished = true)


func _script(json: String) -> DialogueScript:
	return DialogueScript.from_json(json)


func test_plays_the_sample_start_to_finish():
	_scene.play(DialogueScript.from_file("res://data/dialogue/sample.json"))
	# First line is shown by play(); advance until finished.
	var guard := 0
	while not _scene.is_finished() and guard < 50:
		_scene.advance()
		guard += 1
	assert_true(_finished, "reached the end of the script")
	assert_eq(_lines.size(), 4, "four spoken lines shown (Kai, Serra, Rina, Kai)")
	assert_eq(_lines[0], "Kai: Emberwing, form up! The Mock Battle is ours to win.")
	# give_item then start_battle fired.
	assert_eq(_events.size(), 2)
	assert_eq(_events[0][0], "give_item")
	assert_eq(_events[1][0], "start_battle")


func test_first_line_is_shown_on_play():
	_scene.play(_script('[{"speaker":"Kai","text":"Hi."},{"speaker":"Serra","text":"Bye."}]'))
	assert_eq(_scene.current_line().speaker, "Kai")
	assert_eq(_lines.size(), 1, "the opening line appears immediately")


func test_leading_events_fire_before_the_first_line():
	_scene.play(_script('[{"event":"give_item","item":"x"},{"speaker":"Kai","text":"Now me."}]'))
	assert_eq(_events.size(), 1, "the leading event fired")
	assert_eq(_scene.current_line().speaker, "Kai")


func test_start_battle_is_terminal():
	_scene.play(_script('[{"speaker":"Kai","text":"Charge!"},{"event":"start_battle"},{"speaker":"Ghost","text":"never seen"}]'))
	_scene.advance()  # past Kai's line -> hits start_battle -> finishes
	assert_true(_scene.is_finished())
	assert_eq(_lines.size(), 1, "the line after start_battle is never shown")


func test_typewriter_reveal_then_advance():
	_scene.typewriter_speed = 10.0  # slow reveal
	_scene.play(_script('[{"speaker":"Kai","text":"Hello there"},{"speaker":"Serra","text":"Hi"}]'))
	assert_true(_scene.is_revealing(), "line starts revealing")
	# First advance completes the reveal, not the line.
	_scene.advance()
	assert_false(_scene.is_revealing(), "reveal snapped to full")
	assert_eq(_scene.current_line().speaker, "Kai", "still on Kai's line")
	# Second advance moves on.
	_scene.advance()
	assert_eq(_scene.current_line().speaker, "Serra")
