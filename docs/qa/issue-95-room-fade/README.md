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

## Pending acceptance gates

- Integrate #85 and #89 only after each is accepted/merged, by ordinary main merge;
  preserve #92 if accepted main contains it. Run proportional boundary checks,
  including the actual autosave checkpoint and custom keyboard controls.
- Native original-renderer QA is **next**. [Lead release/nomination receipt](https://github.com/KumarG23/vael-academy/issues/95#issuecomment-6373373082) confirms #92 ended its jobs and names #95 sole controller. Process inventory confirms no remaining graphical game/input/capture job. No graphical run has started at this source commit.
- Once released: record tested commit SHA, native checkpoint hash/provenance and
  declared fixture deltas; use disposable saves/settings and the existing renderer.
  Walk public doors both directions; keyboard/pointer earned travel; invalid,
  current and cancel; held movement/interaction/overlay keys; 1280×720 and compact
  resize; dialogue/Journal/door continuation. Inspect captures and a short clip
  proving source → concealed switch → restored room; compare complete Campaign,
  roster/support/grades/calendar/training/RNG and manual/autosave bytes with the
  same ordinary trip. Record actions/timings/limits, end every job and explicitly
  release the GUI. Do not turn bounded fixtures into natural-progression claims.
- Exact final-head CI and engineering-lead acceptance before ready/merge.
