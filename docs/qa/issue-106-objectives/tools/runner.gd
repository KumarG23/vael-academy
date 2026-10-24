extends SceneTree
## Ordinary Title entry with a read-only observer; no campaign fixture changes.

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	_start.call_deferred()

func _start() -> void:
	root.add_child(load("res://docs/qa/issue-106-objectives/tools/reporter.gd").new())
	change_scene_to_file("res://scenes/title/title.tscn")
