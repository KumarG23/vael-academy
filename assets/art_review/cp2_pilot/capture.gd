extends SceneTree
var pilot: Node
const OUT := "/tmp/vael-cp2-captures"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280, 720)
	run.call_deferred()
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("CAPTURE ",name)
func run() -> void:
	pilot = load("res://scenes/proto/illustrated_pilot.tscn").instantiate()
	root.add_child(pilot)
	current_scene = pilot
	await create_timer(0.4).timeout
	await shot("01-idle")
	pilot._act("walk")
	await create_timer(0.32).timeout
	await shot("02-walk")
	await create_timer(1.12).timeout
	await shot("02b-return-walk")
	await idle()
	for action in ["hit", "crit", "miss", "cast", "kill", "spar"]:
		pilot._act(action)
		while pilot.kai.is_moving():
			await process_frame
		await create_timer(0.55 if action == "cast" else 0.25).timeout
		await shot("03-"+action+"-windup")
		await create_timer(0.22 if action == "cast" else (0.16 if action == "crit" else 0.22)).timeout
		await shot("04-"+action+"-impact")
		await idle()
		await create_timer(0.35).timeout
	pilot.reset_actors()
	pilot._act("dialogue")
	await create_timer(0.3).timeout
	await shot("05-dialogue")
	quit()
func idle() -> void:
	while pilot.busy:
		await process_frame
