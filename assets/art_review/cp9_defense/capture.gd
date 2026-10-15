extends SceneTree
## Actual input callbacks and native base strike; no hardcoded adjusted results.
const OUT := "res://assets/art_review/cp9_defense/"
var pilot: Node
var case_name := "dodge"
var choice := "dodge"
var offset := 0.0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")


func on_window() -> void:
	if choice == "":
		return
	var at := float(pilot.trial.settings["cue"]) + offset
	while pilot.trial.elapsed < at:
		await process_frame
	var event := InputEventKey.new()
	event.keycode = KEY_Q if choice == "dodge" else KEY_E
	event.pressed = true
	pilot._unhandled_input(event)
	print("INPUT ", case_name, " ", choice, " elapsed=", pilot.trial.input_time)


func run() -> void:
	pilot = (load("res://scenes/proto/active_defense_pilot.tscn") as PackedScene).instantiate()
	root.add_child(pilot)
	current_scene = pilot
	pilot.window_opened.connect(on_window)
	pilot.judged.connect(func(report: Dictionary) -> void: print("JUDGED ", case_name, " ", report, " hp_before_contact=", pilot.kai.current_hp))
	pilot.presentation.impact_applied.connect(func(source: Node, strike) -> void:
		print("CONTACT ", case_name, " hp=", source.current_hp, " ", strike)
		shot(case_name + "-contact"))
	await create_timer(0.7).timeout
	await shot("ready")
	for scenario: String in ["dodge", "block", "early", "no-input", "assist"]:
		case_name = scenario
		choice = "dodge" if scenario in ["dodge", "early"] else ("block" if scenario == "block" else "")
		offset = -0.6 if scenario == "early" else 0.0
		pilot.auto_block = scenario == "assist"
		pilot._assist_button.button_pressed = pilot.auto_block
		await pilot.begin_trial()
		await shot(scenario + "-map")
		await create_timer(0.8).timeout
	quit()
