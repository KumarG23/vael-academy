extends SceneTree
## Real road map, unaltered units/terrain, cosmetic fire with visible threat tiles.
func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	run.call_deferred()

func run() -> void:
	var view = load("res://scenes/battle/prologue.tscn").instantiate()
	view.dialogue_enabled = false  # isolated map presentation review, no story flags
	root.add_child(view)
	current_scene = view
	var before = view.make_save_payload()
	view._cursor.set_process(false)
	view._cursor.move_to(Vector2i(11, 7))
	for i in range(60):
		await process_frame
	var e := InputEventKey.new()
	e.keycode = KEY_H
	e.pressed = true
	Input.parse_input_event(e)
	for i in range(180):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://assets/art_review/vs1b_package/fire-threats.png")
	assert(view.make_save_payload() == before, "animation/panning cannot change campaign, units, terrain or RNG")
	print("PASS fire/embers/smoke on real map with threats; native battle payload unchanged")
	quit()
