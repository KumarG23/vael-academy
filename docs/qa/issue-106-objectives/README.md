# GH-106 — current assignment reference

Authority: MASTER_PLAN §§1–2, §6 WO-9.7 objectives/quest log and partial §10 M9;
ACADEMY_BIBLE §3 Mission Board / War Room and §4 Calendar & Traditions / weekly
rhythm. This exposes existing current-event data. The six-week sample remains
scaffolding; authored semester mapping, future quests and story remain outside
this delivery. No canon contradiction was found and no Neal taste approval is
claimed.

The appended Objectives tab is index 7. Existing tab/System row indices, shipped
and additional keys remain unchanged. Battle metadata follows exactly
`ChapterRegistry.scene_for(current_event.chapter_id, Campaign.house_id)`, as the
War Room does. The selected root ChapterDef supplies its display name; battle
and Journal now share the unchanged ROUT/SEIZE/boss-fallback wording. Inspection
walks inherited PackedScene root properties without constructing or readying a
BattleView. Explicit overrides (including null) win; child-node chapters,
incorrect roots, absent scenes/chapters and blank names cannot imply a usable
mission. Nonbattle weeks say “No mission this week.” A null event says the
current assignment is unavailable, without claiming a completed canonical year.

TextParagraph wraps using the active UI font, with bounded line scrolling only
when necessary. Rendered line metrics and ascent/descent keep title, tabs, body
and footer separate. Native QA exposed legacy frame source slicing stretching
corner ornaments over the text despite mathematical bounds: this Journal alone
uses a complete 112 px source corner in the existing 22 px destination corner.
The optional UITheme parameter leaves every other caller's defaults unchanged.
No new art, autoload, routing/progression or save/settings schema was introduced.

## Automated evidence

- Regression-first production SubViewport suite on unchanged accepted base
  `d15bdb95`: **0/7 pass, 40/50 assertions**. The fresh worktree first needed the
  documented import/class-cache repair before a meaningful baseline run.
- Initial implementation: **7/7, 4,293 assertions**. The wrap traversal was then
  bounded by actual line count instead of an unnecessary 100 repeated steps.
- Expanded frame/header/footer assertions exposed existing baseline overlap:
  affected group **159/160, 6,313/6,321 assertions / 14 scripts**. The remaining
  159 tests passed (Journal, Calendar, close, keyboard controls/preferences,
  castle, travel, map, fade, SaveSystem, autosave, load feedback, load validation).
- After measured title/footer/body correction and the native frame correction:
  **48/48, 958 assertions / 5 scripts** (new suite, Journal, Calendar navigation,
  close input, keyboard-controls input), exit 0. The new suite is **7/7, 543**.
- Fresh-cache import exited 0 with no script-load errors. It reported four
  discarded QA image paths removed during the import scan; stale import entries
  were removed, and the follow-up cached import exited 0 without errors/warnings.
- Full GUT: **1,007/1,007, 18,431 assertions / 122 scripts**, exit 0
  (**471.944 s**); helpers **113 discovered, 111 pass/two existing opt-in skips**
  (6.551 s). This uses the final gameplay source in the manifest. Additional
  route-identity/non-default-state assertions were strengthened after collection
  and receive a final focused pass; no duplicate full suite or GUI run.
- Final strengthened Objectives suite: **7/7, 556 assertions**, exit 0
  (3.946 s). Actual routed resource identity, read-only Campaign/RNG on each
  battle route, actual named-boss wording and non-default training/entry/prep
  sentinels pass. No gameplay source changed after native acceptance/full GUT.

The new suite checks actual selected chapter resources on all three houses at
both battle weeks; FREE/HOLIDAY/null/unknown event data; inherited, overridden,
null and invalid-root isolated scenes; ROUT/SEIZE/DEFEAT_BOSS fallback; long-label
wrapping and live resize at all three target sizes; measured complete glyph
lines, title/tabs/footer/frame bounds; all six extra keys plus defaults; actionless
confirm; consumed Esc/J/custom cancel and subsequent castle input. Full Campaign
(including RNG), active/skip-reset/prep/support state, all manual slots, Autosave
and settings bytes/absence are compared. Unknown missions and extended labels
are isolated test data, never production additions. Existing assertions remain.

All local imports/GUT runs use the common Git-directory `vael-godot-heavy.lock`
and disposable XDG player data. No simultaneous heavy Godot work was launched.
The full run reported 67 existing wait-frame deprecations and the documented
headless pixel-popup texture/readback diagnostics (see GH-65); no script-load
errors or assertion failures. Inherited exit-time ObjectDB/resource cleanup
diagnostics occurred in earlier focused runs.

## Native original-renderer evidence

Sole controller authorized by issue #106 after #95/#96 releases. Inventory found
no prior game/input/capture jobs. Godot **4.7.2 Vulkan Forward+ / llvmpipe**, native
X11 on the shared desktop, disposable saves/settings. [Source/capture hashes and
exact client dimensions](manifest.json), [whole-state comparisons](results.json).
The source manifest identifies the actual tested working source on accepted
base `d15bdb95`; it does not attribute earlier captures to a later commit.

1. Through ordinary Title input, pointer activation of shipped **Dev Jump →
   Campus** provided the Week-1 BATTLE reference. This is an explicitly declared
   existing developer setup, not earned opening-battle progression. Shipped
   J/Left reached Objectives. Enter did nothing, Right/Left switched and returned;
   default Esc closed without opening a system menu. Held Right resumed walking.
   Inspected captures [1280×720](images/04-battle-default.png),
   [800×450](images/05-battle-800.png),
   [640×360](images/06-battle-640-top.png),
   [after Down](images/07-battle-640-bottom.png),
   [exploration](images/08-exploration.png).
   The complete existing assignment fits at these sizes; Down therefore remains
   clamped. Long-label scrolling is supplementary automated fixture evidence.
