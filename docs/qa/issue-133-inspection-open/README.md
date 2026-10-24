# GH-133 — inspection open layout timing, native evidence

Basis: MASTER_PLAN §§1–2 (presentation/logic split, inspectable tactics), §6 WO-4.4/9.5, partial §10 M9; ACADEMY_BIBLE §4. No contradiction, no canon/mechanic change.

Source: parent `59ff4457` plus the uncommitted-at-capture GH-133 test change (production `BattleView._open_stats_for` identical to the committed repair). Godot 4.7.2, original Forward+ (llvmpipe), private X11 slot b (`DISPLAY=:101`, run dir with its own XDG/HOME), real `xdotool` keys, one real pointer click, real window resizes; captures are full-client (`xwininfo` origin), all 15 viewed. No project/renderer change. Heavy lock held for the run; slot released on exit (command ended, exit 143 = deliberate kill of the game).

Fixture (declared, supplementary): shipped `battle.tscn` started by a temporary uncommitted runner scene that only gave the shipped foe "Tidemark Soldier" a five-weapon pack (the full-pack sheet); it also logs read-only state hashes once per change. All gameplay after that is ordinary input: Right×4/Up moves the cursor (hover shows), Enter, Enter opens inspection.

Observed (images/, hashes in manifest.sha256):
- 04 default 1152×648: full-pack sheet open with hover at right, no overlap.
- 05 live shrink 800×450, 06 640×360 (wide two-column sheet, hover pinned above it), 07 grow 800×450, 08 grow default: sheet and hover stay inside the client and clear of each other every step.
- 09 any key (Q) closes at 640×360; 10/11 cursor to a different foe (Tidemark Sentinel, long wrapped name) and inspect: new content settles correctly; 12 real pointer click on the sheet dismisses; 13/14 continuation: cursor moves, hover updates, Soldier re-opens full-pack sheet at 640×360; 15 Esc leaves normal battle.
- Three inspection opens, cursor re-activates after each dismissal.

State/persistence: `state.log` shows the Campaign and battle-snapshot hashes (campaign=2931598241 battle=245177007) unchanged across all three opens/closes and resizes. `files_before/after.txt`: the only file in the disposable profile was Godot's own `godot.log` (no save/settings written; caches excluded).

Limits: first-frame (pre-`_process`) geometry cannot be seen in a real client; it is covered headlessly by `test_ordinary_inspection_open_is_laid_out_before_the_next_frame` and the original test, now routed through `_open_stats_for`. One foe-pack fixture; no full-school replay; no Neal visual approval claimed.
