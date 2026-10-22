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

