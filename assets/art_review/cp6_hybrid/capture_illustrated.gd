extends "res://assets/art_review/cp6_hybrid/capture.gd"
## Same final B player and native outcomes, without A segments in the movie.
func run() -> void:
	pilot = (load("res://scenes/proto/hybrid_combat_pilot.tscn") as PackedScene).instantiate()
	root.add_child(pilot)
	current_scene = pilot
	pilot.comparison_beat.connect(on_beat)
	pilot.mode = "B"
	pilot._update_mode()
	await create_timer(0.6).timeout
	await shot("01-pixel-map")
	for kind: String in ["sword", "critical", "miss", "magic", "defeat"]:
		action = kind
		await pilot.review(kind)
		print("RESULT B ", kind, " seed ", pilot.last_seed, " ", pilot.last_result.strikes)
		await create_timer(0.5).timeout
	quit()
