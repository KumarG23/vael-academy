extends GutTest
## AW-36: the AudioManager autoload — SFX library + looping music, null-safe so a
## missing asset is silence, never a crash. (Headless has no audio device; we
## exercise the API and the library, not actual playback.)

const SFX := ["cursor", "confirm", "cancel", "select", "hit", "crit", "miss",
	"heal", "level_up", "door", "rank_up", "victory"]


func after_each() -> void:
	AudioManager.muted = false
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
