extends SceneTree
## Issue #83 QA seed: write ONE real valid campaign save through the production
## save path into physical slot 2, so the Title Load menu and Journal System tab
## have a valid slot to continue into. Slots 0 and 1 are filled with invalid
## occupied files by the shell afterwards.
##
## Run with a disposable profile:
##   XDG_DATA_HOME=/tmp/opencode/issue83-gui godot --headless --path . \
##     -s docs/qa/issue-83-load-failure/tools/seed_fixture.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var campaign: Node = root.get_node("Campaign")
	campaign.reset_new_game(false)
	campaign.set_house("emberwing")
	campaign.house_locked = true
	campaign.week = 3
	campaign.flags = {"gold": 120, "prologue_done": true}
	campaign.set_unit_state("kai", {"level": 2, "xp": 17})
	var saves := SaveSystem.new()
	if not campaign.save_to_slot(2, saves):
		printerr("seed_fixture: could not write slot 2")
		quit(1)
		return
	print("seed_fixture: wrote %s" % saves.slot_path(2))
	quit(0)
