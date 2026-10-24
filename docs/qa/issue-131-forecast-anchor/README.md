# GH-131 — forecast panel re-anchor, native evidence

Basis: MASTER_PLAN §§1–2 (presentation/logic separation), §6 WO-4.4/9.5, partial §10 M9; ACADEMY_BIBLE §4. No contradiction, no canon/mechanic change.

Source: `a9c62e8f8da1afe0e3412c6e0e6f9f899c0b92f5` (repair `battle_view.gd` unchanged since; accepted main `9183237a` integrated). Godot 4.7.2, original Forward+ (llvmpipe), private X11 slot b with its own Xauthority and disposable saves, real `xdotool` keys and window resizes, full-client captures (all viewed). No project/renderer change.

Fixture (declared, supplementary): shipped `battle.tscn` standalone; a temporary uncommitted runner moved Kael one tile from the shipped long-named foe "Tidemark Soldier" (whose name wraps in the 142px forecast column, 218px panel). Everything after that is ordinary input: Enter (select) → Enter (stay) → Enter (Attack) → Enter (weapon) opens the forecast.

Observed ([images](images), hashes in `manifest.sha256`):
- Default window: forecast open, full, bottom margin intact (`05`).
- Live shrink with forecast open to 800×450 (`06`) and 640×360 (`07`); live grow back to 800×450 (`08`) and default (`09`): wrapped forecast stays fully inside every client, both columns/all fields visible.
- Esc cancels targeting; Enter reopens at 800×450 (`12`); at 640×360 Esc/re-open, then Enter continues into the attack (`16` shows the forecast in-bounds at 640×360 before the strike).
- No crash/script errors in the engine log. Hover/inspection/camera/save were not touched by the source change; their headless suites pass below.

Headless on the same source (shared lock, disposable XDG): combined order dialogue → audio → keyboard preferences → Journal calendar → Journal System → load-failure feedback → roster → grades → battle-reference-resize: **81/81, 16,582 assertions** (9 scripts). Regression test fails on unchanged main (8/9), passes after (9/9). Hover-promotion/refresh scripts were not separately re-run beyond the earlier forecast-script set (26/26).

Limits: one long-name fixture; no full-school replay; no Neal visual approval claimed; pixel-exact margin not measured beyond inspection.
