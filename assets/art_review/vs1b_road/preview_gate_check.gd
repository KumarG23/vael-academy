extends SceneTree
## VS-1B: both historical visual pilots must keep their previews local.


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var campaign: Node = root.get_node("Campaign")
	campaign.reset_new_game(false)
	var before: Dictionary = campaign.to_dict()
	var spell: Resource = load("res://data/weapons/crownspark.tres")
	for path: String in ["res://scenes/proto/illustrated_pilot.tscn", "res://scenes/proto/hybrid_combat_pilot.tscn"]:
		var pilot: Node = load(path).instantiate()
		root.add_child(pilot)
		await process_frame
		assert(spell.required_story_flag == "crownspark_unlocked")
		assert(pilot.kai.unit_def.extra_weapons[0] != spell)
		assert(pilot.kai.can_use_weapon(pilot.kai.unit_def.extra_weapons[0]))
		assert(not pilot.kai.can_use_weapon(spell))
		if path.contains("hybrid"):
			var result = pilot.prepare_review("magic")
			assert(not result.strikes.is_empty())
		else:
			pilot.kai.equip_weapon(pilot.kai.unit_def.extra_weapons[0])
			assert(pilot.kai.weapon().id == "crownspark")
		assert(campaign.to_dict() == before)
		print("PASS private preview spell, unchanged shared gate/Campaign: ", path)
		pilot.queue_free()
		await process_frame
	assert(spell.required_story_flag == "crownspark_unlocked")
	print("PASS preview isolation survives both pilot lifetimes")
	quit()
