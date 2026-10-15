extends SceneTree
## CP-8 production Mock Battle + production executor/menu, rendered with audio.
## Fixture staging only: close the supported pair and wound final rival for KO.
const OUT := "res://assets/art_review/cp8_integration/"
var view: Node
var action := "sword"
var contacts := 0
var dialogue_clock := 0.0
var last_line := ""
var dialogue_seen: Array[String] = []


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	run.call_deferred()


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("CAPTURE ", name)


func _process(delta: float) -> bool:
	if view == null:
		return false
	dialogue_clock += delta
	for node in view.find_children("*", "", true, false):
		# Resolve project scripts only after autoloads exist in standalone -s runs.
		if node.get_script() != null and node.get_script().resource_path == "res://src/ui/dialogue_scene.gd" and not node.is_finished():
			var text: String = node._current.text if node._current != null else ""
			if text != last_line:
				last_line = text
				dialogue_clock = 0.0
				node.typewriter_speed = 0
				node.skip_reveal()
				if text not in dialogue_seen:
					dialogue_seen.append(text)
					shot("dialogue-" + str(dialogue_seen.size()))
			if dialogue_clock >= 1.3:
				dialogue_clock = 0.0
				var event := InputEventKey.new()
				event.keycode = KEY_ENTER
				event.pressed = true
				node._unhandled_key_input(event)
	return false


func on_beat(name: String) -> void:
	print("BEAT ", action, " ", name, " frame=", Engine.get_process_frames())
	if name == "contact":
		contacts += 1
	if name in ["establish", "contact", "release", "defeat", "map"]:
		shot(action + "-" + name + "-" + str(contacts))


func choose_seed(kai: Node, serra: Node, lethal: bool) -> void:
	for seed_value in range(10000):
		var rng = load("res://src/combat/combat_rng.gd").new(seed_value)
		var result = load("res://src/combat/combat_resolver.gd").resolve(view._combatant_for(kai, kai.cell), view._combatant_for(serra, serra.cell), view._manhattan(kai.cell, serra.cell), rng)
		if result.strikes[0].connected and result.defender_defeated() == lethal and not result.attacker_defeated():
			view._rng = load("res://src/combat/combat_rng.gd").new(seed_value)
			print("NATIVE ", action, " seed=", seed_value, " ", result.strikes)
			return
	assert(false, "no native seed")


func command_attack(kai: Node, serra: Node, command: String) -> void:
	var event := InputEventAction.new()
	event.action = "cursor_confirm"
	event.pressed = true
	view._cursor.move_to(kai.cell)
	view._cursor._unhandled_input(event)
	view._cursor._unhandled_input(event)
	view._menu._index = view._menu_actions.find(command)
	view._menu._unhandled_input(event)
	if view._menu_context in ["attack_weapon", "magic_spell"]:
		view._menu._index = 0
		view._menu._unhandled_input(event)
	view._cursor.move_to(serra.cell)
	await create_timer(0.4).timeout
	await shot(action + "-forecast")
	view._cursor._unhandled_input(event)
	while view._busy:
		await process_frame
	await create_timer(0.6).timeout


func run() -> void:
	# Standalone local replay: uses the real production view, never saves to disk.
	root.get_node("Campaign").call("reset_new_game", false)
	view = (load("res://scenes/battle/mock_battle.tscn") as PackedScene).instantiate()
	view.dialogue_enabled = false  # skip long intro; real boss quote enabled below
	root.add_child(view)
	current_scene = view
	view._cursor.set_process(false)
	view._illustrated_combat.beat.connect(on_beat)
	view._illustrated_combat.juice.sound_cued.connect(func(name: String) -> void: print("SFX ", action, " ", name))
	view._illustrated_combat.impact_applied.connect(func(source: Node, strike) -> void: print("CONTACT ", source.unit_id(), " hp=", source.current_hp, " ", strike))
	var kai: Node = view.unit_by_id("kai")
	var serra: Node = view._boss_unit
	kai.cell = Vector2i(8, 12)
	serra.cell = Vector2i(9, 12)
	kai.position = view._grid.cell_center(kai.cell)
	serra.position = view._grid.cell_center(serra.cell)
	view._focus_player_start()
	await create_timer(3.8).timeout
	view.dialogue_enabled = true
	choose_seed(kai, serra, false)
	await command_attack(kai, serra, "attack")
	print("PROGRESSION sword xp=", kai.xp, " uses=", kai.inventory.equipped_weapon_item().uses)
	action = "magic"
	contacts = 0
	kai.has_acted = false
	kai.current_hp = kai.max_hp()
	serra.current_hp = serra.max_hp()
	# Fixture chooses Kai's existing innate spell through the real Magic menu.
	kai.inventory.equip(kai.inventory.items[1])
	kai.cell = Vector2i(7, 12)
	kai.position = view._grid.cell_center(kai.cell)
	choose_seed(kai, serra, false)
	await command_attack(kai, serra, "magic")
	print("PROGRESSION magic xp=", kai.xp, " uses=", kai.inventory.equipped_weapon_item().uses)
	action = "yield"
	contacts = 0
	for unit in view._units.duplicate():
		if unit.team != 0 and unit != serra:
			view._remove_unit_without_events(unit)
	kai.has_acted = false
	kai.inventory.equip(kai.inventory.items[1])
	kai.cell = Vector2i(8, 12)
	kai.position = view._grid.cell_center(kai.cell)
	serra.current_hp = 1
	kai.xp = 95
	choose_seed(kai, serra, true)
	await command_attack(kai, serra, "attack")
	while not view._result_screen.is_shown():
		await process_frame
	await shot("victory")
	print("FINAL victory=", view._battle_victory, " level=", kai.level, " xp=", kai.xp,
		" uses=", kai.inventory.equipped_weapon_item().uses, " defeated=", view._defeated_unit_ids)
	await create_timer(1.0).timeout
	quit()
