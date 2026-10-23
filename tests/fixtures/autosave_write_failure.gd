extends SceneTree
## GH-85: RLIMIT_FSIZE produces a real short write on an ordinary temp file.
## Parent ignores SIGXFSZ; small files/retries remain writable under the limit.

func _initialize() -> void:
	var saves := SaveSystem.new("user://autosave_write_failure")
	var manual: Array[PackedByteArray] = []
	for slot in range(3):
		if not saves.save_slot(slot, {"campaign": {"marker": slot}}):
			quit(1)
			return
		manual.append(FileAccess.get_file_as_bytes(saves.slot_path(slot)))
	if not saves.save_autosave({"campaign": {"week": 2}}):
		quit(2)
		return
	for padding_size: int in [1500, 65536]:
		var prior := FileAccess.get_file_as_bytes(saves.autosave_path())
		var wrote := saves.save_autosave({"campaign": {"week": 3, "padding": "x".repeat(padding_size)}})
		if wrote \
				or FileAccess.get_file_as_bytes(saves.autosave_path()) != prior \
				or FileAccess.file_exists(saves.autosave_path() + ".tmp"):
			printerr("Write failure damaged recovery or left temp (%d bytes)" % padding_size)
			quit(3)
			return
		if not saves.save_autosave({"campaign": {"week": 4}}) or int(saves.load_autosave()["campaign"]["week"]) != 4:
			printerr("Write failure retry failed")
			quit(4)
			return
	for slot in range(3):
		if FileAccess.get_file_as_bytes(saves.slot_path(slot)) != manual[slot]:
			quit(5)
			return
	var dir := DirAccess.open(saves.save_dir)
	for file: String in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_dir))
	print("Autosave real write failure and retry passed")
	quit(0)
