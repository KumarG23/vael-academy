extends Node
## AW-36: central audio — one-shot SFX + looping music, as an autoload. SFX live
## at res://assets/audio/sfx/<name>.wav (convention, like the sprite/tile hooks);
## music is passed by path. Everything is null-safe: a missing file is silence,
## never a crash, so code never blocks on audio assets.

const SFX_DIR := "res://assets/audio/sfx/"
const VOICES := 10  # simultaneous one-shots before the oldest is stolen

# Volume changes (e.g. the journal's System sliders) reach what is already
# sounding, not just the next track or line.
var master_volume := 1.0:
	set(v):
		master_volume = v
		_apply_volumes()
var music_volume := 0.7:
	set(v):
		music_volume = v
		_apply_volumes()
var sfx_volume := 0.85:
	set(v):
		sfx_volume = v
		_apply_volumes()
# Issue #10: one mute policy for both the field and set_muted(). Muting silences
# what is already sounding (music, narrator, every pooled SFX voice); unmuting
# brings back only the requested looping track — stale one-shots stay gone.
var muted := false:
	set(v):
		if v == muted:
			return
		muted = v
		_apply_mute()

# Issue #43 (M9.6): the three levels are player-installation preferences, kept
# in their own ConfigFile beside — never inside — campaign/battle saves.
const PREFS_PATH := "user://settings.cfg"
const PREFS_SECTION := "audio"
const DEFAULT_LEVELS := {"master_volume": 1.0, "music_volume": 0.7, "sfx_volume": 0.85}
var prefs_path := PREFS_PATH  # tests point this at a disposable file

var _sfx_cache := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_path := ""
var _voice: AudioStreamPlayer  # AW-78: the narrator's own channel (VN scenes)


func _ready() -> void:
	# Autoloads are ready before the main scene, so the first title/dialogue
	# sound already plays at the player's saved levels.
	load_preferences()
	process_mode = Node.PROCESS_MODE_ALWAYS  # audio keeps going through pauses
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	_apply_volumes()
	# AW-36: global game beats chime through here, wherever they fire from.
	EventBus.support_rank_up.connect(func(_pair: String, _rank: String) -> void: play_sfx("rank_up"))
	EventBus.battle_won.connect(func() -> void: play_sfx("victory"))


## Play a named one-shot from the SFX library. `pitch` lets callers vary a shared
## sound (e.g. a slightly higher confirm). No-op when muted or the file is absent.
func play_sfx(sfx_name: String, pitch := 1.0) -> void:
	if muted or sfx_name == "":
		return
	var stream := _load_sfx(sfx_name)
	if stream == null:
		return
	var p := _voices[_next]
	_next = (_next + 1) % VOICES
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = _sfx_db()
	p.play()


func _load_sfx(sfx_name: String) -> AudioStream:
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	var path := SFX_DIR + sfx_name + ".wav"
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_sfx_cache[sfx_name] = s
	return s


## Start (or switch to) a looping music track by resource path. Re-calling with
## the currently-playing track is a no-op, so scene setups can call it freely.
## While muted the request is remembered and starts on unmute.
func play_music(path: String) -> void:
	if path == _music_path and (muted or _music.playing):
		return
	_music_path = path
	_start_music()


## (Re)start the requested track from the top; silence if muted or it's missing.
func _start_music() -> void:
	_music.stop()
	if muted or _music_path == "":
		return
	var s: AudioStream = load(_music_path) if ResourceLoader.exists(_music_path) else null
	if s == null:
		return
	_set_loop(s)
	_music.stream = s
	_music.volume_db = _music_db()
	_music.play()


## AW-78: play a narration clip by res:// path (the hearth narrator). One voice
## at a time — starting a new line stops the previous. Null-safe like the SFX.
func play_voice(path: String) -> void:
	_voice.stop()
	if muted or path == "":
		return
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		return
	if s is AudioStreamWAV:
		(s as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
	_voice.stream = s
	_voice.volume_db = _sfx_db()
	_voice.play()


func stop_voice() -> void:
	_voice.stop()


func stop_music() -> void:
	_music_path = ""
	_music.stop()


func _set_loop(s: AudioStream) -> void:
	if s is AudioStreamWAV:
		var w := s as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# loop_end 0 loops the whole clip; being explicit is safer across imports
		if w.loop_end <= 0:
			w.loop_end = w.data.size() / 2  # 16-bit mono frames
	elif s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	elif s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true


func _music_db() -> float:
	return linear_to_db(clampf(music_volume * master_volume, 0.0001, 1.0))


func _sfx_db() -> float:
	return linear_to_db(clampf(sfx_volume * master_volume, 0.0001, 1.0))


## Re-level the players that already exist; null-safe before _ready builds them.
func _apply_volumes() -> void:
	if _music != null:
		_music.volume_db = _music_db()
	if _voice != null:
		_voice.volume_db = _sfx_db()
	for p in _voices:
		p.volume_db = _sfx_db()


## Issue #43: restore the saved levels from `prefs_path`. Read-only — the file is
## never rewritten here. A missing or unparseable file keeps today's defaults;
## each level is validated on its own, so one bad entry can't cost the others:
## an absent, non-numeric (string/bool/…) or non-finite value uses that level's
## default, and a finite number outside 0..1 is clamped into range (the same
## bounds the Journal steps within).
func load_preferences() -> Error:
	var cfg := ConfigFile.new()
	var err := ERR_FILE_NOT_FOUND
	if FileAccess.file_exists(prefs_path):
		err = cfg.load(prefs_path)
		if err != OK:
			push_warning("Audio preferences unreadable (%s): %s — using defaults" % [error_string(err), prefs_path])
	for key: String in DEFAULT_LEVELS:
		var level: float = DEFAULT_LEVELS[key]
		if err == OK and cfg.has_section_key(PREFS_SECTION, key):
			var v: Variant = cfg.get_value(PREFS_SECTION, key)
			if (v is float or v is int) and is_finite(float(v)):
				level = clampf(float(v), 0.0, 1.0)
			else:
				push_warning("Audio preference %s=%s is not a finite number — using %s" % [key, var_to_str(v), level])
		set(key, level)
	return err


## Issue #43: write the current levels to `prefs_path`. Other sections/keys in a
## readable file are kept; an unreadable one is replaced, since there is nothing
## coherent left to keep. Written to a temp file and renamed over the old one so
## a failed write never truncates the player's settings. Failure is reported,
## never fatal — the live levels keep applying for this session.
func save_preferences() -> Error:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(prefs_path) and cfg.load(prefs_path) != OK:
		cfg = ConfigFile.new()
	for key: String in DEFAULT_LEVELS:
		cfg.set_value(PREFS_SECTION, key, get(key))
	var tmp := prefs_path + ".tmp"
	var err := cfg.save(tmp)
	if err == OK:
		err = DirAccess.rename_absolute(tmp, prefs_path)
	if err != OK:
		if FileAccess.file_exists(tmp):
			DirAccess.remove_absolute(tmp)
		push_warning("Audio preferences not saved (%s): %s" % [error_string(err), prefs_path])
	return err


func set_muted(on: bool) -> void:
	muted = on


## Null-safe before _ready builds the players (nothing is sounding yet then).
func _apply_mute() -> void:
	if _music == null:
		return
	if muted:
		_music.stop()
		_voice.stop()
		for p in _voices:
			p.stop()
	elif _music_path != "" and not _music.playing:
		_start_music()
