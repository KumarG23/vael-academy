extends SceneTree
## CP-6: drive real title-menu callbacks into the new scene, then return.
var title: Node
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var campaign: Node = root.get_node("Campaign")
	var state: Dictionary = campaign.call("to_dict").duplicate(true)
	title = load("res://scenes/title/title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	var confirm := InputEventAction.new()
	confirm.action = "cursor_confirm"
	confirm.pressed = true
	title._menu._index = 2
	title._menu._unhandled_input(confirm)
	assert(title._context == "dev")
	for index in range(title.DEV_JUMPS.size()):
		if title.DEV_JUMPS[index][1] == "hybrid_combat":
			title._menu._index = index
			break
	title._menu._unhandled_input(confirm)
	await process_frame
	await process_frame
	assert(current_scene.get_script().get_global_name() == "HybridCombatPilot")
	assert(current_scene.mode == "B")
	assert(campaign.call("to_dict") == state)
	print("PASS real title-menu input → A/B pilot; illustrated B default; campaign unchanged")
	current_scene._review_buttons[-1].pressed.emit()
	await process_frame
	await process_frame
	assert(current_scene.get_script().get_global_name() == "TitleScreen")
	print("PASS Title button returns through deferred scene change")
	quit()
