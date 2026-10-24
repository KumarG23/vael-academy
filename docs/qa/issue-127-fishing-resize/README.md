# GH-127 — active fishing cast through window resize

## Plan and owning document

- `MASTER_PLAN.md` §§1–2, §6 WO-6.4, §10 M9 / modernization status.
- `ACADEMY_BIBLE.md` §3, “The grounds & waterside” and “Fishing”: fishing remains the existing self-contained waterside activity and a counterweight to combat.
- No conflict with authored story, mechanic, reward, or scope direction was found. No canon decision was made.

## Automated source evidence

- Accepted base: `8b442f13b34d86924cdb0fe374b49d7a7872649a`.
- Regression-first production `FishingGame` in real `SubViewport`s: on the unchanged source, the new suite failed its geometry case (18 bound assertions) after shrinking; the other three test cases passed. This confirms the stale viewport geometry in the source, not a native reproduction.
- After repair, production resize + original fishing tests pass **19/19, 155 assertions / 2 scripts**. They cover 1280×720, 800×450, 640×360, shrink/restore in WAITING and BITE, line/bobber/marker/hint bounds, active-font hint width and outline margins, marker sway pinning, exact text and click-through behavior, timers/phase/local RNG/Campaign snapshots, same-seed result with and without resize, early miss, the unchanged strict `> 0.55s` expiry boundary, one catch, no post-finish mutation, dispatched Space confirm, and normal castle cleanup/control recovery.
- Affected fishing/castle/Journal/close/keyboard/Campaign/save boundary: **141/141 tests, 4,800 assertions / 13 scripts**, exit 0. The focused process reports 35 inherited GUT wait-frame deprecations and the existing exit-time two ObjectDB / one resource diagnostics.
- Team helpers: **113 discovered, 111 passed, two existing opt-in lifecycle skips**.
- Final Godot 4.7.2 editor import on the changed production source exited 0 with no script-load errors. It used the common `vael-godot-heavy.lock` and disposable `XDG_DATA_HOME`.
- Final full GUT: **1,032/1,032 tests, 22,685 assertions / 126 scripts**, exit 0 (482.922 s). The run reported 99 inherited wait-frame deprecations and expected dummy-renderer image readback diagnostics in existing battle animation tests; no test failed.
- Final latest fishing/Journal pass, including manual/autosave/settings byte snapshots: **43/43 tests, 267 assertions / 3 scripts**, exit 0. The final affected fishing/castle/Journal/close/keyboard/Campaign/save boundary passes **142/142, 4,816 assertions / 13 scripts**, exit 0; it reports 35 inherited GUT wait-frame deprecations and existing exit-time two ObjectDB / one resource diagnostics. Team helpers: **113 discovered, 111 passed, two existing opt-in lifecycle skips**.

## Native original-Forward+ acceptance — complete

