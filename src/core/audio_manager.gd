extends Node
## AW-36: central audio — one-shot SFX + looping music, as an autoload. SFX live
## at res://assets/audio/sfx/<name>.wav (convention, like the sprite/tile hooks);
## music is passed by path. Everything is null-safe: a missing file is silence,
## never a crash, so code never blocks on audio assets.

const SFX_DIR := "res://assets/audio/sfx/"
const VOICES := 10  # simultaneous one-shots before the oldest is stolen

var master_volume := 1.0
var music_volume := 0.7
var sfx_volume := 0.85
var muted := false

var _sfx_cache := {}
var _voices: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # audio keeps going through pauses
	for i in range(VOICES):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_voices.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
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
	p.volume_db = linear_to_db(clampf(sfx_volume * master_volume, 0.0001, 1.0))
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
func play_music(path: String) -> void:
	if path == _music_path and _music.playing:
		return
	_music_path = path
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if s == null:
		_music.stop()
		return
	_set_loop(s)
	_music.stream = s
	_music.volume_db = linear_to_db(clampf(music_volume * master_volume, 0.0001, 1.0))
	if not muted:
		_music.play()


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


func set_muted(on: bool) -> void:
	muted = on
	if on:
		_music.stop()
	elif _music_path != "":
		var path := _music_path
		_music_path = ""  # force a fresh start
		play_music(path)
