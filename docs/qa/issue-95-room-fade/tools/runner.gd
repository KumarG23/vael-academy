extends SceneTree
## Native QA entry: ordinary Title/load; adds only a read-only reporter.

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_start.call_deferred()


func _start() -> void:
	var reporter: Node = load("res://docs/qa/issue-95-room-fade/tools/reporter.gd").new()
	root.add_child(reporter)
	change_scene_to_file("res://scenes/title/title.tscn")
