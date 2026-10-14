extends SceneTree

var surface: Node
const OUT := "/tmp/vael-cp1-audit"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1280, 720)
	run.call_deferred()

func show_scene(path: String) -> Node:
	if surface != null:
		surface.queue_free()
		await process_frame
	var next: Node = load(path).instantiate()
	root.add_child(next)
	surface = next
	current_scene = next
	return next

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var err := root.get_texture().get_image().save_png(OUT + "/" + name + ".png")
	print("CAPTURE ", name, " ", err)

func pause(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	var campaign: Node = root.get_node("Campaign")
	campaign.reset_new_game(false)
	campaign.house_locked = true
	await show_scene("res://scenes/title/title.tscn")
	await pause(0.4)
	await shot("01-title")
	var castle: Node = await show_scene("res://scenes/castle/castle.tscn")
	await pause(3.4)
	await shot("02-campus")
	castle.enter_room("library")
	await pause(3.4)
	await shot("03-library")
	var journal = load("res://src/ui/academy_journal.gd").new()
	castle._ui.add_child(journal)
	await pause(0.4)
	await shot("04-journal")
	journal.queue_free()
	await process_frame
	castle.enter_room("waterside")
	await pause(4.2)
	castle._play_dialogue("res://data/dialogue/castle_liora.json")
	castle._dialogue.skip_reveal()
	await pause(0.3)
	await shot("05-dialogue")
	var battle: Node = load("res://scenes/battle/mock_battle.tscn").instantiate()
	surface.queue_free()
	await process_frame
	battle.dialogue_enabled = false
	root.add_child(battle)
	surface = battle
	current_scene = battle
	await pause(5.5)
	await shot("06-battle")
	var kai: Node
	var foe: Node
	for u in battle._units:
		if u.unit_id() == "kai": kai = u
		if u.unit_id() == "serra": foe = u
	if kai != null and foe != null:
		foe.cell = kai.cell + Vector2i(1, 0)
		foe.position = battle._grid.cell_center(foe.cell)
		await battle._begin_combat_cam(kai, foe)
		var strike = load("res://src/combat/strike_result.gd").new()
		strike.connected = true
		strike.was_crit = true
		strike.damage = 6
		strike.defender_hp_after = foe.current_hp - 6
		capture_strike(battle, kai, foe, strike)
		await pause(0.35)
		await shot("07-combat-windup")
		await pause(0.22)
		await shot("08-combat-impact")
		await pause(1.0)
		await battle._end_combat_cam()
	var vn: Node = await show_scene("res://scenes/flow/prologue_vn.tscn")
	vn._dialogue.skip_reveal()
	await pause(0.4)
	await shot("09-vn-opening")
	vn._dialogue.advance()
	vn._dialogue.skip_reveal()
	await pause(0.4)
	await shot("10-painted-vn")
	root.get_node("AudioManager").stop_voice()
	root.get_node("AudioManager").stop_music()
	quit()

func capture_strike(battle: Node, kai: Node, foe: Node, strike: RefCounted) -> void:
	await battle._juice.play_strike(kai, foe, strike, false)
