# Issue #43 — Journal audio preferences

Scope: MASTER_PLAN §2 coding rules, §6 WO-9.3/WO-9.6 and §10 rows 9.3/9.4–9.10; HANDOFF AW-36/AW-39. ACADEMY_BIBLE §3's existing castle/Journal experience is preserved. No relevant canon contradiction found.

`AudioManager` restores the existing master/music/SFX levels in autoload `_ready`, before main-scene playback. Journal changes apply immediately and save to installation-local `user://settings.cfg` (`[audio]` keys `master_volume`, `music_volume`, `sfx_volume`), independent of campaign/battle saves and slots. Direct transient assignments in audio tests do not save.

Missing/unparseable files use defaults 1.0/0.7/0.85. In a readable file, missing, wrong-type and non-finite fields use their own defaults; finite integers/floats clamp independently to [0,1], including zero. Restore never writes. An explicit changed Journal control preserves unrelated keys/sections in a readable file; it replaces an unparseable file with the current audio levels. Save writes a sibling temporary file then renames it over the destination. Failure warns, preserves the previous destination, and leaves live controls working; later input retries. Existing zero-volume floor (-80 dB), mute policy and requested-track behavior remain.

Baseline: unchanged game source `24b9bf539493d0acf83a4b1e35126165f76ea83b`, production Journal with viewport action input in one headless Godot process, then a genuinely fresh process sharing disposable XDG data. First process selects 0.60/0.40/0.55; second starts at 1.00/0.70/0.85. This established the restart regression before finishing the preserved implementation.

Verified code/test SHA: `171ccafc93c19a4ab8e374f7b648a2f02fc471a8`, integrating reviewed main `2c1698fe`. Godot 4.7.2: post-integration focused **57/57 tests, 376 assertions**; import exit 0 without script-load errors; full GUT **828/828 tests, 12,078 assertions, 104 scripts**, exit 0 (220.534 s, 22 deprecations). Exit also reports two ObjectDB instances and one resource still in use, as seen in the focused run. Helpers: **66 pass, 2 opt-in lifecycle skips**. Before integration, a fresh `.godot` cache import passed and full GUT passed **822/822, 10,987 assertions**. Final delivery-note updates and integration of QA-only main `f185d6a8` change only documentation/QA evidence relative to the verified code/test SHA; game/test source is identical. PR #45 records the final head and CI outcome.

Automated runtime fixture: `tests/fixtures/audio_prefs_probe.gd`. The `journal` mode traverses the real tabs/rows, changes the three controls and activates Return to Title. The `startup` mode observes restored autoload levels, opens the title and dispatches cursor input to its real SFX, then requests existing music and narration. The GUT test checks serialized settings, fresh-process restored values and the players' actual volume/playing properties. This uses the headless dummy audio driver; it is not audible or graphical signoff.

Additional production-boundary checks cover independent validation (including NaN/infinities, bool, string, collections, missing fields and bounds), read-only restore, unrelated settings, malformed replacement on explicit save, blocked writes/renames, previous-file preservation/recovery, pre-ready mute, New Game and loading all three actual disposable campaign slots. Existing Journal and mute tests are preserved. Preferences and saves use disposable paths; child processes use disposable `XDG_DATA_HOME` on Linux. On other platforms, only the XDG-specific process cases are marked pending to avoid accessing player data.

Reproduction:

```sh
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/test_audio_preferences.gd,res://tests/test_audio.gd,res://tests/test_academy_journal.gd,res://tests/test_journal_close_input.gd -gexit
```

Run under disposable `XDG_DATA_HOME`. Serialize clean import/full GUT with `vael-godot-heavy.lock` in the Git common directory. Final checks and exact tested candidate SHA are recorded in the PR.

## Graphical acceptance — 2026-10-22

Completed at exact game SHA **`2c3b71afd39c584ddb3079b4e81a9038b600b0d3`**, after #40's explicit release and #43's recorded exclusive claim. Godot 4.7.2, unchanged **Forward+ / Vulkan llvmpipe**, existing shared display, disposable installation data. An external SceneTree observer starts the unchanged title scene and reads live node fields every 0.2 s; it never sets volume/campaign state or invokes save/load handlers. All interactions below use actual X11 keyboard events. [Curated observations, save/settings hashes, driver measurements and provenance](issue-43-audio-preferences/results.json).

