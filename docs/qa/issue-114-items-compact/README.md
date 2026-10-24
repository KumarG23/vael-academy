# GH-114 — existing Journal Items compact layout

## Scope and references

This changes presentation and reachability for the existing Quartermaster
Items tab under `MASTER_PLAN.md` §§1–2, §6 WO-9.4/9.7 and partial §10 M9.
The owning design is `ACADEMY_BIBLE.md` §3, Quartermaster/inventory/trading;
existing transfer, bound-item, tome and persistence rules are in `HANDOFF.md`
AW-52/AW-53/AW-55. No canon contradiction was found. No new mechanic,
inventory rule, content, schema, renderer or project-setting change was made.

## Automated evidence

`tests/test_journal_items_compact.gd` instantiates the production Academy
Journal in a real `SubViewport`, dispatches configured/default keyboard
events, and measures renderer layout with `UITheme.font()`. It covers
1280×720, 800×450 and 640×360; both resize directions; all three existing
trade stages; first/final students and recipients; complete shipped labels,
equipped markers and uses; full five-item packs; empty pack/roster; refusal
feedback; default/custom controls; browse/cancel/close invariance; and the
existing transfer/save-load path.

Regression-first on accepted main `300f146a`, the new viewport checks failed
four cases: compact item label/instruction widths, the final student's body
bounds, and compact refusal-toast bounds. Original-renderer QA then exposed a
second 640×360 overlap between the scroll counter and stage instruction. Its
new measured-bounds assertion failed before the fix. The final focused file
passes **9/9 tests, 364 assertions**. The final 18-script affected boundary
passes **160/160 tests, 9,385 assertions**.

