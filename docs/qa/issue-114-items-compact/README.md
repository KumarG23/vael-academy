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
