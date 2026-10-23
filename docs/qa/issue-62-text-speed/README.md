# Issue #62 — persistent Journal dialogue text speed

Plan basis: [MASTER_PLAN.md](../../../MASTER_PLAN.md) §§1–2, §6 WO-9.6 and §10 rows 9.4–9.10. Existing presentation and conversations remain within [ACADEMY_BIBLE.md](../../../ACADEMY_BIBLE.md) §3. Installation-local preference storage extends the existing Journal/settings architecture documented in [HANDOFF.md](../../../HANDOFF.md) for #43; it does not move dialogue state into campaign or audio data. No story or canon conflict was found.

The Journal System now offers Normal (48 characters/second), Fast (96) and Instant. The default is Normal. `DialogueScene.typewriter_speed < 0` follows the installation preference; any exported value `>= 0` is an explicit per-instance override (including the existing 0 and 10 pilot/test values). Instant completes the current reveal without advancing the dialogue. The preference uses `[dialogue] text_speed` in installation-local `user://settings.cfg`, keeps readable unrelated settings, and remains outside campaign saves. Invalid values default to Normal. Failed writes preserve the prior readable file, report failure in the Journal, and leave the live selection usable.

## Runtime evidence — 2026-10-23

Godot 4.7.2, original Forward+ Vulkan renderer (llvmpipe), real X11 keyboard input, compact 800×450 window. The disposable installation profile was newly created for this check. Fixture provenance: shipped Title → Dev Jump → Campus, with no campaign save preloaded; Slot 1 was saved through the ordinary Journal save row. Its campaign payload remains separate from the preference.

1. Fresh process: Journal System showed the default Normal setting. Existing audio values showed Music 70%, SFX 85%, Master 100%.
2. Arrow navigation changed Text Speed through all three modes. The selected row and System tab stayed active; visible feedback reported the chosen mode and rate. Save/load rows, audio rows, Return to Title, and the footer remained visible at both 1280×720 and 800×450. Captures: [default-size Fast](images/system-default-fast.png), [compact Normal](images/system-compact-normal.png), [compact Fast](images/system-compact-fast.png), and [compact Instant](images/system-compact-instant.png).
3. Set Fast, save Slot 1 normally, close the application, and launch a fresh process with the same disposable installation profile. Before entering dialogue, the Journal showed Fast and the existing audio values remained 70/85/100. The slot remained available.
4. In that fresh process, use Dev Jump → The Awakening. Its existing Oakstead opening line revealed at Fast speed and waited for player input with the advance marker visible; it did not auto-advance. [Authored dialogue capture](images/dialogue-compact-fast.png).

The UI fixture is an existing shipped preview/Dev Jump route, not an earned campaign run. No fixture save came from player data. No prose, art, voice behavior, or renderer setting changed. These captures are functional QA evidence, not Neal's visual/taste approval. This bounded run did not replay the school loop or test physical speaker output.

## Automated checks

Focused regressions cover actual Journal System input and handled navigation, all-mode reveal/advance/choice/event callback order, explicit speed overrides, omitted/malformed/invalid values, preservation of audio and unrelated readable settings, failed-write preservation/retry, fresh-process restoration before first dialogue, and New Game/load isolation from campaign payloads. Existing audio preference, Journal, dialogue, support-playback and receipt tests remain in the full GUT run.

On merged accepted base `5663ec2c`, the focused `test_dialogue_preferences.gd` passes **9/9 tests, 93 assertions**. A fresh-cache Godot 4.7.2 `--headless --import` exits 0 without script-load errors. The required full GUT command passes **862/862 tests, 12,916 assertions, 108 scripts**, exit 0 (236.676 s; 27 existing deprecation notices), serialized with the common Git-directory heavy lock and disposable XDG data. GUT explicitly expects the engine parse error produced by the malformed-config fixture. PR [#66](https://github.com/KumarG23/vael-academy/pull/66) is open for exact-head CI and lead review.
