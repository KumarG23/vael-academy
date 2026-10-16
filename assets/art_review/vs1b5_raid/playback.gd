extends SceneTree
## Native VN renderer/input playback of four approved package scripts.
## Separate from smoke.gd's full campaign path; never writes Campaign or saves.
const OUT := "res://assets/art_review/vs1b5_raid/"
const FILES := ["road_bandit_intro", "road_bandit_outro"]


func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	run.call_deferred()


func key() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func run() -> void:
	var scene = load("res://src/ui/dialogue_scene.gd").new()
	root.add_child(scene)
	current_scene = scene
	scene.typewriter_speed = 0.0  # reader-paced capture; production typing is unchanged
	for name: String in FILES:
		scene.play(load("res://src/ui/dialogue_script.gd").from_file("res://data/dialogue/" + name + ".json"))
		var count: int = 0
		while not scene.is_finished():
			var line: String = scene.current_line().text
			print(name, " ", scene._index, " ", line)
			var seconds: float = clampf(line.length() / 35.0, 1.5, 4.0)
			if name == "road_bandit_outro" and scene._index in [8, 9, 10, 11, 12, 13, 14]:
				seconds = maxf(seconds, 3.0)
			# Exact rendered frames make MovieWriter pacing independent of timers.
			for frame in range(int(ceil(seconds * 30.0))):
				await process_frame
			var before: int = scene._index
			await key()
			assert(scene.is_finished() or scene._index == before + 1, "no skipped dialogue panels")
			count += 1
		assert(count == scene._script.size())
		print("SCENE PASS ", name, " ", count)
	print("PASS native VN playback all 57 road panels; reader-paced, no Campaign/save writes")
	quit()
