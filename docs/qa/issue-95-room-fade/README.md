# GH-95 academy room fade — validation record

Scope: MASTER_PLAN §§1–2, §6 WO-9.9 and partial §10 M9;
ACADEMY_BIBLE §§3/4b; STYLE_BIBLE's approved CP-7 pixel-world direction.
No new canon or art direction is proposed. Existing school-year authoring remains
with #30. This record does not claim Neal's visual approval.

The local CastleScene presentation uses **120 ms out + a fully concealed frame
before switching + 120 ms in**, paced by ordinary scene frames. The opaque cover
also remains black during the switch frame. Slow frames can lengthen presentation;
there is no world/global time-scale change. Initial/programmatic `enter_room()`
remains synchronous. Physical public doors and accepted earned travel share the
same path; excluded town/grove doors retain their existing behavior.

Destination access and the original authored spawn are checked before starting
and again at concealment. Fast travel still requires an earned visit and #81's
reachable safe arrival. Physical entry keeps its ordinary authored door spawn and
re-arm semantics. A changed eligibility check aborts the switch and reveals the
source, without a delayed retry. Door audio is issued once at the actual switch.
The existing title starts its full 1.5 s hold and 0.45 s fade after reveal.

The state machine owns no timers, tweens, coroutines or deferred room switches.
Input is consumed in `_input` before overlays, including key echoes/releases and
pointer events. `_unhandled_input` also guards the editor before acting. Only
ordinary held movement polling resumes after reveal. Source interaction/prompt
references clear at start; the destination prompt is refreshed after reveal.
Removal clears local cover/request state; synchronous external initialization
supersedes a pending fade.

## Automated evidence

Godot 4.7.2 clean import passed (exit 0), without script-load errors. Helpers:
104 discovered, 102 passed and two existing opt-in skips (8.480 s). Tests use
isolated player data and serialize Godot work under the Git-common-directory
`vael-godot-heavy.lock`.

Initial new suite: 13/13 tests, 149 assertions. Affected castle/map/travel/input,
Journal/close, layout, campaign/flow/load, SaveSystem/resume and load-feedback/
battle-save checks: **153/153, 5,295 assertions / 15 scripts**, exit 0 (37.904 s).

Self-review identified a physical-door retry after an aborted concealed switch.
A new regression repairs the destination after rejection and runs the ordinary
door check while still on its source doorway: **13/14 passed, 166/167 assertions**
before the re-arm fix. Disarming an accepted physical trip immediately (while
still revalidating its original cell/door/spawn at concealment) fixes that retry.
Final fade/castle/travel/map group: **56/56, 1,251 assertions / 4 scripts**, exit 0
(19.210 s); new fade suite **14/14, 167 assertions**. The broader affected pass
preceded only this local re-arm fix. Both affected runs report the inherited
exit-time two ObjectDB instances / one resource diagnostic; neither reports
script-load errors. The initial full run was stopped early to fix this concrete
regression; the completed full run on corrected source passes **960/960, 16,964 assertions / 116 scripts**, exit 0 (448.021 s), with 55 inherited deprecation notices and the same exit-time resource diagnostics. A cached editor import after adding the QA observer/new test UID also exits 0 without script-load errors. Existing assertions are preserved; door/travel tests now
await the bounded presentation before asserting arrival.

New `tests/test_academy_room_fade.gd` uses a production CastleScene in a real
SubViewport and real viewport key/pointer dispatch. Deterministic calls to its
production `_process` advance each presentation boundary so assertions can inspect
both halves and full concealment without sleep races. Existing travel tests also
exercise ordinary engine-frame continuation. This is headless runtime evidence,
not graphical evidence.

## Native original-renderer acceptance — complete

