extends SceneTree
## VS-1B real New Game → revised road → native victory → bread → Tidemark oath.
## Original units/map/stats, seed1; accelerated reading, legal menu/cursor actions.
const OUT := "res://assets/art_review/vs1b_road/"
var captures: Dictionary = {}
var steps: int = 0


func _initialize() -> void:
	root.size = Vector2i(1152, 648)
	run.call_deferred()


func key(code: Key = KEY_ENTER) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func confirm() -> void:
	var event := InputEventAction.new()
	event.action = "cursor_confirm"
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func shot(label: String) -> void:
	if captures.has(label):
		return
	captures[label] = true
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("CAPTURE ", label)


func settle(view: Node) -> void:
	var deadline := Time.get_ticks_msec() + 45000
	while is_instance_valid(view) and view._busy and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(is_instance_valid(view) and not view._busy, "battle action stalled")


func dialogue_in(view: Node) -> Node:
	for node: Node in view.find_children("*", "", true, false):
		if node.get_script() != null and node.get_script().resource_path == "res://src/ui/dialogue_scene.gd" and not node.is_finished():
			return node
	return null


func read_road(view: Node, prefix: String) -> void:
	var lines: int = 0
	while view._dialogue_playing and lines < 80:
		var d: Node = dialogue_in(view)
		assert(d != null)
		if d.is_revealing():
			await key()
		var line: String = d.current_line().text
		print(prefix, " ", lines, " ", line)
		if line.begins_with("I must reach Vael"):
			await shot("01-hesta-handoff")
		elif line.begins_with("By the well, a woman"):
			await shot("02-endangered-family")
		elif line.begins_with("Kai is across the road"):
			await shot("03-involuntary-mark")
		elif line.begins_with("You can't hold the road"):
			await shot("04-serra-organizes")
		elif line.begins_with("The one at the camp"):
			await shot("05-rina-observes")
		elif line.begins_with("Kai kneels."):
			await shot("09-bread-bundle")
		elif line.begins_with("He breaks off a piece"):
			await shot("10-bread-offer")
		elif line.begins_with("For both of you."):
			await shot("11-perrin-cloak")
		elif line.begins_with("We're going to Vael too"):
			await shot("12-walk-with-us")
		await key()
		lines += 1
	assert(lines < 80)
	assert(lines == (20 if prefix == "INTRO" else 19))


func run() -> void:
	var campaign: Node = root.get_node("Campaign")
	change_scene_to_file("res://scenes/title/title.tscn")
	for i in range(5):
		await process_frame
	await confirm()
	await confirm()
	for i in range(5):
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/flow/opening.tscn")
	var vn: Node = current_scene
	var order: Array = []
	while current_scene == vn and steps < 250:
		if order.is_empty() or order[-1] != vn._i:
			order.append(vn._i)
		if vn._dialogue.is_revealing():
			await key()
		await key()
		steps += 1
	assert(order == [0, 1, 2, 3, 4])
	for i in range(5):
		await process_frame
	var view: Node = current_scene
	assert(view.chapter.id == "prologue")
	assert(campaign.flags.get("opening_complete", false))
	assert(campaign.flags.get("kai_awakened", false))
	assert(not campaign.flags.has("crownspark_unlocked"))
	await read_road(view, "INTRO")
	assert(campaign.flags.get("road_intro_seen", false))
	assert(campaign.week == 1 and not campaign.house_locked)
	view._rng = load("res://src/combat/combat_rng.gd").new(1)
	view._cursor.set_process(false)
	await create_timer(1.5).timeout
	await shot("06-road-playable")
	var rounds: int = 0
	while not view._battle_over and rounds < 16:
		await settle(view)
		if view._battle_over:
			break
		rounds += 1
		for actor: Node in view._living_units_on_team(0):
			if view._battle_over:
				break
			if not is_instance_valid(actor) or actor.has_acted:
				continue
			var decision = load("res://src/ai/ai_brain.gd").decide(actor, view._units, view.chapter, view._terrain_db, 0, view._support_state)
			view._cursor.move_to(actor.cell)
			await confirm()
			view._cursor.move_to(decision.move_to)
			await confirm()
			await settle(view)
			assert(view._selected == actor and view._menu_context == "action")
			if actor.unit_id() == "kai":
				assert(not actor.can_use_weapon(load("res://data/weapons/crownspark.tres")))
				assert(not view._menu_actions.has("magic"))
				assert(actor.weapon().id == "sig_kai")
				await shot("07-kai-no-controlled-magic")
			var command: String = "wait"
			if decision.target != null:
				command = "magic" if actor.weapon().is_magical() else "attack"
			assert(view._menu_actions.has(command))
			view._menu._index = view._menu_actions.find(command)
			await confirm()
			if decision.target != null:
				if view._menu_context in ["attack_weapon", "magic_spell"]:
					view._menu._index = 0
					await confirm()
				view._cursor.move_to(decision.target.cell)
				await shot("08-native-forecast")
				await confirm()
			await settle(view)
		if not view._battle_over and view._turn.is_player_phase():
			view._end_player_phase()
			await settle(view)
	assert(view._battle_over and view._battle_victory)
	print("ROAD WON round=", view._turn.round_number)
	assert(view._dialogue_playing)
	assert(not view._result_screen.is_shown())
	assert(not campaign.flags.has("road_aftermath_seen"))
	await read_road(view, "AFTERMATH")
	assert(view._result_screen.is_shown())
	assert(campaign.flags.get("road_aftermath_seen", false))
	await shot("13-victory-after-bread")
	await key()
	for i in range(5):
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/flow/house_choice.tscn")
	assert(campaign.flags.get("prologue_done", false))
	await key(KEY_RIGHT)
	await confirm()
	var choice: Node = current_scene
	while current_scene == choice and steps < 300:
		if choice._dialogue != null:
			if choice._dialogue.is_revealing():
				await key()
			await key()
		else:
			await process_frame
		steps += 1
	for i in range(8):
		await process_frame
	assert(current_scene.room.id == "campus")
	assert(campaign.week == 1 and campaign.house_locked and campaign.house_id == "tidemark")
	assert(not campaign.flags.has("crownspark_unlocked"))
	await create_timer(1.5).timeout
	await shot("14-tidemark-campus")
	print("PASS New Game/five scenes → Hesta handoff/rescue → original native battle/sword-only Kai → bread aftermath before victory → Tidemark oath → Week 1 campus. No saves or art generated.")
	quit()
