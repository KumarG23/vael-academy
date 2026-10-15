extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var campaign: Node = root.get_node("Campaign")
	var state: Dictionary = campaign.call("to_dict").duplicate(true)
	var title: Node = (load("res://scenes/title/title.tscn") as PackedScene).instantiate()
	root.add_child(title)
	current_scene = title
	title._dev_jump("active_defense")
	for frame in range(6):
		await process_frame
	var pilot: Node = current_scene
	assert(pilot.get_script().resource_path.ends_with("active_defense_pilot.gd"))
	pilot.presentation.impact_applied.connect(func(_source: Node, _strike) -> void:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = true
		pilot._unhandled_input(event))
	pilot.begin_trial()
	var deadline := Time.get_ticks_msec() + 10000
	while (current_scene == null or current_scene == pilot) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(current_scene != null)
	assert(current_scene.get_script().resource_path.ends_with("title_screen.gd"))
	# Let the interrupted hit-stop timer and deferred scene cleanup finish.
	pilot = null
	title = null
	await create_timer(0.3, true, false, true).timeout
	assert(is_equal_approx(Engine.time_scale, 1.0))
	assert(campaign.call("to_dict") == state)
	print("PASS real title route, Escape at impact, time-scale restoration, Campaign unchanged")
	quit()
