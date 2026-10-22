extends SceneTree
## GH-56 bounded integration fixture: production result input -> deferred castle.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void: fail("watchdog timeout"))
	var campaign: Node = root.get_node("Campaign")
	var resume_script: Script = load("res://src/flow/resume.gd")
	campaign.reset_new_game(false)
	campaign.house_locked = true
	var term := int(OS.get_cmdline_user_args()[0])
	campaign.semester = term
	campaign.week = campaign.semester_end_week()
	campaign.deploy()
	var battle: Node = load("res://scenes/battle/closing_rite_emberwing.tscn").instantiate()
	battle.strike_delay = 0.0
	battle.dialogue_enabled = false
	root.add_child(battle)
	current_scene = battle
	await process_frame
	await process_frame
	# A valid live-battle JSON round trip retains campaign receipts and normal resume.
	var saves := SaveSystem.new("user://test_report_card_battle_probe")
	if not saves.save_slot(0, battle.make_save_payload()):
		fail("live snapshot save")
		return
	var live := saves.load_slot(0)
	if resume_script.stage(live) == "":
		fail("live snapshot resume")
		return
	var battle_type: Script = load("res://src/ui/battle_view.gd")
	battle_type.next_resume = {}
	# Complete the fresh production battle; routing/math are covered separately.
	battle.chapter = battle.chapter.duplicate()
	battle.chapter.outro_dialogue = ""
	battle.chapter.boss_yield_dialogue = ""
	battle._end_battle(true)
	await process_frame
	if campaign.report_cards.size() != 1 or campaign.week != (4 if term == 1 else 7):
		fail("one closure at week 7")
		return
	var card: Dictionary = campaign.report_cards[0].duplicate(true)
	battle._end_battle(true)
	if campaign.report_cards.size() != 1 or campaign.report_cards[0] != card:
		fail("duplicate result preserves locked card")
		return
	# Completed-result payload carries pending receipt but cannot stage a new battle.
	if not saves.save_slot(0, battle.make_save_payload()):
		fail("completed snapshot save")
		return
	var result := saves.load_slot(0)
	if resume_script.battle_live(result) or not campaign.restore_save(result["campaign"]):
		fail("completed result restore")
		return
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	battle._result_screen._unhandled_key_input(event)
	for i in range(5):
		await process_frame
	if current_scene == null or current_scene.scene_file_path != "res://scenes/castle/castle.tscn":
		fail("normal result enters castle")
		return
	var castle: Node = current_scene
	if castle._dialogue == null or castle._dialogue_queue.size() != 1:
		fail("card before queued feast")
		return
	castle._dialogue._finish()
	if int(campaign.flags.get("gold", 0)) != {"S": 400, "A": 250, "B": 150, "C": 80, "D": 40}[card["rank"]] or not campaign.flags.get("merchant_unlocked", false):
		fail("one C reward and merchant")
		return
	castle._dialogue._finish()
	castle._refresh_date()
	if castle._dialogue != null or not campaign.flags.get("festival_seen" if term == 1 else "feast_seen", false):
		fail("completed feast does not repeat")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(0)))
	print("Report card production result -> castle passed")
	quit(0)

func fail(message: String) -> void:
	printerr("Report card probe failed: " + message)
	quit(1)