On source `4f11054d`, before accepted #112 integration, clean Godot 4.7.2
import exited 0; full GUT passed **1,027/1,027 tests, 20,249 assertions / 125
scripts** (479.318 s); helpers passed **113 discovered, 111 passed, two
existing opt-in skips**. This is the required full baseline and is attributed
to that commit. Accepted #108/#112 source/tests/QA/status were integrated
normally through `8b442f13`; the combined source then passed a clean import
and affected boundary. Verify passed for pre-integration head
`fda7f32fd8357a4c53c68c294c3c61cf1ea05414`
([run 40117611917](https://github.com/KumarG23/vael-academy/actions/runs/40117611917));
accepted main #117 has since advanced the PR head, so this does not verify the
integrated source.


## Accepted-main integration

Main `2d7ae52338fa25556ca8ee1ffce6112b4a0c4a4a` (#117 / PR #120) was merged
normally. The source conflict was isolated to the Journal toast drawing branch:
Items on tab 2 keeps its wrapped inventory feedback, System on tab 4 keeps its
reserved message row and range hint, and the shared toast path remains for
load-error and other-tab feedback. The complete #117 source/tests/QA captures,
manifests and status were retained; MASTER_PLAN and HANDOFF retain both issue
records.

On the merged working tree, the proportional combined boundary passed
**116/116 tests, 18,030 assertions / 12 scripts**: Items layout/input and
transfer, inventory, System rows/feedback/load rejection, Journal/close and
sibling tabs, custom keyboard controls, Campaign load validation and SaveSystem.
It ran under the shared `vael-godot-heavy.lock` with disposable XDG data. The
run reported 79 inherited `wait_frames` deprecations and existing exit-time
two ObjectDB / one resource diagnostics. No repeated full GUT/import/helper or
native GUI run; those earlier results remain attributed to their source heads.
No GUI job was launched because #122 owns the desktop. Exact integrated-head
Verify is the remaining gate; PR #130 stays draft.


### Subsequent accepted-main integration

Accepted main `028132c504060ca6af48bd67f07eb9042712647a` (PR #132) was then
merged normally. The only conflicts were HANDOFF and MASTER_PLAN status rows;
there was no Journal source conflict. Both task records and accepted #118/#131
source, tests, QA captures/manifests and status records remain intact. The
previous 116/116, 18,030-assertion combined boundary is attributed to the
preceding #117 integration head; it was not repeated for this documentation
conflict-only integration. #118/#131 evidence remains attributed to their
own source runs and accepted-main checks. No GUI run was made because #122
owns the desktop. Exact Verify for the current integration head remains
pending.

## Original-renderer evidence

The #112 owner released the desktop, and the lead named #114/Luna the next
sole GUI controller ([release](https://github.com/KumarG23/vael-academy/issues/112#issuecomment-6385623578),
[handoff](https://github.com/KumarG23/vael-academy/issues/112#issuecomment-6385711360)).
Bounded Godot 4.7.2 Forward+ runs use ordinary Title → Load from isolated
copies of the earned Week 2 checkpoint
([source save](../issue-5-school-loop/emberwing-return-save.json), SHA-256
`681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`). The
checked-in checkpoint was not modified.

On the earned copy, native Items were inspected at 1280×720, 800×450 and
640×360, including stage-1 item selection and stage-2 recipient selection
through shrink/restore resize. The active student/item/recipient remained
visible; names, equipped marker, use counts, giver identity, selected
recipient, instructions and refusal feedback remained readable. An ordinary
successful transfer was saved to UI Slot 2 and reloaded. Perrin lost
`sig_perrin` (34 uses), Kai gained it, and the other inventory items/uses
were preserved.

For browse invariance, a fresh earned-checkpoint copy was saved to UI Slot 2
before Items browsing. After stage browsing, live resize, cancel and close,
saving to the same slot produced the same SHA-256: `8104826b83a95589c4ec0e159bfda96d8e61ed8d0603701a219174ed211042bf`.
Slot 0 stayed byte-identical to the source checkpoint (`681e0c32…`). After
the explicit transfer, Slot 2 became
`83aab4f0285bd240e8541936f1727a7f55a67af06067558d356fe1e51d1ec2c2`; reload
restored the transfer. The saved Campaign fields outside the Kai and Perrin
`unit_states` entries were unchanged. Those two entries were refreshed by the
existing `Unit.save_state()` transfer path, including the transferred
inventory; the save schema and campaign RNG/progression/flags/support/calendar
did not change. Native Crownspark refusal did not change either saved file.

The first earned-profile run configured Up/Down to I/N using the shipped
Keyboard Controls editor (an intentional settings write). Its settings
SHA-256 `616550e1671adc6fd6303c7224fdc9f3f9ba4e902ee6d1eacefa4048e6864f83`
remained stable through Items browsing/resize, refusal, cancel/close and custom
Up continuation in exploration. The state-boundary profile used default
controls and made no settings write. The only intentional save writes were
the explicitly selected Slot 2 snapshots used to measure browse invariance
and transfer persistence.

The supplementary overrides in
[`fixtures/supplementary_inventory_overrides.json`](fixtures/supplementary_inventory_overrides.json)
were applied only to a separate disposable copy of the earned save. They are
fixture data, not earned progress. Original-renderer captures show the
complete five-item list at 1280×720 and the scroll window reaching the final
item at 800×450 and 640×360, with complete names, equipped status and uses.
The final student remains selected and visible in the compact student window.
The Codex of Reason tome refusal and full-pack refusal were readable at
640×360. The fixture save remained unchanged at SHA-256
`caec6941ad53497c7eedc642a3acd498ed932714b578def711d3679b7caab470`; no
fixture transfer was saved.

All game/input/capture processes ended after each run. The screenshot list
and per-image SHA-256s are in [`images/`](images/) and
[`capture-hashes.sha256`](capture-hashes.sha256). Captures identify earned
state versus fixture-only UI. Invalid crops, unrelated tabs, and exploratory
captures were excluded. Automated SubViewport evidence does not claim a full
graphical playthrough, and no Neal visual approval is implied.


### Accepted Supports integration and rendered marker-width follow-through

Accepted main `d5f512599a7c1de81405d893c5fb24a578c5aa52` (PR #129 / Supports)
was merged normally. HANDOFF and MASTER_PLAN status were the only conflicts;
both GH-114 and GH-124 records and the complete Items/Supports/System
source, tests and QA were retained. The Journal source auto-merged.

A new production-SubViewport regression measures the exact rendered item label,
including both selected (`› `) and unselected (two-space) prefixes, against the
row reserved by `_items_layout()`. It walks every item in every current roster
pack at 1280×720, 800×450, 640×360 and both live resize directions, and repeats
this for all five names in the separately declared shipped-weapon fixture.
Before the source fix, the focused suite failed 9/10 tests (714 assertions):
at 640×360 the actual marker-prefixed equipped `Bulwark Lance` and `Verdant
Blade` text wrapped to an extra line and exceeded the computed row for both
marker forms. `_items_layout()` now reserves the active font's measured width
for the wider marker before wrapping; row height and scrolling use those
complete lines. The final Items suite passes **10/10, 771 assertions**.

The combined accepted-main Journal Items/Supports/System/input/close/save
boundary passes **134/134 tests, 18,744 assertions / 14 scripts** under the
common Git-directory `vael-godot-heavy.lock` and disposable XDG data. It includes
all Journal tab layout/input groups, keyboard controls/preferences, inventory,
SaveSystem and Campaign load validation. It reported 96 inherited wait-frame
deprecations and expected keyboard-settings malformed/unwritable fixture
diagnostics; no test failed. No unchanged full GUT/import/helper baseline was
repeated.

This wrapping correction is a source delta after the existing native captures,
so those captures remain attributed to their recorded pre-correction source.
No GUI job was launched: #133 owns slot b and #114 has no current GUI naming.
A bounded original-Forward+ delta check is still needed after the lead names
#114 a GUI task slot. Exact-head Verify is pending for the integration commit.


### Named slot-B source-delta QA and feedback clearance

The continuation issue body named #114 for isolated slot B after #133 released
all graphical jobs. The actual source base for this delta was
`59faa49ea1904d828dc9187033c26d0bc777cacf`, already containing the accepted
Supports integration and measured rendered-marker correction. A second native
finding arose during the requested full-pack refusal inspection: at 640×360,
the floating inventory refusal toast covered the stage instruction. The
SubViewport feedback-clearance regression failed at 1280×720, 800×450 and
640×360 before a narrow Items-only correction reserved a measured 14 px
feedback line above the contextual hint and ended visible item rows above the
feedback line. The System reserved message branch and shared load-error toast
branch are unchanged.

After that correction, the focused production-SubViewport suite passes
**10/10 tests, 780 assertions**. The combined accepted-main
Items/Supports/System/Journal/input/close/custom-key/load-feedback/inventory/
Campaign/SaveSystem boundary passes **134/134 tests, 18,753 assertions / 14
scripts** under the common heavy lock and disposable XDG profile. These are
headless regression/runtime checks; no unchanged full GUT/import/helper run
was repeated.

The lead named #114 for slot B only after #133 explicitly released it
([release comment](https://github.com/KumarG23/vael-academy/pull/134#issuecomment-6388536358)).
Godot 4.7.2 original Forward+ was launched from ordinary Title → Load on a
separate copy of the earned Week 2 checkpoint. The source checkpoint SHA-256
was `681e0c32af7483a6b48abdfe2c0c612ee65cf5450352d62ca5a8a431275b1fe4`;
the isolated slot-0 copy matched it before interaction and still matched it
after close. The fixture override hash was
`16ce6cd1c306f6ab9b0d4baa6115a9ce516e8ba7b9da6564f1fd6ff6cd7f4d42`; its
separate slot copy was `ae2c5ecb0aa9d551a778639281d6abb9f5b166c4cdc838ec199ba82c54fe8fe7`
before and after the refusal/browse flow. That override is explicitly
supplementary fixture data, not earned progress. The checked-in earned save
was not modified.

In the earned copy, the actual client window was measured at 1280×720,
800×450 and 640×360, and shrunk/restored in both item and recipient stages.
Bulwark Lance and Verdant Blade selected and unselected row states were
inspected at the default and 800×450 sizes; the selected wrapped/equipped
labels were inspected at 640×360. At compact size the one-row window means a
neighboring item may scroll out while selected; the regression checks both
marker forms for every shipped item at all sizes. The active giver and
selected recipient remained visible in recipient mode, and resize/restore
returned to the same default recipient capture hash
(`4ad639c3523f0fad8a15a6ff89575c33bb468e9941ad0263857ff515b3a5b4d7`).

The separately labelled five-item fixture showed first and final rows, full
recipient capacity and the full-pack refusal at all three sizes. At 640×360,
the refusal reads `Perrin's pack is full.` in its own bordered line above the
complete recipient instruction, with the selected Ember Heir's Lance, Kai
as giver, Perrin as selected full recipient and pack counts visible. The
toast's expiry/back path and ordinary close to campus were also captured.
No fixture transfer was saved. The earned-copy browse/cancel/close hash stayed
equal to the original source hash. Prior earned successful-transfer and
save/reload evidence remains exactly as recorded above; this narrow source
delta did not repeat that transfer path because transfer/save behavior is
unchanged.

New inspected captures are in [`images-delta/`](images-delta/), with exact
per-image hashes and the current source/test hashes in
[`capture-hashes.sha256`](capture-hashes.sha256). The captures are original
desktop screenshots with the game client at the stated size, not crops. All
slot-B game, input and capture processes ended through the driver `quit`; the
slot was released. Evidence establishes the requested bounded presentation
delta, not a full graphical playthrough or Neal's visual approval. No canon
contradiction was found.

Exact-head Verify and lead delta review are still required; PR #130 remains a
draft until those gates pass.
