# Issue #43 — Journal audio preferences

Scope: MASTER_PLAN §2 coding rules, §6 WO-9.3/WO-9.6 and §10 rows 9.3/9.4–9.10; HANDOFF AW-36/AW-39. ACADEMY_BIBLE §3's existing castle/Journal experience is preserved. No relevant canon contradiction found.

`AudioManager` restores the existing master/music/SFX levels in autoload `_ready`, before main-scene playback. Journal changes apply immediately and save to installation-local `user://settings.cfg` (`[audio]` keys `master_volume`, `music_volume`, `sfx_volume`), independent of campaign/battle saves and slots. Direct transient assignments in audio tests do not save.

Missing/unparseable files use defaults 1.0/0.7/0.85. In a readable file, missing, wrong-type and non-finite fields use their own defaults; finite integers/floats clamp independently to [0,1], including zero. Restore never writes. An explicit changed Journal control preserves unrelated keys/sections in a readable file; it replaces an unparseable file with the current audio levels. Save writes a sibling temporary file then renames it over the destination. Failure warns, preserves the previous destination, and leaves live controls working; later input retries. Existing zero-volume floor (-80 dB), mute policy and requested-track behavior remain.

Baseline: unchanged game source `24b9bf539493d0acf83a4b1e35126165f76ea83b`, production Journal with viewport action input in one headless Godot process, then a genuinely fresh process sharing disposable XDG data. First process selects 0.60/0.40/0.55; second starts at 1.00/0.70/0.85. This established the restart regression before finishing the preserved implementation.

Automated runtime fixture: `tests/fixtures/audio_prefs_probe.gd`. The `journal` mode traverses the real tabs/rows, changes the three controls and activates Return to Title. The `startup` mode observes restored autoload levels, opens the title and dispatches cursor input to its real SFX, then requests existing music and narration. The GUT test checks serialized settings, fresh-process restored values and the players' actual volume/playing properties. This uses the headless dummy audio driver; it is not audible or graphical signoff.

Additional production-boundary checks cover independent validation (including NaN/infinities, bool, string, collections, missing fields and bounds), read-only restore, unrelated settings, malformed replacement on explicit save, blocked writes/renames, previous-file preservation/recovery, pre-ready mute, New Game and loading all three actual disposable campaign slots. Existing Journal and mute tests are preserved. Preferences and saves use disposable paths; child processes use disposable `XDG_DATA_HOME` on Linux. On other platforms, only the XDG-specific process cases are marked pending to avoid accessing player data.

Reproduction:

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_preferences.gd,res://tests/test_audio.gd,res://tests/test_academy_journal.gd,res://tests/test_journal_close_input.gd -gexit
```

Run under disposable `XDG_DATA_HOME`. Serialize clean import/full GUT with `vael-godot-heavy.lock` in the Git common directory. Final checks and exact tested candidate SHA are recorded in the PR.

Graphical follow-up for lead scheduling: use the tested PR SHA, original renderer and disposable installation data; enter campus → J → System, change all three audio rows and verify displayed levels/live sound; Return to Title, New Game and load each campaign slot; close the application and relaunch, checking displayed values and the first title/dialogue/music/SFX playback. Coordinate exclusive shared-GUI ownership through #5/#39 first. This implementation did not control the shared desktop, and claims no graphical, audible or Neal visual approval.
