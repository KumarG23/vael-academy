class_name SaveSystem
extends RefCounted
## JSON save-slot IO for campaign/battle snapshots. Pure file boundary; scenes
## provide the payload and title/hub scenes can later call the same load API.

const VERSION := 1
const DEFAULT_SAVE_DIR := "user://saves"
const SLOT_PREFIX := "slot_"
const SLOT_EXT := ".json"

var save_dir := DEFAULT_SAVE_DIR


func _init(p_save_dir: String = DEFAULT_SAVE_DIR) -> void:
	save_dir = p_save_dir


func slot_path(slot: int) -> String:
	return "%s/%s%d%s" % [save_dir.trim_suffix("/"), SLOT_PREFIX, slot, SLOT_EXT]


func save_slot(slot: int, payload: Dictionary) -> bool:
	if slot < 0:
		return false
	var data := payload.duplicate(true)
	data["version"] = int(data.get("version", VERSION))
	data["slot"] = slot
	_ensure_save_dir()
	var file := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


func load_slot(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {}
	return json.data


func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func list_slots(max_slots: int = 3) -> Array:
	var out: Array = []
	for i in range(max_slots):
		if has_slot(i):
			var data := load_slot(i)
			var battle: Dictionary = data.get("battle", {}) if data.get("battle") is Dictionary else {}
			out.append({
				"slot": i,
				"version": int(data.get("version", 0)),
				# AW-75: a live battle in the slot — shown as ⚔ and resumed on load
				"in_battle": not battle.is_empty() and not bool(battle.get("battle_over", false)),
				# Battle snapshots write current_chapter_id/casual_mode; campaign
				# saves (hub/title) write chapter_id/casual — accept both.
				"chapter_id": data.get("campaign", {}).get("current_chapter_id",
					data.get("campaign", {}).get("chapter_id", "")),
				"casual_mode": bool(data.get("campaign", {}).get("casual_mode",
					data.get("campaign", {}).get("casual", false))),
			})
	return out


func _ensure_save_dir() -> void:
	var absolute := ProjectSettings.globalize_path(save_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
