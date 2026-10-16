extends SceneTree
## Native full-board/normal-camera readability and cosmetic-state review.
const OUT := "res://assets/art_review/vs1b5_raid/"
func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	run.call_deferred()
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
func action(name: String) -> void:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	Input.parse_input_event(e)
	await process_frame
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await process_frame
func run() -> void:
	var view = load("res://scenes/battle/prologue.tscn").instantiate()
	view.dialogue_enabled = false
	root.add_child(view)
	current_scene = view
	var before = view.make_save_payload()
	view._cursor.set_process(false)
	for i in range(240):
		await process_frame
	await shot("map-start")
	view.set_process(false) # freeze camera follow only; child terrain VFX still run
	view._camera.zoom = Vector2.ONE * minf(1100.0 / view._grid.pixel_size().x, 580.0 / view._grid.pixel_size().y)
	view._camera.position = view._grid.pixel_size() * 0.5
	view._camera.position_smoothing_enabled = false
	for i in range(30):
		await process_frame
	await shot("map-overview")
	view._cursor.move_to(view.unit_by_id("kai").cell)
	await action("cursor_confirm")
	for i in range(60):
		await process_frame
	await shot("map-movement")
	await action("cursor_cancel")
	var e := InputEventKey.new()
	e.keycode = KEY_H
	e.pressed = true
	Input.parse_input_event(e)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	for i in range(120):
		await process_frame
	await shot("map-threats")
	assert(view.make_save_payload() == before, "presentation cannot change battle, RNG or campaign")
	print("PASS real map: normal start, full board, threat ranges; battle payload unchanged")
	quit()
