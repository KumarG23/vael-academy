extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func run() -> void:
	var title: Node = load("res://scenes/title/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	await press("cursor_down")
	await press("cursor_down")
	await press("cursor_confirm")
	for i in range(8):
		await press("cursor_down")
	await press("cursor_confirm")
	await process_frame
	print("ENTRY ", current_scene.scene_file_path)
	assert(current_scene.scene_file_path == "res://scenes/proto/authored_motion_pilot.tscn")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame
	print("RETURN ", current_scene.scene_file_path)
	assert(current_scene.scene_file_path == "res://scenes/title/title.tscn")
	quit()
