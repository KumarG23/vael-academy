extends GutTest
## AW-36: the AudioManager autoload — SFX library + looping music, null-safe so a
## missing asset is silence, never a crash. (Headless has no audio device; we
## exercise the API and the library, not actual playback.)

const SFX := ["cursor", "confirm", "cancel", "select", "hit", "crit", "miss",
	"heal", "level_up", "door", "rank_up", "victory"]


func after_each() -> void:
	AudioManager.muted = false
	AudioManager.master_volume = 1.0
	AudioManager.music_volume = 0.7
	AudioManager.sfx_volume = 0.85
	AudioManager.stop_music()
	AudioManager.stop_voice()
	for p in AudioManager._voices:
		p.stop()  # no one-shot leaks into the next test


func test_autoload_is_registered():
	assert_not_null(AudioManager, "AudioManager autoload present")
	assert_eq(AudioManager._voices.size(), AudioManager.VOICES, "voice pool built")


func test_every_named_sfx_exists_on_disk():
	for sfx_name in SFX:
		var path: String = AudioManager.SFX_DIR + str(sfx_name) + ".wav"
		assert_true(ResourceLoader.exists(path), "SFX asset present: %s" % sfx_name)


func test_play_sfx_is_safe_and_caches():
	AudioManager.play_sfx("hit")
	AudioManager.play_sfx("crit", 1.2)
	assert_true(AudioManager._sfx_cache.has("hit"), "loaded SFX is cached")
	assert_not_null(AudioManager._sfx_cache["hit"], "hit loaded")


func test_unknown_sfx_is_silent_not_a_crash():
	AudioManager.play_sfx("does_not_exist")  # must not throw
	assert_true(AudioManager._sfx_cache.has("does_not_exist"))
	assert_null(AudioManager._sfx_cache["does_not_exist"], "missing SFX caches as null")


func test_muted_suppresses_sfx():
	AudioManager.muted = true
	# No assertion on playback (headless), but this must be a no-op path, not an error.
	AudioManager.play_sfx("hit")
	assert_true(AudioManager.muted)


func test_music_tracks_the_requested_path():
	AudioManager.play_music("res://assets/audio/music/battle_theme.wav")
	assert_eq(AudioManager._music_path, "res://assets/audio/music/battle_theme.wav")
	AudioManager.stop_music()
	assert_eq(AudioManager._music_path, "", "stop clears the current track")


func test_missing_music_is_silent():
	AudioManager.play_music("res://assets/audio/music/nope.wav")
	assert_false(AudioManager._music.playing, "no track, no crash")


## The journal's volume sliders must reach the track already playing, not wait
## for the next play_music call.
func test_volume_changes_reach_the_current_track():
	AudioManager.play_music("res://assets/audio/music/battle_theme.wav")
	var before: float = AudioManager._music.volume_db
	AudioManager.music_volume = 0.3
	assert_lt(AudioManager._music.volume_db, before, "music slider lowers the live track")
	var after_music: float = AudioManager._music.volume_db
	AudioManager.master_volume = 0.5
	assert_lt(AudioManager._music.volume_db, after_music, "master slider lowers it too")
	assert_almost_eq(AudioManager._music.volume_db, linear_to_db(0.3 * 0.5), 0.01)


func test_sfx_volume_reaches_voices_and_narrator():
	AudioManager.sfx_volume = 0.4
	var want := linear_to_db(0.4)
	assert_almost_eq(AudioManager._voice.volume_db, want, 0.01, "narrator follows the SFX slider")
	for p in AudioManager._voices:
		assert_almost_eq(p.volume_db, want, 0.01, "every SFX voice follows the slider")


func test_zero_volume_is_floored_not_infinite():
	AudioManager.master_volume = 0.0
	assert_almost_eq(AudioManager._music.volume_db, linear_to_db(0.0001), 0.01)


## AW-72: the quiz answers with its own voice — a chime and a buzz.
func test_quiz_answer_sfx_exist():
	assert_true(ResourceLoader.exists("res://assets/audio/sfx/correct.wav"), "the chime is real")
	assert_true(ResourceLoader.exists("res://assets/audio/sfx/wrong.wav"), "so is the buzz")


## Issue #10: mute must silence what is already sounding — music, the narrator
## and every pooled SFX voice — through either entry point, and unmute must
## bring back only the requested looping track (never stale one-shots).
const BATTLE_THEME := "res://assets/audio/music/battle_theme.wav"
const CAMPUS_CHILL := "res://assets/audio/music/campus_chill.mp3"
const NARRATION := "res://assets/audio/vo/prologue/p2_narrows.wav"


func _start_everything() -> void:
	AudioManager.play_music(BATTLE_THEME)
	AudioManager.play_voice(NARRATION)
	AudioManager.play_sfx("hit")
	AudioManager.play_sfx("crit")


func _any_sfx_playing() -> bool:
	for p in AudioManager._voices:
		if p.playing:
			return true
	return false


