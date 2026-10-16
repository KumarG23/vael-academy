extends SceneTree
## Short composition proof through the real VN input/rendering path.
func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	run.call_deferred()

func run() -> void:
	var scene = load("res://src/ui/dialogue_scene.gd").new()
	root.add_child(scene)
	scene.play(load("res://src/ui/dialogue_script.gd").from_file("res://data/dialogue/road_bandit_outro.json"))
	while scene._index < 11:
		scene.skip_reveal()
		var e := InputEventKey.new()
		e.pressed = true
		e.keycode = KEY_ENTER
		scene._unhandled_key_input(e)
	scene.skip_reveal()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/art_review/vs1b_package/bread-insets-after.png")
	quit()
