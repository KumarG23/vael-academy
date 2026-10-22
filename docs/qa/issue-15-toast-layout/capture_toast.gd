extends SceneTree
## Issue #15 capture: real castle scene, real fishing finish path, rendered frame.
var out_dir := ""
var sizes := [Vector2i(1280, 720), Vector2i(800, 450)]

func _initialize() -> void:
	out_dir = OS.get_environment("CAP_OUT")
	_run.call_deferred()

func _run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.reset_new_game(false)
	load("res://src/castle/castle_scene.gd").next_room = "waterside"
	for size in sizes:
		root.size = size
		DisplayServer.window_set_size(size)
		await process_frame
		var castle = (load("res://scenes/castle/castle.tscn") as PackedScene).instantiate()
		root.add_child(castle)
		await create_timer(2.3).timeout  # arrival title card (1.5s hold + 0.45s fade)
		campaign.fish_log["Warded Coin"] = 1
		castle._start_fishing()
		castle._fishing.finished.emit({"caught": true, "fish": "Warded Coin"})
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		_shot(castle, size, "fishing")
		castle._toast("No bonds strong enough yet — fight beside your housemates.")
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		_shot(castle, size, "support")
		castle._toast("Week 5: The Clash of Three Banners awaits — the year holds its breath until you answer it.")
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		_shot(castle, size, "long")
		castle.queue_free()
		load("res://src/castle/castle_scene.gd").next_room = "waterside"
		await process_frame
	quit()

func _shot(castle, size: Vector2i, tag: String) -> void:
	var t: Label = castle._toast_label
	var img := root.get_texture().get_image()
	var path := "%s/toast-%s-%dx%d.png" % [out_dir, tag, size.x, size.y]
	img.save_png(path)
	print("CARD showing=%s" % castle._title_card.is_showing())
	print("CAP %s %dx%d img=%dx%d rect=%s lines=%d text=%s" % [tag, size.x, size.y,
		img.get_width(), img.get_height(), t.get_global_rect(), t.get_line_count(), t.text])
