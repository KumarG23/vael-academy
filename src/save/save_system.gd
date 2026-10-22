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
	data["version"] = _int_or(data.get("version"), VERSION)
	data["slot"] = slot
	_ensure_save_dir()
	# Write to a sibling temp file and swap it in, so a failed or interrupted
	# write never truncates the player's existing save in this slot.
	var path := slot_path(slot)
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var write_ok := file.get_error() == OK
	file.close()
	var tmp_abs := ProjectSettings.globalize_path(tmp_path)
	if not write_ok:
		DirAccess.remove_absolute(tmp_abs)
		return false
	if DirAccess.rename_absolute(tmp_abs, ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(tmp_abs)
		return false
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
			var campaign: Dictionary = data.get("campaign", {}) if data.get("campaign") is Dictionary else {}
			out.append({
				"slot": i,
				"version": _int_or(data.get("version"), 0),
				# AW-75: a live battle in the slot — shown as ⚔ and resumed on load
				"in_battle": not battle.is_empty() and not _first_bool(battle, ["battle_over"]),
				# Battle snapshots write current_chapter_id/casual_mode; campaign
				# saves (hub/title) write chapter_id/casual — accept both. Values
				# of the wrong type (hand-edited/corrupt files) fall through.
				"chapter_id": _first_string(campaign, ["current_chapter_id", "chapter_id"]),
				"casual_mode": _first_bool(campaign, ["casual_mode", "casual"]),
			})
	return out


static func _int_or(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_INT, TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			if String(value).is_valid_int():
				return String(value).to_int()
	return fallback


static func _first_string(section: Dictionary, keys: Array) -> String:
	for key in keys:
		var value: Variant = section.get(key)
		if value is String or value is StringName:
			return String(value)
	return ""


static func _first_bool(section: Dictionary, keys: Array) -> bool:
	for key in keys:
		var value: Variant = section.get(key)
		if value is bool:
			return value
	return false


func _ensure_save_dir() -> void:
	var absolute := ProjectSettings.globalize_path(save_dir)
	DirAccess.make_dir_recursive_absolute(absolute)