Tested source: **`e02a73d810fc4a4e11352ac5deed0d10c8b7d1cc`**. Original
**Godot 4.7.2 Vulkan 1.4.318 Forward+ / llvmpipe LLVM 20.1.2 (256 bits)**.
[Lead nomination after #92 release](https://github.com/KumarG23/vael-academy/issues/95#issuecomment-6373373082)
was received before launch; inventory contained no graphical game/input/capture
job. The normal Title → Load Game → Slot 0 route used the unchanged, previously
earned [native Week-2 checkpoint](../issue-5-school-loop/emberwing-return-save.json),
SHA-256 **`681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`**,
in disposable saves/settings. **No checkpoint field or visit was seeded/edited.**
The only harness additions are the committed Title entry runner, initial window
size and read-only observer. An external BFS over observed passable cells plans
native X11 key holds; it never calls a game handler or writes avatar/world state.

[Structured complete states/phase events/checks](results.json) and
[SHA-256 manifest](manifest.json). All **18 retained captures** were inspected.
Both original 3-second / 60 fps clips were inspected through complete 10 fps
frame sequences plus original-resolution source/concealed/reveal frames and
60 fps black detection:

- [Default 1280×720 clip](clips/default-transition.mp4): map selection → source
  fade → full concealment (0.5167–0.5500 s) → Entrance reveal/title and held-right
  ordinary movement. [Source](images/clip-source.png),
  [whole viewport concealed](images/clip-0.52.png),
  [reveal](images/clip-0.66.png). The OS cursor is independent of the game cover.
- [Compact 640×360 clip](clips/compact-transition.mp4): ordinary map navigation,
  accepted travel → source fade → full concealment (1.4500–1.5500 s) → Campus
  reveal/title. [Concealed](images/compact-concealed.png),
  [revealed](images/compact-revealed.png). Native client pixels only; no image
  synthesis, scaling or renderer substitution. Compact captures use the observed
  client rectangle; full-size captures are the fullscreen native client.

Actions and results:

1. [Initial actual Campus entry](images/01-initial.png) earns only Campus;
   [initial list](images/02-only-campus.png) has no undiscovered interiors.
   Current-room Enter leaves the map/location/state unchanged; Escape closes
   without opening System. Ordinary walking crosses Campus `(22,7)` →
   [Entrance Hall](images/03-door-entrance.png), then back to Campus. Both trips
   fade once, and authored spawns/camera/music/title/re-arm continue normally.
2. Earned keyboard travel Campus → Entrance and
   [pointer travel Entrance → Campus](images/06-pointer-travel.png) share the
   concealed path. Further physical Entrance ↔ Common Hall trips work in both
   directions and earn only Common Hall. Every observed room switch occurs with
   cover alpha 1; phase events show one source/destination sequence per request. The viewport
   test explicitly asserts one `room_changed` emission.
3. A native accepted confirmation is followed immediately by held Right,
   Enter, J, M, Esc and editor-grave keys plus left/right pointer input.
   `07-input-blocked` samples source fade-out alpha 0.3407 with no overlay/menu/
   dialogue. [After reveal](images/08-held-revealed.png), ordinary held movement
   continues, without a bounce, activity or overlay. Keys are released normally;
   no InputMap/time-scale mutation or injected game event is used. Headless
   viewport tests additionally cover explicit echo/releases during both halves.
4. At **640×360**, keyboard travel, [pointer travel](images/14-compact-pointer.png),
   [current-room no-op](images/13-compact-current-map.png) and pointer cancel work.
   A native **640×360 → 800×450 resize during fade-out** is recorded with phase 1
   in `15-resize-during-fade`; [reveal](images/15-resized-reveal.png) is complete,
   unobscured and usable. Invalid pointer confirmation outside destination rows
   keeps the [open map](images/19-invalid-pointer.png), exact location and state.
5. After reveal, existing physical doors remain usable, the existing
   [Kael conversation](images/16-dialogue.png) starts/advances/completes using
   native Enter, and [Journal](images/09-journal.png) opens/closes with close
   consumption intact. Further ordinary door continuation returns to Entrance.
   The only subsequent progression is the existing `read_kael_chat = true`
   receipt from that deliberately activated conversation.

Whole-state checks compare actual loaded Campus state with each subsequent trip:
**all Campaign fields (including roster, support/grades/flags/calendar/training
and training RNG) and live support state match except exactly the already-supported
unique visit receipts**. Final visits are `campus`, `entrance`, `common_hall`;
final state equals the initial complete state plus those receipts and the actual
Kael-read flag. No training/hub/rest/save handler is called by presentation.
Slot 0 retains the byte-identical checkpoint hash above; other manual slots,
autosave and settings files remain absent. All 17 observed presentations settle;
phase-observer elapsed times are **224–259 ms** (frame-sampled, not a fixed wall
clock promise). One room rebuild occurs per accepted request. No runtime/script
errors appear in the game log. The game exits normally with **code 0**.

**All game/input/capture jobs ended; inventory is empty.**
[Explicit GUI release](https://github.com/KumarG23/vael-academy/issues/95#issuecomment-6373539269).
No control is retained.

Limits: bounded three-room/native checkpoint acceptance, not a full-school replay
or Neal taste/visual approval. Dynamic invalid destination/access/spawn and
teardown cases are production viewport/lifecycle tests; native invalid checks
cover unavailable destinations/current-room/blank-pointer/cancel without
corrupting authored resources. Actual autosave-file/custom-key integration stays
pending accepted #85/#89. Native Journal open/close passed, but its inherited
compact **Roster** stats/gear overflow was observed separately and filed as
[#96](https://github.com/KumarG23/vael-academy/issues/96), with default/compact
captures; #95 does not claim that unrelated layout is fixed.

## Remaining acceptance gates

- Integrate #85 and #89 only after each is accepted/merged, by ordinary main merge;
  preserve #92 if accepted main contains it. Run proportional boundary checks,
  including the actual autosave checkpoint and custom keyboard controls.
- Actual exact-final-head CI success and engineering-lead acceptance before
  ready/merge. No draft sibling copying, unchanged full/native replays merely to
  wait, direct-main push or self-merge.
