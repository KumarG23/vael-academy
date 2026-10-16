extends SceneTree
## VS-1A real scene/input smoke. No fixture HP, positions, stats or roster edits.
## Accelerates reading; uses AIBrain only to choose legal player commands.
const OUT := "res://assets/art_review/vs1a_opening/"
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


func run() -> void:
	var campaign: Node = root.get_node("Campaign")
	change_scene_to_file("res://scenes/title/title.tscn")
	for i in range(5):
		await process_frame
	await shot("01-title")
	await confirm()  # New Game
	await confirm()  # Classic
	for i in range(5):
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/flow/opening.tscn")
	var vn: Node = current_scene
	var seen: Array = []
	while current_scene == vn and steps < 250:
		var d: Node = vn._dialogue
		assert(d != null)
		if seen.is_empty() or seen[-1] != vn._i:
			seen.append(vn._i)
		# Real Enter first completes the typewriter, then advances the panel.
		if d.is_revealing():
			await key()
		var line: String = d.current_line().text if d.current_line() != null else ""
		if line.begins_with("Chanterelles"):
			await shot("02-forest")
		elif line.begins_with("A wall that is not"):
			await shot("03-long-narration")
		elif line.begins_with("A full day."):
			await shot("04-waking")
		elif line.begins_with("Every winter."):
			await shot("05-tam-sword")
		elif line.begins_with("I'm still angry"):
			await shot("06-family")
		elif line == "Bring the sword.":
			await shot("07-hesta")
		elif line.begins_with("You come home."):
			await shot("08-goodbye")
		await key()
		steps += 1
	assert(seen == [0, 1, 2, 3, 4], "canonical scenes exactly once")
	for i in range(5):
		await process_frame
	var view: Node = current_scene
	assert(view.chapter.id == "prologue")
	assert(campaign.flags.get("kai_awakened", false))
	assert(campaign.flags.get("opening_complete", false))
	assert(not campaign.flags.has("prologue_done"))
	assert(campaign.week == 1 and not campaign.house_locked)
	view._rng = load("res://src/combat/combat_rng.gd").new(1)
	view._cursor.set_process(false)  # keep the OS mouse from moving the cursor
	await create_timer(1.5).timeout
	await shot("09-road-start")
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
			var decision = load("res://src/ai/ai_brain.gd").decide(actor, view._units,
				view.chapter, view._terrain_db, 0, view._support_state)
			print("ACTION ", actor.unit_id(), " ", actor.cell, " -> ", decision.move_to,
				" target=", decision.target.unit_id() if decision.target != null else "wait")
			view._cursor.move_to(actor.cell)
			await confirm()
			view._cursor.move_to(decision.move_to)
			await confirm()
			await settle(view)
			assert(view._selected == actor and view._menu_context == "action")
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
				await shot("10-road-forecast")
				await confirm()
			await settle(view)
		if not view._battle_over and view._turn.is_player_phase():
			view._end_player_phase()
			await settle(view)
	assert(view._battle_over and view._battle_victory, "native road battle won")
	print("ROAD WON rounds=", view._turn.round_number, " flags=", campaign.flags)
	await shot("11-road-victory")
	await key()
	for i in range(5):
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/flow/house_choice.tscn")
	assert(campaign.flags.get("prologue_done", false))
	assert(campaign.week == 1)
	var road_checkpoint: Dictionary = campaign.to_dict()
	await shot("12-oath")
	await confirm()  # Emberwing; real pitch and commit
	var choice: Node = current_scene
	while current_scene == choice and steps < 300:
		if choice._dialogue != null:
			if choice._dialogue.is_revealing():
				await key()
			await shot("13-house-pitch")
			await key()
		else:
			await process_frame
		steps += 1
	for i in range(8):
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/castle/castle.tscn")
	assert(current_scene.room.id == "campus")
	assert(campaign.week == 1 and campaign.house_locked and campaign.house_id == "emberwing")
	assert(not campaign.active)
	await create_timer(1.5).timeout
	await shot("14-campus-arrival")
	var before: Vector2 = current_scene._avatar.position
	Input.action_press("ui_right")
	await create_timer(0.25).timeout
	Input.action_release("ui_right")
	assert(current_scene._avatar.position != before, "campus movement is playable")
	await verify_mission("emberwing")
	for house: String in ["tidemark", "thornrook"]:
		campaign.from_dict(road_checkpoint)
		change_scene_to_file("res://scenes/flow/house_choice.tscn")
		for i in range(5):
			await process_frame
		current_scene._index = 1 if house == "tidemark" else 2
		await confirm()
		var oath: Node = current_scene
		var limit: int = 0
		while current_scene == oath and limit < 30:
			if oath._dialogue != null:
				if oath._dialogue.is_revealing():
					await key()
				await key()
			else:
				await process_frame
			limit += 1
		for i in range(8):
			await process_frame
		assert(current_scene.room.id == "campus")
		assert(campaign.week == 1 and campaign.house_locked and campaign.house_id == house)
		await shot("arrival-" + house)
		await verify_mission(house)
	print("PASS all three real pitches, locked houses, campus arrivals and rival-specific Opening Rite preparations")
	print("PASS New Game input → five VN scenes → native road victory → result input → pitch → locked oath → movable Week 1 campus. No saves written.")
	quit()


func verify_mission(house: String) -> void:
	current_scene._open_mission()  # existing War Room interaction, no data edits
	await confirm()
	for i in range(8):
		await process_frame
	var expected: String = "mock_battle" if house == "emberwing" else "mock_battle_vs_thornrook" if house == "tidemark" else "mock_battle_vs_emberwing"
	assert(current_scene.chapter.id == expected)
	assert(current_scene._prep_active)
	# Finish the real existing intro before claiming preparation was reached.
	var battle: Node = current_scene
	var panels: int = 0
	while battle._dialogue_playing and panels < 60:
		await key()
		panels += 1
	assert(not battle._dialogue_playing)
	assert(battle._phase == 4)  # BattleView.Phase.PREP
	await key(KEY_ESCAPE)  # actual preparations menu
	assert(battle._menu.visible and battle._menu_context == "prep_field")
	assert(root.get_node("Campaign").active)
	await shot("rite-prep-" + house)
	print("PASS mission continuation ", house, " -> ", expected)