This is a bounded **Title → Dev Jump → Campus** fixture, not a fresh campaign playthrough. The three campaign slots were created through the real Journal in that shipped preview; no save was seeded or edited.

1. Title: ↓ twice → Enter → Campus Enter. Open J, → four times to System, ↓ six times to Music. [Inspected defaults](issue-43-audio-preferences/images/02-journal-defaults.png): music 70%, SFX 85%, master 100%.
2. Music ← three times; ↓, SFX ← three times; ↓, master ← four times. [Inspected chosen levels](issue-43-audio-preferences/images/03-journal-chosen.png): **40% / 55% / 60%**. Serialized settings match 0.4 / 0.55 / 0.6. Six more ← presses show [0% master](issue-43-audio-preferences/images/04-zero-master.png), with the existing −80 dB player floor; six → restore 60%.
3. From master row, ↑ eight times; Enter saves Slot 1, ↓/Enter saves Slot 2, ↓/Enter saves Slot 3. Activate each real Load row, reopening J → System between loads. Each reload enters the castle with 60/40/55% master/music/SFX and leaves settings bytes identical. [Inspected post-load Journal](issue-43-audio-preferences/images/06-after-slot-loads.png). The three JSON saves contain no audio preference fields.
4. Journal → Return to Title; Title → New Game → Classic. [Inspected normal public Oakstead opening](issue-43-audio-preferences/images/08-new-game-opening.png); levels remain 60/40/55% and settings bytes stay identical. This tests New Game reset continuity, not progression through the opening. Close the application normally with Alt+F4 and verify process exit 0.
5. Relaunch a **different process** with the same disposable installation data. Before title input, observed master/music/SFX are already 0.6/0.4/0.55 and player levels are −12.3958 dB music / −9.6297 dB voice/SFX. Title ↓ produces the first cursor SFX; Enter → Load Slot 1 starts campus music. J → System shows the [inspected fresh-process restored Journal](issue-43-audio-preferences/images/10-fresh-journal-restored.png). Settings SHA-256 remains `7d31194070cd912761245710c09a5f772a46c8532fd0bf29227779a21bd48789`.

Actual PulseAudio **output-monitor PCM** was recorded from the graphical game, not the dummy driver. Sampling uses `ffmpeg -f pulse -i <existing-monitor> -t 1 -acodec pcm_s16le <capture.wav>` (two seconds for first title SFX). The existing virtual sink was used; no service or audio device was created.

| Interval | RMS (16-bit PCM units) | Peak | Recording |
| --- | ---: | ---: | --- |
| Campus, defaults | 2607.8003 | 15049 | [PCM](issue-43-audio-preferences/audio/music-default.wav) |
| Campus, chosen levels | 1082.3639 | 5625 | [PCM](issue-43-audio-preferences/audio/music-chosen.wav) |
| Campus, displayed 0% master | 0.6974 | 2 | [PCM](issue-43-audio-preferences/audio/music-zero-master.wav) |
| Fresh process, first title cursor | 396.4208 | 3703 | [PCM](issue-43-audio-preferences/audio/first-title-sfx.wav) |
| Fresh process, first campus music | 848.6120 | 3817 | [PCM](issue-43-audio-preferences/audio/music-after-relaunch.wav) |

These are different music positions, so RMS establishes functional attenuation rather than a calibrated gain ratio. The displayed zero has a floating residual around 1.39e-16; the existing −80 dB floor explains the near-zero PCM. No speaker/headphone listening or Neal visual/story/taste approval is claimed. The normal public New Game path displayed Oakstead without active narration in sampled frames; **narration startup remains covered by the fresh-process headless production fixture**, not a claimed graphical voice playback. No unrelated renderer/UI/canon changes or new defect found in this bounded check.

Both acceptance process logs have no script/runtime errors. The second process quit normally via Journal → Title → Quit, exit 0. **Desktop explicitly released on #43/#39 for #39's next scheduled window**; no further GUI input is planned. Evidence/status-only follow-up does not rerun full GUT, per lead direction. Later main `fd843f18` integration changes team tooling/docs only; game source/data/scenes/tests are identical to the graphically tested SHA. After that tooling integration, helpers passed **90 discovered: 88 pass, 2 opt-in lifecycle skips** (6.133 s). New-head CI supplies final integration checks.
