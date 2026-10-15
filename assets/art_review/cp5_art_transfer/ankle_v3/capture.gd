extends SceneTree
## Run without --headless; the actor needs a real 3D renderer.
const OUT := "/tmp/vael-cp5-ankle-captures"
# Load the scene after autoload startup (HANDOFF standalone -s cache gotcha).
var pilot: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280, 720)
	run.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("CAPTURE ", name)


func wait_for_action() -> void:
	for frame in range(900):
		if not pilot.busy:
			return
		await process_frame
	push_error("Motion capture timed out: position=%s target=%s velocity=%s pause=%s" % [pilot.actor.position, pilot._target, pilot._velocity, pilot._pause])
	quit(1)


func run() -> void:
	pilot = (load("res://scenes/proto/kai_art_motion_pilot.tscn") as PackedScene).instantiate()
	root.add_child(pilot)
	current_scene = pilot
	await create_timer(0.5).timeout
	await shot("01-kai-art-idle")
	print("HUMAN height ", pilot.actor.source_height, " factor ", pilot.actor.pixel_factor, " nominal speed ", pilot.actor.nominal_speed())
	pilot._act("walk")
	await create_timer(0.7).timeout
	await shot("02-kai-art-walk")
	await create_timer(2.8).timeout
	await shot("03-kai-art-return")
	await wait_for_action()
	pilot._act("turn")
	await create_timer(1.2).timeout
	await shot("04-mannequin-turn")
	await wait_for_action()
	pilot._act("reset")
	pilot._compare()
	pilot._act("formal")
	pilot._act("walk")
	await create_timer(0.7).timeout
	await shot("05-formal-walk")
	await wait_for_action()
	# Review-only close view; never changes the actor's game-scale setup.
	pilot.actor.scale = Vector2.ONE * 1.7
	pilot.actor.position = Vector2(580, 570)
	pilot.actor.target_yaw = 0.85
	await create_timer(0.5).timeout
	await shot("06-kai-art-close")
	# Review every ankle through complete close-up cycles in both facings.
	pilot.set_process(false)
	pilot.actor.set_process(false)
	pilot.illustration.set_process(false)
	pilot.actor.position = Vector2(580, 500)
	for clip: String in ["Walk", "Walk_Formal"]:
		pilot.actor.player.play(clip, 0.0)
		var duration: float = pilot.actor.player.current_animation_length
		pilot.actor.player.pause()
		for yaw: float in [PI / 2.0, -PI / 2.0]:
			pilot.actor.target_yaw = yaw
			for frame in range(80):
				pilot.actor.player.seek(duration * frame / 80.0, true)
				pilot.actor.player.advance(0.0)
				pilot.illustration.update_from_motion()
				await process_frame
				if frame in [40, 70]:
					await shot("ankle-%s-%s-%02d" % [clip, "east" if yaw > 0 else "west", frame])
	quit()