Lead authorization: [issue #127 comment 6388204487](https://github.com/KumarG23/vael-academy/issues/127#issuecomment-6388204487) named isolated slot a after #124/#131 released. All three graphical runs ended normally; the slot wrapper released Xvfb/display :100. No other slot or shared desktop was used.

**Tested source:** `492344494475b27beea56bd77c2ae2290d1848cb`, the normal merge of accepted main `028132c5` into `team/issue-127`. **Renderer:** Godot 4.7.2 stable, Vulkan 1.4.318 Forward+, llvmpipe LLVM 20.1.2 (256 bits). Captures are unmodified 1280×720 X11 screen grabs; the game window/client was resized through actual OS window events. The full-size captures use fullscreen to expose the complete 1280×720 client viewport. No renderer/project setting was changed.

### Earned-checkpoint playthrough and live cast

The primary run copied the unchanged earned [Emberwing Week-2 return checkpoint](../issue-5-school-loop/emberwing-return-save.json) to isolated `slot_0.json`; source SHA-256 is `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`, and the copied file had that same hash before and after the session. Nothing in the checkpoint was edited. Real keyboard input followed Title → Load Game → Slot 0 → Campus, then ordinary walking through the Campus physical Waterside door. [Loaded Campus](images/native-loaded-campus.png), [Waterside entry](images/native-waterside-entry.png), and [the existing Cast a line point](images/native-cast-point.png) show this route. There was no Dev Jump, debug outcome, save-field injection, pause, or timing change.

A naturally started cast at the default 1152×648 window was resized during WAITING through 800×450 and 640×360. The inspected [800×450](images/native-waiting-800x450.png) and [640×360](images/native-waiting-640x360.png) captures each show the existing line, bobber, and full strike hint. A separate fullscreen sample gives the exact [1280×720 WAITING view](images/native-fullscreen-waiting-1280x720.png). In a further ordinary cast, the active BITE marker and hint were captured at 640×360, then the live window was resized to 800×450 inside the unchanged bite interval; [640×360](images/native-bite-640x360.png) and [800×450](images/native-bite-800x450.png) show the marker pinned above the bobber and both complete hints. A supplementary full-screen run captures exact [1280×720 WAITING](images/native-fullscreen-waiting-1280x720.png) and [BITE](images/native-fullscreen-bite-1280x720.png), including the full strike hint. The 1280×720 BITE was left to expire naturally; [the visible miss result](images/native-fullscreen-natural-miss-1280x720.png) says “...it got away.”

The screen observer detected the visible `!` glyph in the rendered window; the actual strike was an OS-level Space key. One cast was allowed to expire naturally and showed the normal miss result. On the next cast, Space was sent immediately after the marker appeared; the game showed [Caught a Lakeperch! (x1)](images/native-natural-catch.png). A further ordinary cast followed that catch before Journal/save exploration; the saved catch count remained one. The game’s existing `0.55s` bite window was never paused or lengthened.

### Journal, normal save, and fresh Title load

The real compact [Journal Fish Log](images/native-fish-log-before-save.png) displayed the naturally earned `Lakeperch ×1` plus the checkpoint’s pre-existing `Warded Coin ×1`. Journal → System → Save used the ordinary menu and wrote Slot 2; the game showed [Saved to slot 2](images/native-normal-save-feedback.png). The generated manual-save file SHA-256 is `0d827bcbb66e35303f57c3e56fa61eddac88565d10647169d213a0158489b29f`. The original Slot 1 checkpoint stayed byte-identical. No Autosave or `settings.cfg` appeared in the isolated profile.

The first process returned through the normal in-game Title route and quit. A separate slot-a process used a new disposable profile containing a byte-for-byte copy of the game-produced Slot 2 file (same `0d827…` hash), then followed Title → Load Game → Slot 1. [Fresh Title](images/native-fresh-title.png), [the ordinary Load menu](images/native-fresh-load-menu.png), and [the loaded Campus](images/native-fresh-loaded-campus.png) record the route. After opening the Journal in the fresh process, [Fish Log at 640×360](images/native-fresh-load-fish-log-640x360.png) still displayed `Lakeperch ×1` and `Warded Coin ×1`.

### State, files, and limits

The resize interval did not write or replace the original checkpoint. Before the explicit Journal save, the only save payload was Slot 1 at the exact `681e0c32…` source hash; after that normal save, it remained the same and the new Slot 2 was `0d827b…`. No Autosave or settings file was present. The later fresh process received an unmodified copy of that newly saved file. Capture SHA-256 values are recorded in [`manifest.sha256`](manifest.sha256).

The native run compares on-disk save bytes and visually observed outcomes; it does not claim a readout of every volatile in-memory Campaign/RNG/support field. Those complete Campaign/RNG/result/timer invariants are covered by the production SubViewport regression tests above, including same-seed resized/no-resize results, no post-DONE mutation, and manual/Autosave/settings byte snapshots. The primary earned-checkpoint route is the physical Waterside door. The later exact-1280 fullscreen sample is explicitly supplementary setup: it loaded the naturally game-produced Slot 2 through Title, used the shipped room map to return to an already visited Waterside, then inspected a naturally started cast. No second earned route is claimed. Captures document the actual tested source; no Neal visual approval is claimed.

## Accepted-main integration

Accepted Supports main `d5f512599a7c1de81405d893c5fb24a578c5aa52` (#124 / PR #129) was integrated normally after the prior #131 integration at `492344494475b27beea56bd77c2ae2290d1848cb`. The only merge conflicts were adjacent records in `HANDOFF.md` and the `MASTER_PLAN.md` §10 status table; both GH-127 and GH-124 records/status rows were retained. The accepted Supports Journal implementation, regression tests, QA report, captures, and source hashes remain intact. FishingGame and its resize regression source are unchanged by this incoming integration.

The proportional integrated boundary passed **212/212 tests, 18,510 assertions / 23 scripts**, exit 0 (32.912 s), under the common Git-directory `vael-godot-heavy.lock` with disposable XDG data. It covered fishing/resize, Castle cleanup, Journal and Supports layout/playback/state, close/navigation, keyboard, Campaign, and save/load. The run reported 96 inherited wait-frame deprecations and expected malformed-support and keyboard-preference failure-fixture diagnostics; no failed tests. No unchanged full GUT, helper, import, or native baseline was repeated. Native evidence remains source-attributed to `492344494475b27beea56bd77c2ae2290d1848cb`; this integration adds headless coverage of the accepted Supports changes, not new GUI evidence. Exact integration-head Verify is the remaining automated gate.
