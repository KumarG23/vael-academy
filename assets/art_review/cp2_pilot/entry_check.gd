extends SceneTree
func _initialize() -> void:
	root.size = Vector2i(1280,720)
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
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/vael-cp2-captures/00-dev-jump.png")
	for i in 7:
		await press("cursor_down")
	await press("cursor_confirm")
	await create_timer(0.4).timeout
	print("ENTRY_SCENE ",current_scene.scene_file_path)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/vael-cp2-captures/06-entry.png")
	quit()
