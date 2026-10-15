extends SceneTree
## CP-6 real-renderer capture; all outcomes come from the real combat resolver.
const OUT := "/tmp/vael-cp6-captures"
var pilot: Node
var action := "map"
var variant := "A"
var count := {}

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(OUT)
	run.call_deferred()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("CAPTURE ", name)

func on_beat(mode: String, name: String) -> void:
	print("BEAT ", mode, " ", action, " ", name)
	if name in ["establish", "ready", "critical_hold", "commit", "dodge", "release", "contact", "settle"]:
		var key := mode + "-" + action + "-" + name
		count[key] = int(count.get(key, 0)) + 1
		delayed_shot.call_deferred(key + "-" + str(count[key]))

func delayed_shot(name: String) -> void:
	for frame in range(6):
		await process_frame
	await shot(name)

func run() -> void:
	pilot = (load("res://scenes/proto/hybrid_combat_pilot.tscn") as PackedScene).instantiate()
	root.add_child(pilot)
	current_scene = pilot
	pilot.comparison_beat.connect(on_beat)
	await create_timer(0.6).timeout
	await shot("01-pixel-map")
	await pilot.kai.move_along_path([Vector2i(6, 4), Vector2i(5, 4), Vector2i(6, 4)])
	for kind: String in ["sword", "critical", "miss", "magic", "defeat"]:
		action = kind
		for mode: String in ["A", "B"]:
			pilot.mode = mode
			pilot._update_mode()
			await pilot.review(kind)
			print("RESULT ", mode, " ", kind, " seed ", pilot.last_seed, " ", pilot.last_result.strikes)
			await shot(mode + "-" + kind + "-return-map")
			await create_timer(0.5).timeout
	quit()
