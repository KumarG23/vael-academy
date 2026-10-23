extends Node
## Installation-local dialogue presentation preferences. Kept separate from
## AudioManager and Campaign so save slots cannot alter reading speed.

const PREFS_PATH := "user://settings.cfg"
const SECTION := "dialogue"
const KEY_TEXT_SPEED := "text_speed"
const MODES := ["normal", "fast", "instant"]
const SPEEDS := {"normal": 48.0, "fast": 96.0, "instant": 0.0}

var prefs_path := PREFS_PATH # tests may point this at disposable data
var text_speed := "normal"
var last_write_error: Error = OK


func _ready() -> void:
	load_preferences()


func load_preferences() -> Error:
	text_speed = "normal"
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(prefs_path):
		return ERR_FILE_NOT_FOUND
	var err := cfg.load(prefs_path)
	if err != OK:
		push_warning("Dialogue preferences unreadable (%s): %s — using normal text speed" % [error_string(err), prefs_path])
		return err
	var value: Variant = cfg.get_value(SECTION, KEY_TEXT_SPEED, "normal")
	if value is String and value in MODES:
		text_speed = value
	else:
		push_warning("Dialogue text speed %s is invalid — using normal" % var_to_str(value))
	return OK


func characters_per_second() -> float:
	return float(SPEEDS.get(text_speed, SPEEDS["normal"]))


func label() -> String:
	match text_speed:
		"fast": return "Fast (96 chars/sec)"
		"instant": return "Instant"
	return "Normal (48 chars/sec)"


## The live selection changes before IO. A failed write leaves this session usable
## and reports the error; temp-write + rename protects the existing config file.
func set_text_speed(mode: String) -> Error:
	if mode not in MODES:
		return ERR_INVALID_PARAMETER
	text_speed = mode
	last_write_error = save_preferences()
	return last_write_error


func save_preferences() -> Error:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(prefs_path):
		var read_err := cfg.load(prefs_path)
		if read_err != OK:
			push_warning("Dialogue preferences not saved because settings are unreadable (%s): %s" % [error_string(read_err), prefs_path])
			return read_err
	cfg.set_value(SECTION, KEY_TEXT_SPEED, text_speed)
	var tmp := prefs_path + ".tmp"
	var err := cfg.save(tmp)
	if err == OK:
		err = DirAccess.rename_absolute(tmp, prefs_path)
	if err != OK:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		push_warning("Dialogue preferences not saved (%s): %s" % [error_string(err), prefs_path])
	return err
