extends SceneTree
## Real GPU / native resolver capture. Run with --fixed-fps 60 --write-movie.
const OUT := "res://assets/art_review/cp7_defeat"
var pilot: Node
var action := "defeat"
var contact_number := 0


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	run.call_deferred()


func shot(name: String) -> void:
	# Unit refreshes its actor texture in _process, after the beat callback.
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + name + ".png")


func on_beat(_mode: String, name: String) -> void:
	if name not in ["commit", "contact", "defeat"]:
		return
	var juice: Node = pilot.presentation.juice
	print("FRAME ", Engine.get_process_frames(), " ", action, " ", name,
		" pose=", juice.active_target._illustrated.pose,
		" source_hp=", juice.active_target.current_hp)
	if name == "contact":
		contact_number += 1
	if action == "defeat" or name == "defeat":
		shot(action + "-" + name + "-" + str(contact_number))


func run() -> void:
	pilot = (load("res://scenes/proto/hybrid_combat_pilot.tscn") as PackedScene).instantiate()
	root.add_child(pilot)
	current_scene = pilot
	pilot.mode = "B"
	pilot._update_mode()
	pilot.comparison_beat.connect(on_beat)
	await create_timer(0.6).timeout
	for kind: String in ["defeat", "critical"]:
		action = kind
		contact_number = 0
		await pilot.review(kind)
		print("RESULT ", kind, " seed=", pilot.last_seed, " ", pilot.last_result.strikes)
		await create_timer(0.5).timeout
	quit()