2. Configured all six extra keys through the shipped System keyboard editor:
   I/N/G/L/O/P for Up/Down/Left/Right/Confirm/Cancel. Extra Left/Right reached and
   left Objectives, I/N navigated, O stayed actionless, P closed. Inspected
   [compact reference](images/10-custom-objectives-640.png). Settings bytes were
   compared only after that deliberate configuration; Journal reference input
   itself did not write them. Shipped controls remained available.
3. Returned through System → Title, used ordinary [Load Game](images/02-load.png)
   to restore the earned [Week-2 checkpoint](../issue-5-school-loop/emberwing-return-save.json).
   SHA-256 **681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4**.
   No checkpoint field was edited. Three manual files plus Autosave were isolated
   byte-identical copies to check preservation. Observed “Week 2 · Term begins”
   and “No mission this week.” at [1280×720](images/03-nonbattle-default.png),
   [800×450](images/11-nonbattle-800.png), [640×360](images/12-nonbattle-640.png).
   Extra confirm/Up/Down/close left Campaign/support/entry/prep state and position
   identical and returned `busy == false` with no system menu. The walking
   capture is from the declared Week-1 setup, not an earned Week-2 walk.
4. All observed campaign fields including training RNG, live support snapshot,
   active/skip-reset/prep state and position compare equal across each read-only
   interval. All four save files retain the exact checkpoint hash, and settings
   retain their post-configuration bytes. The read-only reporter invokes no
   action, entry, routing, save or progression handlers.

Capture setup initially inherited a maximized/cropped desktop window. Those
captures were rejected. The final borderless client was unmapped/reparented to
the existing X11 root, resized and focused through ordinary desktop automation;
retained captures are full client images. No renderer override, compositing of
captures, game-state injection or earned-checkpoint rewrite was used.

All game/input/capture jobs ended; final process exited 0 through System → Return
to Title → Quit. [Explicit GUI release](https://github.com/KumarG23/vael-academy/issues/106#issuecomment-6384514756).
Native acceptance is bounded: other houses/closing battle, unavailable metadata,
null/HOLIDAY and extended labels are automated/isolated-fixture coverage, not
native earned progression. This original acceptance preceded the accepted Roster merge; see the
integration receipt below. No full-school replay, future
calendar authorship, new mission content or Neal approval is claimed.


## Accepted Roster integration — 2026-10-24

Normally merged accepted main **0b54e16b38ede97f346b06ca7c95afda20c7dc85**
(PR #99, accepted source bcd1690e). Actual conflicts were MASTER_PLAN and the
Journal footer. Preserved both status rows and every sibling source/test/QA
record. Ten Roster layout/paging functions and test_journal_roster_compact.gd
are byte-identical to accepted main. The Roster draw branch retains its accepted
legacy frame/title and dedicated measured footer/body; the other tabs retain
GH-106's captured frame/title/footer and Objectives behavior. No metadata,
objective wording, calendar data, state/save or custom-key code changed.

Proportional integration checks **100/100 tests, 2,114 assertions / 10 scripts**, exit 0 (31.732 s), under the common Godot lock/disposable data; no script-load errors. The run retains 56 inherited wait-frame deprecations and existing exit-time two ObjectDB/one resource diagnostics. The new production coexistence test navigates Roster ↔
Objectives with actual viewport input, verifies actionless confirm, accepted
PageUp/Down paging/clamping and unchanged tab-row counts at 1280×720, 800×450,
640×360 and restored default, and compares complete Campaign/RNG state.
All accepted Roster assertions remain unchanged. No new local full GUT or native
baseline was repeated for this integration. No GUI was used: #108 is now the
lead-named sole controller. Existing native evidence stays attributed to the
source in the manifest and to #96's accepted QA, rather than being relabeled as
an integration-head capture. Final exact-head Verify and lead review remain gates.


## Accepted test-isolation integration — 2026-10-24

Lead accepted **4c535c1c0a7a9e4a06b5c910c2b5c8ad1e56b6bc** source/runtime/checks,
with no production/test finding and exact Verify 40098210146 SUCCESS. Retain that
acceptance and all earlier source-specific native/full-suite evidence. Normally
merged accepted #98/main **afe9859264895b17e35f5ee3c89b820dc6b14529**; conflicts
were HANDOFF and MASTER_PLAN only. Kept both records and updated acceptance status
where resolving those rows. Production, Objectives/Roster/Calendar/input tests and
the source/capture manifest are unchanged from accepted #106; the incoming
isolation test/assertions are unchanged from accepted main.

Post-#98 Journal/preferences boundary **86/86 tests, 1,877 assertions / 9 scripts**, exit 0 (29.434 s); same-process dialogue→audio repeated on that reused disposable profile **24/24, 381 assertions**, exit 0 (12.704 s). Installation settings remained absent after both runs; no script-load errors. Boundary reported 61 inherited deprecations and existing exit-time two ObjectDB/one resource diagnostics; repeat reported five deprecations. Both processes use the same disposable XDG profile under the
common Godot lock. The first runs dialogue then audio before the Journal boundary;
the second repeats dialogue→audio on reused data. Installation settings remain
absent after both runs. No source repair, new test, GUI, local full/import/native
replay, new canon or Neal approval claim. #108 retains sole GUI control. Final
integration-head Verify and lead delta review remain required.