func _assert_all_silent(context: String) -> void:
	assert_false(AudioManager._music.playing, "music silent (%s)" % context)
	assert_false(AudioManager._voice.playing, "narrator silent (%s)" % context)
	assert_false(_any_sfx_playing(), "SFX pool silent (%s)" % context)


func test_live_players_report_playing_headless() -> void:
	# Guard for the tests below: the dummy driver still tracks player state.
	_start_everything()
	assert_true(AudioManager._music.playing, "music sounding")
	assert_true(AudioManager._voice.playing, "narrator sounding")
	assert_true(_any_sfx_playing(), "SFX sounding")


func test_muted_field_silences_live_music_narration_and_sfx() -> void:
	_start_everything()
	AudioManager.muted = true
	_assert_all_silent("muted = true")


func test_set_muted_silences_live_music_narration_and_sfx() -> void:
	_start_everything()
	AudioManager.set_muted(true)
	assert_true(AudioManager.muted)
	_assert_all_silent("set_muted(true)")


func test_new_playback_is_suppressed_while_muted() -> void:
	AudioManager.muted = true
	_start_everything()
	_assert_all_silent("requests while muted")
	assert_eq(AudioManager._music_path, BATTLE_THEME, "the request is still remembered")


func test_field_unmute_restores_music_but_not_stale_one_shots() -> void:
	_start_everything()
	AudioManager.muted = true
	AudioManager.muted = false
	assert_true(AudioManager._music.playing, "looping track comes back")
	assert_eq(AudioManager._music_path, BATTLE_THEME)
	assert_false(AudioManager._voice.playing, "stale narration is not replayed")
	assert_false(_any_sfx_playing(), "stale SFX are not replayed")


func test_set_muted_unmute_restores_music_but_not_stale_one_shots() -> void:
	_start_everything()
	AudioManager.set_muted(true)
	AudioManager.set_muted(false)
	assert_true(AudioManager._music.playing, "looping track comes back")
	assert_false(AudioManager._voice.playing, "stale narration is not replayed")
	assert_false(_any_sfx_playing(), "stale SFX are not replayed")


func test_track_switch_while_muted_plays_the_new_track_on_unmute() -> void:
	AudioManager.play_music(BATTLE_THEME)
	AudioManager.muted = true
	AudioManager.play_music(CAMPUS_CHILL)
	assert_false(AudioManager._music.playing, "switch stays silent while muted")
	AudioManager.muted = false
	assert_true(AudioManager._music.playing, "the latest request plays")
	assert_eq(AudioManager._music_path, CAMPUS_CHILL)
	assert_eq(AudioManager._music.stream.resource_path, CAMPUS_CHILL, "not the stale track")


func test_stop_music_while_muted_stays_stopped_on_unmute() -> void:
	AudioManager.play_music(BATTLE_THEME)
	AudioManager.set_muted(true)
	AudioManager.stop_music()
	AudioManager.set_muted(false)
	assert_false(AudioManager._music.playing, "a stopped scene stays quiet")
	assert_eq(AudioManager._music_path, "")


func test_missing_and_empty_tracks_are_safe_across_unmute() -> void:
	AudioManager.play_music(BATTLE_THEME)
	AudioManager.muted = true
	AudioManager.play_music("res://assets/audio/music/nope.wav")
	AudioManager.muted = false
	assert_false(AudioManager._music.playing, "missing track: silence, not the old one")
	AudioManager.muted = true
	AudioManager.play_music("")
	AudioManager.set_muted(false)
	assert_false(AudioManager._music.playing, "empty track: silence")


func test_repeated_mute_unmute_is_stable() -> void:
	for i in range(3):
		_start_everything()  # fresh narration + SFX each cycle, same track
		AudioManager.muted = true
		AudioManager.set_muted(true)
		_assert_all_silent("repeat mute %d" % i)
		AudioManager.set_muted(false)
		AudioManager.muted = false
		assert_true(AudioManager._music.playing, "repeat unmute %d" % i)
		assert_eq(AudioManager._music_path, BATTLE_THEME, "bookkeeping intact %d" % i)


func test_mute_preserves_volume_settings() -> void:
	AudioManager.music_volume = 0.3
	AudioManager.sfx_volume = 0.4
	AudioManager.play_music(BATTLE_THEME)
	AudioManager.muted = true
	AudioManager.muted = false
	assert_almost_eq(AudioManager._music.volume_db, linear_to_db(0.3), 0.01, "music level kept")
	assert_almost_eq(AudioManager._voice.volume_db, linear_to_db(0.4), 0.01, "narrator level kept")


func test_mute_before_ready_is_safe() -> void:
	var am: Node = load("res://src/core/audio_manager.gd").new()
	am.muted = true  # players don't exist yet
	am.set_muted(false)
	am.set_muted(true)
	add_child_autofree(am)  # _ready builds the players while muted
	assert_true(am.muted, "pre-ready mute survives _ready")
	am.play_music(BATTLE_THEME)
	assert_false(am._music.playing, "still muted after _ready")
	am.muted = false
	assert_true(am._music.playing, "unmute after _ready plays the request")
